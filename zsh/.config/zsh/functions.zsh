# yazi 包装：退出后 cd 到最后目录
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp"
  [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}

mkcd() { mkdir -p -- "$1" && builtin cd -- "$1"; }

# 代理开关
v() {
  if systemctl is-active --quiet v2raya; then
    sudo systemctl stop v2raya
    echo "v2rayA Proxy: OFF"
  else
    sudo systemctl start v2raya
    echo "v2rayA Proxy: ON"
  fi
}
d() {
  if systemctl is-active --quiet daed; then
    sudo systemctl stop daed
    echo "daed Proxy: OFF"
  else
    sudo systemctl start daed
    echo "daed Proxy: ON"
  fi
}

# 终端内快速打开
function lazygit_widget() {
  lazygit
  zle reset-prompt
}
zle -N lazygit_widget
bindkey '^g' lazygit_widget

function yazi_widget() {
  zle -I
  y < /dev/tty
  zle reset-prompt
}
zle -N yazi_widget
bindkey '^y' yazi_widget

function opencode_widget() {
  zle -I
  cd "$HOME/dotfiles"
  opencode < /dev/tty
  zle reset-prompt
}
zle -N opencode_widget
bindkey '^o' opencode_widget

# ask deepseek
ask() {
  local model="deepseek/deepseek-v4-flash"
  if [[ $# -eq 0 ]]; then
    cd "$HOME/t/copilot-ask"
    OPENCODE_EXPERIMENTAL_PLAN_MODE=true opencode -s ses_1feb442aeffefQeRlxIEBL0piB -m "$model"
  else
    OPENCODE_EXPERIMENTAL_PLAN_MODE=true opencode run --dir "$HOME/t/copilot-ask" -s ses_1feb442aeffefQeRlxIEBL0piB -m "$model" "$@"
  fi
}
askx() {
  local model="deepseek/deepseek-v4-pro"
  if [[ $# -eq 0 ]]; then
    cd "$HOME/t/copilot-ask"
    OPENCODE_EXPERIMENTAL_PLAN_MODE=true opencode -s ses_1feb442aeffefQeRlxIEBL0piB -m "$model"
  else
    OPENCODE_EXPERIMENTAL_PLAN_MODE=true opencode run --dir "$HOME/t/copilot-ask" -s ses_1feb442aeffefQeRlxIEBL0piB -m "$model" "$@"
  fi
}

# Colemak 参考
colemak() {
echo "  +-----------------------------------------------------+ "
echo "  |             C O L E M A K   L A Y O U T             | "
echo "  +-----------------------------------------------------+ "
echo "                                                          "
echo "   [Q] [W] [F] [P] [G]   [J] [L] [U] [Y] [;] [[] []] [\]  "
echo "     [A] [R] [S] [T] [D]   [H] [N] [E] [I] [O] [']        "
echo "       [Z] [X] [C] [V] [B]   [K] [M] [,] [.] [/]          "
}

# 项目环境变量
export REPO_DIR="$HOME/Desktop/Ferrous/terraria_ig/repo/sp21-s456"
export SNAPS_DIR="$HOME/Desktop/Ferrous/terraria_ig/repo/snaps-sp21-s456"

# xl: 执行后续命令，并将该命令以可复用形式追加到 yeah.sh（按天追加 #YYYYMMDD 注释）
xl() {
  local logfile="$HOME/Documents/Xtea_log/yeah.sh"
  local dir=${logfile%/*}
  local today last_date cmd
  if [ "$#" -eq 0 ]; then
    return 0
  fi

  cmd=$(printf '%q ' "$@")
  cmd=${cmd% }

  if mkdir -p -- "$dir"; then
    today="#$(date +%Y%m%d)"
    last_date=$(grep -E '^#[0-9]{8}$' "$logfile" 2>/dev/null | tail -n 1)
    {
      if [ "$last_date" != "$today" ]; then
        if [ -s "$logfile" ]; then
          printf '\n'
        fi
        printf '%s\n' "$today"
      fi
      printf '%s\n' "$cmd"
    } >> "$logfile" || printf 'xl: 无法写入日志：%s\n' "$logfile" >&2
  else
    printf 'xl: 无法创建日志目录：%s\n' "$dir" >&2
  fi

  eval "$cmd"
}
