#!/bin/bash
STD="$HOME/cangjie-stdx-ohos/linux_ohos_aarch64_cjnative"
echo "=== static/ ==="; ls -la "$STD/static"
echo "=== static/stdx (head) ==="; ls "$STD/static/stdx" 2>/dev/null | head -30
echo "=== find cjpm.toml ==="; find "$STD" -name 'cjpm.toml'
echo "=== linux ref stdx/ ==="; ls /opt/cangjie/linux_x86_64_cjnative/static/stdx 2>/dev/null | head
echo "=== linux stdx/cjpm.toml ==="; head -20 /opt/cangjie/linux_x86_64_cjnative/static/stdx/cjpm.toml 2>/dev/null