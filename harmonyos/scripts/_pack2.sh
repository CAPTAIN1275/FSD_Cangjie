#!/bin/bash
set -e
OSDK="$HOME/cangjie-ohos/cangjie"
STDX="$HOME/cangjie-stdx-ohos/linux_ohos_aarch64_cjnative"
PROJ="/mnt/d/Desktop/FSD_Cangjie/harmonyos/project"
SRC="$HOME/FSD_Cangjie_HarmonyOS"   # 已有脚本所在
B="/mnt/d/Desktop/_hsign/FSD_Cangjie_HarmonyOS"

rm -rf /mnt/d/Desktop/_hsign
mkdir -p "$B/lib"

# 二进制
cp "$PROJ/target/aarch64-linux-ohos/release/bin/main" "$B/FSD_Cangjie"
chmod +x "$B/FSD_Cangjie"

# 运行时 .so + stdx .so（-L 解引用，避免断链）
cp -aL "$OSDK/runtime/lib/linux_ohos_aarch64_cjnative/." "$B/lib/"
cp -aL "$STDX/dynamic/stdx/." "$B/lib/"

# 配置/文本
cp "/mnt/d/Desktop/FSD_Cangjie/unix/fsd.conf" "$B/fsd.conf"
cp "$PROJ/motd.txt" "$B/motd.txt"
cp "$PROJ/adminhelp.txt" "$B/adminhelp.txt"
cp "$PROJ/cert.txt" "$B/cert.txt"

# 脚本
cp "$SRC/fsd_d.sh" "$B/fsd_d.sh"
cp "$SRC/run.sh" "$B/run.sh"
cp "$SRC/run_bg.sh" "$B/run_bg.sh"
cp "$SRC/sign.sh" "$B/sign.sh"
cp "$SRC/sign.bat" "$B/sign.bat"
chmod +x "$B/fsd_d.sh" "$B/run.sh" "$B/run_bg.sh" "$B/sign.sh" "$B/FSD_Cangjie"

echo "=== bundle ==="; ls "$B"
echo "=== lib count ==="; ls "$B/lib" | wc -l
echo "=== 断链检查 ==="; find "$B/lib" -xtype l 2>/dev/null | head