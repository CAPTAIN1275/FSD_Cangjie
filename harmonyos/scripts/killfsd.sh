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
