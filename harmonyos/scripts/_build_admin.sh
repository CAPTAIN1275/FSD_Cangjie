#!/bin/bash
set -e
S="$HOME/cangjie-ohos/cangjie"
source "$S/envsetup.sh" >/dev/null 2>&1
CRT="$HOME/ohos-sysroot/usr/lib/aarch64-linux-ohos"
cd /mnt/d/Desktop/FSD_Cangjie/harmonyos/sys3010
for d in "." "/tmp"; do
  ln -sf "$CRT/Scrt1.o" "$d/Scrt1.o"
  ln -sf "$CRT/crti.o"  "$d/crti.o"
  ln -sf "$CRT/crtn.o"  "$d/crtn.o"
done
rm -rf target
cjpm build --target aarch64-linux-ohos 2>&1 | grep -vE "unsecure|parser|warnings generated|^ *\^|==>|^ *[0-9]+ \||^ *\||^$" | tail -20
echo "=== 产物 ==="
ls -la target/aarch64-linux-ohos/release/bin/ 2>/dev/null