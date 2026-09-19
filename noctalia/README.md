# Noctalia Dotfiles

这个模块保存 Noctalia v5 的手写配置。

## 目录

```text
~/dotfiles/noctalia/
└── .config/
    └── noctalia/
        └── config.toml
```

部署后：

```text
~/.config/noctalia -> ~/dotfiles/noctalia/.config/noctalia
```

## 安装/启用

当前 `~/.config/noctalia` 是空目录时，执行：

```sh
rmdir ~/.config/noctalia
ln -s ../dotfiles/noctalia/.config/noctalia ~/.config/noctalia
```

如果目录里已有内容，先备份再替换。

## 配置优先级

Noctalia 当前分两层：

```text
~/.config/noctalia/*.toml
~/.local/state/noctalia/settings.toml
```

`settings.toml` 是 GUI 管理的覆盖层，优先级更高。  
因此本文件里写的键，如果 `settings.toml` 中也有同键，最终以 GUI/state 为准。

## 当前需要留意的 state 覆盖

当前 `~/.local/state/noctalia/settings.toml` 已包含：

- `shell.telemetry_enabled`
- `theme.mode`
- `theme.source`
- `wallpaper.default.path`
- `wallpaper.last.path`
- `lockscreen_widgets`

其中锁屏布局、壁纸切换、主题切换更适合继续由 GUI 管理。  
如果希望 `config.toml` 里的主题、壁纸、telemetry 等声明生效，需要：

1. 在 Noctalia GUI 中改成相同值，或
2. 清理 `settings.toml` 中对应覆盖键，然后重载。

## 验证

```sh
noctalia config validate ~/dotfiles/noctalia/.config/noctalia/config.toml
```

或验证完整合并配置：

```sh
noctalia config validate
```
