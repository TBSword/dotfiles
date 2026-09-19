# fzf：优先使用系统提供的 key-bindings 与 completion
if [[ -r /usr/share/fzf/key-bindings.zsh ]]; then
  source /usr/share/fzf/key-bindings.zsh
  [[ -r /usr/share/fzf/completion.zsh ]] && source /usr/share/fzf/completion.zsh
elif [[ -r "$HOME/.config/zsh/fzf.zsh" ]]; then
  source "$HOME/.config/zsh/fzf.zsh"
fi

# zsh-autosuggestions
[[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
  source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# zsh-syntax-highlighting 必须最后加载
if [[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern cursor)
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# 可选：opam，按需保留
[[ -r "$HOME/.opam/opam-init/init.zsh" ]] && source "$HOME/.opam/opam-init/init.zsh" > /dev/null 2> /dev/null
