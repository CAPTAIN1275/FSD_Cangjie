#!/bin/bash
set -e
SRC="/mnt/d/Desktop/FSD_Cangjie/harmonyos/sys3010/target/aarch64-linux-ohos/release/bin/main"
B="/mnt/d/Desktop/_hsign/FSD_Cangjie_HarmonyOS"
cp "$SRC" "$B/admin"
chmod +x "$B/admin"
echo "copied: $(ls -la "$B/admin")"