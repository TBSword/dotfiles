# Niri Dotfiles — 当前架构说明

本文档描述 `~/dotfiles/niri` 当前实际使用的架构，方便维护和排错。  
当前生效 profile 由 `~/.config/niri/profile.kdl` 决定，可能随 `niri-shell-switch` 变化。

## 1. 目录结构

```text
~/dotfiles/niri/
├── README.md
├── .config/
│   └── niri/
│       ├── config.kdl                 # Niri 入口配置
│       ├── profile.kdl                # 当前启用的 profile
│       └── profiles/
│           ├── glue.kdl               # 旧 Waybar / Vicinae / swaybg / swayidle 方案
│           └── noctalia.kdl           # Noctalia v5 方案
└── .local/
    └── bin/
        ├── lock-screen                # swaylock 锁屏脚本
        ├── niri-shell-switch          # glue/noctalia profile 切换
        ├── noctalia-start             # Noctalia 启动包装脚本，负责 mako 清理
        ├── niri-sys                   # Waybar CPU / 内存模块
        ├── niri-temp                  # Waybar 温度模块
        ├── niri-ws                    # Waybar 工作区模块
        ├── swaybg-start               # glue profile 壁纸启动脚本
        ├── swayidle-start             # glue profile idle 启动脚本
        ├── wallpaper-select           # fuzzel 壁纸选择器
        └── wallpaper-set              # 直接设置壁纸
```

部署后的符号链接：

```text
~/.config/niri                    -> ~/dotfiles/niri/.config/niri
~/.local/bin/<script>             -> ~/dotfiles/niri/.local/bin/<script>
```

## 2. 配置文件加载链

```text
~/.config/niri/config.kdl
└── include "profile.kdl"
    └── include "profiles/<当前 profile>.kdl"
```

`config.kdl` 固定不变，只负责 include `profile.kdl`。  
`profile.kdl` 决定当前使用哪套环境：

```kdl
include "profiles/noctalia.kdl"
```

要切换 profile，优先使用：

```sh
niri-shell-switch toggle
niri-shell-switch glue
niri-shell-switch noctalia
```

## 3. Profile 对照

### 3.1 `glue.kdl`：旧 Shell 组合

启动项：

```kdl
spawn-at-startup "fcitx5"
spawn-at-startup "mako"
spawn-at-startup "swaybg-start"
spawn-at-startup "waybar"
spawn-at-startup "swayidle-start"
spawn-sh-at-startup "vicinae server"
```

组成：

- Waybar：顶部状态栏
- Vicinae：应用启动器
- swaybg：壁纸
- swayidle：空闲锁屏/关屏
- swaylock：锁屏界面
- fuzzel：脚本/dmenu 选择器
- matugen：生成 Waybar 配色

主要键位：

- `Mod+D`：Vicinae toggle
- `Mod+Shift+W`：`wallpaper-select`
- `Super+Alt+L`：`lock-screen`
- `Mod+T`：kitty
- 音量/亮度分别使用 `wpctl` / `brightnessctl`
- 媒体键使用 `playerctl`

### 3.2 `noctalia.kdl`：Noctalia v5 方案

启动项：

```kdl
spawn-at-startup "fcitx5"
spawn-sh-at-startup "exec $HOME/dotfiles/niri/.local/bin/noctalia-start"
```

特点：

- Noctalia v5 接管 bar、launcher、控制中心、通知、OSD、锁屏、壁纸、剪贴板等。
- Noctalia Settings 窗口规则：

```kdl
window-rule {
    match app-id="dev.noctalia.Noctalia"
    open-floating true
    default-column-width { fixed 1080; }
    default-window-height { fixed 920; }
}
```

- 开启了 `honor-xdg-activation-with-invalid-serial`，用于 Noctalia 通知 action 和窗口激活。
- 键位改为通过 Noctalia IPC：

```kdl
Mod+D        -> noctalia msg panel-toggle launcher
Mod+Shift+W  -> noctalia msg panel-toggle wallpaper
Super+Alt+L  -> noctalia msg session lock
音量/亮度/媒体 -> noctalia msg ...
```

## 4. 脚本职责

### `niri-shell-switch`

用于在 `glue` 和 `noctalia` 之间切换：

1. 读取/改写 `~/.config/niri/profile.kdl`
2. 调用 `niri msg action load-config-file`
3. 停止两套方案共用的旧后台进程
4. 启动目标 profile 需要的后台进程

它会停止：

- `mako`
- `noctalia`
- `waybar`
- `swaybg`
- `swayidle`
- `vicinae`

mako 现在由 profile 生命周期管理：

- `glue` profile：由 `glue.kdl` 的 `spawn-at-startup "mako"` 启动
- `noctalia` profile：由 `noctalia-start` 清理 mako，通知交给 Noctalia
- 切换 profile 时 `niri-shell-switch` 会先停止旧 profile 的 mako，再按目标 profile 决定是否启动

### `noctalia-start`

Noctalia 启动包装脚本：

1. 如果旧的 `~/.config/systemd/user/niri.service.wants/mako.service` 仍存在，或 mako 被
   systemd 启用，则执行 `systemctl --user disable --now mako.service`。
2. 如果当前会话已有 mako 在运行，则停止它，避免继续占用
   `org.freedesktop.Notifications`。
3. 最后 `exec noctalia "$@"`，保持原 Noctalia 启动参数。

这样 `glue` profile 仍然可以在自己启动时拉起 mako，而 `noctalia` profile 不会和 mako
争通知总线。

### `swaybg-start`

- 读取 `~/.local/state/wallpaper/current`
- 默认从 `~/Pictures/wallpapers` 选图
- 可选调用 matugen 生成 Waybar 配色
- 最后用 `swaybg -m fill` 设置壁纸

仅 `glue` profile 使用。

### `wallpaper-select` / `wallpaper-set`

- `wallpaper-select`：用 fuzzel 列出壁纸，调用 `swaybg-start`
- `wallpaper-set`：直接把指定图片交给 `swaybg-start`

仅 `glue` profile 使用。

### `swayidle-start` / `lock-screen`

- `swayidle-start`：读取 `~/.config/swayidle/config`
- `lock-screen`：使用 `swaylock`，锁屏背景跟随 `~/.local/state/wallpaper/current`

仅 `glue` profile 使用。Noctalia profile 的锁屏由 Noctalia 自己处理。

### Waybar 模块

- `niri-sys`：CPU / 内存使用率
- `niri-temp`：仅在温度 >= 75°C 时输出
- `niri-ws`：当前工作区/总数，使用 Nerd Font 字形

仅 `glue` profile 的 Waybar 使用。

## 5. 当前外部组件与配置

| 组件 | 路径/说明 |
|---|---|
| Niri 配置 | `~/.config/niri` → `~/dotfiles/niri/.config/niri` |
| Noctalia 手写配置 | `~/dotfiles/noctalia/.config/noctalia/`，部署到 `~/.config/noctalia` |
| Noctalia GUI 状态 | `~/.local/state/noctalia/settings.toml` |
| Noctalia 运行时状态 | `~/.local/state/noctalia/state.toml` |
| Noctalia 日志 | `~/.cache/noctalia/noctalia.log` |
| Waybar | `~/dotfiles/waybar/.config/waybar` |
| Vicinae | `~/dotfiles/vicinae-config`、`~/dotfiles/vicinae-scripts` |
| fuzzel | `~/dotfiles/fuzzel/.config/fuzzel` |
| matugen | `~/dotfiles/matugen/.config/matugen` |
| DankMaterialShell 旧配置 | `~/.config/DankMaterialShell/settings.json` |
| mako 生命周期 | `glue.kdl` 启动；`noctalia-start` 清理；systemd 自动拉起由启动包装脚本移除 |

## 6. 常见操作

重载 Niri 配置：

```sh
niri msg action load-config-file
```

查看输出：

```sh
niri msg outputs
```

查看工作区：

```sh
niri msg workspaces
```

查看 layer shell 表面：

```sh
niri msg layers
```

切换 Shell profile：

```sh
niri-shell-switch toggle
```

查看 Noctalia 状态：

```sh
noctalia msg status
```

查看 Noctalia 配置是否合法：

```sh
noctalia config validate
```

## 7. 已知集成点

1. **通知归属由 profile 决定（已验证）**  
   `glue` profile 使用 mako，`noctalia` profile 使用 Noctalia 通知服务。  
   `~/.config/systemd/user/niri.service.wants/mako.service` 已被移除，systemd 中 mako 为
   `disabled` 且未加载；`glue` profile 仍通过 `spawn-at-startup "mako"` 正常启动 mako。  
   Noctalia 运行日志已出现 `listening on org.freedesktop.Notifications`，并成功处理外部通知。

2. **Noctalia GUI 状态优先**  
   `~/.local/state/noctalia/settings.toml` 是 GUI 管理的覆盖层，优先级高于 `~/.config/noctalia/*.toml`。  
   Noctalia 手写配置放在 `~/dotfiles/noctalia/.config/noctalia/`，通过符号链接部署到
   `~/.config/noctalia/`。如果发现手写配置不生效，需要检查 `settings.toml` 中的覆盖键。

3. **两套 Shell 的旧组件并存**  
   Waybar、DMS、matugen、swaybg、swayidle、vicinae、mako 仍存在于系统中。  
   `noctalia` profile 不会主动启动它们，但手动启动或残留进程仍可能引入冲突。

4. **Hyprland 配置独立**  
   `~/dotfiles/hypr/.config/hypr/hyprland.conf` 是旧的 Hyprland 配置，不属于 Niri 架构，当前没有接入 Noctalia。
