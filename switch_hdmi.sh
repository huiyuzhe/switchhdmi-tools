#!/bin/bash
# 一键切换显示器输入源（LG T270LG, Apple Silicon, 依赖 m1ddc）
# 用法: ./switch_hdmi.sh [toggle|list|current|status|<输入代码>]
#   toggle  按输入源列表顺序循环切换（默认）
#   list    列出所有输入源（机器可读: 代码<TAB>名称）
#   current 输出当前输入源代码（失败则非 0 退出）
#   status  人类可读的当前输入源
#   <代码>  直接切到指定输入源

# 自动选择 DDC 工具: macOS 优先 m1ddc，Intel Mac 备选 ddcctl，Linux 用 ddcutil
M1DDC="/opt/homebrew/bin/m1ddc"
STATE_FILE="$HOME/.hdmi_switch_state"
if [ -x "$M1DDC" ]; then
  DDC_TOOL=m1ddc
elif command -v m1ddc >/dev/null 2>&1; then
  DDC_TOOL=m1ddc
  M1DDC=$(command -v m1ddc)
elif command -v ddcctl >/dev/null 2>&1; then
  DDC_TOOL=ddcctl
  M1DDC=$(command -v ddcctl)
elif command -v ddcutil >/dev/null 2>&1; then
  DDC_TOOL=ddcutil
else
  echo "未找到 DDC 工具: macOS 请 brew install m1ddc（或 ddcctl），Linux 请安装 ddcutil"
  exit 1
fi

# ============ 可配置区 ============
# 输入源列表，格式 "代码:名称"，按顺序排列
# 一键切换就在这个列表里循环；以后有第 3 路，往这里加一行即可
# 常见 VCP 0x60 代码: 15=HDMI1 17=HDMI2 18=HDMI3 4=DP1 11=DP2
INPUTS=(
  "15:HDMI 1（另一台电脑）"
  "17:HDMI 2（本机）"
)
# =================================

count_inputs() { echo ${#INPUTS[@]}; }

label_of() {
  local e code="${1}"
  for e in "${INPUTS[@]}"; do
    if [ "${e%%:*}" = "$code" ]; then echo "${e#*:}"; return 0; fi
  done
  echo "输入 $code"
}

index_of() {
  # 返回代码在列表中的下标（0 起），找不到输出空
  local e code="${1}" i=0
  for e in "${INPUTS[@]}"; do
    if [ "${e%%:*}" = "$code" ]; then echo "$i"; return 0; fi
    i=$((i + 1))
  done
  return 1
}

get_input() {
  # DDC 读取偶发失败，重试 3 次
  # ddcctl 读取输出格式不可靠，直接返回失败（toggle 走状态文件兜底）
  [ "$DDC_TOOL" = ddcctl ] && return 1
  local tries=0 input=""
  while [ $tries -lt 3 ]; do
    if [ "$DDC_TOOL" = m1ddc ]; then
      input=$("$M1DDC" get input 2>/dev/null)
    else
      input=$("$M1DDC" getvcp 0x60 2>/dev/null | grep -oE 'current value *= *[0-9]+' | grep -oE '[0-9]+$')
    fi
    # 只接受纯数字，过滤 m1ddc 偶发打到 stdout 的错误信息
    case "$input" in
      ''|*[!0-9]*) ;;
      *) echo "$input"; return 0 ;;
    esac
    tries=$((tries + 1))
    sleep 0.3
  done
  return 1
}

do_switch() {
  local target="$1"
  case "$DDC_TOOL" in
    m1ddc)
      "$M1DDC" set input "$target" 2>/dev/null || return 1
      ;;
    ddcctl)
      "$M1DDC" -d 1 -i "$target" >/dev/null 2>&1 || return 1
      ;;
    *)
      "$M1DDC" setvcp 0x60 "$target" >/dev/null 2>&1 || return 1
      ;;
  esac
  echo "$target" > "$STATE_FILE"
  echo "已切换到 $(label_of "$target")"
}

is_number() { [ -n "$1" ] && [ "$1" -eq "$1" ] 2>/dev/null; }

case "${1:-toggle}" in
  status)
    if cur=$(get_input); then
      echo "当前输入: $(label_of "$cur") ($cur)"
    else
      echo "读取失败（显示器无响应）"
      exit 1
    fi
    ;;
  current)
    get_input || exit 1
    ;;
  list)
    for e in "${INPUTS[@]}"; do
      printf '%s\t%s\n' "${e%%:*}" "${e#*:}"
    done
    ;;
  toggle)
    n=$(count_inputs)
    if cur=$(get_input); then
      idx=$(index_of "$cur" 2>/dev/null)
    elif [ -f "$STATE_FILE" ]; then
      # 读取失败时退回状态文件记忆
      idx=$(index_of "$(cat "$STATE_FILE" 2>/dev/null)" 2>/dev/null)
    else
      idx=""
    fi
    if [ -n "$idx" ]; then
      next=$(( (idx + 1) % n ))
    else
      next=0
    fi
    target="${INPUTS[$next]%%:*}"
    do_switch "$target" || { echo "切换失败"; exit 1; }
    ;;
  *)
    if is_number "$1"; then
      do_switch "$1" || { echo "切换失败"; exit 1; }
    else
      echo "用法: $0 [toggle|list|current|status|<输入代码>]"
      exit 2
    fi
    ;;
esac
