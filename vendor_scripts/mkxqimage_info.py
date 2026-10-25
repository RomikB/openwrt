#!/usr/bin/env python3
"""
mkxqimage_info.py - Parse and extract MiWiFi HDR1/BABE firmware packages.

Reference: docs/miwifi_rd15_firmware_format.md

Sub-commands:
  info      (default) Show HDR1 header fields and all BABE segment descriptors.
                      Prints the xiaoqiang_version payload text (seg0 content).
  extract   Extract payloads of BABE1+ segments to files named after the
            BABE 'filename' field.  Seg0 (xiaoqiang_version) is always shown
            as text and never written to disk during extraction.

Usage:
  python3 vendor_scripts/mkxqimage_info.py <firmware.bin>
  python3 vendor_scripts/mkxqimage_info.py <firmware.bin> extract [--outdir DIR]

Examples:
  python3 vendor_scripts/mkxqimage_info.py miwifi_rd15_firmware_89297_1.0.81.bin
  python3 vendor_scripts/mkxqimage_info.py miwifi_rd15_firmware_89297_1.0.81.bin extract
  python3 vendor_scripts/mkxqimage_info.py my_custom.bin extract --outdir /tmp/fw_out
"""

import argparse
import os
import struct
import sys
from pathlib import Path
from typing import List, NamedTuple, Optional


# ---------------------------------------------------------------------------
# Format constants
# ---------------------------------------------------------------------------

HDR1_MAGIC      = b'HDR1'
HDR1_SIZE       = 0x90        # always 144 bytes
BABE_MAGIC      = 0xBABE
BABE_ENTRY_SIZE = 0x30        # 48 bytes per descriptor
TRAILER_SIZE    = 272         # 16-byte header + 256-byte RSA sig

# HDR1 field offsets
HDR1_OFF_TOTAL_SIZE   = 0x04
HDR1_OFF_CHECKSUM     = 0x08
HDR1_OFF_FLAGS        = 0x0C
HDR1_OFF_HDR_LEN      = 0x10
HDR1_OFF_SIGN_EXT_LEN = 0x14

# BABE descriptor field offsets (relative to descriptor start)
BABE_OFF_MAGIC      = 0x00   # uint16 LE
BABE_OFF_RSVD0      = 0x02   # uint16 LE
BABE_OFF_FLASH_ADDR = 0x04   # uint32 LE (0xFFFFFFFF = auto)
BABE_OFF_LENGTH     = 0x08   # uint32 LE
BABE_OFF_PARTITION  = 0x0C   # uint16 LE (0xFFFF = auto)
BABE_OFF_LE_MAGIC   = 0x0E   # uint16 LE
BABE_OFF_FILENAME   = 0x10   # char[32], null-padded


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

class Hdr1(NamedTuple):
    total_size:   int   # file_size - TRAILER_SIZE (not covered by CRC or RSA)
    checksum:     int   # CRC-32: zlib.crc32(data[12:]) ^ 0xFFFFFFFF
    flags:        int   # 0x00550000 -> SHA-256; 0x00540000 -> SHA-1
    hdr_len:      int   # always 0x90 (144 bytes)
    sign_ext_len: int   # byte offset where signed payload metadata ends


class BabeSegment(NamedTuple):
    index:       int
    desc_offset: int    # byte offset of this descriptor in file
    flash_addr:  int    # 0xFFFFFFFF = auto
    length:      int    # exact payload length (unpadded)
    partition:   int    # 0xFFFF = auto
    filename:    str    # segment name from descriptor
    payload_off: int    # byte offset of payload start in file
    padded_len:  int    # length rounded up to 4-byte boundary


# ---------------------------------------------------------------------------
# Parser
# ---------------------------------------------------------------------------

def u16le(data: bytes, off: int) -> int:
    return struct.unpack_from('<H', data, off)[0]

def u32le(data: bytes, off: int) -> int:
    return struct.unpack_from('<I', data, off)[0]

def nullterm(data: bytes, off: int, maxlen: int) -> str:
    chunk = data[off:off + maxlen]
    end = chunk.find(b'\x00')
    if end >= 0:
        chunk = chunk[:end]
    return chunk.decode('ascii', errors='replace')


def parse_hdr1(data: bytes) -> Hdr1:
    if data[:4] != HDR1_MAGIC:
        raise ValueError(f"Not an HDR1 image: magic={data[:4]!r}")
    return Hdr1(
        total_size   = u32le(data, HDR1_OFF_TOTAL_SIZE),
        checksum     = u32le(data, HDR1_OFF_CHECKSUM),
        flags        = u32le(data, HDR1_OFF_FLAGS),
        hdr_len      = u32le(data, HDR1_OFF_HDR_LEN),
        sign_ext_len = u32le(data, HDR1_OFF_SIGN_EXT_LEN),
    )


def parse_segments(data: bytes, hdr: Hdr1) -> List[BabeSegment]:
    """Walk BABE descriptor chain starting at hdr.hdr_len."""
    segments = []
    offset = hdr.hdr_len          # first descriptor starts right after HDR1
    payload_limit = hdr.total_size # payloads end before the trailer
    idx = 0

    while offset + BABE_ENTRY_SIZE <= payload_limit:
        magic = u16le(data, offset)
        if magic != BABE_MAGIC:
            break   # no more descriptors

        flash_addr  = u32le(data, offset + BABE_OFF_FLASH_ADDR)
        length      = u32le(data, offset + BABE_OFF_LENGTH)
        partition   = u16le(data, offset + BABE_OFF_PARTITION)
        filename    = nullterm(data, offset + BABE_OFF_FILENAME, 32)
        payload_off = offset + BABE_ENTRY_SIZE

        # Payload is padded to next 4-byte boundary before the next descriptor
        padded_len = (length + 3) & ~3

        segments.append(BabeSegment(
            index       = idx,
            desc_offset = offset,
            flash_addr  = flash_addr,
            length      = length,
            partition   = partition,
            filename    = filename,
            payload_off = payload_off,
            padded_len  = padded_len,
        ))

        offset = payload_off + padded_len
        idx += 1

    return segments


# ---------------------------------------------------------------------------
# Info printer
# ---------------------------------------------------------------------------

RESET  = '\033[0m'
BOLD   = '\033[1m'
CYAN   = '\033[96m'
GREEN  = '\033[92m'
YELLOW = '\033[93m'
RED    = '\033[91m'
DIM    = '\033[2m'

def colored(text: str, color: str, use_color: bool = True) -> str:
    if not use_color:
        return text
    return color + text + RESET


def cmd_info(data: bytes, use_color: bool) -> None:
    file_size = len(data)

    # ── HDR1 ────────────────────────────────────────────────────────────────
    hdr = parse_hdr1(data)
    computed_trailer_start = hdr.total_size
    trailer = data[computed_trailer_start:computed_trailer_start + TRAILER_SIZE]
    trailer_ver = u32le(trailer, 0) if len(trailer) >= 4 else 0
    rsa_sig     = trailer[16:272] if len(trailer) >= 272 else b''
    sig_nonzero = any(b != 0 for b in rsa_sig)

    checksum_ok  = (hdr.checksum != 0)
    sig_ok       = sig_nonzero

    # CRC-32 verification
    import zlib
    computed_crc = zlib.crc32(data[12:]) ^ 0xFFFFFFFF
    crc_match    = (computed_crc == hdr.checksum)

    # Hash algorithm from flags (HDR1 +0x0C high byte, empirically verified):
    #   0x55 (stock 1.0.68 / 1.0.81) -> SHA-256  (confirmed via openssl dgst)
    #   0x54 (older images)           -> SHA-1    (inferred)
    #   0x01 / 0x00 (single-path)     -> SHA-1
    flags_hash = (hdr.flags >> 16) & 0xFF
    if flags_hash >= 0x50:          # 0x55 = stock release images -> SHA-256
        hash_algo = "SHA-256"
    elif flags_hash & 0x01:
        hash_algo = "SHA-1"
    else:
        hash_algo = f"unknown (flags_byte=0x{flags_hash:02X})"

    print()
    print(colored("═" * 62, CYAN, use_color))
    print(colored("  HDR1 Header", BOLD, use_color))
    print(colored("═" * 62, CYAN, use_color))

    def field(name, raw_val, note=""):
        label = colored(f"  {name:<18}", DIM, use_color)
        val   = colored(raw_val, BOLD, use_color)
        n     = ("  " + colored(note, YELLOW, use_color)) if note else ""
        print(f"{label}{val}{n}")

    field("magic",        f"{data[0:4]}")
    field("total_size",   f"0x{hdr.total_size:08X}  = {hdr.total_size:,} B"
                          f"  ({hdr.total_size/1024/1024:.2f} MiB)")
    if crc_match:
        crc_note = colored(f"CRC-32 OK  (computed: 0x{computed_crc:08X})", GREEN, use_color)
    elif not checksum_ok:
        crc_note = colored("ZERO — placeholder (not yet computed)", RED, use_color)
    else:
        crc_note = colored(f"CRC-32 MISMATCH!  expected: 0x{computed_crc:08X}", RED, use_color)
    print(f"  {'checksum':<18}{colored(f'0x{hdr.checksum:08X}', BOLD, use_color)}  {crc_note}")
    field("flags",        f"0x{hdr.flags:08X}  → RSA sig uses {hash_algo}")
    field("hdr_len",      f"0x{hdr.hdr_len:08X}  = {hdr.hdr_len} B")
    field("sign_ext_len", f"0x{hdr.sign_ext_len:08X}  = {hdr.sign_ext_len:,} B")
    field("file_size",    f"{file_size:,} B  ({file_size/1024/1024:.2f} MiB)")

    print(colored("  ─" * 31, DIM, use_color))

    # trailer info
    rsa_sig_len = u16le(trailer, 0) if len(trailer) >= 2 else 0  # should be 0x0100 = 256
    rsa_sig_len_ok = (rsa_sig_len == 256)
    sig_len_note = (
        colored(f"{rsa_sig_len} B  (RSA-2048)", GREEN, use_color) if rsa_sig_len_ok
        else colored(f"{rsa_sig_len} B  (unexpected!)", RED, use_color)
    )
    if not sig_nonzero:
        sig_info = colored("256 × 0x00  (PLACEHOLDER — zeros)", RED, use_color)
    else:
        sig_info = colored(f"256 bytes non-zero  (RSA-2048/{hash_algo} signature present)", GREEN, use_color)

    print(f"  {'Trailer offset':<18}{colored(f'0x{computed_trailer_start:08X}', BOLD, use_color)}")
    print(f"  {'sig_size':<18}{colored(f'0x{rsa_sig_len:04X}', BOLD, use_color)}  {sig_len_note}")
    print(f"  {'RSA signature':<18}{sig_info}")

    # ── Segments ─────────────────────────────────────────────────────────────
    segments = parse_segments(data, hdr)

    print()
    print(colored("═" * 62, CYAN, use_color))
    print(colored(f"  BABE Segments  ({len(segments)} found)", BOLD, use_color))
    print(colored("═" * 62, CYAN, use_color))

    for seg in segments:
        label  = colored(f"  ── Segment {seg.index}", CYAN, use_color)
        fname  = colored(f"'{seg.filename}'", GREEN, use_color)
        print(f"\n{label}  {fname}")
        field("desc_offset",  f"0x{seg.desc_offset:08X}")
        field("payload_offset", f"0x{seg.payload_off:08X}")
        field("flash_addr",
              "0xFFFFFFFF  (auto-detect)" if seg.flash_addr == 0xFFFFFFFF
              else f"0x{seg.flash_addr:08X}")
        field("partition",
              "0xFFFF  (auto-detect)" if seg.partition == 0xFFFF
              else f"0x{seg.partition:04X}")
        field("length",
              f"{seg.length:,} B  ({seg.length/1024:.1f} KiB)" if seg.length < 1024*1024
              else f"{seg.length:,} B  ({seg.length/1024/1024:.2f} MiB)")
        if seg.padded_len != seg.length:
            field("padded_len",  f"{seg.padded_len:,} B  (+{seg.padded_len-seg.length} B pad)")

        # Seg0: print text content
        if seg.index == 0:
            payload = data[seg.payload_off : seg.payload_off + seg.length]
            try:
                text = payload.decode('utf-8').strip()
                print()
                print(colored("  ── xiaoqiang_version content:", DIM, use_color))
                for line in text.splitlines():
                    print(colored(f"       {line}", DIM, use_color))
            except UnicodeDecodeError:
                print(colored(f"  (binary payload, cannot decode as UTF-8)", YELLOW, use_color))

    # ── Memory map ────────────────────────────────────────────────────────────
    print()
    print(colored("═" * 62, CYAN, use_color))
    print(colored("  Memory Map", BOLD, use_color))
    print(colored("═" * 62, CYAN, use_color))

    rows = []
    rows.append((0, hdr.hdr_len, "HDR1 header", ""))
    for seg in segments:
        rows.append((seg.desc_offset, seg.desc_offset + BABE_ENTRY_SIZE,
                     f"BABE desc {seg.index}", f"'{seg.filename}'"))
        rows.append((seg.payload_off, seg.payload_off + seg.padded_len,
                     f"Payload {seg.index}",
                     f"'{seg.filename}'"
                     + (f" + {seg.padded_len - seg.length}B pad"
                        if seg.padded_len != seg.length else "")))
    rows.append((computed_trailer_start, file_size,
                 "Signature trailer", "272 B"))

    for start, end, name, note in rows:
        addr_str = colored(f"  0x{start:08X}..0x{end-1:08X}", BOLD, use_color)
        size_str = colored(f"({end-start:>10,} B)", DIM, use_color)
        note_str = colored(f"  {note}", YELLOW, use_color) if note else ""
        print(f"{addr_str}  {size_str}  {name}{note_str}")

    print()


# ---------------------------------------------------------------------------
# Extract
# ---------------------------------------------------------------------------

def cmd_extract(data: bytes, outdir: str, use_color: bool) -> None:
    hdr = parse_hdr1(data)
    segments = parse_segments(data, hdr)

    if not segments:
        print("No BABE segments found.", file=sys.stderr)
        sys.exit(1)

    Path(outdir).mkdir(parents=True, exist_ok=True)

    # Seg0: show text, never extract
    seg0 = segments[0]
    payload0 = data[seg0.payload_off : seg0.payload_off + seg0.length]
    print(colored(f"\n[0] '{seg0.filename}'  ({seg0.length} B) — metadata only, not extracted",
                  YELLOW, use_color))
    try:
        print(payload0.decode('utf-8').strip())
    except UnicodeDecodeError:
        print(f"  (binary)")

    # Seg1+: extract to files
    extracted = 0
    for seg in segments[1:]:
        payload = data[seg.payload_off : seg.payload_off + seg.length]
        out_path = Path(outdir) / seg.filename
        out_path.write_bytes(payload)
        size_str = (f"{seg.length/1024/1024:.2f} MiB"
                    if seg.length >= 1024*1024 else f"{seg.length:,} B")
        print(colored(
            f"\n[{seg.index}] '{seg.filename}'  "
            f"({size_str})  → {out_path}",
            GREEN, use_color))
        extracted += 1

    print()
    if extracted:
        print(colored(f"Extracted {extracted} segment(s) to: {outdir}", BOLD, use_color))
    else:
        print(colored("Only 1 segment found (seg0 = metadata). Nothing to extract.", YELLOW, use_color))
    print()


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    ap = argparse.ArgumentParser(
        prog='mkxqimage_info.py',
        description='Parse and extract MiWiFi HDR1/BABE firmware packages',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            'Sub-commands:\n'
            '  (none)    Show header info and segment list (default)\n'
            '  extract   Extract BABE1+ payloads to files\n'
            '\n'
            'Examples:\n'
            '  python3 vendor_scripts/mkxqimage_info.py miwifi_rd15_firmware_89297_1.0.81.bin\n'
            '  python3 vendor_scripts/mkxqimage_info.py my.bin extract --outdir /tmp/out\n'
        ),
    )
    ap.add_argument('firmware', metavar='FIRMWARE',
                    help='Path to HDR1/BABE firmware .bin file')
    ap.add_argument('cmd', nargs='?', default='info',
                    choices=['info', 'extract'],
                    help='Sub-command: info (default) or extract')
    ap.add_argument('--outdir', '-d', default='.',
                    metavar='DIR',
                    help='Output directory for extract (default: current dir)')
    ap.add_argument('--no-color', action='store_true',
                    help='Disable ANSI color output')

    args = ap.parse_args()
    use_color = not args.no_color and sys.stdout.isatty()

    fw_path = os.path.abspath(args.firmware)
    if not os.path.isfile(fw_path):
        ap.error(f"File not found: {fw_path}")

    try:
        data = Path(fw_path).read_bytes()
    except OSError as exc:
        print(f"ERROR reading file: {exc}", file=sys.stderr)
        sys.exit(1)

    try:
        if args.cmd == 'info':
            cmd_info(data, use_color)
        elif args.cmd == 'extract':
            cmd_info(data, use_color)     # always show info first
            print(colored("─" * 62, CYAN if use_color else '', use_color))
            print(colored("Extracting segments...", BOLD, use_color))
            cmd_extract(data, os.path.abspath(args.outdir), use_color)
    except ValueError as exc:
        print(colored(f"ERROR: {exc}", RED, use_color), file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
