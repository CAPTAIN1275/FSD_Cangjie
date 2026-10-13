#!/bin/bash
echo "=== DevEco 里找 binary-sign-tool ==="
find "/mnt/d/DevEco Studio" -iname '*binary-sign*' -o -iname '*binary_sign*' 2>/dev/null | head
echo "=== cangjie-ohos / .cangjie-sdk ==="
find "$HOME/cangjie-ohos" "/mnt/c/Users/CAPTAIN1275/.cangjie-sdk" -iname '*binary-sign*' 2>/dev/null | head
echo "=== DevEco toolchains 目录 ==="
ls "/mnt/d/DevEco Studio/sdk/default/openharmony/toolchains" 2>/dev/null | head -40
echo "=== DevEco sdk 顶层 ==="
ls "/mnt/d/DevEco Studio/sdk/default/openharmony" 2>/dev/null