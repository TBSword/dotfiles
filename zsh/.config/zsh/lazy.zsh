# nvm：不 source nvm.sh，只把"默认版本的 node bin 目录"挂到 PATH（~5ms）。
#
# 为什么这样就一劳永逸：
#   `npm i -g xxx` 永远装进「当前 PATH 上那个 node 的 bin 目录」，
#   而这个目录（~/.nvm/versions/node/<ver>/bin）现在从第一个 shell 起就在 PATH 里，
#   所以 dsh / dst / pnpm / 以后任何全局 CLI 装完立刻可用，不需要再改这份配置。
#
# nvm 本身仍然懒加载（~370ms），只有真的要切版本 / 安装 node 时才付。
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

if [[ -d "$NVM_DIR/versions/node" ]]; then
  # 解析 alias（支持 default -> lts/lithium -> vX.Y.Z 这种链），拿不到就算了
  _nvm_want=
  if [[ -r "$NVM_DIR/alias/default" ]]; then
    _nvm_want=$(<"$NVM_DIR/alias/default")
    _nvm_i=0
    while (( _nvm_i++ < 5 )) && [[ $_nvm_want == */* && -r "$NVM_DIR/alias/$_nvm_want" ]]; do
      _nvm_want=$(<"$NVM_DIR/alias/$_nvm_want")
    done
    _nvm_want=${_nvm_want#v}
  fi

  _nvm_bin=
  # 1) 优先 alias/default 指向的版本（支持 "26"、"26.13.0" 这种前缀写法）
  for _nvm_dir in "$NVM_DIR"/versions/node/*/bin(N); do
    _nvm_ver=${_nvm_dir:h}
    _nvm_ver=${_nvm_ver:t}
    _nvm_ver=${_nvm_ver#v}
    if [[ -n $_nvm_want && ( $_nvm_ver == $_nvm_want || $_nvm_ver == "$_nvm_want".* ) ]]; then
      _nvm_bin=$_nvm_dir
      break
    fi
  done
  # 2) alias 指向的版本没装，就退回已安装的最新版本
  if [[ -z $_nvm_bin ]]; then
    _nvm_bin=$(ls -d "$NVM_DIR"/versions/node/*/bin(N) 2>/dev/null | sort -V | tail -1)
  fi

  [[ -n $_nvm_bin ]] && export PATH="$_nvm_bin:$PATH"
  unset _nvm_want _nvm_bin _nvm_dir _nvm_ver _nvm_i
fi

# 懒加载：只有真的敲 nvm 时才 source nvm.sh
if [[ -s /usr/share/nvm/init-nvm.sh ]]; then
  nvm() {
    unset -f nvm
    source /usr/share/nvm/init-nvm.sh
    nvm "$@"
  }
fi
