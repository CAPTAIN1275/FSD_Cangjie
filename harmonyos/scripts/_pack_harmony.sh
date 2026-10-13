#!/bin/bash
set -e
OSDK="$HOME/cangjie-ohos/cangjie"
STDX="$HOME/cangjie-stdx-ohos/linux_ohos_aarch64_cjnative"
PROJ="/mnt/d/Desktop/FSD_Cangjie/harmonyos/project"
BUNDLE="$HOME/FSD_Cangjie_HarmonyOS"
OUT="/mnt/d/Desktop/FSD_Cangjie/harmonyos/project.tar.gz"

rm -rf "$BUNDLE"; mkdir -p "$BUNDLE/lib"

# 1) 二进制（strip）
cp "$PROJ/target/aarch64-linux-ohos/release/bin/main" "$BUNDLE/FSD_Cangjie"
"$OSDK/third_party/llvm/bin/llvm-strip" "$BUNDLE/FSD_Cangjie" 2>/dev/null || strip "$BUNDLE/FSD_Cangjie" 2>/dev/null || true
chmod +x "$BUNDLE/FSD_Cangjie"

# 2) 运行时 .so + stdx .so
cp -a "$OSDK/runtime/lib/linux_ohos_aarch64_cjnative/." "$BUNDLE/lib/"
cp -a "$STDX/dynamic/stdx/." "$BUNDLE/lib/"

# 3) 配置/文本
cp "/mnt/d/Desktop/FSD_Cangjie/unix/fsd.conf" "$BUNDLE/fsd.conf"
cp "$PROJ/motd.txt" "$BUNDLE/motd.txt" 2>/dev/null || true
cp "$PROJ/adminhelp.txt" "$BUNDLE/adminhelp.txt" 2>/dev/null || true
cp "$PROJ/cert.txt" "$BUNDLE/cert.txt" 2>/dev/null || true

# 4) 启动脚本（Toybox 友好）
cat > "$BUNDLE/run.sh" <<'RUN'
#!/bin/sh
cd "$(dirname "$0")" || exit 1
export LD_LIBRARY_PATH="$PWD/lib:$LD_LIBRARY_PATH"
echo "starting FSD (aarch64-ohos)..."
exec ./FSD_Cangjie
RUN
chmod +x "$BUNDLE/run.sh"

# 5) 后台启动脚本
cat > "$BUNDLE/run_bg.sh" <<'RUNBG'
#!/bin/sh
cd "$(dirname "$0")" || exit 1
export LD_LIBRARY_PATH="$PWD/lib:$LD_LIBRARY_PATH"
nohup ./FSD_Cangjie > fsd.log 2>&1 &
echo "FSD started pid=$!"
RUNBG
chmod +x "$BUNDLE/run_bg.sh"

# 6) 签名脚本（在鸿蒙电脑上执行）
cat > "$BUNDLE/sign.sh" <<'SIGN'
#!/bin/sh
# 在鸿蒙电脑 HiShell 里运行：对二进制和所有 .so 自签名（HiShell 会强制验签）
DIR="$(cd "$(dirname "$0")" && pwd)"
BST="${BINARY_SIGN_TOOL:-binary-sign-tool}"
if ! command -v "$BST" >/dev/null 2>&1 && [ ! -x "$BST" ]; then
  echo "找不到 binary-sign-tool，请设置 BINARY_SIGN_TOOL=<ohos-sdk>/toolchains/lib/binary-sign-tool"
  exit 1
fi
sign_one() { "$BST" sign -selfSign 1 -inFile "$1" -outFile "$1" && echo "signed: $1" || echo "FAILED: $1"; }
sign_one "$DIR/FSD_Cangjie"
for so in "$DIR"/lib/*.so; do sign_one "$so"; done
echo "签名完成"
SIGN
chmod +x "$BUNDLE/sign.sh"

# 6b) Windows 一键签名脚本（用 DevEco 的 Java + binary-sign-tool.jar）
cat > "$BUNDLE/sign.bat" <<'BAT'
@echo off
setlocal
set "JAVA=D:\DevEco Studio\jbr\bin\java.exe"
set "JAR=D:\DevEco Studio\sdk\default\openharmony\toolchains\lib\binary-sign-tool.jar"
if not exist "%JAVA%" ( echo [ERROR] 找不到 JAVA: %JAVA% ^(改 sign.bat 里的路径^) & pause & exit /b 1 )
if not exist "%JAR%" ( echo [ERROR] 找不到 JAR: %JAR% & pause & exit /b 1 )
cd /d "%~dp0"
echo == 签名 FSD_Cangjie ==
"%JAVA%" -jar "%JAR%" sign -selfSign 1 -inFile "FSD_Cangjie" -outFile "FSD_Cangjie"
for %%f in ("lib\*.so") do (
  echo == 签名 %%f ==
  "%JAVA%" -jar "%JAR%" sign -selfSign 1 -inFile "%%~ff" -outFile "%%~ff"
)
echo == 全部签名完成 ==
pause
BAT

# 5b) fsd_d.sh —— HarmonyOS/Toybox 版启动脚本（./fsd_d.sh）
cat > "$BUNDLE/fsd_d.sh" <<'FSDD'
#!/bin/sh
# FSD 启动/重启脚本 — HarmonyOS (Toybox) 版；用法: ./fsd_d.sh
cd "$(dirname "$0")" || exit 1
export LD_LIBRARY_PATH="$PWD/lib:$LD_LIBRARY_PATH"
export cjHeapSize=1gb
ulimit -n 65535 2>/dev/null || true
BIN=FSD_Cangjie
has_pid() { [ -n "$(pgrep -f "$BIN" 2>/dev/null)" ]; }
echo "========================================"
echo "  LDP FLY ADS FSD Server (HarmonyOS)"
echo "========================================"
if has_pid; then
    echo "  Graceful shutdown (notify all clients)..."
    touch fsd_stop
    i=0
    while [ $i -lt 15 ]; do
        has_pid || break
        sleep 1
        i=$((i+1))
    done
    if has_pid; then
        echo "  Still running, force kill..."
        pkill -f "$BIN" 2>/dev/null
        sleep 3
        pkill -9 -f "$BIN" 2>/dev/null
    fi
    rm -f fsd_stop
    sleep 1
fi
nohup ./$BIN >> fsd.log 2>&1 &
PID=$!
sleep 1
if kill -0 "$PID" 2>/dev/null; then
    echo "  FSD started. PID: $PID"
    echo "  Log: fsd.log"
else
    echo "  [ERROR] FSD failed to start! Check fsd.log"
fi
echo "========================================"
FSDD
chmod +x "$BUNDLE/fsd_d.sh"

# 7) 打包
cd "$HOME"
rm -f "$OUT"
tar czf "$OUT" "$(basename "$BUNDLE")"
echo "=== 包 ==="; ls -la "$OUT"
echo "=== 目录 ==="; ls "$BUNDLE"
echo "=== lib 文件数 ==="; ls "$BUNDLE/lib" | wc -l
echo "=== 二进制 ==="; file "$BUNDLE/FSD_Cangjie"