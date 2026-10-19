#!/usr/bin/env bash
# ==============================================================================
#  zsh-config-backup · 一键在线安装引导脚本（GitHub 模式）
# ------------------------------------------------------------------------------
#  本文件放在仓库根目录，服务器上一条命令即可安装 / 更新到最新：
#
#      curl -fsSL https://raw.githubusercontent.com/Lee-Bluce/zsh-config-backup/main/bootstrap.sh | bash
#
#  常用变体：
#      # 装给指定用户（root 执行时）
#      ... | bash -s -- --user deploy
#      # 服务器也用 p10k 观感（本地终端需装 MesloLGS NF 字体）
#      ... | bash -s -- --with-p10k
#      # 不装系统依赖（zsh/git 已就绪）
#      ... | bash -s -- --skip-packages
#      # 国内网络加速
#      ... | GITHUB_MIRROR=https://ghfast.top/ bash
#      # 换仓库 / 分支
#      ... | GITHUB_REPO=owner/repo BRANCH=dev bash
#      # 只预览不执行
#      ... | bash -s -- --dry-run
#
#  说明：脚本直接下载仓库源码包，所以你只要 git push，所有服务器下次执行
#        这条命令就自动装到最新配置，无需手动打包上传。
# ==============================================================================
set -euo pipefail

GITHUB_REPO="${GITHUB_REPO:-Lee-Bluce/zsh-config-backup}"
BRANCH="${BRANCH:-main}"
GITHUB_MIRROR="${GITHUB_MIRROR:-}"     # 例如 https://ghfast.top/ 或 https://gh-proxy.com/

command -v tar >/dev/null 2>&1 || { echo "[omz-setup] 需要 tar，请先安装" >&2; exit 1; }

# 下载器：优先 curl，其次 wget
if command -v curl >/dev/null 2>&1; then
  download() { curl -fsSL --connect-timeout 15 -o "$2" "$1"; }
elif command -v wget >/dev/null 2>&1; then
  download() { wget -q -T 15 -O "$2" "$1"; }
else
  echo "[omz-setup] 需要 curl 或 wget，请先安装" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PKG="$TMP_DIR/src.tar.gz"
TARBALL="https://github.com/${GITHUB_REPO}/archive/refs/heads/${BRANCH}.tar.gz"

try_download() {   # $1=url  $2=描述
  echo "[omz-setup] 尝试下载（$2）: $1"
  download "$1" "$PKG" 2>/dev/null && [[ -s "$PKG" ]]
}

ok=0
if [[ -n "$GITHUB_MIRROR" ]]; then
  try_download "${GITHUB_MIRROR%/}/${TARBALL}" "镜像加速" && ok=1
fi
if [[ $ok -eq 0 ]]; then
  try_download "$TARBALL" "GitHub 官方" && ok=1
fi
[[ $ok -eq 1 ]] || {
  echo "[omz-setup] 下载失败：$TARBALL" >&2
  echo "[omz-setup] 国内网络可加镜像重试：curl -fsSL <bootstrap地址> | GITHUB_MIRROR=https://ghfast.top/ bash" >&2
  exit 1
}

tar -xzf "$PKG" -C "$TMP_DIR" || { echo "[omz-setup] 解包失败" >&2; exit 1; }

# 源码包顶层目录名形如 <repo>-<branch>，动态识别，避免改名后失效
SRC_DIR="$(find "$TMP_DIR" -maxdepth 1 -mindepth 1 -type d | head -1)"
[[ -n "$SRC_DIR" && -f "$SRC_DIR/install.sh" ]] || { echo "[omz-setup] 仓库内容异常：找不到 install.sh" >&2; exit 1; }

# 以当前用户运行安装器：脚本内部只对「装包 / 改默认 shell」等步骤自动提权，
# 这样克隆下来的文件属主始终是你自己，不会出现 root 拥有的配置文件。
bash "$SRC_DIR/install.sh" "$@"
