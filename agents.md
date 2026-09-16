# 当前状态

## 仓库概况

- 路径：`~/dotfiles`
- 用途：个人 dotfiles，用 Git 管理 `~/.config` 与 `~/.local/bin` 中的配置文件
- 分支：`main`
- 记录时 HEAD：`07d611b add agents.md`
  - 更新约定：每次修改本文件后，把这一行更新为当时的 `git rev-parse --short HEAD` 和最新提交标题

## 目录结构

| 目录 | 内容 |
|---|---|
| `docs/` | `local-tools.md`（本地工具说明）、`opencode-instructions.md`（交流偏好） |
| `hypr/` | Hyprland 配置 |
| `kitty/` | kitty 终端配置与主题 |
| `lazygit/` | lazygit 配置 |
| `meilisearch/` | meilisearch 相关 systemd 服务与索引脚本 |
| `mpd/` `ncmpcpp/` | MPD 及客户端配置 |
| `mpv/` | mpv 配置 |
| `niri/` | niri 合成器配置（`config.kdl`）与脚本（`niri-ws`、`niri-sys`、`niri-temp`、`swaybg-start`、`swayidle-start`） |
| `nvim/` | Neovim 配置（lazy.nvim） |
| `opencode/` | opencode 配置 |
| `swayidle/` `swaylock/` | idle 与锁屏配置 |
| `systemd/` | 用户级 systemd 服务 |
| `tmux/` | tmux 配置与脚本（`tmux-edit`、`tmux-opencode`、`tmux-yazi`） |
| `waybar/` | waybar 配置与脚本 |
| `yazi/` | yazi 文件管理器配置与插件 |
| `zsh/` | zsh 配置（`.zshrc`） |

## 关键约定与工具

- `docs/opencode-instructions.md`：交流偏好——中文、简洁直接、不用类比/隐喻、不加 emoji、不添加代码注释
- `docs/local-tools.md` 记录了本地脚本行为：
  - `tmux-edit`：yazi → 按文件目录复用/创建 tmux 中的 nvim 窗口
  - `tmux-opencode`：yazi 中 Ctrl+O 打开 opencode 窗口
  - `tmux-yazi`：niri Mod+Y 创建独立 yazi tmux session
- waybar 使用 `~/.local/bin/niri-ws`、`niri-sys`、`niri-temp` 自定义脚本
- 路径规范：任何配置/脚本都不得硬编码 `/home/explosivitea/...` 这类绝对用户路径
  - shell/zsh：用 `$HOME` 或 `~`
  - Python：用 `Path.home()` 或 `os.path.expanduser("~")`
  - systemd 单元：用 `%h`；`environment.d` 中可用 `${HOME}`
  - 配置解析器支持变量/wordexp 时（如 swaylock）用 `$HOME` 或 `~`
- `~/.local/bin` 下的脚本必须纳入仓库，放到对应 stow 包的 `.local/bin/` 下；新增或修改脚本后重新 `stow <package>`，目标路径应为符号链接而不是真实文件
- `.gitignore` 仅忽略 `.legacy` 与 `.fiddle`
- `nvim.log` 是 nvim 启动日志（如 `/run/user/1000` 只读告警），无保存价值，建议保持忽略或清理

## 注意

- `yazi/.config/yazi/plugins/` 下的插件目录克隆后可能自带内嵌 `.git`，提交前需删除其 `.git` 或改为 submodule
