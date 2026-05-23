#!/bin/bash
export CANGJIE_HOME=/opt/cangjie
export PATH=$CANGJIE_HOME/bin:$CANGJIE_HOME/tools/bin:$PATH
export LD_LIBRARY_PATH=$CANGJIE_HOME/runtime/lib/linux_x86_64_cjnative:$LD_LIBRARY_PATH

cd /www/wwwroot/system.ldpfly.cn/map/online/fsd2
killall -9 FSD_Cangjie 2>/dev/null
tar -xzf fsd-source.tar.gz
cjpm build
cp target/release/bin/main ./FSD_Cangjie
chmod +x ./FSD_Cangjie
nohup ./FSD_Cangjie > fsd.log 2>&1 &
echo "FSD deployed. PID: $!"
