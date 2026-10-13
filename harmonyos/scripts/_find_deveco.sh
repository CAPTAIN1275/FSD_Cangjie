#!/bin/bash
echo "=== DevEco 相关目录 ==="
find /mnt/d -maxdepth 3 -type d -iname '*deveco*' 2>/dev/null | head
echo "=== D 盘 sysroot 目录 ==="
find /mnt/d -maxdepth 10 -type d -name 'sysroot' 2>/dev/null | head
echo "=== D 盘 aarch64-linux-ohos 目录 ==="
find /mnt/d -maxdepth 10 -type d -name 'aarch64-linux-ohos' 2>/dev/null | head
