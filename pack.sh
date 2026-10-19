#!/usr/bin/env bash
# ==============================================================================
#  omz-setup · 打包脚本
#  在 Mac 上执行，生成可上传到下载机的 tar.gz
#     bash pack.sh
# ==============================================================================
set -euo pipefail
cd "$(dirname "$0")"

OUT_DIR="dist"
STAMP="$(date +%Y%m%d)"
TARBALL="omz-setup.tar.gz"

mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR/$TARBALL" "$OUT_DIR/omz-setup-$STAMP.tar.gz"

# 打包整个目录（排除 .git、dist、系统垃圾文件），顶层目录名为 omz-setup
COPYFILE_DISABLE=1 tar --exclude='.git' --exclude='dist' --exclude='.DS_Store' \
  -czf "$OUT_DIR/$TARBALL" -C .. omz-setup

echo
echo "打包完成："
echo "  $PWD/$OUT_DIR/$TARBALL"
ls -lh "$OUT_DIR/$TARBALL" | awk '{print "  大小: "$5}'
if command -v shasum >/dev/null 2>&1; then
  echo "  SHA256: $(shasum -a 256 "$OUT_DIR/$TARBALL" | awk '{print $1}')"
else
  echo "  SHA256: $(sha256sum "$OUT_DIR/$TARBALL" | awk '{print $1}')"
fi

# 同步刷新 bootstrap.sh 里的下载地址占位（可选，需设置 BASE_URL）
if [[ -n "${BASE_URL:-}" ]]; then
  sed -i.bak "s|^BASE_URL=.*|BASE_URL=\"${BASE_URL%/}\"|" bootstrap.sh && rm -f bootstrap.sh.bak
  echo "  已写入 bootstrap.sh 的 BASE_URL=$BASE_URL"
fi

cat <<EOF

下一步（上传到下载机）：
  1) 把这两个文件上传到下载机的 web 根目录（如 /var/www/html 或 nginx root）：
       $OUT_DIR/$TARBALL
       bootstrap.sh
  2) 在下载机上启动一个简单 HTTP 服务（或丢给 nginx）：
       cd <web根目录> && python3 -m http.server 8000 --bind 0.0.0.0
  3) 在任意服务器上执行一条命令完成安装：
       curl -fsSL http://<下载机IP>:8000/bootstrap.sh | bash
EOF
