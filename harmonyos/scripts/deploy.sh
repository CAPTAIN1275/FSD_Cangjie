#!/bin/sh
# 部署/重启 — HarmonyOS 版（设备上无构建环境）
# 用新版本时：先把新的 FSD_Cangjie + lib/ 覆盖到本目录，再执行本脚本
cd "$(dirname "$0")" || exit 1
chmod +x FSD_Cangjie fsd_d.sh killfsd.sh 2>/dev/null
./killfsd.sh
./fsd_d.sh
