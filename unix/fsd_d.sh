#!/bin/bash
cd "$(dirname "$(readlink -f "$0")")"

echo "========================================"
echo "  LDP FLY ADS FSD Server"
echo "========================================"

# 停止旧进程
OLD_FSD=$(pgrep FSD_Cangjie)
if [ -n "$OLD_FSD" ]; then
    echo "  Stopping old FSD... ($OLD_FSD)"
    killall -9 FSD_Cangjie main 2>/dev/null
    sleep 1
fi

# 强制释放端口（防止其他进程占用）
fuser -k 6809/tcp 3010/tcp 3011/tcp 8080/tcp 2>/dev/null || true
sleep 1

# 启动 FSD
export LD_LIBRARY_PATH=/opt/cangjie/runtime/lib/linux_x86_64_cjnative:$LD_LIBRARY_PATH
nohup ./FSD_Cangjie >> fsd.log 2>&1 &
FSD_PID=$!
sleep 1

# 验证启动
if kill -0 $FSD_PID 2>/dev/null; then
    echo "  FSD started. PID: $FSD_PID"
    echo "  Log: fsd.log"
else
    echo "  [ERROR] FSD failed to start!"
    echo "  Check fsd.log for details."
fi

echo "========================================"
