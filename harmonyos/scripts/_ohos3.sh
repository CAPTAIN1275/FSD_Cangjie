#!/bin/bash
source "$HOME/cangjie-ohos/cangjie/envsetup.sh" >/dev/null 2>&1
echo "CANGJIE_HOME=$CANGJIE_HOME"
echo "=== cjc version ==="; cjc --version 2>&1
echo "=== cjc target/arch options ==="; cjc --help 2>&1 | grep -iE 'target|sysroot|--arch|host' | head -20
echo "=== linux sdk stdx (for reference) ==="; ls /opt/cangjie/linux_x86_64_cjnative/static/stdx 2>/dev/null | head
echo "=== ohos sdk third_party ==="; ls "$HOME/cangjie-ohos/cangjie/third_party" 2>/dev/null | head
echo "=== ohos lib ==="; ls "$HOME/cangjie-ohos/cangjie/lib/linux_ohos_aarch64_cjnative" 2>/dev/null | head
