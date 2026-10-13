#!/bin/bash
D="$HOME/cangjie-stdx-ohos/linux_ohos_aarch64_cjnative/static/stdx"
cat > "$D/cjpm.toml" <<'EOF'
[package]
  cjc-version = "1.2.0"
  name = "stdx"
  output-type = "static"
  src-dir = "."
  version = "1.0.0"
  target-dir = ""
EOF
echo "written:"; cat "$D/cjpm.toml"