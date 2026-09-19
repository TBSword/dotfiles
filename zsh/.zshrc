# zsh 入口：实际配置在 ~/.config/zsh/modern.zsh 及其模块中
export ZDOTDIR="${ZDOTDIR:-$HOME}"
[[ -r "$HOME/.config/zsh/modern.zsh" ]] && source "$HOME/.config/zsh/modern.zsh"
