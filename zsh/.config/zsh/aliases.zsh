# 编辑器与文件操作
(( $+commands[nvim] )) && alias vim='nvim'
(( $+commands[lazygit] )) && alias lg='lazygit'
if (( $+commands[eza] )); then
  alias ls='eza --group-directories-first --icons=auto --color=auto'
  alias l='eza -l --group-directories-first --icons=auto --color=auto'
  alias ll='eza -lh --group-directories-first --icons=auto --git --color=auto'
  alias la='eza -lah --group-directories-first --icons=auto --git --color=auto'
  alias lt='eza --tree --level=3 --group-directories-first --icons=auto --color=auto'
  alias l.='eza -d .* --group-directories-first --icons=auto --color=auto'
else
  alias ls='ls --color=auto'
  alias ll='ls -l --color=auto'
  alias la='ls -la --color=auto'
  alias l.='ls -d .* --color=auto'
fi
alias grep='grep --color=auto'
(( $+commands[rg] )) && alias rg='rg --smart-case'
(( $+commands[duf] )) && alias df='duf'
(( $+commands[dust] )) && alias du='dust'
(( $+commands[procs] )) && alias p='procs'
if (( $+commands[bat] )); then
  alias cat='bat --style=plain --paging=never'
  alias catn='bat --style=numbers --paging=never'
fi

# pacman
alias qpac='pacman -Q | grep'
alias spac='pacman -Ss'
alias ipac='sudo pacman -S'
alias upac='sudo pacman -Syu'
alias dpac='sudo pacman -Rsn'
alias cpac='sudo paccache -r'

# 其他
alias syncthinglocal='syncthing cli show system | grep 127'
alias editkeys='sudo -E nvim /etc/keyd/*'
alias loadkeys='keyd check && sudo keyd reload'
alias xtealog="nvim $HOME/Documents/Xtea_log/yeah.sh"
alias nvfu='systemctl hibernate'
