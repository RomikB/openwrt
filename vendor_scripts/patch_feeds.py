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

def main():
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    print(f"[patch_feeds] Applying patches to external feeds in {repo_root}...")

    # Patch feeds/luci lucihttp Makefile
    lucihttp_makefile = os.path.join(repo_root, "feeds/luci/contrib/package/lucihttp/Makefile")
    patch_lucihttp_makefile(lucihttp_makefile)

    # Patch feeds/packages iperf3 Makefile
    iperf3_makefile = os.path.join(repo_root, "feeds/packages/net/iperf3/Makefile")
    patch_iperf3_makefile(iperf3_makefile)

    print("[patch_feeds] Feed patching complete.")

if __name__ == "__main__":
    main()
