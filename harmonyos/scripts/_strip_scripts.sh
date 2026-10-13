#!/bin/bash
set -e
B="/mnt/d/Desktop/_hsign/FSD_Cangjie_HarmonyOS"
# 删掉多余脚本
rm -f "$B/run.sh" "$B/run_bg.sh" "$B/sys.sh" "$B/sign.sh" "$B/sign.bat"
# 对齐 Linux：补 nginx 安全配置（若存在）
NG="/mnt/d/Desktop/FSD_Cangjie/unix/nginx_fsd_security.conf"
if [ -f "$NG" ]; then cp "$NG" "$B/"; echo "已加 nginx_fsd_security.conf"; else echo "unix 里没有 nginx_fsd_security.conf"; fi
echo "=== 包根 ==="; ls "$B"
# 重新打包
cd /mnt/d/Desktop/_hsign
rm -f /mnt/d/Desktop/FSD_Cangjie/harmonyos/dist/FSD_Cangjie_HarmonyOS.tar.gz
tar czf /mnt/d/Desktop/FSD_Cangjie/harmonyos/dist/FSD_Cangjie_HarmonyOS.tar.gz FSD_Cangjie_HarmonyOS
echo "=== 包 ==="; ls -la /mnt/d/Desktop/FSD_Cangjie/harmonyos/dist/FSD_Cangjie_HarmonyOS.tar.gz
echo "=== 顶层清单 ==="; tar tzf /mnt/d/Desktop/FSD_Cangjie/harmonyos/dist/FSD_Cangjie_HarmonyOS.tar.gz | grep -v '/lib/' | sort