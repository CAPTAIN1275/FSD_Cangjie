#!/bin/bash
set -e
cd /mnt/d/Desktop/_hsign/FSD_Cangjie_HarmonyOS
rm -f /mnt/d/Desktop/FSD_Cangjie/harmonyos/dist/FSD_Cangjie_HarmonyOS.tar.gz
tar czf /mnt/d/Desktop/FSD_Cangjie/harmonyos/dist/FSD_Cangjie_HarmonyOS.tar.gz .
echo "=== 包 ==="; ls -la /mnt/d/Desktop/FSD_Cangjie/harmonyos/dist/FSD_Cangjie_HarmonyOS.tar.gz
echo "=== 顶层 ==="; tar tzf /mnt/d/Desktop/FSD_Cangjie/harmonyos/dist/FSD_Cangjie_HarmonyOS.tar.gz | grep -vE '/lib/' | sort