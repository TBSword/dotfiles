# IdeaVim 内置快捷键速查表

> 依据：[JetBrains/ideavim](https://github.com/JetBrains/ideavim) `master` 分支自带的帮助文件
> `src/main/resources/help/ideavim.txt`（提交 `73c8040`，2026-11-11，面向 IntelliJ 2026.1）。
> 文中的键位都是**安装后即可用的默认值**，不需要任何配置；需要额外开启的插件单独标注。
>
> 官方页面：<https://www.jetbrains.com/help/idea/ideavim.html>

## 怎么读这份表

| 写法 | 含义 |
| --- | --- |
| `<C-x>` | `Ctrl` + `x` |
| `<S-x>` | `Shift` + `x` |
| `<A-x>` | `Alt` + `x` |
| `<leader>` | 默认是 `\`，可用 `let mapleader = " "` 改 |
| `{motion}` | 任意移动命令，如 `w`、`e`、`$`、`j` |
| `{char}` | 任意单个字符 |
| `[count]` | 可选数字前缀，如 `3dd` |

三个前提：

1. **Vim 核心命令**：默认全部可用（本表第 1–8 节）。
2. **IDE 联动命令**：IdeaVim 额外加的默认映射，用来调用 IDE 功能（第 9 节，重点）。
3. **插件命令**：`surround`、`commentary` 等默认**关闭**，要在 `~/.ideavimrc` 里 `set xxx` 才有（第 10 节）。

在 IDE 里随时可以 `:help` 查单个键，`:map` / `:nmap` / `:imap` 查当前映射。

---

## 0. 30 秒上手

```text
i / a / o        进入插入模式          Esc        回到普通模式
:w  :q  :wq      保存 / 关闭 / 保存并关闭
u  <C-r>         撤销 / 重做            .          重复上次修改
/word  n  N      搜索 / 下一个 / 上一个
v  V  <C-v>      字符 / 行 / 块可视模式
y  d  p          复制 / 剪切 / 粘贴
gg  G  :42       文件头 / 文件尾 / 跳到第 42 行
:%s/old/new/g    全文替换
:actionlist      列出 IDE 动作（IdeaVim 特有，见第 9 节）
```

> **只想先记 10 个 IdeaVim 专属键？**
> `gd` 跳到声明 · `K` 看文档 · `<C-t>` 返回 · `gq` 格式化 · `=` 自动缩进 ·
> `gh` 进 Select 模式 · `gt` 切标签页 · `<C-w>h/j/k/l` 切分屏 ·
> `:actionlist` 找 IDE 动作 · 记得 `:w` 默认会保存**所有**文件。

---

## 1. 模式与切换

| 键 | 作用 |
| --- | --- |
| `i` / `a` | 光标前 / 后插入 |
| `I` / `A` | 行首 / 行尾插入 |
| `o` / `O` | 下方 / 上方新开一行插入 |
| `gi` | 回到上次退出插入模式的位置继续插入 |
| `gI` | 在第 1 列插入 |
| `R` | 替换模式（逐字覆盖） |
| `r{char}` | 替换光标处 `[count]` 个字符 |
| `v` / `V` / `<C-v>`（`<C-q>`） | 字符 / 行 / 块可视模式 |
| `gh` / `gH` | 进入 Select 模式（选中字符 / 整行，打字即替换，IDE 风格） |
| `gv` | 重新选中上次的可视区域 |
| `:` | 命令行模式 |
| `/` `?` | 向前 / 向后搜索 |
| `Esc`、`<C-[>`、`<C-c>` | 回普通模式 |
| `<C-\><C-n>` | 从任何模式强制回普通模式（丢弃未完成命令） |
| `v_<C-g>` | 可视模式 ↔ Select 模式切换 |

> Select 模式是 Vim 的“选中后直接打字替换”，和 IDE 的选区行为一致；`idearefactormode` 决定重构后进入哪种模式。

---

## 2. 移动

### 2.1 基本

| 键 | 作用 |
| --- | --- |
| `h` `j` `k` `l` | 左 / 下 / 上 / 右 |
| 方向键 | 同上（插入模式也可用） |
| `0` / `^` / `$` | 行首 / 首个非空白字符 / 行尾 |
| `g_` | 行尾最后一个非空白字符 |
| `\|` | 跳到第 `[count]` 列 |
| `+` `-` `<CR>` | 下一行 / 上一行行首 |
| `gm` | 当前屏幕行的中间 |
| `go` | 缓冲区第 `[count]` 个字符 |
| `%` | 跳到匹配的括号；`{count}%` 跳到文件百分比位置 |
| `H` `M` `L` | 屏幕顶部 / 中间 / 底部 |
| `gg` `G` | 文件首 / 文件尾（`{count}gg`、`{count}G` 指定行） |

### 2.2 按词移动

| 键 | 作用 |
| --- | --- |
| `w` `b` `e` | 下一个词首 / 上一个词首 / 词尾 |
| `W` `B` `E` | 以 WORD（空白分隔）为单位 |
| `ge` `gE` | 上一个词 / WORD 的末尾 |
| `[w` `]w` `[b` `]b` | 以 camelCase 片段为单位移动（IdeaVim 扩展） |
| `[s` `]s` | 上一个 / 下一个拼写错误 |

### 2.3 段落、句子、括号、方法

| 键 | 作用 |
| --- | --- |
| `{` `}` | 上一段 / 下一段 |
| `(` `)` | 上一句 / 下一句 |
| `[[` `]]` | 上一个 / 下一个 `{`（或“节”） |
| `[]` `][` | 上一个 / 下一个 `}` |
| `[{` `]}` | 未匹配的 `{` / `}` |
| `[(` `])` | 未匹配的 `(` / `)` |
| `[m` `]m` | 上一个 / 下一个方法**开始** |
| `[M` `]M` | 上一个 / 下一个方法**结束** |

### 2.4 行内查找

| 键 | 作用 |
| --- | --- |
| `f{char}` / `F{char}` | 向右 / 向左跳到字符 |
| `t{char}` / `T{char}` | 向右 / 向左跳到字符前一个位置 |
| `;` / `,` | 重复 / 反向重复上一次 `f`/`t` |

### 2.5 搜索

| 键 | 作用 |
| --- | --- |
| `/pattern` `?pattern` | 向前 / 向后搜索 |
| `n` `N` | 同向 / 反向重复搜索 |
| `*` `#` | 向前 / 向后搜索光标下的整词 |
| `g*` `g#` | 同上，但允许匹配词的一部分 |
| `gn` `gN` | 选中下一个 / 上一个匹配（可视模式可扩展选区） |
| `:noh` | 清除搜索高亮 |

### 2.6 标记、跳转列表、修改列表

| 键 | 作用 |
| --- | --- |
| `m{a-z}` | 设置标记 |
| `` `a `` / `'a` | 跳到标记 `a` 的精确位置 / 行首 |
| `''` | 跳回上次跳转前的位置（两个单引号） |
| `:marks` | 列出标记 |
| `<C-o>` / `<C-i>`（`<Tab>`） | 跳转列表后退 / 前进 |
| `:jumps` | 查看跳转列表 |
| `g;` / `g,` | 修改列表（changelist）后退 / 前进 |
| `<C-t>` | 从标签栈（tag stack）回退（配合 `<C-]>`、`gd`、`:tag`） |
| `:clearjumps` | 清空跳转列表 |

> IdeaVim 默认把**全局标记**（`mA`–`mZ`）映射到 IDE 书签（`set ideamarks`，默认开）。

### 2.7 滚动

| 键 | 作用 |
| --- | --- |
| `<C-e>` / `<C-y>` | 向下 / 向上滚一行（光标不动） |
| `<C-d>` / `<C-u>` | 向下 / 向上滚半屏（光标跟随） |
| `<C-f>` / `<C-b>`（`<PageDown>`/`<PageUp>`） | 向下 / 向上翻页 |
| `zz` `zt` `zb` | 当前行居中 / 置顶 / 置底 |
| `zs` / `ze` | 水平滚动，让光标位于窗口左 / 右边缘 |
| `zh` / `zl` | 向左 / 向右滚动若干列 |

---

## 3. 编辑

### 3.1 删除、修改、替换

| 键 | 作用 |
| --- | --- |
| `x` / `X` | 删除光标处 / 前一个字符 |
| `d{motion}` | 删除（如 `dw`、`d$`、`dap`） |
| `dd` / `D` | 删除整行 / 删到行尾 |
| `c{motion}` / `cc` / `C` | 删除并进入插入模式 |
| `s` / `S` | 删字符 / 删行并插入 |
| `r{char}` / `R` | 替换字符 / 进入替换模式 |
| `~` | 切换大小写并右移 |

### 3.2 复制、粘贴

| 键 | 作用 |
| --- | --- |
| `y{motion}` / `yy` / `Y` | 复制 |
| `p` / `P` | 光标后 / 前粘贴 |
| `gp` / `gP` | 粘贴后光标停在新文本之后 |
| `]p` / `[p` | 粘贴并自动对齐当前行缩进 |
| `]P` / `[P` | 同上，粘贴在光标前 |

### 3.3 撤销、重做

| 键 | 作用 |
| --- | --- |
| `u` / `U` | 撤销 / 撤销整行的最近修改 |
| `<C-r>` | 重做 |
| `:undo` / `:redo` | 同上（Ex 形式） |

### 3.4 缩进、格式化

| 键 | 作用 |
| --- | --- |
| `>>` / `<<` | 增加 / 减少缩进 |
| `>{motion}` / `<{motion}` | 对移动范围缩进 |
| `=` / `==` | 用 **IDE 的自动缩进**重排（`gg=G` 全文格式化缩进） |
| `gq{motion}` / `gw{motion}` | 用 **IDE 代码格式化器**排版并按 `textwidth` 折行 |
| `:sort` | 排序（`!` 反序，`i` 忽略大小写，`n` 数字，`u` 去重） |

> `=`、`gq`、`gw` 都调用 IDE 的 formatter，效果取决于语言和代码风格设置，这也是 IdeaVim 最好用的地方之一。

### 3.5 大小写、合并、重复替换

| 键 | 作用 |
| --- | --- |
| `gu{motion}` / `gU{motion}` | 转小写 / 大写 |
| `g~{motion}` / `g?{motion}` | 反转大小写 / ROT13 |
| `J` / `gJ` | 合并行（带空格 / 不带空格） |
| `&` | 在当前行重复上次 `:s`（不带标志） |
| `g&` | 全文重复上次 `:s`（带原标志） |

### 3.6 数字增减

| 键 | 作用 |
| --- | --- |
| `<C-a>` / `<C-x>` | 光标处数字 +1 / -1 |
| `g<C-a>` / `g<C-x>`（可视模式） | 选中多行数字依次递增 / 递减 |

### 3.7 折叠、拼写

| 键 | 作用 |
| --- | --- |
| `za` | 切换当前折叠 |
| `zc` / `zo` | 关闭 / 打开折叠 |
| `zM` / `zR` | 关闭 / 打开全部折叠 |
| `zm` / `zr` | 多折一级 / 少折一级 |
| `zj` / `zk` | 下一个 / 上一个折叠 |
| `zg` / `zw` | 把词加入 / 移出 IDE 拼写词典 |
| `z=` | 拼写建议 |

> 折叠用的是 IDE 的折叠模型（`za`、`zc`、`zo` 会调用 IDE 的 Expand/Collapse），不是 Vim 的 `foldmethod`。

### 3.8 其他

| 键 | 作用 |
| --- | --- |
| `gx` | 用系统浏览器打开光标下的 URL |
| `ga` | 显示字符的十进制 / 十六进制 / 八进制值 |
| `g8` | 显示字符的 UTF-8 字节序列 |
| `!{motion}` | 把文本交给外部命令过滤（如 `!}sort`） |
| `q:` / `q/` / `q?` | 打开命令行窗口编辑历史命令 / 搜索 |

### 3.9 插入模式里的常用键

| 键 | 作用 |
| --- | --- |
| `<C-w>` | 删除光标前一个词（**不是**窗口命令） |
| `<C-u>` | 删除本行已输入的内容 |
| `<C-r>{reg}` | 插入寄存器内容，`<C-r>=` 插入表达式结果 |
| `<C-o>` | 临时执行一条普通模式命令再回来 |
| `<C-t>` / `<C-d>` | 增加 / 减少一级缩进 |
| `<C-v>` / `<C-q>` | 按字面插入下一个字符（或数字编码） |
| `<C-k>` | 输入 digraph |
| `<C-n>` / `<C-p>` | IDE 补全弹窗中下一个 / 上一个候选项 |
| `<C-y>` | 补全弹窗中接受当前候选 |
| `<C-x>` | 进入 Vim 补全（`<C-x><C-l>` 整行、`<C-x><C-f>` 文件名） |
| `<C-e>` | 复制光标下一行的字符 |

---

## 4. 文本对象

`i` = inner（不含分隔符），`a` = around（含分隔符/尾随空白）。可与 `d`、`c`、`y`、`v` 等组合，如 `diw`、`ci"`、`ya}`。

| 对象 | 选中范围 |
| --- | --- |
| `iw` / `aw` | 词 / 词 + 尾随空白 |
| `iW` / `aW` | WORD |
| `is` / `as` | 句子 |
| `ip` / `ap` | 段落（含后续空行） |
| `i(` `i)` `ib` / `a(` `a)` `ab` | 圆括号内 / 含括号 |
| `i[` `i]` / `a[` `a]` | 方括号 |
| `i{` `i}` `iB` / `a{` `a}` `aB` | 花括号 |
| `i<` `i>` / `a<` `a>` | 尖括号 |
| `i"` `i'` / `a"` `a'` | 引号字符串（`a` 含引号和尾随空白） |
| `it` / `at` | XML/HTML 标签块（含标签） |

> 反引号字符串用 `` i` `` 和 `` a` ``。

---

## 5. 可视模式

| 键 | 作用 |
| --- | --- |
| `v` / `V` / `<C-v>` | 字符 / 行 / 块 |
| `o` / `O` | 跳到选区另一端（块模式下换角） |
| `gv` | 交换当前与上次的选区 |
| `d` `x` / `c` `s` / `y` | 删除 / 修改 / 复制选区 |
| `>` `<` / `=` | 缩进 / IDE 自动缩进 |
| `J` / `gJ` | 合并选中行 |
| `u` `U` `~` | 小写 / 大写 / 反转大小写 |
| `p` `P` | 用寄存器覆盖选区 |
| `I` `A`（块模式） | 在每行块首 / 块尾插入相同文本（IDE 多光标实现） |
| `:` | 对选区执行 Ex 命令（自动补 `'<,'>`） |
| `g<C-a>` / `g<C-x>` | 数字序列递增 / 递减 |
| `gq` / `gw` | IDE 格式化选区 |

---

## 6. 搜索与替换

| 命令 | 作用 |
| --- | --- |
| `:s/old/new/` | 当前行替换 |
| `:%s/old/new/g` | 全文替换 |
| `:s/old/new/gc` | 逐个确认 |
| `:'<,'>s/old/new/g` | 选区替换（在可视模式按 `:` 自动带范围） |
| `:1,20s/old/new/g` | 指定行范围 |
| `:g/pat/cmd` / `:v/pat/cmd` | 对匹配 / 不匹配的行执行命令 |
| `:normal {keys}` | 对范围行执行普通模式按键 |
| `:&` / `:&&` | 重复上次替换（不带 / 带原标志） |
| `:~` | 用上次搜索模式替换 |

常用替换标志：`g` 全部、`c` 确认、`i` 忽略大小写、`I` 区分大小写。正则走 Vim 的 `magic` 语法，和 IDE 自己的 regex 写法不同，复杂表达式建议先用 `/` 试。

---

## 7. 寄存器与宏

| 寄存器 | 内容 |
| --- | --- |
| `"`（无名） | 默认寄存器 |
| `"0` | 最近一次复制 |
| `"1`–`"9` | 删除历史（`"1` 最新） |
| `"-` | 小删除（不足一行） |
| `"a`–`"z` / `"A`–`"Z` | 自定义（大写为追加） |
| `"*` / `"+` | 系统剪贴板（配合 `:set clipboard=unnamedplus`） |
| `"_` | 黑洞（删除不记录） |
| `"%` / `"#` | 当前文件名 / 备用文件名 |
| `".` / `":` / `"/` | 上次插入的文本 / 上次命令 / 上次搜索 |

| 键 | 作用 |
| --- | --- |
| `q{a-z}` / `q` | 开始 / 停止录制宏 |
| `@{a-z}` / `@@` | 执行 / 重复执行宏 |
| `:reg` | 查看所有寄存器 |
| `"ap` | 粘贴 `a` 寄存器 |

---

## 8. 窗口、标签页、文件

IdeaVim 把这些 Vim 概念映射到 IDE 的编辑器分屏、标签页和文件操作。

### 8.1 分屏（IDE 的 Split）

| 键 | 作用 |
| --- | --- |
| `<C-w>s` / `<C-w>v` | 水平 / 垂直分屏 |
| `<C-w>h/j/k/l`（或 `<C-w>` + 方向键） | 移到左 / 下 / 上 / 右的分屏 |
| `<C-w>w` / `<C-w>W` | 下一个 / 上一个分屏 |
| `<C-w>c` / `<C-w>q` | 关闭当前分屏 |
| `<C-w>o` | 只保留当前分屏 |
| `<C-w>=` | 均分大小 |
| `<C-w>+` `-` `<` `>` | 调整高 / 宽 |
| `<C-w>_` / `<C-w>\|` | 高度 / 宽度最大化 |
| `:sp` / `:vs` | 水平 / 垂直分屏（可带文件名） |
| `:res[ize]` | 设置分屏高度 |

### 8.2 标签页（IDE 的 Editor Tab）

| 键 | 作用 |
| --- | --- |
| `gt` / `gT` | 下一个 / 上一个标签页 |
| `<C-PageDown>` / `<C-PageUp>` | 同上（插入模式里也可用） |
| `:tabn` / `:tabp` | 同上 |
| `:tabc` / `:tabo` / `:tabm` | 关闭 / 只留当前 / 移动标签页 |
| `<C-^>`（`<C-6>`） | 切换到上一个活动标签页（alternate file） |

### 8.3 文件与缓冲区

| 命令 | 作用 |
| --- | --- |
| `:e` | 无参数时打开 IDE 的 Open File 对话框；`:e {file}` 打开文件；`:e #` 回上一个文件 |
| `:find` / `:fin` | 无参数时打开 IDE 的 Go to File 弹窗；`:find {file}` 在项目中查找并打开 |
| `:b {name}` / `:b {N}` | 按名字或编号切换标签页 |
| `:ls` | 列出打开的编辑器 |
| `:bd` | 关闭当前文件的标签页 |
| `:w` | 保存（**默认会保存所有文件**，见第 12 节） |
| `:wa` | 保存全部 |
| `:wq` / `:x` / `ZZ` | 保存并关闭当前编辑器 |
| `:q` / `ZQ` | 关闭当前编辑器（不保存） |
| `:qa` | 关闭所有编辑器（IDE 本身不退出） |

---

## 9. IdeaVim 特有：与 IDE 联动的默认映射

这一节是 IdeaVim 相比原生 Vim 多出来的部分，**默认生效**，也是“自带快捷键”里最有价值的一组。

### 9.1 代码导航

| 键 | 作用 |
| --- | --- |
| `gd` / `gD` | 跳到声明（IDE 的 Go to Declaration），并记录跳转 |
| `<C-]>` | 跳到定义（Go to Declaration），并压入标签栈 |
| `<C-t>` | 从标签栈回退 |
| `<C-o>` / `<C-i>` | 跳转列表后退 / 前进 |
| `g;` / `g,` | 修改列表后退 / 前进 |
| `K` | 显示光标下符号的文档（Quick Documentation） |
| `gh` / `gH` | 进入 Select 模式（IDE 风格选择） |
| `gx` | 打开光标下的 URL |
| `<C-Down>` / `<C-Up>` | 执行 IDE 键位里绑定给 Ctrl+↓ / Ctrl+↑ 的动作（通常是下 / 上一个方法） |

> `:actionlist` 里能查到的动作都能绑定，见 9.4。

### 9.2 编辑与格式化

| 键 | 作用 |
| --- | --- |
| `=` / `==` / `gg=G` | 用 IDE 自动缩进重排 |
| `gq` / `gw` | 用 IDE 格式化器排版并折行 |
| `za` `zc` `zo` `zM` `zR` `zm` `zr` | IDE 折叠 |
| `zg` `zw` `z=` / `]s` `[s` | IDE 拼写检查 |
| `J` / `gJ` | 普通合并；开启 `set ideajoin` 后走 IDE 的“智能合并”（会合并字符串字面量等） |
| `p` / `P` | 普通粘贴；`set clipboard+=ideaput` 后走 IDE 的粘贴实现（自动转义等） |

### 9.3 面板、终端、杂项

| 键/命令 | 作用 |
| --- | --- |
| `:sh` | 打开 IDE 的 Terminal 工具窗口 |
| `:smile` | 显示 ASCII art（按文件类型） |
| `:actionlist` | 列出所有 IDE Action ID，可带搜索词，`<CR>` 直接执行 |
| `:sethandler` | 指定某个快捷键交给 Vim 还是 IDE，例如 `:sethandler <C-V> n-v:vim i:ide` |
| `:set ideatrackactionids` | 打开后，执行 IDE 动作会弹出其 Action ID，方便写映射 |

### 9.4 调用任意 IDE 动作（`:action` / `<Action>`）

```vim
" Ex 命令：执行一次
:action GotoFile

" 映射里用 <Action>(id)，注意括号
map <leader>f <Action>(GotoFile)
map <leader>a <Action>(FindInPath)
map <leader>r <Action>(ReformatCode)

" 查找动作 ID
:actionlist extract
:actionlist <C-D
```

注意：

- 映射到 `<Action>` 时**不能用 `noremap`**，要用 `map` / `nmap` 等可递归形式。
- `:action` 只适合手敲，不要写进映射。
- 在 IDE 里用 “Search Everywhere” 搜 `IdeaVim: track action IDs` 也能实时看到动作 ID。

常用 Action ID（用 `:actionlist` 确认当前 IDE 的准确值）：

| Action ID | 功能 |
| --- | --- |
| `GotoFile` | 转到文件 |
| `GotoClass` / `GotoSymbol` | 转到类 / 符号 |
| `GotoDeclaration` / `GotoImplementation` | 转到声明 / 实现 |
| `FindInPath` / `ReplaceInPath` | 全局查找 / 替换 |
| `ShowHoverInfo` | 悬浮文档 / 错误说明 |
| `QuickImplementations` | 快速查看实现 |
| `ReformatCode` | 格式化代码 |
| `OptimizeImports` | 优化 import |
| `RenameElement` | 重命名 |
| `IntroduceVariable` / `ExtractMethod` | 引入变量 / 抽取方法 |
| `CommentByLineComment` | 行注释 |
| `RecentFiles` / `Switcher` | 最近文件 / 切换器 |
| `Run` / `Debug` | 运行 / 调试 |
| `ToggleLineBreakpoint` | 断点开关 |
| `StepOver` / `StepInto` | 单步 |
| `SaveAll` | 保存全部 |
| `Back` / `Forward` | IDE 的后退 / 前进 |

---

## 10. 内置插件（默认关闭，需手动开启）

IdeaVim 把不少经典 Vim 插件做成了内置扩展。**默认都不生效**，在 `~/.ideavimrc` 里用 `set <名字>` 或 `Plug '...'` 开启，然后 `:source ~/.ideavimrc` 或重启 IDE。

| 插件 | 开启 | 主要按键 |
| --- | --- | --- |
| surround | `set surround` | `ys{motion}{char}` 添加、`cs{old}{new}` 修改、`ds{char}` 删除、可视模式 `S{char}` |
| commentary | `set commentary` | `gcc` 注释当前行、`gc{motion}`、可视模式 `gc`、`:Commentary` |
| multiple-cursors | `set multiple-cursors` | `<C-n>` 选中并添加下一个、`g<C-n>`、`<A-n>` 全选、`<C-x>` 跳过、`<C-p>` 取消 |
| exchange | `set exchange` | `cx{motion}`、`cxx`、`cxc`、可视模式 `X` |
| ReplaceWithRegister | `set ReplaceWithRegister` | `gr{motion}`、`grr`、可视模式 `gr` |
| textobj-entire | `set textobj-entire` | `ie` / `ae`（整个文件） |
| highlightedyank | `set highlightedyank` | 复制后短暂高亮 |
| quick-scope | `set quickscope` | 行内 `f`/`t` 目标字符高亮 |
| matchit | `set matchit` | 扩展 `%` 的匹配（if/end、HTML 标签等） |
| sneak | `Plug 'justinmk/vim-sneak'` | `s{char}{char}` 两字符跳转 |
| easymotion | `set easymotion`（另装 AceJump + IdeaVim-EasyMotion 插件） | `<Leader><Leader>w/b/e/f{char}/j/k`：给目标打标签，按键即跳（默认 leader 是 `\`，即 `\\w`） |
| AceJump | 装 IDE 的 AceJump 插件后 `map <leader>j <Action>(AceJumpAction)` | 全屏打标签跳转任意位置 |
| abolish | `set abolish` | `crs` `crm` `crc` `cru` `cr-` 等改变命名风格 |
| argtextobj | `set argtextobj` | `aa` / `ia` 参数文本对象 |
| NERDTree | `set NERDTree` | `:NERDTree` 打开项目树 |
| Which-Key | `set which-key` | 按键提示弹窗（`<leader>?` 等，取决于配置） |
| visual-multi | `set visual-multi` | 多光标/多选区 |
| Mini.ai | `set mini-ai` | 扩展 `a`/`i` 文本对象 |
| targets | `set targets` | 更多配对/引号/参数文本对象 |
| indent-object | `set textobj-indent` | 按缩进层级的文本对象 |
| CamelCaseMotion | `set CamelCaseMotion` | 驼峰词移动 |
| Peekaboo | `set peekaboo` | 弹出寄存器内容预览 |
| yankring | `set yankring` | 复制历史 |
| youcompleteme | `set youcompleteme` | `Tab` 循环补全 |

> 完整列表和各插件的安装方式见仓库 `doc/IdeaVim Plugins.md`。部分插件（如 `anyobject`、`Switch`、`dial`）需要在 IDE 插件市场额外安装。

---

## 11. 常用 `:set` 选项

### 11.1 标准 Vim 选项（IdeaVim 实现了的子集）

| 选项 | 说明 |
| --- | --- |
| `ignorecase` / `smartcase` | 搜索忽略大小写 / 含大写时区分 |
| `hlsearch` / `incsearch` | 高亮匹配 / 增量搜索 |
| `number` / `relativenumber` | 行号 / 相对行号（映射到 IDE 设置） |
| `wrap` / `list` | 软换行 / 显示空白（映射到 IDE） |
| `scrolloff` / `sidescrolloff` | 光标上下 / 左右保留行数 |
| `clipboard` | `unnamed`、`unnamedplus`、`ideaput`、`autoselect` |
| `history` | 命令行历史条数 |
| `timeout` / `timeoutlen` | 映射键序列超时 |
| `selection` / `selectmode` | 选区行为 / 何时进入 Select 模式 |
| `whichwrap` | 哪些移动键可以跨行 |
| `virtualedit` | 目前仅支持 `onemore` |
| `gdefault` | `:s` 默认带 `g` |
| `iskeyword` | `w`、`*` 等识别的词字符 |

### 11.2 IdeaVim 独有选项（`idea` 前缀）

| 选项 | 默认 | 说明 |
| --- | --- | --- |
| `ideajoin` | off | `J` 使用 IDE 智能合并 |
| `ideaput`（`clipboard+=ideaput`） | off | 粘贴走 IDE 实现 |
| `idearefactormode` | `select` | 重构后进入 `keep` / `select` / `visual` |
| `ideamarks` | on | 全局标记 ↔ IDE 书签 |
| `ideawrite` | `all` | `:w` 的行为：`file` 只存当前文件，`all` 等于 `:wa` |
| `ideavimsupport` | `dialog` | 在对话框等编辑器里也启用（`dialog`、`singleline`） |
| `ideastatusicon` | `enabled` | 状态栏图标：`enabled` / `gray` / `disabled` |
| `ideatrackactionids` | off | 显示执行的 Action ID |
| `ideawindowjumps` | off | 每个分屏独立跳转列表 |
| `ideavisualdelay` | `100` | IDE 选区转 Visual 的延迟（毫秒） |
| `ideascrollcursor` | off | 鼠标滚动时是否带着光标 |
| `ideaoutsideeditor` | on | 无编辑器时 `<Action>` 映射仍生效 |
| `ideacopypreprocess` | off | 复制时运行 IDE 的复制预处理（转义等） |
| `ideaeditor` | `python,debug` | 额外启用 Vim 的非文件编辑器 |

查当前值：`:set option?`；恢复默认：`:set option&`。

### 11.3 一份可直接用的 `~/.ideavimrc`

```vim
" ---- 基础 ----
set number relativenumber
set ignorecase smartcase
set hlsearch incsearch
set scrolloff=5
set timeoutlen=300

" ---- IdeaVim 特色 ----
set ideajoin                 " J 走 IDE 智能合并
set clipboard+=ideaput       " 粘贴走 IDE 实现
set idearefactormode=visual  " 重构后进 Visual 模式
set ideawrite=file           " :w 只保存当前文件（默认是 all）
set ideastatusicon=gray

" ---- 常用 IDE 动作 ----
map <leader>f <Action>(GotoFile)
map <leader>a <Action>(FindInPath)
map <leader>r <Action>(ReformatCode)
map <leader>i <Action>(OptimizeImports)
map <leader>d <Action>(GotoDeclaration)
map <leader>u <Action>(ShowUsages)

" ---- 插件 ----
set surround
set commentary
set multiple-cursors
set exchange
set ReplaceWithRegister
set textobj-entire
set highlightedyank
set matchit
```

> 注意：`<Action>` 映射只能用 `map`/`nmap` 等，不能加 `nore`。

---

## 12. 和 Vim 不一样的地方（容易踩的坑）

1. **`:w` 默认保存所有文件**。`ideawrite` 默认 `all`，`:w` 等价于 `:wa`；想只存当前文件用 `:set ideawrite=file`。
2. **`:q` 不退出 IDE**，只关当前编辑器标签页；`:qa` 也只是关闭所有编辑器。
3. **插入模式里 `<C-w>` 是删除前一个词**，不是窗口命令；窗口命令只在普通模式。
4. **和 Vim 冲突的 IDE 快捷键会被 Vim 接管**：例如 `Ctrl+B` 是向上翻页、`Ctrl+F` 向下翻页、`Ctrl+D/U` 半屏滚动、`Ctrl+R` 重做、`Ctrl+O/I` 跳转列表。想恢复 IDE 行为，用 `:sethandler` 或在 `Settings | Editor | Vim` 里调整。不冲突的 IDE 快捷键（`Ctrl+Alt+L`、`Shift+F6`、`Alt+Enter`、`F2` 等）照常可用。
5. **`gq`、`=` 依赖 IDE 的格式化/缩进**，没有 formatter 的语言效果会退化。
6. **折叠是 IDE 的折叠**，`foldmethod` 等 Vim 折叠选项不适用。
7. **部分 Vim 功能未实现**：如真正的 `:terminal`、`:make`、`+clientserver`、Vim9 script、部分 `:help` 标签。需要时用 `:action` 调 IDE 功能。
8. **宏可以混用 IDE 动作**，但 `<Action>` 在宏/`:normal` 里的行为取决于上下文，复杂场景建议先小范围试。
9. **IDE 弹窗、对话框默认不吃 Vim 键**（`ideavimsupport` 控制），在对话框里按键行为可能和编辑器里不同。
10. **搜索/替换用 Vim 风格正则**，不是 IDE 的 regex 语法，`\d`、`\w` 这类写法要按 Vim 的规则来。

---

## 13. 跳到任意单词 / 任意位置

「输入一个词，跳到它的下一次出现」在默认配置里没有单独的按键，用搜索即可；想要「全屏打标签，一键跳过去」则需要插件。

### 13.1 开箱可用

| 方式 | 说明 |
| --- | --- |
| `/word<CR>` | 跳到下一个 `word`，`n` / `N` 继续 |
| `?word<CR>` | 向上找 |
| `*` / `#` | 光标所在单词：向下 / 向上找（整词） |
| `g*` / `g#` | 同上，允许匹配单词的一部分 |
| `gn` / `gN` | 选中下一个 / 上一个匹配，可配合 `c`、`d` 使用 |
| `:action Find` | 打开 IDE 的文件内查找栏 |
| `:action FindInPath` | 打开项目范围查找 |

> 普通模式里 `Ctrl+F` 被 IdeaVim 用作翻页，所以 IDE 的「查找」要么用 `:action Find`，要么把 Ctrl+F 的处理权交给 IDE（`Settings | Editor | Vim` 的冲突列表，或 `:sethandler <C-F> n:ide`）。

### 13.2 插件方案

| 方案 | 开启 | 按键 |
| --- | --- | --- |
| sneak（内置扩展） | `Plug 'justinmk/vim-sneak'` | `s{char}{char}` 两字符跳转，`;` / `,` 继续；`S` 反向 |
| EasyMotion | 装 AceJump **和** IdeaVim-EasyMotion（缺一不可），再 `set easymotion` | `<Leader><Leader>w` 等给单词打标签；`<Leader><Leader>f{char}` 给字符打标签 |
| AceJump | 装 IDE 的 AceJump 插件 | `:action AceJumpAction`（建议映射，如 `map <leader>j <Action>(AceJumpAction)`） |
| quick-scope | `set quickscope` | 用高亮辅助 `f` / `t` 的目标选择（不直接跳词） |

> EasyMotion 的两个插件缺一不可：IdeaVim-EasyMotion 的 `plugin.xml` 里声明了 `<depends>AceJump</depends>`，只装前者会被 IDE 禁用。只想装一个插件就用 AceJump（映射 `<Action>(AceJumpAction)`）；一个都不想装就用内置的 sneak 或 `/word`。

EasyMotion 配置：默认前缀是 `<Leader><Leader>`（leader 为 `\` 时按 `\\w`）。想改成单个 leader：

```vim
set easymotion
" 把前缀从 <Leader><Leader> 改成单个 <Leader>，之后用 \w 触发
map <Leader> <Plug>(easymotion-prefix)
```

映射示例：

```vim
" 用 / 跳任意单词，仍然是最通用的做法
nnoremap <leader>/ /

" AceJump：全屏打标签
map <leader>j <Action>(AceJumpAction)
```


---

## 附录 A：查看与自定义

```vim
:map          " 所有模式的映射
:nmap         " 普通模式
:imap         " 插入模式
:vmap         " 可视模式
:set          " 查看被修改过的选项
:help         " IdeaVim 帮助；:help x 查具体键
:actionlist   " IDE 动作列表
```

自定义映射示例：

```vim
let mapleader = " "

" 用 Vim 的方式做 IDE 的事
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>h :noh<CR>

" 用 IDE 的方式扩展 Vim
map <leader>gs <Action>(GotoSymbol)
map <leader>gt <Action>(GotoTest)
map <leader>rr <Action>(Run)
map <leader>dd <Action>(Debug)
```

## 附录 B：参考

- 仓库：<https://github.com/JetBrains/ideavim>
- 官方文档：<https://www.jetbrains.com/help/idea/ideavim.html>
- 插件市场：<https://plugins.jetbrains.com/plugin/164-ideavim>
- 内置帮助源文件：`src/main/resources/help/ideavim.txt`
- 插件列表：`doc/IdeaVim Plugins.md`
- 选项列表：`doc/set-commands.md`
