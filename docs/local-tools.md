# Local Tools

## tmux-edit

`~/.local/bin/tmux-edit` — 从 yazi 打开文件时，按文件所在目录在 tmux 中创建/复用 `n-<dirname>` 窗口。同目录的文件共享一个 nvim，不同目录各自独立。避免 yazi → nvim 的嵌套栈。

### 调用方式

在 yazi 中按 `E`，通过 `shell --orphan` 调用 `tmux-edit`。不阻塞 yazi。

### 行为

```
1. 通过 $TMUX 检测当前 session → 无 session 则降级为直接 nvim
2. 取文件所在目录名，窗口命名为 n-<dirname>
3. 窗口已存在 → 向该窗口发送 ":e <path>" + Enter
4. 窗口不存在 → 创建新窗口启动 nvim，再发送文件
5. 切换焦点到该 nvim 窗口
```

## tmux-opencode

`~/.local/bin/tmux-opencode` — 从 yazi 按 Ctrl+O 时，在当前 tmux session 中创建 opencode 窗口。

## tmux-yazi

`~/.local/bin/tmux-yazi` — niri Mod+Y 调用，创建独立 tmux session（`yazi-1`、`yazi-2` 递增），在其中启动 yazi。

### Keybinds

| 按键 | 环境 | 动作 |
|---|---|---|
| `Mod+Y` | niri | 打开 kitty + tmux + yazi |
| `Mod+Z` | niri | 新窗口打开 opencode web（需先 enable systemd 服务） |
| `Ctrl+O` | zsh | 在当前目录打开 opencode |
| `Ctrl+G` | zsh | 打开 lazygit |
| `Ctrl+Y` | zsh | 打开 yazi |
| `e` | yazi | shell --orphan → tmux-edit，发到同目录 nvim 窗口 |
| `<Enter>` | yazi | wise-enter：目录进入/隧道跳过，压缩包解压，HTML→Firefox 新窗口，sh→kitty 执行，其他→open |
| `i` | yazi | easyjump 跳转 + 自动调用 wise-enter（同 Enter） |
| `I` | yazi | easyjump 仅跳转，不自动打开 |
| `o` | yazi | 按 `[open]` 规则打开：文本→nvim，HTML→xdg-open，文件夹→xdg-open |
| `O` | yazi | 交互式选择 opener |
| `Ctrl+O` | yazi | 在当前 session 打开 opencode 窗口 |
