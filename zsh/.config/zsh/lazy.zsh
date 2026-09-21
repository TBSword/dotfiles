# nvm：首次调用 node/npm/npx/nvm 时再加载，缩短 Shell 启动时间
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [[ -s /usr/share/nvm/init-nvm.sh ]]; then
  nvm() {
    unset -f nvm node npm npx 2>/dev/null
    source /usr/share/nvm/init-nvm.sh
    nvm "$@"
  }
  node() { nvm "$@"; }
  npm()  { nvm "$@"; }
  npx()  { nvm "$@"; }
fi

# opam：保留原按需初始化；这里不额外包装，由 plugins.zsh 加载
