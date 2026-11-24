# 当前状态

## 仓库概况

- 路径：`~/dotfiles`
- 用途：个人 dotfiles，用 Git 管理 `~/.config` 与 `~/.local/bin` 中的配置文件
- 分支：`main`
- 记录时 HEAD：`bcc4a49 tmux: terraria workspace 走独立 socket，detach-on-destroy 改为 on`
  - 更新约定：每次修改本文件后，把这一行更新为当时的 `git rev-parse --short HEAD` 和最新提交标题

## 目录结构

| 目录 | 内容 |
|---|---|
| `applications/` | XDG 桌面条目，目前为 `terraria.desktop` |
| `deskpet/` | Wayland 桌宠原型：C + layer-shell 实现、Quickshell QML 版、说明文档 |
| `docs/` | `local-tools.md`（本地工具说明）、`opencode-instructions.md`（交流偏好） |
| `hypr/` | Hyprland 配置 |
| `kitty/` | kitty 终端配置与主题 |
| `koreader/` | KOReader（Flatpak）配置：用户默认值、补丁、本地插件，详见下文「KOReader 配置」 |
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
| `zsh/` | zsh 配置与命令（`.zshrc`、`terraria`） |

## 关键约定与工具

- `docs/opencode-instructions.md`：交流偏好——中文、简洁直接、不用类比/隐喻、不加 emoji、不添加代码注释
- `docs/local-tools.md` 记录了本地脚本行为：
  - `tmux-edit`：yazi → 按文件目录复用/创建 tmux 中的 nvim 窗口
  - `tmux-opencode`：yazi 中 Ctrl+O 打开 opencode 窗口
  - `tmux-yazi`：niri Mod+Y 创建独立 yazi tmux session
  - `terraria`：打开或复用 CS61B 学习工作区的 Firefox、IDEA、kitty-tmux 窗口；Mod+D 里显示为 Terraria
- waybar 使用 `~/.local/bin/niri-ws`、`niri-sys`、`niri-temp` 自定义脚本
- desktop entry 放在 `applications/` 包，部署用 `stow applications`，之后运行 `update-desktop-database ~/.local/share/applications`
- 路径规范：任何配置/脚本都不得硬编码 `/home/explosivitea/...` 这类绝对用户路径
  - shell/zsh：用 `$HOME` 或 `~`
  - Python：用 `Path.home()` 或 `os.path.expanduser("~")`
  - systemd 单元：用 `%h`；`environment.d` 中可用 `${HOME}`
  - 配置解析器支持变量/wordexp 时（如 swaylock）用 `$HOME` 或 `~`
- `~/.local/bin` 下的脚本必须纳入仓库，放到对应 stow 包的 `.local/bin/` 下；新增或修改脚本后重新 `stow <package>`，目标路径应为符号链接而不是真实文件
- `.gitignore` 仅忽略 `.legacy` 与 `.fiddle`
- `nvim.log` 是 nvim 启动日志（如 `/run/user/1000` 只读告警），无保存价值，建议保持忽略或清理

## KOReader 配置

- 配置目录：`~/.var/app/rocks.koreader.KOReader/config/koreader`（Flatpak 路径，不在 `~/.config` 下）
- 仓库 stow 包：`koreader/`，部署命令 `cd ~/dotfiles && stow -t ~ koreader`
- 已纳入版本管理，部署后为目标目录内的符号链接：
  - `defaults.custom.lua`：用户级默认值（返回空表，实际由 `settings.reader.lua` 覆盖）
  - `patches/`：用户补丁，`2-fm-jk-page.lua`（文件管理器 j/k 翻页）、`2-zoom-keys.lua`（缩放键）、`2-q-filebrowser.lua`（阅读界面按 q 回文件列表）
  - `plugins/hop_lookup.koplugin/`：本地插件；其原目录内嵌的 `.git`（无 remote、仅 `0b709b3 first working implementation` 一次提交）未纳入仓库，已另存到 `.legacy/hop_lookup.koplugin.git`（`.legacy` 被 gitignore）
- 不纳入仓库的运行时状态：`settings.reader.lua`、`settings/`（含 sqlite 数据库，约 27M）、`cache/`（约 79M）、`history.lua`、`docsettings/`、`help/`
- `settings.reader.lua` 不能用符号链接管理：`LuaSettings:flush` 会先把它 `os.rename` 成 `.old` 再写新文件，符号链接会被替换成实体文件
- 改阅读器设置时直接改配置目录下的真实文件；改补丁或插件则改 `~/dotfiles/koreader/` 下的文件
- 返回文件列表：Home 键（KOReader 内置，`readerui.lua:551`）或 q（`2-q-filebrowser.lua`，走同一 `Home` 事件）；Esc 不是直接返回，它按 `back_in_reader`（当前 `previous_location`）先回跳转历史，历史空了才提示退出
- `q` 由补丁在 ReaderUI 层截获，优先于 Hotkeys 插件，所以 Hotkeys 里再给 q 绑动作不会生效；要换键只改补丁里的 `KEY`
- 补丁文件名前缀只能用 `0`/`1`/`2`/`8`/`9`：`reader.lua` 只对这几个优先级调用 `applyPatches`，`3`-`7` 开头的补丁永远不执行，也不会报错或写 crash.log
- 为什么 `settings/` 不进仓库：`settings.reader.lua`、`settings/hotkeys.lua` 都由 `LuaSettings:flush` 先 `os.rename` 成 `.old` 再写新文件，符号链接会被替换成实体文件，仓库与真实配置会静默脱钩；加上 sqlite 缓存体积大且频繁变动

## 注意

- `yazi/.config/yazi/plugins/` 下的插件目录克隆后可能自带内嵌 `.git`，提交前需删除其 `.git` 或改为 submodule
