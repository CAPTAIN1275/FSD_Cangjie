#!/bin/bash
set -e
B="/mnt/d/Desktop/_hsign/FSD_Cangjie_HarmonyOS"
S="/mnt/d/Desktop/FSD_Cangjie/harmonyos/scripts"

cat > "$B/sys.sh" <<'SY'
#!/bin/sh
# 向 3010 系统管理接口发送命令（HarmonyOS/Toybox）
# 用法: ./sys.sh "命令"     例: ./sys.sh clients   ./sys.sh "say hello"   ./sys.sh "shutdown confirm"
# 环境变量可覆盖: FSD_SYS_PWD(默认 disable)  FSD_SYS_HOST(默认 127.0.0.1)  FSD_SYS_PORT(默认 3010)
HOST=${FSD_SYS_HOST:-127.0.0.1}
PORT=${FSD_SYS_PORT:-3010}
PWD=${FSD_SYS_PWD:-disable}
CMD="$1"
if [ -z "$CMD" ]; then
  echo "用法: $0 \"<命令>\""
  echo "命令: help servers servers2 clients info time route cert ping say wall kill"
  echo "      stat metar pos log distance range dump wp refreshmetar shutdown quit"
  exit 1
fi
if ! command -v nc >/dev/null 2>&1; then
  echo "缺少 nc(netcat)。可用: printf 'pwd %s\\n%s\\nquit\\n' \"$PWD\" \"$CMD\" | nc $HOST $PORT"
  exit 1
fi
{ printf 'pwd %s\n' "$PWD"; sleep 0.3; printf '%s\n' "$CMD"; sleep 0.6; printf 'quit\n'; } | nc "$HOST" "$PORT"
SY
chmod +x "$B/sys.sh"
cp "$B/sys.sh" "$S/" 2>/dev/null || true

echo "=== 包根 ==="; ls "$B"
cd /mnt/d/Desktop/_hsign
rm -f /mnt/d/Desktop/FSD_Cangjie/harmonyos/dist/FSD_Cangjie_HarmonyOS.tar.gz
tar czf /mnt/d/Desktop/FSD_Cangjie/harmonyos/dist/FSD_Cangjie_HarmonyOS.tar.gz FSD_Cangjie_HarmonyOS
echo "=== 包 ==="; ls -la /mnt/d/Desktop/FSD_Cangjie/harmonyos/dist/FSD_Cangjie_HarmonyOS.tar.gz