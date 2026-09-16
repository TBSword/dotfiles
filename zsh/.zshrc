# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000

# Was going to set zsh to vim mode when I found this setting already here. Dunno what happened.
bindkey -v

# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename "$HOME/.zshrc"

autoload -Uz compinit
compinit
# End of lines added by compinstall

# Starship stuff idk it's in the installation tutorial
eval "$(starship init zsh)"

# zsh-autosuggestions
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_ACCEPT_WIDGETS=(
    forward-char
    end-of-line
    vi-end-of-line
    vi-forward-word
    vi-add-eol
)

# Show how to access a syncthing panel through a browser
alias syncthinglocal='syncthing cli show system | grep 127'

# Yazi needs a default editor before I figure out how to configure it
export EDITOR='vim'
# Yazi shell wrapper that changes working dir upon exit
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

# Some extended ls commands for convenience
alias l.='ls -d .* --color=auto'
alias ll='ls -l --color=auto'

# Toggle proxy
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

# Enable fzf features
source ~/fzf.zsh

# Add ./.local to PATH
export PATH="$PATH:$HOME/.local/bin"

# nvm needs this code
source /usr/share/nvm/init-nvm.sh

# query pacman
alias qpac='pacman -Q | grep'
# search pacman
alias spac='pacman -Ss'
# pacman install
alias ipac='sudo pacman -S'
# pacman update 
alias upac='sudo pacman -Syu'
# pacman delete 
alias dpac='sudo pacman -Rsn'
# pacman cache clean
alias cpac='sudo paccache -r'

# Quick Lazygit
function lazygit_widget(){
    lazygit
    zle reset-prompt
}

zle -N lazygit_widget

bindkey '^g' lazygit_widget

# Quick Yazi
function yazi_widget(){
    zle -I
    y < /dev/tty
    zle reset-prompt
}

zle -N yazi_widget

bindkey '^y' yazi_widget

# Quick Opencode
function opencode_widget(){
    zle -I
    cd "$HOME/dotfiles"
    opencode < /dev/tty
    zle reset-prompt
}

zle -N opencode_widget

bindkey '^o' opencode_widget

# keyd shortcuts
alias editkeys='sudo -E nvim /etc/keyd/*'
alias loadkeys='keyd check && sudo keyd reload'
# Xtea_log is my journal as a sysadmin
alias xtealog="nvim $HOME/Documents/Xtea_log/yeah.sh"
alias nvfu='systemctl hibernate'

# android sdk
export ANDROID_HOME=/opt/android-sdk
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH

# ask deepseek in terminal
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

# Colemak reference
colemak() {
echo "  +-----------------------------------------------------+ "
echo "  |             C O L E M A K   L A Y O U T             | "
echo "  +-----------------------------------------------------+ "
echo "                                                          "
echo "   [Q] [W] [F] [P] [G]   [J] [L] [U] [Y] [;] [[] []] [\]  "
echo "     [A] [R] [S] [T] [D]   [H] [N] [E] [I] [O] [']        "
echo "       [Z] [X] [C] [V] [B]   [K] [M] [,] [.] [/]          "
}

# BEGIN opam configuration
# This is useful if you're using opam as it adds:
#   - the correct directories to the PATH
#   - auto-completion for the opam binary
# This section can be safely removed at any time if needed.
[[ ! -r "$HOME/.opam/opam-init/init.zsh" ]] || source "$HOME/.opam/opam-init/init.zsh" > /dev/null 2> /dev/null
# END opam configuration
#

export REPO_DIR="$HOME/Desktop/Ferrous/terraria_ig/repo/sp21-s456"
export SNAPS_DIR="$HOME/Desktop/Ferrous/terraria_ig/repo/snaps-sp21-s456"

