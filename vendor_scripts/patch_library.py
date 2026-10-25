#!/usr/bin/env python3

import argparse
import shutil
import struct
import sys
from pathlib import Path

from elftools.elf.elffile import ELFFile


DT_NEEDED = "DT_NEEDED"
DT_STRTAB = "DT_STRTAB"
DT_STRSZ = "DT_STRSZ"

PT_LOAD = "PT_LOAD"
PT_DYNAMIC = "PT_DYNAMIC"
PT_INTERP = "PT_INTERP"

ELF32_DYN_SIZE = 8


def align_up(value, alignment):
    if alignment <= 1:
        return value
    return (value + alignment - 1) & ~(alignment - 1)


class ELFError(Exception):
    pass


class ELFEditor:
    def __init__(self, path):
        self.path = Path(path)
        self.data = bytearray(self.path.read_bytes())

        # pyelftools is used only for parsing.
        #
        # The actual modifications are performed on self.data because
        # pyelftools is primarily an ELF reader, not a binary patcher.
        self.elf = ELFFile(self._file())

        if self.elf.elfclass != 32:
            raise ELFError("Only ELF32 is supported by this script")

        if self.elf.little_endian is False:
            raise ELFError("Only little-endian ELF is supported")

        self.load_segments = []
        self.dynamic_segment = None
        self.interp_segment = None

        for segment in self.elf.iter_segments():
            p_type = segment["p_type"]

            if p_type == PT_LOAD:
                self.load_segments.append(segment)

            elif p_type == PT_DYNAMIC:
                self.dynamic_segment = segment

            elif p_type == PT_INTERP:
                self.interp_segment = segment

        if self.dynamic_segment is None:
            raise ELFError("ELF has no PT_DYNAMIC segment")

    def _file(self):
        """
        Create a file-like object from the current byte buffer.

        ELFFile needs a seekable file object. Using bytes here means
        pyelftools always parses the original/current in-memory image.
        """
        import io
        return io.BytesIO(self.data)

    def reopen(self):
        """
        Recreate the pyelftools ELF object after modifications.

        This is necessary because pyelftools keeps references to the
        original file object.
        """
        self.elf = ELFFile(self._file())
        self.load_segments = []
        self.dynamic_segment = None
        self.interp_segment = None

        for segment in self.elf.iter_segments():
            p_type = segment["p_type"]

            if p_type == PT_LOAD:
                self.load_segments.append(segment)

            elif p_type == PT_DYNAMIC:
                self.dynamic_segment = segment

            elif p_type == PT_INTERP:
                self.interp_segment = segment

    def get_dynamic_entries(self):
        """
        Return dynamic entries together with their raw file offsets.

        An ELF32 dynamic entry consists of:

            d_tag : 4 bytes
            d_val : 4 bytes

        PT_DYNAMIC gives us the FILE offset of the first entry, so the
        file offset of d_val is:

            dynamic_offset + index * 8 + 4
        """
        segment = self.dynamic_segment

        base = segment["p_offset"]
        size = segment["p_filesz"]

        entries = []

        for index in range(size // ELF32_DYN_SIZE):
            offset = base + index * ELF32_DYN_SIZE

            tag, value = struct.unpack_from("<II", self.data, offset)

            entries.append({
                "index": index,
                "offset": offset,
                "tag": tag,
                "value": value,
                "value_offset": offset + 4,
            })

            if tag == 0:
                break

        return entries

    def find_dynamic(self, name):
        """
        Find a DT_* entry by its symbolic name.

        pyelftools is used here to identify the meaning of the tag.
        The returned object additionally contains the RAW FILE offset
        of the d_val field, which is what we need when patching it.
        """
        wanted = name

        for entry in self.get_dynamic_entries():
            tag_name = self._dynamic_tag_name(entry["tag"])

            if tag_name == wanted:
                return entry

        return None

    @staticmethod
    def _dynamic_tag_name(tag):
        """
        Convert a numeric DT_* value into its symbolic name.

        The values below are the standard ELF32 dynamic tags we need.
        """
        names = {
            0: "DT_NULL",
            1: "DT_NEEDED",
            5: "DT_STRTAB",
            10: "DT_STRSZ",
            14: "DT_SONAME",
        }

        return names.get(tag, f"DT_UNKNOWN_{tag}")

    def get_string_table(self):
        """
        Locate DT_STRTAB in the FILE.

        DT_STRTAB contains a VIRTUAL ADDRESS, not a file offset.

        pyelftools provides address_offsets(), which translates an ELF
        virtual address into a file offset using PT_LOAD segments:

            file_offset =
                p_offset + (virtual_address - p_vaddr)

        This is important because the input ELF may have NO SECTION
        HEADERS at all. Program headers are sufficient.
        """
        strtab = self.find_dynamic(DT_STRTAB)

        if strtab is None:
            raise ELFError("DT_STRTAB not found")

        strtab_vaddr = strtab["value"]

        offsets = list(self.elf.address_offsets(strtab_vaddr))

        if not offsets:
            raise ELFError(
                f"Cannot translate DT_STRTAB address "
                f"0x{strtab_vaddr:x} to a file offset"
            )

        strtab_offset = offsets[0]

        strsz = self.find_dynamic(DT_STRSZ)

        if strsz is None:
            raise ELFError("DT_STRSZ not found")

        return {
            "vaddr": strtab_vaddr,
            "offset": strtab_offset,
            "size": strsz["value"],
            "strsz_entry": strsz,
        }

    def read_string(self, file_offset):
        """
        Read a NUL-terminated string directly from the ELF file.
        """
        end = self.data.find(b"\0", file_offset)

        if end == -1:
            raise ELFError(
                f"Unterminated ELF string at 0x{file_offset:x}"
            )

        return self.data[file_offset:end].decode(
            "utf-8",
            errors="replace",
        )

    def get_needed(self):
        """
        Return all DT_NEEDED entries.

        DT_NEEDED's d_val is NOT a file offset.

        It is an offset relative to DT_STRTAB:

            string_file_offset =
                strtab_file_offset + DT_NEEDED.d_val
        """
        strtab = self.get_string_table()

        result = []

        for entry in self.get_dynamic_entries():
            if self._dynamic_tag_name(entry["tag"]) != DT_NEEDED:
                continue

            string_offset = entry["value"]
            file_offset = strtab["offset"] + string_offset

            result.append({
                "name": self.read_string(file_offset),
                "entry": entry,
                "string_offset": string_offset,
                "file_offset": file_offset,
            })

        return result

    def get_soname(self):
        """
        Return DT_SONAME entry if present, else None.
        """
        entry = self.find_dynamic("DT_SONAME")
        if entry is None:
            return None

        strtab = self.get_string_table()
        string_offset = entry["value"]
        file_offset = strtab["offset"] + string_offset

        return {
            "name": self.read_string(file_offset),
            "entry": entry,
            "string_offset": string_offset,
            "file_offset": file_offset,
        }

    def print_info(self):
        print(f"File: {self.path}")

        if self.interp_segment is not None:
            interp = self.interp_segment.get_interp_name()
            print(f"INTERP : {interp}")
            print(
                f"         file offset 0x"
                f"{self.interp_segment['p_offset']:x}"
            )
        else:
            print("INTERP : <none>")

        soname_info = self.get_soname()
        if soname_info:
            print(f"SONAME : {soname_info['name']}")
            print(f"         string at 0x{soname_info['file_offset']:x}")
        else:
            print("SONAME : <none>")

        strtab = self.get_string_table()

        print()
        print(
            f"DT_STRTAB : virtual 0x{strtab['vaddr']:x}, "
            f"file 0x{strtab['offset']:x}"
        )
        print(f"DT_STRSZ  : {strtab['size']}")

        print()
        print("NEEDED:")

        for item in self.get_needed():
            print(
                f"  {item['name']} "
                f"(string at 0x{item['file_offset']:x})"
            )

    def allocate_string_space(self, size):
        """
        Allocate space for a new string strictly at the end of a PT_LOAD segment.
        If the gap between Segment 0 and Segment 1 is large enough, allocate at the end of Segment 0.
        Otherwise, allocate at the end of the last PT_LOAD segment (e.g. Segment 1), where the file can grow freely.

        Returns (alloc_file_offset, d_val) where d_val is the offset relative to DT_STRTAB (vaddr - strtab_vaddr).
        """
        strtab = self.get_string_table()
        strtab_vaddr = strtab["vaddr"]

        if not self.load_segments:
            return None, None

        s0 = self.load_segments[0]
        s_last = self.load_segments[-1]
        needed_growth = align_up(size, 4)

        # Check if s0 has enough gap before s1
        gap = (self.load_segments[1]["p_offset"] - (s0["p_offset"] + s0["p_filesz"])) if len(self.load_segments) > 1 else 99999999

        if needed_growth <= gap:
            target_seg = s0
        else:
            target_seg = s_last

        curr_offset = target_seg["p_offset"]
        curr_filesz = target_seg["p_filesz"]
        curr_memsz = target_seg["p_memsz"]
        alloc_offset = curr_offset + curr_filesz
        alloc_vaddr = target_seg["p_vaddr"] + curr_filesz
        d_val = alloc_vaddr - strtab_vaddr

        ph_offset = self._find_program_header(target_seg, "PT_LOAD")
        new_filesz = curr_filesz + needed_growth
        new_memsz = max(curr_memsz, curr_filesz) + needed_growth

        struct.pack_into("<I", self.data, ph_offset + 16, new_filesz)
        struct.pack_into("<I", self.data, ph_offset + 20, new_memsz)

        if len(self.data) < alloc_offset + needed_growth:
            self.data.extend(b"\x00" * (alloc_offset + needed_growth - len(self.data)))
        else:
            self.data[alloc_offset : alloc_offset + needed_growth] = b"\x00" * needed_growth

        self.reopen()
        return alloc_offset, d_val

    def get_or_add_string(self, new_name):
        """
        Find an existing string in DT_STRTAB or allocate space at the end of PT_LOAD.
        Returns the string offset relative to DT_STRTAB.
        """
        strtab = self.get_string_table()
        strtab_offset = strtab["offset"]
        strtab_size = strtab["size"]
        new_data = new_name.encode("utf-8") + b"\0"

        # 1. Check if string is already present in string table
        existing_idx = self.data[strtab_offset : strtab_offset + strtab_size].find(new_data)
        if existing_idx != -1:
            return existing_idx

        # 2. Allocate at the end of PT_LOAD segment
        new_file_offset, d_val = self.allocate_string_space(len(new_data))
        if new_file_offset is None:
            raise ELFError(f"Not enough space to add '{new_name}' to PT_LOAD")

        self.data[new_file_offset : new_file_offset + len(new_data)] = new_data

        new_end = d_val + len(new_data)
        if new_end > strtab["size"]:
            struct.pack_into(
                "<I",
                self.data,
                strtab["strsz_entry"]["value_offset"],
                new_end,
            )

        self.reopen()
        return d_val

    def patch_soname(self, new_name):
        """
        Replace DT_SONAME entry.

        If the new name fits into the old string area, replace it in place.
        Otherwise, allocate at the end of PT_LOAD and update DT_SONAME and DT_STRSZ.
        """
        soname_info = self.get_soname()
        if soname_info is None:
            raise ELFError("ELF has no DT_SONAME entry")

        old_name = soname_info["name"]
        old_file_offset = soname_info["file_offset"]
        old_length = len(old_name) + 1
        new_data = new_name.encode("utf-8") + b"\0"

        if len(new_data) <= old_length:
            self.data[
                old_file_offset:
                old_file_offset + len(new_data)
            ] = new_data

            remaining = old_length - len(new_data)
            if remaining:
                self.data[
                    old_file_offset + len(new_data):
                    old_file_offset + old_length
                ] = b"\0" * remaining

            print(
                f"SONAME: {old_name} -> {new_name} "
                f"(in place at 0x{old_file_offset:x})"
            )
            return

        new_string_offset = self.get_or_add_string(new_name)
        struct.pack_into(
            "<I",
            self.data,
            soname_info["entry"]["value_offset"],
            new_string_offset,
        )

        print(
            f"SONAME: {old_name} -> {new_name} "
            f"(string offset 0x{new_string_offset:x})"
        )
        self.reopen()

    def patch_needed(self, old_name, new_name):
        """
        Replace one DT_NEEDED entry.

        If the new name fits into the old string area, replace it in place.
        Otherwise, append it to the end of PT_LOAD, avoiding overwriting any ELF data.
        """
        needed = self.get_needed()

        matches = [
            item for item in needed
            if item["name"] == old_name
        ]

        if not matches:
            raise ELFError(
                f"DT_NEEDED entry '{old_name}' was not found"
            )

        if len(matches) > 1:
            raise ELFError(
                f"DT_NEEDED entry '{old_name}' occurs multiple times"
            )

        item = matches[0]

        old_file_offset = item["file_offset"]
        old_length = len(old_name) + 1
        new_data = new_name.encode("utf-8") + b"\0"

        if len(new_data) <= old_length:
            # The replacement fits into the existing string.
            self.data[
                old_file_offset:
                old_file_offset + len(new_data)
            ] = new_data

            # Clear any remaining bytes from the old string.
            remaining = old_length - len(new_data)
            if remaining:
                self.data[
                    old_file_offset + len(new_data):
                    old_file_offset + old_length
                ] = b"\0" * remaining

            print(
                f"NEEDED: {old_name} -> {new_name} "
                f"(in place at 0x{old_file_offset:x})"
            )
            return

        new_string_offset = self.get_or_add_string(new_name)

        # Update DT_NEEDED.d_val.
        struct.pack_into(
            "<I",
            self.data,
            item["entry"]["value_offset"],
            new_string_offset,
        )

        print(
            f"NEEDED: {old_name} -> {new_name} "
            f"(string offset 0x{new_string_offset:x})"
        )
        self.reopen()

    def patch_interp(self, new_interp):
        """
        Replace PT_INTERP.

        PT_INTERP.p_offset directly specifies the FILE offset of the
        interpreter string.

        If the new interpreter fits into the existing PT_INTERP area,
        replace it in place.
        """
        if self.interp_segment is None:
            raise ELFError("ELF has no PT_INTERP segment")

        segment = self.interp_segment

        old_offset = segment["p_offset"]
        old_size = segment["p_filesz"]

        new_data = new_interp.encode("utf-8") + b"\0"

        if len(new_data) <= old_size:
            self.data[
                old_offset:
                old_offset + len(new_data)
            ] = new_data

            # Clear unused bytes in the PT_INTERP area.
            remaining = old_size - len(new_data)

            if remaining:
                self.data[
                    old_offset + len(new_data):
                    old_offset + old_size
                ] = b"\0" * remaining

            print(
                f"INTERP: {segment.get_interp_name()} -> "
                f"{new_interp} "
                f"(in place at 0x{old_offset:x})"
            )

            return

        # Need to relocate the interpreter string to the end of PT_LOAD.
        new_offset, _ = self.allocate_string_space(len(new_data))

        if new_offset is None:
            raise ELFError(
                f"Not enough space for new INTERP '{new_interp}'"
            )

        self.data[
            new_offset:
            new_offset + len(new_data)
        ] = new_data

        phdr_offset = self._find_program_header(
            segment,
            PT_INTERP,
        )

        struct.pack_into(
            "<I",
            self.data,
            phdr_offset + 4,
            new_offset,
        )

        struct.pack_into(
            "<I",
            self.data,
            phdr_offset + 16,
            len(new_data),
        )

        print(
            f"INTERP: {segment.get_interp_name()} -> "
            f"{new_interp} "
            f"(relocated to 0x{new_offset:x})"
        )

        self.reopen()

    def _find_program_header(self, segment, expected_type):
        """
        Find the raw PROGRAM header corresponding to a pyelftools
        segment.

        We compare p_offset and p_filesz because they uniquely identify
        the segment in this context.
        """
        type_val = expected_type
        if isinstance(expected_type, str):
            type_map = {
                "PT_NULL": 0,
                "PT_LOAD": 1,
                "PT_DYNAMIC": 2,
                "PT_INTERP": 3,
                "PT_TLS": 7,
            }
            type_val = type_map.get(expected_type, expected_type)

        e_phoff = self.elf.header["e_phoff"]
        e_phentsize = self.elf.header["e_phentsize"]
        e_phnum = self.elf.header["e_phnum"]

        for index in range(e_phnum):
            offset = e_phoff + index * e_phentsize

            p_type = struct.unpack_from(
                "<I",
                self.data,
                offset,
            )[0]

            p_offset = struct.unpack_from(
                "<I",
                self.data,
                offset + 4,
            )[0]

            p_filesz = struct.unpack_from(
                "<I",
                self.data,
                offset + 16,
            )[0]

            if (
                p_type == type_val
                and p_offset == segment["p_offset"]
                and p_filesz == segment["p_filesz"]
            ):
                return offset

        raise ELFError(
            f"Could not find raw program header for {expected_type}"
        )

    def save(self, output):
        output = Path(output)
        output.write_bytes(self.data)
        print(f"\nWritten: {output}")


def parse_needed(value):
    """
    Parse:

        old.so=new.so

    into:

        ("old.so", "new.so")
    """
    if "=" not in value:
        raise argparse.ArgumentTypeError(
            "--needed must have the form OLD=NEW"
        )

    old, new = value.split("=", 1)

    if not old or not new:
        raise argparse.ArgumentTypeError(
            "--needed must have the form OLD=NEW"
        )

    return old, new


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Patch ELF32 dynamic dependencies without "
            "requiring section headers."
        )
    )

    parser.add_argument(
        "input",
        help="Input ELF file",
    )

    parser.add_argument(
        "--needed",
        action="append",
        type=parse_needed,
        default=[],
        metavar="OLD=NEW",
        help="Replace a DT_NEEDED library",
    )

    parser.add_argument(
        "--interp",
        metavar="PATH",
        help="Replace the ELF PT_INTERP interpreter",
    )

    parser.add_argument(
        "--soname",
        metavar="NAME",
        help="Replace the ELF DT_SONAME",
    )

    parser.add_argument(
        "-o",
        "--output",
        metavar="FILE",
        help="Output file (default: INPUT.patched)",
    )

    parser.add_argument(
        "--backup",
        action="store_true",
        help="Create INPUT.bak before patching",
    )

    parser.add_argument(
        "--info",
        action="store_true",
        help="Only display ELF information",
    )

    args = parser.parse_args()

    input_path = Path(args.input)

    if not input_path.is_file():
        print(
            f"ERROR: file not found: {input_path}",
            file=sys.stderr,
        )
        return 1

    try:
        editor = ELFEditor(input_path)

        if args.info:
            editor.print_info()
            return 0

        if not args.needed and not args.interp and not args.soname:
            parser.error(
                "nothing to patch; use --needed, --interp, and/or --soname"
            )

        if args.backup:
            backup = input_path.with_suffix(
                input_path.suffix + ".bak"
            )

            shutil.copy2(input_path, backup)
            print(f"Backup: {backup}")

        for old_name, new_name in args.needed:
            editor.patch_needed(old_name, new_name)

        if args.interp:
            editor.patch_interp(args.interp)

        if args.soname:
            editor.patch_soname(args.soname)

        if args.output:
            output = Path(args.output)
        else:
            output = input_path.with_name(
                input_path.name + ".patched"
            )

        editor.save(output)

        print()
        print("Verification:")
        verifier = ELFEditor(output)
        verifier.print_info()

        return 0

    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
