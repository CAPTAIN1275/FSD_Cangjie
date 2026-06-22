#!/bin/bash
cd "$(dirname "$(readlink -f "$0")")"

FSD_PID=$(pgrep FSD_Cangjie)

if [ -z "$FSD_PID" ]; then
    echo "========================================"
    echo "  没有正在运行的 FSD"
    echo "========================================"
    exit 0
fi

echo "========================================"
echo "  正在停止 FSD... (PID: $FSD_PID)"
echo "========================================"

# 先发 SIGTERM 让 OS 正常关闭 socket
echo "  Sending SIGTERM..."
kill $FSD_PID 2>/dev/null
sleep 3

# 还不死才 SIGKILL
if kill -0 $FSD_PID 2>/dev/null; then
    echo "  Force killing..."
    kill -9 $FSD_PID 2>/dev/null
    sleep 1
fi

if pgrep FSD_Cangjie > /dev/null 2>&1; then
    echo "  [ERROR] 无法停止 FSD"
else
    echo "  FSD 已清除"
fi
echo "========================================"
