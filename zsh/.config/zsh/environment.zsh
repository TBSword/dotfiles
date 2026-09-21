# 编辑器、分页器与颜色
(( $+commands[nvim] )) && export EDITOR=nvim
export VISUAL="${VISUAL:-${EDITOR:-vim}}"
export PAGER='less -FRX'
export LESS='-FRX'
export LESSHISTFILE='-'
if (( $+commands[bat] )); then
  export BAT_THEME="${BAT_THEME:-ansi}"
  export BAT_STYLE='numbers,changes,header'
  export BAT_PAGER='less -FRX'
  (( $+commands[col] )) && export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi
(( $+commands[delta] )) && export GIT_PAGER='delta'

# PATH 与工具目录
export PATH="$HOME/.local/bin:$PATH"
export ANDROID_HOME=/opt/android-sdk
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

# fzf 预览与默认选项
export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:-} --height 45% --layout=reverse --border --info=inline --cycle"
if (( $+commands[fd] )); then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git --exclude node_modules'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git --exclude node_modules'
fi
if (( $+commands[bat] )); then
  export FZF_CTRL_T_OPTS='--preview "bat --style=numbers --color=always --line-range :200 {}"'
  (( $+commands[eza] )) && export FZF_ALT_C_OPTS='--preview "eza --tree --level=2 --color=always {} | head -100"'
fi
