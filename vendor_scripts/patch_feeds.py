#!/usr/bin/env python3
import os
import sys

def patch_lucihttp_makefile(makefile_path):
    if not os.path.isfile(makefile_path):
        print(f"[patch_feeds] Note: {makefile_path} not found, skipping.")
        return False

    with open(makefile_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Check if already patched
    if "define Package/liblucihttp" in content and "DEPENDS:=+libgcc" in content:
        print(f"[patch_feeds] Already patched: {makefile_path}")
        return True

    # Replace Package/liblucihttp section to include DEPENDS:=+libgcc
    old_target = """define Package/liblucihttp
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=LuCI HTTP utility library
  ABI_VERSION:=0
endef"""

    new_target = """define Package/liblucihttp
  SECTION:=libs
  CATEGORY:=Libraries
  TITLE:=LuCI HTTP utility library
  ABI_VERSION:=0
  DEPENDS:=+libgcc
endef"""

    if old_target in content:
        content = content.replace(old_target, new_target, 1)
        with open(makefile_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"[patch_feeds] Successfully patched: {makefile_path}")
        return True
    else:
        print(f"[patch_feeds] Warning: Target block not found in {makefile_path}")
        return False

def patch_iperf3_makefile(makefile_path):
    if not os.path.isfile(makefile_path):
        print(f"[patch_feeds] Note: {makefile_path} not found, skipping.")
        return False

    with open(makefile_path, 'r', encoding='utf-8') as f:
        content = f.read()

    if "DEPENDS:=+libatomic +libgcc" in content:
        print(f"[patch_feeds] Already patched: {makefile_path}")
        return True

    old_target1 = "  DEPENDS+=+libatomic +libgcc"
    old_target2 = "  DEPENDS+=+libatomic"
    new_target = "  DEPENDS:=+libatomic +libgcc"

    if old_target1 in content:
        content = content.replace(old_target1, new_target, 1)
    elif old_target2 in content:
        content = content.replace(old_target2, new_target, 1)
    else:
        print(f"[patch_feeds] Warning: Target block not found in {makefile_path}")
        return False

    with open(makefile_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"[patch_feeds] Successfully patched: {makefile_path}")
    return True

def patch_amneziawg_feed(repo_root):
    amneziawg_dir = os.path.join(repo_root, "feeds/amneziawg/kmod-amneziawg")
    makefile_path = os.path.join(amneziawg_dir, "Makefile")
    if not os.path.isdir(amneziawg_dir) or not os.path.isfile(makefile_path):
        print(f"[patch_feeds] Note: {makefile_path} not found, skipping.")
        return False

    # 1. Update feeds/amneziawg/kmod-amneziawg/Makefile
    makefile_content = """include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=kmod-amneziawg
PKG_VERSION:=1.0.20260611
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/amnezia-vpn/amneziawg-linux-kernel-module.git
# Version: latest stable release tag
PKG_SOURCE_VERSION:=v$(PKG_VERSION)
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
MAKE_PATH:=src

include $(INCLUDE_DIR)/package.mk

define KernelPackage/amneziawg
\tSECTION:=kernel
\tCATEGORY:=Kernel modules
\tSUBMENU:=Network Support
\tTITLE:=AmneziaWG VPN Kernel Module
\tFILES:=$(PKG_BUILD_DIR)/$(MAKE_PATH)/amneziawg.ko
\tEXTRA_DEPENDS:=
\tDEPENDS:= \\
\t\t+kmod-udptunnel4 \\
\t\t+kmod-udptunnel6 \\
\t\t$(if $(call kernel_version_cmp,-ge,$(LINUX_VERSION),5.6), \\
\t\t\t+kmod-crypto-lib-chacha20poly1305 \\
\t\t\t+kmod-crypto-lib-curve25519 \\
\t\t)
endef

define Build/Prepare
\t$(call Build/Prepare/Default)
\t# Kernel sourcetree is only needed for Linux >= 5.6 (LINUX_VERSION_CODE >= 330240)
\tif [ $(LINUX_VERSION_CODE) -ge 330240 ]; then \\
\t\tln -sf $(LINUX_DIR) $(PKG_BUILD_DIR)/$(MAKE_PATH)/kernel; \\
\tfi
endef

define Build/Compile
\t$(MAKE_VARS) $(MAKE) -C "$(LINUX_DIR)" \\
\t\t$(KERNEL_MAKE_FLAGS) \\
\t\tM="$(PKG_BUILD_DIR)/$(MAKE_PATH)" \\
\t\tEXTRA_CFLAGS="$(BUILDFLAGS)" \\
\t\tWIREGUARD_VERSION="$(WIREGUARD_VERSION)" \\
\t\tmodules
endef

$(eval $(call KernelPackage,amneziawg))
"""
    with open(makefile_path, 'w', encoding='utf-8') as f:
        f.write(makefile_content)
    print(f"[patch_feeds] Successfully patched: {makefile_path}")

    # Create patches directory and 001-fix-kernel-5.4-compat.patch
    patches_dir = os.path.join(amneziawg_dir, "patches")
    os.makedirs(patches_dir, exist_ok=True)
    patch_file = os.path.join(patches_dir, "001-fix-kernel-5.4-compat.patch")
    patch_content = """diff -uNr a/src/compat/compat.h b/src/compat/compat.h
--- a/src/compat/compat.h	2026-06-11 22:58:33.000000000 +0000
+++ b/src/compat/compat.h	2026-08-27 11:22:10.332410464 +0000
@@ -896,10 +896,6 @@
 
 #if (LINUX_VERSION_CODE >= KERNEL_VERSION(5, 4, 200) || (LINUX_VERSION_CODE < KERNEL_VERSION(4, 20, 0) && LINUX_VERSION_CODE >= KERNEL_VERSION(4, 19, 249)) || (LINUX_VERSION_CODE < KERNEL_VERSION(4, 15, 0) && LINUX_VERSION_CODE >= KERNEL_VERSION(4, 14, 285)) || (LINUX_VERSION_CODE < KERNEL_VERSION(4, 10, 0) && LINUX_VERSION_CODE >= KERNEL_VERSION(4, 9, 320))) && LINUX_VERSION_CODE < KERNEL_VERSION(5, 10, 0) && !defined(ISUBUNTU2004)
 #define COMPAT_INIT_CRYPTO
-#define blake2s_init zinc_blake2s_init
-#define blake2s_init_key zinc_blake2s_init_key
-#define blake2s_update zinc_blake2s_update
-#define blake2s_final zinc_blake2s_final
 #endif
 #if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 5, 0) && LINUX_VERSION_CODE < KERNEL_VERSION(5, 10, 0)
 #define blake2s_hmac zinc_blake2s_hmac
@@ -1103,11 +1099,8 @@
 		return htons(ETH_P_IPV6);
 	return 0;
 }
-#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 1, 0) || defined(ISRHEL8)
+#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 8, 0) || defined(ISRHEL8)
 static const struct header_ops ip_tunnel_header_ops = { .parse_protocol = ip_tunnel_parse_protocol };
-#else
-#define header_ops hard_header_len
-#define ip_tunnel_header_ops *(char *)0 - (char *)0
 #endif
 #endif
 
@@ -1404,7 +1397,7 @@
 #include <crypto/blake2s.h>
 #define blake2s_ctx blake2s_state
 #define blake2s(key, keylen, in, inlen, out, outlen) \\
-	blake2s(out, in, key, outlen, inlen, keylen)
+	(blake2s)((u8 *)(out), (const u8 *)(in), (const u8 *)(key), (size_t)(outlen), (size_t)(inlen), (size_t)(keylen))
 #endif
 
 #endif /* _WG_COMPAT_H */
diff -uNr a/src/crypto/Kbuild.include b/src/crypto/Kbuild.include
--- a/src/crypto/Kbuild.include	2026-06-11 22:58:33.000000000 +0000
+++ b/src/crypto/Kbuild.include	2026-08-27 11:22:10.332592824 +0000
@@ -31,8 +31,10 @@
 
 zinc-y += chacha20poly1305.o
 
+ifeq ($(wildcard $(srctree)/include/crypto/blake2s.h),)
 zinc-y += blake2s/blake2s.o
 zinc-$(CONFIG_ZINC_ARCH_X86_64) += blake2s/blake2s-x86_64.o
+endif
 
 zinc-y += curve25519/curve25519.o
 zinc-$(CONFIG_ZINC_ARCH_ARM) += curve25519/curve25519-arm.o
diff -uNr a/src/crypto/zinc.h b/src/crypto/zinc.h
--- a/src/crypto/zinc.h	2026-06-11 22:58:33.000000000 +0000
+++ b/src/crypto/zinc.h	2026-08-27 11:22:10.332685354 +0000
@@ -9,7 +9,11 @@
 int chacha20_mod_init(void);
 int poly1305_mod_init(void);
 int chacha20poly1305_mod_init(void);
+#if (LINUX_VERSION_CODE >= KERNEL_VERSION(5, 4, 200) || (LINUX_VERSION_CODE < KERNEL_VERSION(4, 20, 0) && LINUX_VERSION_CODE >= KERNEL_VERSION(4, 19, 249)) || (LINUX_VERSION_CODE < KERNEL_VERSION(4, 15, 0) && LINUX_VERSION_CODE >= KERNEL_VERSION(4, 14, 285)) || (LINUX_VERSION_CODE < KERNEL_VERSION(4, 10, 0) && LINUX_VERSION_CODE >= KERNEL_VERSION(4, 9, 320))) && LINUX_VERSION_CODE < KERNEL_VERSION(5, 10, 0)
+static inline int blake2s_mod_init(void) { return 0; }
+#else
 int blake2s_mod_init(void);
+#endif
 int curve25519_mod_init(void);
 
 #endif
diff -uNr a/src/device.c b/src/device.c
--- a/src/device.c	2026-06-11 22:58:33.000000000 +0000
+++ b/src/device.c	2026-08-27 11:22:32.859566690 +0000
@@ -300,7 +300,11 @@ static void wg_setup(struct net_device *dev)
 			     max(sizeof(struct ipv6hdr), sizeof(struct iphdr));
 
 	dev->netdev_ops = &netdev_ops;
+#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 8, 0)
 	dev->header_ops = &ip_tunnel_header_ops;
+#else
+	dev->header_ops = NULL;
+#endif
 	dev->hard_header_len = 0;
 	dev->addr_len = 0;
 	dev->needed_headroom = DATA_PACKET_HEAD_ROOM;
diff -uNr a/src/main.c b/src/main.c
--- a/src/main.c	2026-06-11 22:58:33.000000000 +0000
+++ b/src/main.c	2026-08-27 11:22:10.332863436 +0000
@@ -11,6 +11,7 @@
 #include "ratelimiter.h"
 #include "netlink.h"
 #include "uapi/wireguard.h"
+#include "crypto/zinc.h"
 
 #include <linux/init.h>
 #include <linux/module.h>
"""
    with open(patch_file, 'w', encoding='utf-8') as f:
        f.write(patch_content)
    print(f"[patch_feeds] Successfully created patch: {patch_file}")
    return True

def main():
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    print(f"[patch_feeds] Applying patches to external feeds in {repo_root}...")

    # Patch feeds/luci lucihttp Makefile
    lucihttp_makefile = os.path.join(repo_root, "feeds/luci/contrib/package/lucihttp/Makefile")
    patch_lucihttp_makefile(lucihttp_makefile)

    # Patch feeds/packages iperf3 Makefile
    iperf3_makefile = os.path.join(repo_root, "feeds/packages/net/iperf3/Makefile")
    patch_iperf3_makefile(iperf3_makefile)

    # Patch feeds/amneziawg kmod-amneziawg
    patch_amneziawg_feed(repo_root)

    print("[patch_feeds] Feed patching complete.")

if __name__ == "__main__":
    main()
