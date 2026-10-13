#!/bin/bash
STD=$HOME/cangjie-stdx-ohos/linux_ohos_aarch64_cjnative
echo "=== static ==="; ls "$STD/static" 2>/dev/null | head -30
echo "=== dynamic ==="; ls "$STD/dynamic" 2>/dev/null | head -15
echo "=== crypto 相关 ==="; find "$STD" -iname '*crypto*' 2>/dev/null | head
echo "=== cjpm.toml ==="; find "$STD" -name 'cjpm.toml' 2>/dev/null | head
S="$HOME/cangjie-ohos/cangjie"
echo "=== 目标三元组 ==="
grep -rIoh -E "aarch64-unknown-linux-ohos|aarch64-linux-ohos|linux-ohos" "$S/tools" "$S/envsetup.sh" 2>/dev/null | sort -u | head
echo "=== cjpm --help ==="
source "$S/envsetup.sh" >/dev/null 2>&1
cjpm --help 2>&1 | grep -iE "target|ohos" | head