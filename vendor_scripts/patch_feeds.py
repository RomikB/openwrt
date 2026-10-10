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

def patch_zapret2_makefile(makefile_path):
    if not os.path.isfile(makefile_path):
        print(f"[patch_feeds] Note: {makefile_path} not found, skipping.")
        return False

    with open(makefile_path, 'r', encoding='utf-8') as f:
        content = f.read()

    if "LUA_JIT?=0" in content:
        print(f"[patch_feeds] Already patched: {makefile_path}")
        return True

    if "LUA_JIT?=1" in content:
        content = content.replace("LUA_JIT?=1", "LUA_JIT?=0", 1)
        with open(makefile_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"[patch_feeds] Successfully patched: {makefile_path} (LUA_JIT set to 0 for Lua 5.4)")
        return True
    else:
        print(f"[patch_feeds] Warning: Target 'LUA_JIT?=1' not found in {makefile_path}")
        return False

def patch_ruantiblock_init(init_path):
    if not os.path.isfile(init_path):
        print(f"[patch_feeds] Note: {init_path} not found, skipping.")
        return False

    with open(init_path, 'r', encoding='utf-8') as f:
        content = f.read()

    if 'ls -d /tmp/dnsmasq.*.d' in content:
        print(f"[patch_feeds] Already patched: {init_path}")
        return True

    old = 'if [ -d "${VAR_DIR}/dnsmasq.d" ]; then\n\t\tprintf "${VAR_DIR}/dnsmasq.d"\n\t\treturn 0\n\telse'
    new = 'if [ -d "${VAR_DIR}/dnsmasq.d" ]; then\n\t\tprintf "${VAR_DIR}/dnsmasq.d"\n\t\treturn 0\n\tfi\n\t_first_instance_dir=$(ls -d /tmp/dnsmasq.*.d 2>/dev/null | head -n 1)\n\tif [ -n "$_first_instance_dir" ]; then\n\t\tprintf "$_first_instance_dir"\n\t\treturn 0\n\telse'

    if old in content:
        content = content.replace(old, new, 1)
        with open(init_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"[patch_feeds] Successfully patched: {init_path} (fallback to /tmp/dnsmasq.*.d for OpenWrt 24)")
        return True
    else:
        print(f"[patch_feeds] Warning: Target block not found in {init_path}")
        return False

def patch_ruantiblock_config_script(config_script_path):
    if not os.path.isfile(config_script_path):
        print(f"[patch_feeds] Note: {config_script_path} not found, skipping.")
        return False

    with open(config_script_path, 'r', encoding='utf-8') as f:
        content = f.read()

    if '_auto_dir=$(ls -d /tmp/dnsmasq.*.d' in content:
        print(f"[patch_feeds] Already patched: {config_script_path}")
        return True

    target = 'network_get_subnet subnet_lan "lan"\nif [ -n "$subnet_lan" ]; then\n    FPROXY_PRIVATE_NETS="${subnet_lan} ${FPROXY_PRIVATE_NETS}"\nfi'
    replacement = target + '\n\nif [ -z "$DNSMASQ_CONFDIR" ] || [ ! -d "$DNSMASQ_CONFDIR" ]; then\n    _auto_dir=$(ls -d /tmp/dnsmasq.*.d 2>/dev/null | head -n 1)\n    [ -n "$_auto_dir" ] && DNSMASQ_CONFDIR="$_auto_dir"\nfi\n'

    if target in content:
        content = content.replace(target, replacement, 1)
        with open(config_script_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"[patch_feeds] Successfully patched: {config_script_path} (dynamic dnsmasq confdir fallback)")
        return True
    else:
        print(f"[patch_feeds] Warning: Target block not found in {config_script_path}")
        return False

def patch_podkop_makefile(makefile_path):
    if not os.path.isfile(makefile_path):
        print(f"[patch_feeds] Note: {makefile_path} not found, skipping.")
        return False

    with open(makefile_path, 'r', encoding='utf-8') as f:
        content = f.read()

    if "DEPENDS:=sing-box " in content:
        print(f"[patch_feeds] Already patched: {makefile_path}")
        return True

    old = "DEPENDS:=+sing-box "
    new = "DEPENDS:=sing-box "
    if old in content:
        content = content.replace(old, new, 1)
        with open(makefile_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"[patch_feeds] Successfully patched: {makefile_path} (use non-selecting dependency for sing-box)")
        return True
    else:
        print(f"[patch_feeds] Warning: Target block not found in {makefile_path}")
        return False

def patch_luci_app_podkop_makefile(makefile_path):
    if not os.path.isfile(makefile_path):
        print(f"[patch_feeds] Note: {makefile_path} not found, skipping.")
        return False

    with open(makefile_path, 'r', encoding='utf-8') as f:
        content = f.read()

    if "# $(eval $(call BuildPackage,$(PKG_NAME)))" in content:
        print(f"[patch_feeds] Already patched: {makefile_path}")
        return True

    old = "$(eval $(call BuildPackage,$(PKG_NAME)))"
    new = "# BuildPackage is invoked automatically by luci.mk\n# $(eval $(call BuildPackage,$(PKG_NAME)))"
    if old in content:
        content = content.replace(old, new, 1)
        with open(makefile_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"[patch_feeds] Successfully patched: {makefile_path} (remove duplicate BuildPackage)")
        return True
    else:
        print(f"[patch_feeds] Warning: Target block not found in {makefile_path}")
        return False

def main():
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    print(f"[patch_feeds] Applying patches to external feeds in {repo_root}...")

    # Patch feeds/luci lucihttp Makefile
    lucihttp_makefile = os.path.join(repo_root, "feeds/luci/contrib/package/lucihttp/Makefile")
    patch_lucihttp_makefile(lucihttp_makefile)

    # Patch feeds/packages iperf3 Makefile
    iperf3_makefile = os.path.join(repo_root, "feeds/packages/net/iperf3/Makefile")
    patch_iperf3_makefile(iperf3_makefile)

    # Patch feeds/zapret2 zapret2 Makefile (use Lua 5.4 instead of LuaJIT)
    zapret2_makefile = os.path.join(repo_root, "feeds/zapret2/zapret2/Makefile")
    patch_zapret2_makefile(zapret2_makefile)

    # Patch feeds/ruantiblock init script (OpenWrt 24 procd dnsmasq dir fallback)
    ruantiblock_init = os.path.join(repo_root, "feeds/ruantiblock/ruantiblock/files/etc/init.d/ruantiblock")
    patch_ruantiblock_init(ruantiblock_init)

    # Patch feeds/ruantiblock config_script (dynamic dnsmasq confdir fallback)
    ruantiblock_config_script = os.path.join(repo_root, "feeds/ruantiblock/ruantiblock/files/usr/share/ruantiblock/config_script")
    patch_ruantiblock_config_script(ruantiblock_config_script)

    # Patch feeds/podkop podkop Makefile (non-selecting sing-box dependency)
    podkop_makefile = os.path.join(repo_root, "feeds/podkop/podkop/Makefile")
    patch_podkop_makefile(podkop_makefile)

    # Patch feeds/podkop luci-app-podkop Makefile (remove duplicate BuildPackage)
    luci_app_podkop_makefile = os.path.join(repo_root, "feeds/podkop/luci-app-podkop/Makefile")
    patch_luci_app_podkop_makefile(luci_app_podkop_makefile)

    # Patch package/addons/luci-theme-argon Makefile (use uclient-fetch instead of heavy GNU wget)
    argon_makefile = os.path.join(repo_root, "package/addons/luci-theme-argon/Makefile")
    patch_argon_makefile(argon_makefile)

    # Patch feeds/forkop apply.uc (remove unsupported interval flags on concatenated sets for Linux 5.4)
    forkop_apply_uc = os.path.join(repo_root, "feeds/forkop/forkop/files/usr/lib/nft/apply.uc")
    patch_forkop_apply_uc(forkop_apply_uc)

    print("[patch_feeds] Feed patching complete.")

def patch_forkop_apply_uc(apply_uc_path):
    if not os.path.isfile(apply_uc_path):
        print(f"[patch_feeds] Note: {apply_uc_path} not found, skipping.")
        return False

    with open(apply_uc_path, 'r', encoding='utf-8') as f:
        content = f.read()

    changed = False
    old_v4 = 'return nft_create_set(table, name, "{ type ipv4_addr . inet_service; flags interval; auto-merge; }");'
    new_v4 = 'return nft_create_set(table, name, "{ type ipv4_addr . inet_service; }");'
    if old_v4 in content:
        content = content.replace(old_v4, new_v4, 1)
        changed = True

    old_v6 = 'return nft_create_set(table, name, "{ type ipv6_addr . inet_service; flags interval; auto-merge; }");'
    new_v6 = 'return nft_create_set(table, name, "{ type ipv6_addr . inet_service; }");'
    if old_v6 in content:
        content = content.replace(old_v6, new_v6, 1)
        changed = True

    if changed:
        with open(apply_uc_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"[patch_feeds] Successfully patched: {apply_uc_path} (Linux 5.4 concatenated sets compatibility)")
        return True
    else:
        print(f"[patch_feeds] Already patched or target blocks not found: {apply_uc_path}")
        return True

def patch_argon_makefile(makefile_path):
    if not os.path.isfile(makefile_path):
        print(f"[patch_feeds] Note: {makefile_path} not found, skipping.")
        return False

    with open(makefile_path, 'r', encoding='utf-8') as f:
        content = f.read()

    if "LUCI_DEPENDS:=+uclient-fetch +jsonfilter" in content:
        print(f"[patch_feeds] Already patched: {makefile_path}")
        return True

    old = "LUCI_DEPENDS:=+USE_APK:wget-any +!USE_APK:wget +jsonfilter"
    new = "LUCI_DEPENDS:=+uclient-fetch +jsonfilter"
    if old in content:
        content = content.replace(old, new, 1)
        with open(makefile_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"[patch_feeds] Successfully patched: {makefile_path} (use uclient-fetch instead of GNU wget)")
        return True
    else:
        print(f"[patch_feeds] Warning: Target block not found in {makefile_path}")
        return False

if __name__ == "__main__":
    main()
