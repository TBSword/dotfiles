# hop_lookup.koplugin

hop.nvim 风格的「标签跳词查词」插件。由一个 Dispatcher action 触发全屏 hint 浮层：
扫描当前可见页的词，给每个**去重后**的词头上打一个标签；敲标签字符逐步收窄，
标签补完的那一刻立即查词（无需回车）；同时支持方向键/D-pad 移动光标、浮层内翻页重扫、
以及在 GoldenDict 与 KOReader 内置词典之间切换查词后端。

```
┌──────────────────────────────────────────────┐
│  ▁▁      ▁▁▁        ▁▁                       │   ← 每个词头上的标签
│  a       s          d                        │
│  The quick brown fox jumps over the lazy dog │
│      ┌───────┐                               │   ← 光标词 = 反色框
│      │ quick │                               │
│  Esc close · tag = lookup · F6/F7 page …     │   ← 底部状态条
└──────────────────────────────────────────────┘
```

## 安装

把整个 `hop_lookup.koplugin` 目录放进 KOReader 的 `plugins/` 目录即可：

```sh
cp -r hop_lookup.koplugin /path/to/koreader/plugins/
```

然后在 KOReader 里（`设置 → 插件管理`，或按需在 `手势`/`快捷键`/`配置文件` 里绑定
`Hop lookup (tag words)` 动作）使用。

## 触发方式

* **Dispatcher action**：`hop_lookup_action`（事件 `HopLookup`）。
  可在 `手势 → 手势管理`、`快捷键`、`Profiles` 里绑定到你喜欢的按键/手势。
  该动作只在阅读器内有意义（`reader=true`）。
* **菜单**：阅读器菜单 → `更多工具`（more_tools） → `Hop lookup` → `Start hop lookup`，
  8 个配置项都在这个子菜单里。

## 怎么用（以及怎么自查）

1. 用你绑定的手势/快捷键，或菜单 `更多工具 → Hop lookup → Start hop lookup` 打开浮层；
   这时每个去重后的词头上都会出现黑色标签。
2. **在浮层打开的状态下**敲标签字符。标签是一个字符就打一个，是两个字符就依次打两个；
   标签补完的**那一刻**就会查词，不需要回车。也可以按回车直接查光标（反色框）所在的词。
   **查词后浮层不会自动关闭**（只有 `Esc` / `Ctrl+H` / 点击才关），所以可以接着敲下一个
   标签连续查词；查词后已输入的标签会被清空，所有标签重新显示。翻页除 `F6`/`F7`/`PageUp`/
   `PageDown` 外，也可以用 `空格`（下一页）和 `Shift+空格`（上一页），与阅读器一致。
3. 查词时的反馈：
   * 走后端 GoldenDict：屏幕上方会闪过一条 `→ GoldenDict: 词`，表示词已经交给 GoldenDict；
   * `auto` 且没找到 GoldenDict：会提示一次「GoldenDict not found (…) — using the built-in
     dictionary」，然后弹内置词典窗口。
4. **`Esc` / `Ctrl+H` / 点击是「关闭浮层」，不会查任何词** —— 按完它们浮层就消失了，
   之后敲字只会给阅读器。想验证查词链路请用第 2 步或回车，或者直接用下面的自查菜单。

自查菜单（`更多工具 → Hop lookup`）：

* `Check GoldenDict`：判定结果 —— 找到的可执行文件、变体（ng / 原版）、**判定依据**、
  以及将会执行的命令行。
* `Test GoldenDict lookup`：**真正执行一次**并把证据摊开给你看：

  ```
  Shell commands: working          ← 能不能执行 shell 命令（KOReader 自己启动外部词典也用这个）
  Executable runs: Usage: goldendict [options]   ← 可执行文件确实能跑，并打印了 --help 的第一行
  Launched with test word “hop-lookup-test”: yes ← 命令确实发出去了
  GoldenDict process: running (pid 4321)         ← 之后确实有 GoldenDict 进程在跑
  Command line: 'goldendict' '-s' '<word>' >/dev/null 2>&1 &
  ```

  若 `GoldenDict process: none found` 或 `Launched: NO`，问题在启动这一侧；若都正常但窗口没
  出现，就是 GoldenDict 自己在决定显示哪个窗口（用 `GoldenDict window` 或浮层里的 F10 切
  popup/main；部分 Wayland 会话下 ng 的 popup 需要 `GOLDENDICT_FORCE_XCB=1`）。

  插件还会用 `ldd` 检查「装是装了但跑不起来」这种情况（缺共享库、装包损坏/部分升级）。
  这时 `Check GoldenDict` 会直接写：

  ```
  PROBLEM: the executable cannot run (missing libraries: libmarisa.so.0).
  Install the missing libraries (or reinstall GoldenDict), then check again.
  ```

  并且 `auto` 后端会回落到内置词典、同时把原因提示出来，而不是什么都不发生。

  还有一种很像的矛盾情况：**你在终端里敲 `goldendict` 一切正常，但在 KOReader 里就是起不来**，
  报的还是一样的缺库错误。这通常是 KOReader 的启动器（AppImage／打包版）导出了自己的
  `LD_LIBRARY_PATH`，把系统库挡在了外面。插件会打印

  ```
  Resolved path: /usr/bin/goldendict
  LD_LIBRARY_PATH: /app/lib:/usr/lib
  ```

  并自动再试一次 `env -u LD_LIBRARY_PATH <goldendict> --help`；如果这样能跑，就会**以后都用
  这种方式启动**，同时在诊断里写明 `Note: LD_LIBRARY_PATH hides …`。

  如果 KOReader 本身是 **Flatpak** 版，还有第三种情况：沙箱里的 `goldendict` 解析到的是
  **宿主机的二进制**（形如 `/run/host/bin/goldendict`），它一个宿主库也加载不了，于是报一长串
  `… => not found`（看起来像坏安装，其实不是）。插件会：

  * 打印 `Environment: Flatpak (应用 id)` 与真实解析到的路径；
  * 若沙箱允许执行宿主命令（`flatpak-spawn --host`）→ 改用
    `flatpak-spawn --host goldendict -s <词>` 在宿主机上启动，popup 正常；变体（ng / 原版）
    也会**通过宿主机**问出来（`flatpak-spawn --host goldendict --help`），这样才能决定要不要
    加 `-s`/`-m`；
  * 若不允许执行宿主命令、但沙箱里有 `xdg-open`/`gio` → 走**桌面 portal**：
    `xdg-open goldendict://<词>`（词按 URL 编码），由宿主机的会话把它交给 GoldenDict；诊断会写明
    `Handed to the desktop portal`，并提醒「若宿主没有 goldendict:// 处理器就不会有反应」。
    注意这条路上**不能**附加 `?target=popup|main`：只有很新的 GoldenDict-ng 才认识它，旧版会把
    `词?target=main` 整个当成要查的词（会显示「No translation for 词?target=main」）。因此
    portal 路由由宿主机上的 GoldenDict 自己决定弹哪个窗口；想要精确控制 popup/main，请放行宿主
    命令（见下），那条路会用 `-s`/`-m`。

    另外：由 portal「代开」的窗口可能被 GoldenDict 当成临时扫描弹窗，**鼠标一碰或焦点一变
    就消失**。想让窗口表现得和你平时打开的一模一样，请走宿主命令那条路（直接命令行调用
    `goldendict -s/-m 词`），或换非 Flatpak 版 KOReader。弹窗太小同样是 GoldenDict 自己的
    设置（上游 issue「popup window too small」）：拖动边框调整、点弹窗上的图钉固定，或者
    改用主窗口（`GoldenDict window → main window`）。
  * 若连 `xdg-open`/`gio` 也没有 → 明确说明原因，并给出放行命令：

    ```
    flatpak override --user --talk-name=org.freedesktop.Flatpak rocks.koreader.KOReader
    ```

    （或者继续用内置词典，或改用非 Flatpak 版 KOReader / AppImage。）

## 按键

| 按键 | 作用 |
| --- | --- |
| 标签字符（字符集内） | 逐步收窄标签；补完（或只剩唯一候选）时立即查词 |
| `Backspace` / `Del` | 退格，回退一个字符 |
| `←` `→` | 光标线性前后移动（按文档阅读顺序） |
| `↑` `↓` | 光标移动到上/下方最近邻词，度量 `|dx|*2 + |dy|` |
| `Enter`（`Press`） | 直接查光标所在的词 |
| `F6` / `PageUp` | 上一页，重新扫词 |
| `F7` / `PageDown` | 下一页，重新扫词 |
| 右键菜单键 / `F10` | 切换 GoldenDict 的 popup / main 模式并保存（浮层右下角会显示当前模式；也可以在菜单里的 `GoldenDict window` 改） |
| `Esc`（`Back`）/ `Ctrl+H` / 点击屏幕 | 关闭浮层 |

> 「右键菜单键」指键盘上的**应用键 / 右键菜单键**（通常夹在右侧 Ctrl 和右侧 Win 之间，
> 图标是一个带指针的菜单），Kindle 上就是 `Menu` 键，手柄上是北面的功能键。键盘上也可以
> 直接按 `F10`（这个键在阅读器里没有别的用途）。如果你找不到这个键，用菜单里的
> `GoldenDict window` 切换即可，效果完全一样。

浮层是模态的：未识别的按键、以及按键释放事件都会被吞掉，不会漏到下面的阅读器；
不属于字符集、或会让候选标签变成空的字符会被忽略（当前输入保持不变）。

### 按键读取与稳健性

* 标签字符可能来自 `TextInput` 事件（带布局的外部键盘），也可能直接来自 `KeyPress`
  的键名（多数设备，以及 SDL/桌面）。插件两条路都走：同一次按键若两者都到，会按
  「紧随其后的 KeyPress」去重，只输入一次，因此不会多打一个字符。
* 按住 `Ctrl`/`Alt`/`AltGr`/`Super`/`Meta` 时送来的 `TextInput` 一律不当作文本，
  所以 `Ctrl+H` 永远不会被当成标签字符 `h`。
* 控制键按**键名**匹配，不要求修饰键完全一致：`Ctrl+H` 大小写不敏感、即使有别的
  修饰键（例如桌面环境误报 `Super`/`Shift`）也照样关闭；`Esc`/`Home` 同理。
* 插件只用 KOReader 长期存在的 API（文档、UIManager、Dispatcher、词典事件等），
  不依赖新版本才有的接口；输入与绘制都包了一层保护：万一出现意外错误，会写一条
  `hop_lookup:` 开头的错误日志并关闭浮层，而不是让阅读器崩溃。

## 8 个配置项

`更多工具 → Hop lookup` 子菜单里可改，全部存在 `G_reader_settings` 的 `hop_lookup` 键下。

| 配置 | 默认值 | 说明 |
| --- | --- | --- |
| 字符集 `label_chars` | `asdfghjkl` | 生成标签用的字符集（空白与重复字符会被忽略，支持多字节字符），另提供几组预设 |
| 后端 `backend` | `auto` | `auto` / `goldendict` / `internal` |
| GoldenDict 窗口 `goldendict_window` | `popup` | `popup` / `main`（浮层内可用菜单键即时切换） |
| GoldenDict 路径 `goldendict_path` | `goldendict` | 可执行文件路径，或 `$PATH` 里的命令名 |
| 标签大写 `label_uppercase` | 关 | 显示大写标签；输入始终大小写不敏感 |
| 最短词长 `min_word_length` | `2` | 短于该长度的词不打标签（CJK 单字始终保留） |
| 初始光标 `initial_cursor` | `center` | `center` 取屏幕中线最近的词 / `first` 取页首词 / `none` 首次按方向键才出现 |
| 去抖 `lookup_debounce` | `200` ms | 查词前的延迟；延迟内的新查词会替换掉待执行的那次 |

### 标签算法

标签是**前缀无关**（prefix-free）的：任何一个标签都不是另一个标签的前缀。
因此「标签敲完 = 唯一确定一个词」，可以立即查词而不必回车；反过来，如果敲到某个
前缀只剩一个候选标签，也会立刻查词。

标签按阅读顺序发放，尽量短、并保持字符集里的先后顺序。以字符集 `asdfghjkl`、
12 个词为例：前 8 个词拿到 `a s d f g h j k`，后 4 个词拿到 `la ls ld lf`
（用字符集里最后一个字符 `l` 展开出双字符标签）。生成过程在标签树上扩展「最浅、
最靠后」的叶子，并保证叶子集合始终是前缀无关的反链；深度按字符数（而非字节数）
计算，所以中日韩字符集也和使用 ASCII 字符集时表现一致。

### 查词后端

* `internal`：走 KOReader 自己的词典（`LookupWord` 事件，并带上词在屏幕上的方框，
  便于词典窗口高亮该词）。
* `goldendict`：把词交给 GoldenDict 可执行文件。
* `auto`（默认）：先探测 GoldenDict，探测不到再回落到内置词典。

探测与启动顺序（`hoplookup_lookup.lua`），找到一个能用就停：

1. 配置里填的 **GoldenDict 路径**（命令名会走 `command -v`，含 `/` 的按文件存在性检查）；
2. 常见命令名：`goldendict`、`goldendict-ng`、`goldendict-qt6`
   （Debian/Ubuntu 的 GoldenDict-ng 包装出来就叫 `goldendict`）；
3. Flatpak：`flatpak run io.github.xiaoyifang.goldendict_ng`；
4. KOReader `Device` 层已知的外部词典应用（Android 的 GoldenDict / GoldenDict Pro 等）；
5. `goldendict://` URL 处理器（`xdg-open "goldendict://词?target=popup|main"`）。

变体判定与参数：

变体判定（`ng` 还是原版）按“证据”从便宜到昂贵依次进行，因为**发行版常把 GoldenDict-ng
装成 `goldendict`**（Arch/AUR、Debian/Ubuntu 都是如此），光看命令名分不出来：

1. 命令名里带 `ng`（如 `goldendict-ng`）；
2. **安装包**：`pacman -Qo` / `dpkg -S` / `rpm -qf` 查这个可执行文件属于哪个包
   （`goldendict-ng` → ng；`goldendict` → 原版）——AUR/发行版安装就靠这条；
3. `goldendict://` URL 处理器（`xdg-mime query`，ng 注册的是
   `io.github.xiaoyifang.goldendict_ng.desktop`）；
4. 已安装的 desktop 文件；
5. `--help` 里出现 `--scanpopup`（ng）或 `--toggle-scan-popup`（原版）——这条最慢，而且
   在已有实例运行等情况可能拿不到输出，所以放最后。

判定为 **GoldenDict-ng** 时 popup 模式传 `-s`、main 模式传 `-m`（Flatpak 版一律按 ng
处理）；判定为**原版 GoldenDict** 时不加参数（它没有强制窗口的选项：已有实例在运行时词
会显示在它的 popup 窗口，冷启动则打开主窗口）。万一所有证据都拿不到，按 ng 处理并在
`Check GoldenDict` 里标出是「assumed」。**不会**用 `--version` 探测：原版没有 `-v`
选项，会把它当成要查的词弹窗。
* 探测结果缓存 60 秒；菜单里的 `Check GoldenDict` 会显示实际找到的可执行文件、判定出的
  变体、以及将要执行的命令行，`Test GoldenDict lookup` 会立刻发一个测试词过去。
* `auto` 后端在回落到内置词典时只会提示一次（按配置的路径），避免「没弹出也没提示」。

## 实现结构

| 文件 | 职责 |
| --- | --- |
| `main.lua` | 插件入口：Dispatcher action 注册、菜单与 8 个配置项、去抖后调用查词 |
| `hoplookup_hintlayer.lua` | 全屏浮层：按键、标签收窄、光标、翻页、绘制与脏矩形 |
| `hoplookup_scanner.lua` | 可见页词扫描：重排文档走 xpointer 逐词遍历，分页文档走 `getTextBoxes` |
| `hoplookup_labels.lua` | 字符集解析、前缀无关标签生成、去重分配、前缀过滤（纯 Lua） |
| `hoplookup_nav.lua` | 光标导航：中线最近词、线性左右、`|dx|*2+|dy|` 上下最近邻（纯 Lua） |
| `hoplookup_lookup.lua` | 后端探测与调用（GoldenDict 命令行 / 设备外部词典 / 内置词典） |
| `hoplookup_defaults.lua` | 8 个配置项的默认值与校验 |

绘制方式：浮层在首次绘制时把整屏快照存进一个 BlitBuffer，之后每次按键只重绘自己的
装饰（标签 + 反色光标框 + 状态条），并按装饰的包围盒做部分刷新；只有翻页/旋转时才让
阅读器重绘整页并重新取快照。这样在墨水屏上按一次键只闪一小块区域。

标签画在**所属单词的左端、与该词同一行**（竖向对齐词框中心），hop.nvim 那种贴纸样式：
行与行之间通常没有能放下标签的空隙，把标签画在词上方会压到上一行文字，看起来像是上
一行的标签。光标所在的词额外画一个反色框，标签叠在反色框之上。

## 测试

仓库里带了一套不依赖 KOReader 的单元/集成测试（用 `tests/stubs/` 里的桩替身加载真实
KOReader API 的形状）：

```sh
cd <插件目录的上一级>
luajit tests/run.lua          # 桩替身下的单元/集成测试
```

另有一个「真 UIManager」集成测试：它加载 KOReader 真实的 `frontend/ui/uimanager.lua`
与真实控件类，只把需要 koreader-base C 组件的模块（device/blitbuffer/font/textwidget
/time/util/dbg/logger）替换成桩，用来跑「打开浮层 → Ctrl+H/其它关闭键 → 再按任意键」
的全键位模糊测试：

```sh
KOREADER_DIR=/path/to/koreader luajit tests/integration/run.lua
```

覆盖：配置校验、标签生成（前缀无关性、1..200 个词、单字符集边界）、去重、
光标导航（含 `|dx|*2+|dy|` 的手算样例）、两种文档的词扫描与词清洗、
GoldenDict 命令行与探测/回落、以及浮层的完整交互（打字查词、退格、方向键、翻页重扫、
右键菜单键切换、绘制与释放、各种关闭路径）。

## 已知限制

* 原版 GoldenDict 无法在选择 popup 模式时强制弹窗（上游没有该选项）；
  需要该行为请使用 GoldenDict-ng。
* 扫描以可见页为界：跨页断词、扫描版 PDF（无文字层）的词不会被打标签。
* 分页文档（PDF/DjVu）在双页模式下会同时扫描可见的两页；重排文档只处理当前可见范围。
* 点击（tap）在无触摸设备上不可用，用 `Esc`/`Ctrl+H` 关闭即可。
