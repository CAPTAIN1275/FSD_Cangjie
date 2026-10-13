#!/bin/bash
S=$HOME/cangjie-ohos/cangjie
echo "=== envsetup.sh ==="; cat "$S/envsetup.sh"
echo "=== stdx anywhere? ==="; find "$S" -iname '*stdx*' 2>/dev/null | head
echo "=== ohos modules ==="; ls "$S/modules/linux_ohos_aarch64_cjnative" 2>/dev/null | head
echo "=== mysql imports (stdx?) ==="
grep -rn "import" /mnt/d/Desktop/FSD_Cangjie/harmonyos/project/vendor 2>/dev/null | grep -i "stdx" | head
echo "=== src imports (stdx?) ==="
grep -rn "import" /mnt/d/Desktop/FSD_Cangjie/harmonyos/project/src 2>/dev/null | grep -i "stdx" | head
echo "=== mysql cjpm.toml ==="; cat /mnt/d/Desktop/FSD_Cangjie/harmonyos/project/vendor/mysqltext/cjpm.toml 2>/dev/null