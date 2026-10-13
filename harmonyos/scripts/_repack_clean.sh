#!/bin/bash
set -e
B="/mnt/d/Desktop/_hsign/FSD_Cangjie_HarmonyOS"
OUT="/mnt/d/Desktop/FSD_Cangjie/harmonyos/dist/FSD_Cangjie_HarmonyOS.tar.gz"
echo "=== 旧包校验 ==="
ls -la "$OUT"
gzip -t "$OUT" && echo "gz ok" || echo "gz BAD"
echo "旧包条目数: $(tar tzf "$OUT" | wc -l)"

cd "$B"
rm -f "$OUT"
# 显式列条目，不带 ./ 前缀
tar czf "$OUT" FSD_Cangjie FSD_Cangjie.bin admin admin.bin adminhelp.txt cert.txt deploy.sh fsd.conf fsd_d.sh killfsd.sh logrotate_fsd.conf motd.txt nginx_fsd_security.conf lib
echo "=== 新包 ==="
ls -la "$OUT"
echo "新包条目数: $(tar tzf "$OUT" | wc -l)"
echo "=== 顶层(非 lib) ==="
tar tzf "$OUT" | grep -vE '/lib/' | sort
echo "=== lib 抽样 ==="
tar tzf "$OUT" | grep '/lib/' | head -3