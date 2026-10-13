#!/bin/bash
set -e
B="/mnt/d/Desktop/_hsign/FSD_Cangjie_HarmonyOS"
FB="/mnt/d/Desktop/FSD_Cangjie/harmonyos/project/target/aarch64-linux-ohos/release/bin/main"
AB="/mnt/d/Desktop/FSD_Cangjie/harmonyos/sys3010/target/aarch64-linux-ohos/release/bin/main"
ls -la "$FB" "$AB"

# 真二进制 -> .bin
cp "$FB" "$B/FSD_Cangjie.bin"; chmod +x "$B/FSD_Cangjie.bin"
cp "$AB" "$B/admin.bin";       chmod +x "$B/admin.bin"

# 包装脚本（设好库路径再 exec）
cat > "$B/FSD_Cangjie" <<'W'
#!/bin/sh
DIR="$(cd "$(dirname "$0")" && pwd)"
LD_LIBRARY_PATH="$DIR/lib:$LD_LIBRARY_PATH" exec "$DIR/FSD_Cangjie.bin" "$@"
W
cat > "$B/admin" <<'W'
#!/bin/sh
DIR="$(cd "$(dirname "$0")" && pwd)"
LD_LIBRARY_PATH="$DIR/lib:$LD_LIBRARY_PATH" exec "$DIR/admin.bin" "$@"
W
chmod +x "$B/FSD_Cangjie" "$B/admin"
echo "=== 相关文件 ==="; ls -la "$B" | grep -E 'FSD_Cangjie|admin'