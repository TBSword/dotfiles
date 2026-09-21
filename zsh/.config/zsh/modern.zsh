# zsh 现代配置入口：按顺序加载同目录模块
# 加载顺序：基础选项 → 环境变量 → 补全 → 按键 → 别名/函数 → 工具 → 插件

_zsh_confdir="${${(%):-%x}:A:h}"
source "$_zsh_confdir/options.zsh"
source "$_zsh_confdir/environment.zsh"
source "$_zsh_confdir/completion.zsh"
source "$_zsh_confdir/keybindings.zsh"
source "$_zsh_confdir/aliases.zsh"
source "$_zsh_confdir/functions.zsh"
source "$_zsh_confdir/tools.zsh"
source "$_zsh_confdir/lazy.zsh"
source "$_zsh_confdir/plugins.zsh"
unset _zsh_confdir
