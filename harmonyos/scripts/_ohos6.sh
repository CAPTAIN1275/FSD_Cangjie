#!/bin/bash
S="$HOME/cangjie-ohos/cangjie"
source "$S/envsetup.sh" >/dev/null 2>&1
cd /tmp
printf 'main(): Int64 { return 0 }\n' > t_ohos.cj
echo "=== cjpm build --help ==="; cjpm build --help 2>&1 | grep -iE "target|ohos|--" | head -20
echo "=== 试探 target 值 ==="
for t in aarch64-linux-ohos aarch64-unknown-linux-ohos ohos-aarch64 aarch64-ohos; do
  echo "-- $t --"
  cjc --target "$t" -c t_ohos.cj -o /tmp/t_ohos.o 2>&1 | head -2
done
echo "=== 无效 target 是否报可用列表 ==="
cjc --target ABC -c t_ohos.cj -o /tmp/t_ohos.o 2>&1 | head -8