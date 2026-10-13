#!/bin/bash
S="$HOME/cangjie-ohos/cangjie"
echo "=== 搜索目标三元组 ==="
grep -rIoh -E "[a-z0-9_]+-unknown-linux-ohos|aarch64-linux-ohos|aarch64-unknown-linux-gnu|ohos-aarch64" "$S" 2>/dev/null | sort -u | head
echo "=== envsetup 里 hw_arch 拼法 ==="
grep -n "hw_arch\|sys_name\|_ohos" "$S/envsetup.sh" | head
echo "=== 目录名规则 linux_ohos_aarch64_cjnative ==="
echo "=== 试 cjpm --help ==="
source "$S/envsetup.sh" >/dev/null 2>&1
cjpm --help 2>&1 | grep -iE "target|ohos|--" | head -25
