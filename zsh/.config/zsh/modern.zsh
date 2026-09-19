export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
mkdir -p -- "$XDG_STATE_HOME/zsh" "$XDG_CACHE_HOME/zsh"

HISTFILE="$XDG_STATE_HOME/zsh/history"
HISTSIZE=100000
SAVEHIST=100000
setopt appendhistory sharehistory incappendhistory histignoredups histignorespace
setopt histexpiredupsfirst histreduceblanks interactivecomments extendedglob autocd
unsetopt beep flowcontrol

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}%d%f'
zstyle ':completion:*:warnings' format '%F{red}no matches%f'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/zcompcache"
[[ -n ${LS_COLORS:-} ]] && zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey -M viins '^[[A' up-line-or-beginning-search
bindkey -M viins '^[[B' down-line-or-beginning-search
KEYTIMEOUT=1

(( $+commands[nvim] )) && export EDITOR=nvim
export VISUAL="${VISUAL:-${EDITOR:-vim}}"
export PAGER='less -FRX'
export LESS='-FRX'
export LESSHISTFILE='-'
if (( $+commands[bat] )); then
  export BAT_THEME="${BAT_THEME:-ansi}"
  export BAT_STYLE='numbers,changes,header'
  export BAT_PAGER='less -FRX'
  alias cat='bat --style=plain --paging=never'
  alias catn='bat --style=numbers --paging=never'
  (( $+commands[col] )) && export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi
(( $+commands[delta] )) && export GIT_PAGER='delta'

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
(( $+commands[nvim] )) && alias vim='nvim'
(( $+commands[lazygit] )) && alias lg='lazygit'
mkcd() { mkdir -p -- "$1" && builtin cd -- "$1"; }

if (( $+commands[fd] )); then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git --exclude node_modules'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git --exclude node_modules'
fi
export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:-} --height 45% --layout=reverse --border --info=inline --cycle"
if (( $+commands[bat] )); then
  export FZF_CTRL_T_OPTS='--preview "bat --style=numbers --color=always --line-range :200 {}"'
  (( $+commands[eza] )) && export FZF_ALT_C_OPTS='--preview "eza --tree --level=2 --color=always {} | head -100"'
fi

ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#5c6370'
ZSH_AUTOSUGGEST_USE_ASYNC=1
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"
(( $+commands[direnv] )) && eval "$(direnv hook zsh)"
(( $+commands[atuin] )) && eval "$(atuin init zsh --disable-up-arrow)"
if [[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern cursor)
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
