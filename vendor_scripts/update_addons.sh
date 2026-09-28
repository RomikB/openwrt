#!/bin/sh
set -e

TOPDIR="$(cd "$(dirname "$0")/.." && pwd)"
ADDONS_DIR="$TOPDIR/package/addons"
mkdir -p "$ADDONS_DIR"

clone_or_update() {
    local name="$1"
    local url="$2"
    local branch="$3"
    local target_dir="$ADDONS_DIR/$name"

    if [ -d "$target_dir/.git" ]; then
        echo "Updating addon '$name' from $url ($branch)..."
        git -C "$target_dir" fetch --depth=1 origin "$branch"
        git -C "$target_dir" checkout -f FETCH_HEAD
    elif [ -d "$target_dir" ]; then
        echo "Addon '$name' already exists without git, skipping."
    else
        echo "Cloning addon '$name' from $url ($branch)..."
        git clone --depth=1 -b "$branch" "$url" "$target_dir"
    fi
}

clone_or_update "luci-theme-argon" "https://github.com/jerrykuku/luci-theme-argon.git" "master"
clone_or_update "luci-app-argon-config" "https://github.com/jerrykuku/luci-app-argon-config.git" "master"
clone_or_update "luci-theme-design" "https://github.com/0x676e67/luci-theme-design.git" "js"

echo "Addons update complete in $ADDONS_DIR"
