#!/bin/bash
cd "$(dirname "$(readlink -f "$0")")"

# 提高文件描述符上限（大量并发连接/DB 连接需要）
ulimit -n 65535 2>/dev/null || true

# 仓颉运行时堆上限（默认 1GB）。规模大或遇到 OutOfMemory 时调大；小内存机器别设太大以免触发 swap。
export cjHeapSize=1gb

echo "========================================"
echo "  LDP FLY ADS FSD Server"
echo "========================================"

# 优雅停止旧进程：先通知所有客户端断开，等进程自行退出（=连接全关），兜底再强杀
if pgrep -x FSD_Cangjie >/dev/null || pgrep -x main >/dev/null; then
    echo "  Graceful shutdown (notify all clients)..."
    touch fsd_stop
    for i in $(seq 1 15); do
        pgrep -x FSD_Cangjie >/dev/null || pgrep -x main >/dev/null || break
        sleep 1
    done
    if pgrep -x FSD_Cangjie >/dev/null || pgrep -x main >/dev/null; then
        echo "  Still running, escalating to SIGTERM/SIGKILL..."
        killall FSD_Cangjie main 2>/dev/null
        sleep 3
        killall -9 FSD_Cangjie main 2>/dev/null
    fi
    rm -f fsd_stop
    sleep 1
fi

# 强制释放端口（防止其他进程占用）
fuser -k 6809/tcp 3010/tcp 3011/tcp 8080/tcp 2>/dev/null || true
sleep 1

# 启动 FSD
export LD_LIBRARY_PATH=/opt/cangjie/runtime/lib/linux_x86_64_cjnative:$LD_LIBRARY_PATH
nohup stdbuf -oL ./FSD_Cangjie >> fsd.log 2>&1 &
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
