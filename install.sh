#!/usr/bin/env bash
# ==============================================================================
#  omz-setup · 一键安装脚本
#  ---------------------------------------------------------------------------
#  在任意一台服务器 / Linux / macOS 上，安装最新版 Oh My Zsh + 你的配置包
#
#  支持的发行版：Debian/Ubuntu/Raspbian、RHEL/CentOS/Rocky/Alma/Fedora、
#                Arch/Manjaro、Alpine、macOS(Homebrew)
#  支持 x86_64 / arm64 / armv7 等所有常见架构（纯 shell 实现，无二进制依赖）
#
#  用法：
#    本地目录模式：  sudo bash install.sh
#    一键在线模式：  curl -fsSL http://<下载机>/bootstrap.sh | bash
#    指定用户安装：  sudo bash install.sh --user deploy
#    带 p10k 主题：  sudo bash install.sh --with-p10k
#    常用参数：      --simple(默认) --with-p10k --user U --skip-chsh
#                    --skip-packages --base-url URL --github-mirror URL
#                    --assets-dir DIR --home DIR --force --dry-run -h
# ==============================================================================
set -euo pipefail

VERSION="1.1.0"

# ------------------------------------------------------------------------------
# 默认参数（可用环境变量或命令行覆盖）
# ------------------------------------------------------------------------------
OMZ_SETUP_BASE_URL="${OMZ_SETUP_BASE_URL:-}"   # 例如 http://192.168.1.10:8000
GITHUB_MIRROR="${GITHUB_MIRROR:-}"             # 例如 https://ghfast.top/  或 https://gh-proxy.com/
TARGET_USER="${TARGET_USER:-}"
TARGET_HOME="${TARGET_HOME:-}"
ASSETS_DIR="${ASSETS_DIR:-}"
THEME_MODE="simple"                            # simple | p10k
SKIP_CHSH=0
SKIP_PACKAGES=0
FORCE=0
DRY_RUN=0

REPO_OMZ="https://github.com/ohmyzsh/ohmyzsh.git"
REPO_P10K="https://github.com/romkatv/powerlevel10k.git"
REPO_AUTOSUGGEST="https://github.com/zsh-users/zsh-autosuggestions.git"
REPO_SYNTAX_HL="https://github.com/zsh-users/zsh-syntax-highlighting.git"

# ------------------------------------------------------------------------------
# 输出工具
# ------------------------------------------------------------------------------
if [[ -t 1 ]]; then
  C_R=$'\033[31m'; C_G=$'\033[32m'; C_Y=$'\033[33m'; C_B=$'\033[36m'; C_N=$'\033[0m'
else
  C_R=""; C_G=""; C_Y=""; C_B=""; C_N=""
fi
log()  { printf '%s[omz-setup]%s %s\n' "$C_B" "$C_N" "$*"; }
ok()   { printf '%s[    OK   ]%s %s\n' "$C_G" "$C_N" "$*"; }
warn() { printf '%s[  WARN   ]%s %s\n' "$C_Y" "$C_N" "$*" >&2; }
die()  { printf '%s[  FAIL   ]%s %s\n' "$C_R" "$C_N" "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
omz-setup · 一键安装脚本 —— 在任意服务器安装最新版 Oh My Zsh + 你的配置包

支持系统：Debian/Ubuntu/Raspbian、RHEL/CentOS/Rocky/Alma/Fedora、
          Arch/Manjaro、openSUSE、Alpine、macOS(Homebrew)
支持架构：x86_64 / arm64 / armv7 等（纯 shell，无二进制依赖）

用法：
  本地目录模式    sudo bash install.sh
  一键在线模式    curl -fsSL http://<下载机>/bootstrap.sh | bash
  指定用户安装    sudo bash install.sh --user deploy
  带 p10k 主题    sudo bash install.sh --with-p10k

参数：
  --user U            为目标用户安装（默认：SUDO_USER，其次 root/当前用户）
  --home DIR          指定目标 HOME（测试或特殊环境用）
  --simple            Mac 风格两行提示符（默认，无需 Nerd Font，适合服务器）
  --with-p10k         安装 powerlevel10k + 你的 .p10k.zsh（同 Mac 观感）
  --base-url URL      在线模式下载配置包的地址，如 http://10.0.0.2:8000
  --github-mirror URL 国内加速前缀，如 https://ghfast.top/
  --assets-dir DIR    指定配置资源目录（默认脚本旁的 files/）
  --skip-packages     不安装系统依赖（zsh/git/curl 已就绪时）
  --skip-chsh         不修改默认登录 shell
  --force             目录已存在且非 git 仓库时强制覆盖
  --dry-run           只打印将执行的操作，不实际改动
  -h, --help          显示帮助

环境变量同名可用：OMZ_SETUP_BASE_URL / GITHUB_MIRROR / TARGET_USER / TARGET_HOME
USAGE
  exit 0
}

# ------------------------------------------------------------------------------
# 解析参数
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)          TARGET_USER="${2:?--user 需要参数}"; shift 2 ;;
    --home)          TARGET_HOME="${2:?--home 需要参数}"; shift 2 ;;
    --assets-dir)    ASSETS_DIR="${2:?--assets-dir 需要参数}"; shift 2 ;;
    --base-url)      OMZ_SETUP_BASE_URL="${2:?--base-url 需要参数}"; shift 2 ;;
    --github-mirror) GITHUB_MIRROR="${2:?--github-mirror 需要参数}"; shift 2 ;;
    --with-p10k)     THEME_MODE="p10k"; shift ;;
    --simple)        THEME_MODE="simple"; shift ;;
    --skip-chsh)     SKIP_CHSH=1; shift ;;
    --skip-packages) SKIP_PACKAGES=1; shift ;;
    --force)         FORCE=1; shift ;;
    --dry-run)       DRY_RUN=1; shift ;;
    -h|--help)       usage ;;
    *) die "未知参数: $1（用 -h 查看帮助）" ;;
  esac
done

# ------------------------------------------------------------------------------
# 定位资源目录（files/zshrc、files/p10k.zsh）
#   · 本地目录模式：脚本旁边的 files/
#   · 在线模式    ：从 $OMZ_SETUP_BASE_URL 下载 omz-setup.tar.gz 并解包
# ------------------------------------------------------------------------------
TMP_DIR=""
cleanup() { [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"; }
trap cleanup EXIT

resolve_assets() {
  local self_dir
  self_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || self_dir=""

  if [[ -n "$ASSETS_DIR" ]]; then
    [[ -f "$ASSETS_DIR/zshrc" ]] || die "--assets-dir 里找不到 zshrc: $ASSETS_DIR"
  elif [[ -n "$self_dir" && -f "$self_dir/files/zshrc" ]]; then
    ASSETS_DIR="$self_dir/files"
  else
    [[ -n "$OMZ_SETUP_BASE_URL" ]] || die "找不到本地 files/ 目录，且未设置 --base-url / OMZ_SETUP_BASE_URL（在线安装需要它）"
    command -v curl >/dev/null 2>&1 || die "在线安装需要 curl"
    TMP_DIR="$(mktemp -d)"
    local url="${OMZ_SETUP_BASE_URL%/}/omz-setup.tar.gz"
    log "下载配置包: $url"
    curl -fsSL --connect-timeout 15 "$url" -o "$TMP_DIR/pkg.tar.gz" || die "下载失败: $url"
    tar -xzf "$TMP_DIR/pkg.tar.gz" -C "$TMP_DIR" || die "解包失败"
    ASSETS_DIR="$TMP_DIR/omz-setup/files"
    [[ -f "$ASSETS_DIR/zshrc" ]] || ASSETS_DIR="$(find "$TMP_DIR" -type f -name zshrc -path '*/files/*' | head -1 | xargs -r dirname)"
    [[ -f "$ASSETS_DIR/zshrc" ]] || die "配置包里找不到 files/zshrc"
  fi
}
resolve_assets
log "资源目录: $ASSETS_DIR"

# ------------------------------------------------------------------------------
# 判断目标用户 / HOME
# ------------------------------------------------------------------------------
CURRENT_USER="$(id -un)"

if [[ -z "$TARGET_USER" ]]; then
  if [[ "$(id -u)" -eq 0 ]]; then
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
      TARGET_USER="$SUDO_USER"
    else
      TARGET_USER="root"
    fi
  else
    TARGET_USER="$CURRENT_USER"
  fi
fi
id "$TARGET_USER" >/dev/null 2>&1 || die "用户不存在: $TARGET_USER"

if [[ -z "$TARGET_HOME" ]]; then
  TARGET_HOME="$(eval echo "~$TARGET_USER")"
fi
[[ -d "$TARGET_HOME" ]] || die "HOME 目录不存在: $TARGET_HOME"

IS_ROOT=0; [[ "$(id -u)" -eq 0 ]] && IS_ROOT=1
RUN_AS_ROOT=0; [[ "$TARGET_USER" == "root" ]] && RUN_AS_ROOT=1
log "目标用户: $TARGET_USER   HOME: $TARGET_HOME   主题模式: $THEME_MODE"

# 以目标用户身份执行命令
runu() {
  if [[ "$CURRENT_USER" == "$TARGET_USER" ]]; then
    "$@"
  elif [[ $IS_ROOT -eq 1 ]]; then
    sudo -u "$TARGET_USER" -H "$@" 2>/dev/null || su -s /bin/sh "$TARGET_USER" -c "$(printf '%q ' "$@")"
  else
    sudo -u "$TARGET_USER" -H "$@"
  fi
}
# 需要 root 权限的系统级操作
as_root() {
  if [[ $IS_ROOT -eq 1 ]]; then "$@"
  elif command -v sudo >/dev/null 2>&1; then sudo "$@"
  else die "需要 root 权限执行: $*"
  fi
}
maybe() { if [[ $DRY_RUN -eq 1 ]]; then log "[dry-run] $*"; else "$@"; fi; }
chown_quiet() { [[ $IS_ROOT -eq 1 ]] && chown -R "$TARGET_USER" "$@" 2>/dev/null || true; }

# ------------------------------------------------------------------------------
# 识别系统 & 安装依赖（zsh / git / curl）
# ------------------------------------------------------------------------------
OS="unknown"; PKG=""
if [[ "$(uname -s)" == "Darwin" ]]; then
  OS="macos"; PKG="brew"
elif [[ -f /etc/alpine-release ]]; then
  OS="alpine"; PKG="apk"
elif [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  local_id="${ID:-}"; local_like="${ID_LIKE:-}"
  case "$local_id" in
    debian|ubuntu|raspbian|linuxmint|kali|pop|deepin|uos) OS="debian"; PKG="apt-get" ;;
    centos|rhel|rocky|almalinux|ol|oracle|fedora|amzn)      OS="rhel";   PKG="dnf" ;;
    arch|manjaro|endeavouros|garuda)                        OS="arch";   PKG="pacman" ;;
    alpine)                                                 OS="alpine"; PKG="apk" ;;
    opensuse*|sles|suse)                                    OS="suse";   PKG="zypper" ;;
  esac
  if [[ "$OS" == "unknown" ]]; then
    case "$local_like" in
      *debian*|*ubuntu*) OS="debian"; PKG="apt-get" ;;
      *rhel*|*fedora*|*centos*) OS="rhel"; PKG="dnf" ;;
      *arch*) OS="arch"; PKG="pacman" ;;
      *suse*) OS="suse"; PKG="zypper" ;;
    esac
  fi
fi
[[ "$PKG" == "dnf" ]] && { command -v dnf >/dev/null 2>&1 || PKG="yum"; }
log "系统识别: OS=$OS  包管理器=${PKG:-未知}"

need_bins() { for b in "$@"; do command -v "$b" >/dev/null 2>&1 || return 0; done; return 1; }

install_packages() {
  local missing=()
  need_bins zsh && missing+=(zsh)
  need_bins git && missing+=(git)
  need_bins curl && missing+=(curl)
  if [[ ${#missing[@]} -eq 0 ]]; then
    ok "zsh / git / curl 均已安装"
    return 0
  fi
  log "需要安装: ${missing[*]}"
  case "$OS" in
    macos)
      command -v brew >/dev/null 2>&1 || die "未检测到 Homebrew，请先安装：https://brew.sh"
      # brew 不允许以 root 身份运行
      if [[ $IS_ROOT -eq 1 && "$TARGET_USER" != "root" ]]; then
        maybe runu brew install "${missing[@]}"
      else
        maybe brew install "${missing[@]}"
      fi ;;
    debian)
      maybe as_root env DEBIAN_FRONTEND=noninteractive apt-get update -y
      maybe as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}" ca-certificates locales ;;
    rhel)
      local pm="dnf"; command -v dnf >/dev/null 2>&1 || pm="yum"
      maybe as_root "$pm" install -y "${missing[@]}" ca-certificates ;;
    arch)   maybe as_root pacman -Sy --noconfirm --needed "${missing[@]}" ;;
    alpine) maybe as_root apk add --no-cache "${missing[@]}" ;;
    suse)   maybe as_root zypper --non-interactive install "${missing[@]}" ;;
    *)      die "无法自动安装依赖（未识别的系统）。请手动安装 zsh、git 后重试。" ;;
  esac
}

if [[ $SKIP_PACKAGES -eq 0 ]]; then
  install_packages
else
  log "已跳过依赖安装 (--skip-packages)"
fi
[[ $DRY_RUN -eq 1 ]] || command -v zsh >/dev/null 2>&1 || die "zsh 未安装成功"

# ------------------------------------------------------------------------------
# Git 仓库获取（支持镜像加速、幂等更新、git 缺失时回退 tarball）
# ------------------------------------------------------------------------------
mirror_url() {
  local u="$1"
  if [[ -n "$GITHUB_MIRROR" ]]; then
    printf '%s%s' "${GITHUB_MIRROR%/}/" "$u"
  else
    printf '%s' "$u"
  fi
}

tarball_fallback() {   # $1=github 仓库 url  $2=目标目录（git 不可用时的兜底）
  local url="$1" dest="$2" tmp tb path br
  path="${url#https://github.com/}"; path="${path%.git}"
  tmp="$(mktemp -d)"
  for br in master main; do
    tb="https://codeload.github.com/${path}/tar.gz/refs/heads/${br}"
    log "git 不可用，尝试 tarball: $tb"
    if curl -fsSL "$tb" -o "$tmp/repo.tar.gz" 2>/dev/null; then
      mkdir -p "$dest"
      if tar -xzf "$tmp/repo.tar.gz" -C "$dest" --strip-components=1; then
        rm -rf "$tmp"
        chown_quiet "$dest"
        return 0
      fi
    fi
  done
  rm -rf "$tmp"
  return 1
}

fetch_repo() {   # $1=github 仓库 url  $2=目标目录
  local repo="$1" dest="$2" url
  url="$(mirror_url "$repo")"

  if [[ $DRY_RUN -eq 1 ]]; then
    log "[dry-run] 将获取仓库: $repo -> $dest"
    return 0
  fi

  if [[ -d "$dest/.git" ]]; then
    log "更新已存在的仓库: $dest"
    runu git -C "$dest" pull --ff-only --depth=1 >/dev/null 2>&1 \
      || warn "更新失败（离线或已修改），继续使用现有版本: $dest"
    return 0
  fi
  if [[ -d "$dest" && -n "$(ls -A "$dest" 2>/dev/null)" ]]; then
    if [[ $FORCE -eq 1 ]]; then
      warn "目录已存在，--force 覆盖: $dest"
      maybe rm -rf "$dest"
    else
      warn "目录已存在且不是 git 仓库，跳过（用 --force 覆盖）: $dest"
      return 0
    fi
  fi

  if command -v git >/dev/null 2>&1; then
    log "克隆: $url"
    runu git clone --depth=1 "$url" "$dest" || {
      log "镜像源不可用，改用 GitHub 官方源重试"
      runu git clone --depth=1 "$repo" "$dest" || die "克隆失败: $repo"
    }
  else
    tarball_fallback "$repo" "$dest" || die "无法获取仓库: $repo"
  fi
  ok "完成: $dest"
}

# ------------------------------------------------------------------------------
# 开始安装
# ------------------------------------------------------------------------------
OMZ_DIR="$TARGET_HOME/.oh-my-zsh"
ZSH_CUSTOM_DIR="$OMZ_DIR/custom"

log "== 1/5 安装 Oh My Zsh =="
fetch_repo "$REPO_OMZ" "$OMZ_DIR"

log "== 2/5 安装插件 =="
fetch_repo "$REPO_AUTOSUGGEST" "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
fetch_repo "$REPO_SYNTAX_HL"   "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"

log "== 3/5 主题与模式 ($THEME_MODE) =="
if [[ "$THEME_MODE" == "p10k" ]]; then
  fetch_repo "$REPO_P10K" "$ZSH_CUSTOM_DIR/themes/powerlevel10k"
fi
maybe mkdir -p "$TARGET_HOME/.config/omz-setup"
if [[ $DRY_RUN -eq 0 ]]; then
  printf '%s\n' "$THEME_MODE" > "$TARGET_HOME/.config/omz-setup/mode"
fi
chown_quiet "$TARGET_HOME/.config/omz-setup"
if [[ $DRY_RUN -eq 1 ]]; then
  log "[dry-run] 主题模式将写入: ~/.config/omz-setup/mode = $THEME_MODE"
else
  ok "主题模式已写入: $TARGET_HOME/.config/omz-setup/mode = $THEME_MODE"
fi

log "== 4/5 部署配置文件 =="
ts="$(date +%Y%m%d-%H%M%S)"

# 备份现有配置（只备份一次，保留最早的原始文件）
if [[ -f "$TARGET_HOME/.zshrc" ]] && grep -q "omz-setup" "$TARGET_HOME/.zshrc" 2>/dev/null; then
  log "检测到旧版 omz-setup 配置，直接更新"
elif [[ -f "$TARGET_HOME/.zshrc" ]]; then
  cp -p "$TARGET_HOME/.zshrc" "$TARGET_HOME/.zshrc.omz-setup.bak-$ts"
  ok "已备份原配置: ~/.zshrc.omz-setup.bak-$ts"
fi
maybe cp "$ASSETS_DIR/zshrc" "$TARGET_HOME/.zshrc"
chown_quiet "$TARGET_HOME/.zshrc"

if [[ "$THEME_MODE" == "p10k" && -f "$ASSETS_DIR/p10k.zsh" ]]; then
  if [[ -f "$TARGET_HOME/.p10k.zsh" ]]; then
    cp -p "$TARGET_HOME/.p10k.zsh" "$TARGET_HOME/.p10k.zsh.omz-setup.bak-$ts"
    ok "已备份原 p10k 配置: ~/.p10k.zsh.omz-setup.bak-$ts"
  fi
  maybe cp "$ASSETS_DIR/p10k.zsh" "$TARGET_HOME/.p10k.zsh"
  chown_quiet "$TARGET_HOME/.p10k.zsh"
fi

if [[ ! -f "$TARGET_HOME/.zshrc.local" && $DRY_RUN -eq 0 ]]; then
  cat > "$TARGET_HOME/.zshrc.local" <<'EOF'
# 本机私有配置（不会被 omz-setup 覆盖），示例见 files/zshrc.local.example
EOF
  chown_quiet "$TARGET_HOME/.zshrc.local"
  ok "已创建 ~/.zshrc.local（写你自己的私有配置到这里）"
fi

log "== 5/5 设置默认 Shell =="
ZSH_BIN="$(command -v zsh || true)"
[[ -n "$ZSH_BIN" ]] || ZSH_BIN="/usr/bin/zsh"

if [[ $SKIP_CHSH -eq 1 ]]; then
  log "已跳过 chsh (--skip-chsh)"
else
  case "$ZSH_BIN" in
    "$TARGET_HOME"/*) warn "zsh 装在用户目录下，无法用作登录 shell: $ZSH_BIN" ;;
    *)
      if ! grep -qx "$ZSH_BIN" /etc/shells 2>/dev/null; then
        if [[ $IS_ROOT -eq 1 || "$PKG" == "brew" ]]; then
          maybe as_root sh -c "printf '%s\n' '$ZSH_BIN' >> /etc/shells"
        else
          warn "请手动把 $ZSH_BIN 加入 /etc/shells 后执行 chsh -s $ZSH_BIN"
        fi
      fi
      cur_shell=""
      if command -v getent >/dev/null 2>&1; then
        cur_shell="$(getent passwd "$TARGET_USER" | awk -F: '{print $7}')"
      elif [[ "$(uname -s)" == "Darwin" ]]; then
        cur_shell="$(dscl . -read "/Users/$TARGET_USER" UserShell 2>/dev/null | awk '{print $2}')"
      fi
      if [[ "$cur_shell" == "$ZSH_BIN" ]]; then
        ok "默认 shell 已经是 zsh"
      elif [[ $DRY_RUN -eq 1 ]]; then
        log "[dry-run] chsh -s $ZSH_BIN $TARGET_USER"
      else
        if runu chsh -s "$ZSH_BIN" 2>/dev/null || as_root chsh -s "$ZSH_BIN" "$TARGET_USER" 2>/dev/null; then
          ok "默认 shell 已设置为 $ZSH_BIN"
        else
          warn "chsh 失败，请手动执行: chsh -s $ZSH_BIN"
        fi
      fi
      ;;
  esac
fi

# ------------------------------------------------------------------------------
# 完成
# ------------------------------------------------------------------------------
printf '\n'
ok "安装完成！oh-my-zsh $(git -C "$OMZ_DIR" describe --tags --always 2>/dev/null || echo '(已安装)')"
printf '%s\n' "  · 配置目录   : $OMZ_DIR"
printf '%s\n' "  · 主配置     : $TARGET_HOME/.zshrc  (私有配置写 $TARGET_HOME/.zshrc.local)"
printf '%s\n' "  · 主题模式   : $THEME_MODE$([[ "$THEME_MODE" == "simple" ]] && echo '  (Mac 风格两行提示符，无需 Nerd Font)')"
printf '%s\n' "  · 立即生效   : exec zsh   或   重新登录"
if [[ "$THEME_MODE" == "p10k" ]]; then
  printf '%s\n' "  · p10k 字体  : 本地终端需安装 MesloLGS NF，否则会显示方块"
fi
printf '%s\n' "  · 重新配置   : 再跑一次本脚本即可更新（幂等）"
printf '%s\n' "  · 卸载回滚   : bash $(dirname "${BASH_SOURCE[0]:-$0}")/uninstall.sh"
