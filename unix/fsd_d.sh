#!/bin/bash
export LD_LIBRARY_PATH=/opt/cangjie/runtime/lib/linux_x86_64_cjnative:$LD_LIBRARY_PATH
cd /www/wwwroot/system.ldpfly.cn/map/online/fsd2
killall -9 FSD_Cangjie 2>/dev/null
sleep 1
nohup ./FSD_Cangjie > fsd.log 2>&1 &
echo "FSD restarted. PID: $!"
