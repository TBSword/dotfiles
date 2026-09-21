# 补全：压缩缓存固定到 XDG_CACHE_HOME，避免主目录散落 .zcompdump
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}%d%f'
zstyle ':completion:*:warnings' format '%F{red}no matches%f'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/zcompcache"
[[ -n ${LS_COLORS:-} ]] && zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

autoload -Uz compinit
local dumpfile="$XDG_CACHE_HOME/zsh/zcompdump"
if [[ -f "$dumpfile" && $dumpfile -nt "$HOME/.zshrc" ]]; then
  compinit -C -d "$dumpfile"
else
  compinit -d "$dumpfile"
fi
