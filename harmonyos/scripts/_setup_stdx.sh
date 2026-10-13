#!/bin/bash
set -e
F=/mnt/d/Downloads/cangjie-stdx-ohos-aarch64-1.2.0.1.zip
echo "=== source ==="; ls -la "$F"
DEST=$HOME/cangjie-stdx-ohos
rm -rf "$DEST"; mkdir -p "$DEST"
cd "$DEST"
unzip -q "$F"
echo "=== top ==="; ls -la "$DEST"
echo "=== 关键内容 ==="
find "$DEST" -maxdepth 3 \( -name 'libstdx*' -o -name '*.cjo' -o -name 'cjpm.toml' \) 2>/dev/null | head -30
echo "=== 目录层级 ==="
find "$DEST" -maxdepth 2 -type d 2>/dev/null