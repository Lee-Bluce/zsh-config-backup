#!/usr/bin/env bash
# ==============================================================================
#  omz-setup · 卸载 / 回滚脚本
# ------------------------------------------------------------------------------
#  默认行为（安全）：只恢复被 omz-setup 覆盖的配置文件，不动 ~/.oh-my-zsh
#  彻底卸载：        bash uninstall.sh --purge        # 同时删除 ~/.oh-my-zsh
#  指定用户：        sudo bash uninstall.sh --user deploy [--purge]
#  切换回原 shell：  bash uninstall.sh --restore-shell
# ==============================================================================
set -euo pipefail

TARGET_USER="${TARGET_USER:-}"
TARGET_HOME="${TARGET_HOME:-}"
PURGE=0
RESTORE_SHELL=0

C_R=$'\033[31m'; C_G=$'\033[32m'; C_Y=$'\033[33m'; C_N=$'\033[0m'
log()  { printf '[omz-setup] %s\n' "$*"; }
ok()   { printf '%s[ OK ]%s %s\n' "$C_G" "$C_N" "$*"; }
warn() { printf '%s[WARN]%s %s\n' "$C_Y" "$C_N" "$*" >&2; }
die()  { printf '%s[FAIL]%s %s\n' "$C_R" "$C_N" "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user) TARGET_USER="${2:?}"; shift 2 ;;
    --home) TARGET_HOME="${2:?}"; shift 2 ;;
    --purge) PURGE=1; shift ;;
    --restore-shell) RESTORE_SHELL=1; shift ;;
    -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "未知参数: $1" ;;
  esac
done

IS_ROOT=0; [[ "$(id -u)" -eq 0 ]] && IS_ROOT=1
if [[ -z "$TARGET_USER" ]]; then
  if [[ $IS_ROOT -eq 1 && -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    TARGET_USER="$SUDO_USER"
  else
    TARGET_USER="$(id -un)"
  fi
fi
id "$TARGET_USER" >/dev/null 2>&1 || die "用户不存在: $TARGET_USER"
[[ -n "$TARGET_HOME" ]] || TARGET_HOME="$(eval echo "~$TARGET_USER")"

OMZ_DIR="$TARGET_HOME/.oh-my-zsh"
log "目标用户: $TARGET_USER   HOME: $TARGET_HOME"

# --- 1. 恢复最新的 .zshrc 备份 ---
latest_backup="$(ls -1t "$TARGET_HOME"/.zshrc.omz-setup.bak-* 2>/dev/null | head -1 || true)"
if [[ -f "$TARGET_HOME/.zshrc" ]] && grep -q "omz-setup" "$TARGET_HOME/.zshrc" 2>/dev/null; then
  rm -f "$TARGET_HOME/.zshrc"
  if [[ -n "$latest_backup" && -f "$latest_backup" ]]; then
    cp -p "$latest_backup" "$TARGET_HOME/.zshrc"
    ok "已恢复原 .zshrc（来自 $(basename "$latest_backup")）"
  else
    warn ".zshrc 已删除，但没有找到备份，请手动恢复"
  fi
else
  log ".zshrc 不是 omz-setup 管理的，保持不动"
fi

# --- 2. 清理模式标记 ---
rm -f "$TARGET_HOME/.config/omz-setup/mode"
rmdir "$TARGET_HOME/.config/omz-setup" 2>/dev/null || true

# --- 3. 可选：删除 oh-my-zsh 本体 ---
if [[ $PURGE -eq 1 ]]; then
  if [[ -d "$OMZ_DIR" ]]; then
    rm -rf "$OMZ_DIR"
    ok "已删除 $OMZ_DIR"
  fi
  log "注意：~/.zshrc.local 与 *.bak 备份已保留，确认无用后可自行删除"
else
  log "保留 $OMZ_DIR（如需删除请加 --purge）"
fi

# --- 4. 可选：恢复登录 shell ---
if [[ $RESTORE_SHELL -eq 1 ]]; then
  for sh in bash /bin/bash /bin/sh; do
    if [[ -x "$sh" ]]; then
      if [[ $IS_ROOT -eq 1 ]]; then chsh -s "$sh" "$TARGET_USER" || warn "chsh 失败"
      else chsh -s "$sh" || warn "chsh 失败"; fi
      ok "登录 shell 已改为 $sh"
      break
    fi
  done
fi

printf '\n'
ok "卸载完成"
