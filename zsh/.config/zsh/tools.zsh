# zsh-autosuggestions 行为（插件本身在 plugins.zsh 加载）
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#5c6370'
ZSH_AUTOSUGGEST_USE_ASYNC=1

# 现代工具初始化
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"
(( $+commands[direnv] )) && eval "$(direnv hook zsh)"
(( $+commands[atuin] )) && eval "$(atuin init zsh --disable-up-arrow)"

# Starship：优先使用 dotfiles 内配置，其次用户配置
if (( $+commands[starship] )); then
  [[ -z ${STARSHIP_CONFIG:-} && -r "$HOME/dotfiles/starship/.config/starship.toml" ]] && \
    export STARSHIP_CONFIG="$HOME/dotfiles/starship/.config/starship.toml"
  eval "$(starship init zsh)"
fi
