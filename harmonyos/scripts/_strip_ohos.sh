#!/bin/bash
S="$HOME/cangjie-ohos/cangjie/third_party/llvm/bin"
echo "=== llvm bin 里的 strip ==="; ls "$S" 2>/dev/null | grep -i strip
B="$HOME/FSD_Cangjie_HarmonyOS"
for cand in "$S/llvm-strip" "$HOME/cangjie-ohos/cangjie/tools/bin/llvm-strip"; do
  if [ -x "$cand" ]; then
    "$cand" "$B/FSD_Cangjie" && echo "stripped via $cand"
    break
  fi
done
echo "=== 其他 strip ==="; find "$HOME/cangjie-ohos" -name '*strip*' -type f 2>/dev/null | head
file "$B/FSD_Cangjie"