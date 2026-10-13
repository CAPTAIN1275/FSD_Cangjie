#!/bin/bash
S="$HOME/cangjie-ohos/cangjie"
source "$S/envsetup.sh" >/dev/null 2>&1
cd /mnt/d/Desktop/FSD_Cangjie/harmonyos/project
echo "=== invalid target -> 看是否报可用列表 ==="
cjpm build --target zzz 2>&1 | head -15
echo "=== try aarch64-linux-ohos ==="
cjpm build --target aarch64-linux-ohos 2>&1 | head -30