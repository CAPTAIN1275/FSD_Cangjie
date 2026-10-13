#!/bin/bash
set -e
B="/mnt/d/Desktop/_hsign/FSD_Cangjie_HarmonyOS"
before=$(ls "$B/lib" | wc -l)
find "$B/lib" -type f ! -name '*.so*' -delete
after=$(ls "$B/lib" | wc -l)
echo "lib 文件: $before -> $after"
# 重新打包
cd /mnt/d/Desktop/_hsign
rm -f /mnt/d/Desktop/FSD_Cangjie/harmonyos/project.tar.gz
tar czf /mnt/d/Desktop/FSD_Cangjie/harmonyos/project.tar.gz FSD_Cangjie_HarmonyOS
echo "=== 包 ==="; ls -la /mnt/d/Desktop/FSD_Cangjie/harmonyos/project.tar.gz
echo "=== 顶层内容 ==="; ls "$B"
echo "=== 二进制架构 ==="; file "$B/FSD_Cangjie"