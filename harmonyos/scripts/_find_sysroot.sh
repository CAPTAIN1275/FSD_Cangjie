#!/bin/bash
echo "=== Scrt1.o (cangjie-sdk / opt / home) ==="
find /opt /home "$HOME/cangjie-ohos" -name 'Scrt1.o' 2>/dev/null | head
echo "=== DevEco .cangjie-sdk 里 aarch64-linux-ohos 的 crt/libc ==="
find /mnt/c/Users/CAPTAIN1275/.cangjie-sdk -path '*aarch64-linux-ohos*' \( -name 'Scrt1.o' -o -name 'crti.o' -o -name 'libc.so' -o -name 'libm.so' \) 2>/dev/null | head
echo "=== sysroot 目录 ==="
find /mnt/c/Users/CAPTAIN1275/.cangjie-sdk -type d -name 'sysroot' 2>/dev/null | head
echo "=== cangjie-ohos 里全部 crt/libc ==="
find "$HOME/cangjie-ohos" \( -name 'crti.o' -o -name 'libc.so' -o -name 'libm.so' -o -name 'ld-musl*' \) 2>/dev/null | head