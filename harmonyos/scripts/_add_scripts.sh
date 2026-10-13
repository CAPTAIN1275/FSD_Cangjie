#!/bin/bash
set -e
B="/mnt/d/Desktop/_hsign/FSD_Cangjie_HarmonyOS"
S="/mnt/d/Desktop/FSD_Cangjie/harmonyos/scripts"

# --- killfsd.sh (HarmonyOS/Toybox) ---
cat > "$B/killfsd.sh" <<'K'
#!/bin/sh
# 停止 FSD — HarmonyOS (Toybox) 版；用法: ./killfsd.sh
cd "$(dirname "$0")" || exit 1
BIN=FSD_Cangjie
has_pid() { [ -n "$(pgrep -f "$BIN" 2>/dev/null)" ]; }
if ! has_pid; then
    echo "========================================"
    echo "  没有正在运行的 FSD"
    echo "========================================"
    exit 0
fi
echo "========================================"
echo "  正在停止 FSD..."
echo "========================================"
# 优雅通知所有客户端断开，等它自己退出
touch fsd_stop
i=0
while [ $i -lt 15 ]; do
    has_pid || break
    sleep 1
    i=$((i+1))
done
if has_pid; then
    echo "  Force killing..."
    pkill -f "$BIN" 2>/dev/null
    sleep 3
    pkill -9 -f "$BIN" 2>/dev/null
fi
rm -f fsd_stop
if has_pid; then
    echo "  [ERROR] 无法停止 FSD"
else
    echo "  FSD 已清除"
fi
echo "========================================"
K

# --- deploy.sh (HarmonyOS：覆盖后重启) ---
cat > "$B/deploy.sh" <<'D'
#!/bin/sh
# 部署/重启 — HarmonyOS 版（设备上无构建环境）
# 用新版本时：先把新的 FSD_Cangjie + lib/ 覆盖到本目录，再执行本脚本
cd "$(dirname "$0")" || exit 1
chmod +x FSD_Cangjie fsd_d.sh killfsd.sh 2>/dev/null
./killfsd.sh
./fsd_d.sh
D

# --- logrotate_fsd.conf（参考，鸿蒙无 logrotate）---
cp "/mnt/d/Desktop/FSD_Cangjie/unix/logrotate_fsd.conf" "$B/logrotate_fsd.conf"

chmod +x "$B/killfsd.sh" "$B/deploy.sh"

# 同步一份到工程 scripts（便于复现）
cp "$B/killfsd.sh" "$B/deploy.sh" "$S/" 2>/dev/null || true

echo "=== 包根目录 ==="; ls "$B"

# 重新打包
cd /mnt/d/Desktop/_hsign
rm -f /mnt/d/Desktop/FSD_Cangjie/harmonyos/dist/FSD_Cangjie_HarmonyOS.tar.gz
tar czf /mnt/d/Desktop/FSD_Cangjie/harmonyos/dist/FSD_Cangjie_HarmonyOS.tar.gz FSD_Cangjie_HarmonyOS
echo "=== 包 ==="; ls -la /mnt/d/Desktop/FSD_Cangjie/harmonyos/dist/FSD_Cangjie_HarmonyOS.tar.gz
echo "=== 内容 ==="; tar tzf /mnt/d/Desktop/FSD_Cangjie/harmonyos/dist/FSD_Cangjie_HarmonyOS.tar.gz | grep -vE '/lib/' | sort