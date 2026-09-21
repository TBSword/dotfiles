# Shell 基础行为与历史记录
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
