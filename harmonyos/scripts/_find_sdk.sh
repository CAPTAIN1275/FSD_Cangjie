#!/bin/bash
echo "=== 找 aarch64-linux-ohos 目录（常见位置）==="
for base in "/mnt/c/Program Files/Huawei" "/mnt/c/Program Files (x86)/Huawei" "/mnt/c/Users/CAPTAIN1275/AppData/Local/Huawei" "/mnt/c/Users/CAPTAIN1275/AppData/Local/OpenHarmony" "/mnt/c/Users/CAPTAIN1275/AppData/Roaming/Huawei" "/mnt/d"; do
  if [ -d "$base" ]; then
    echo "-- under: $base"
    find "$base" -maxdepth 6 -type d -name 'aarch64-linux-ohos' 2>/dev/null | head -3
  fi
done
echo "=== 找 DevEco sdk 目录 ==="
find "/mnt/c/Program Files/Huawei" "/mnt/c/Users/CAPTAIN1275" -maxdepth 5 -type d -iname 'sdk' 2>/dev/null | head
echo "=== Scrt1.o 全局（限 D 盘 + 用户目录）==="
find /mnt/d "/mnt/c/Users/CAPTAIN1275" -maxdepth 7 -name 'Scrt1.o' 2>/dev/null | head