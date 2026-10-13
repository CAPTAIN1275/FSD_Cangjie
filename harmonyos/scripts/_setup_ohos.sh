#!/bin/bash
set -e
F=/mnt/d/Downloads/cangjie-sdk-linux-x64-ohos-1.2.0.tar.gz
echo "=== source ==="; ls -la "$F"
DEST=$HOME/cangjie-ohos
rm -rf "$DEST"; mkdir -p "$DEST"
tar -xzf "$F" -C "$DEST"
echo "=== top ==="; ls -la "$DEST"
echo "=== envsetup/cjc/cjpm ==="; find "$DEST" -maxdepth 4 \( -name 'envsetup*' -o -name 'cjc' -o -name 'cjpm' \) 2>/dev/null
echo "=== target dirs (ohos/arch) ==="; find "$DEST" -maxdepth 4 -type d \( -name '*ohos*' -o -name '*aarch64*' -o -name '*x86_64*' \) 2>/dev/null
echo "=== stdx ==="; find "$DEST" -maxdepth 5 -iname '*stdx*' 2>/dev/null | head
