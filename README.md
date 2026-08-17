# 阅笺 / Reading Folio

[中文说明](#中文说明) · [English](#english)

## 鸣谢与灵感来源 / Acknowledgements

灵感来源：由 Reddit 用户 [hundredpercentcocoa](https://www.reddit.com/user/hundredpercentcocoa/) 创建的 `2-book-receipt-shortcut-and-lockscreen.lua`。

Inspired by `2-book-receipt-shortcut-and-lockscreen.lua` created by Reddit user [hundredpercentcocoa](https://www.reddit.com/user/hundredpercentcocoa/).

---

## 中文说明

「阅笺」（Reading Folio）为 KOReader 提供精致的阅读画面编排与休眠屏保生成功能。可将当前书籍封面、阅读进度、累计/今日阅读时长、章节进度以及书摘批注等数据，编排为支持实时预览、动态转屏与休眠屏保的阅读卡片。

与「文笺 / Type Folio」为同族插件。

### 核心特性与交互体验

1. **15 种精致内置风格与随机选择**：涵盖瑞士网格、黑底终端、引文海报、阅读票根、封面主导、典藏画廊、阅读卷宗、藏书邮票、阅读邮笺、阅读构成、日式留白及梅兰竹菊，并支持置于最后的「随机风格」选项。
2. **休眠屏保与动态转屏**：一键设为休眠屏保。对于横屏构图样式（如“藏书邮票”和“阅读邮笺”），作为屏保时会自动切换为横屏，唤醒后恢复原阅读方向。
3. **即时预览与极速调参 (Live Preview)**：菜单所有单选/开关/字号调参均支持保持菜单打开（`keep_menu_open`），并在修改瞬间自动更新背景预览，无需重复进出菜单。
4. **高度自由的卡片定制**：支持卡片宽高比例（默认/全屏/0.30–1.00自定义）、边框粗细、背景色、卡片阴影、大/中/小字号偏移（-20 至 +20）及封面缩放（0-100%）。
5. **15 项数据条目显示开关**：可单独勾选显示/隐藏书名、作者、封面、章节、页码、阅读百分比、进度条、本章/全书剩余时间、累计/今日阅读时间、电量、时钟、书摘及自定义文字。
6. **自定义布局编辑器**：选择「自定义布局」后进入全屏实时编辑界面，可选择白/灰/黑/透明或图片壁纸，为图片设置 25%–100% 透明度并与下层阅读画面合成，逐项勾选显示或隐藏 15 个项目，并对选中项目进行四向移动、旋转、50%–200% 缩放、横向/竖向文字方向和自动/黑/灰/白独立字体配色；移动步长（1%/3%/5%/10%）与旋转步长（15°/30°/45°/90°）可在「步长」里自选，每次操作即时保存并刷新预览。
7. **预设存储与管理**：自定义布局连同壁纸、卡片外观与字号偏移可保存为命名预设，随时应用、更新为当前布局、重命名或删除。预设名重复时会被拒绝并提示，避免误覆盖——要覆盖旧预设请用该预设子菜单里的「更新为当前编辑布局」。
8. **主题包导入导出**：任一预设可导出为 `.readingfolio-theme.json` 主题包，壁纸为「自定义图片」时该图片一并内嵌（其余壁纸模式只记设置），便于分享或跨设备迁移；导入时校验格式版本与体积上限，遇到重名主题自动追加序号，导入后立即应用。
9. **时钟局刷**：时钟默认静态。改为每分钟更新后，分钟变化时只重绘时钟所在的那一行，可选 UI/快速局刷波形，并可按 1/10/30/60 分钟周期执行一次全刷；预览与真正的休眠屏保走同一套逻辑，内置风格的页脚时钟、瑞士网格与梅兰竹菊的状态行、以及自定义布局的时钟项目都适用。与时钟同处一行的电量、页码、今日时长会随之一起重绘，不会被覆盖。阅读邮笺把时间嵌在日期戳里、典藏画廊/阅读卷宗/藏书邮票/阅读构成本就不显示时间，这五个风格不参与分钟刷新。关闭预览或退出屏保时自动取消定时任务。
10. **Folio Scenes 联动**：可跟随 Type Folio 2.4+ 的每书场景，在预览和休眠时临时切换为静读、研读、编辑或章节聚焦构图，不覆盖原有阅笺风格与内容设置。Type Folio 发布「随机风格」场景时，同样会在内置风格中随机取样。

### 功能与参数全景表

下表按菜单实际层级排列（顶层五项：预览阅笺、显示风格、外观与排版、自定义布局设计器、系统联动与屏保）。

| 菜单模块 | 可调参数 / 功能项 | 说明 / 取值范围 | 默认值 |
| --- | --- | --- | --- |
| **预览阅笺** | — | 直接全屏预览当前设置，点即出图 | — |
| **显示风格** | 15 种内置风格、自定义布局与随机模式 | 瑞士网格、黑底终端、引文海报、阅读票根、封面主导、典藏画廊、阅读卷宗、藏书邮票、阅读邮笺、阅读构成、日式留白、梅、兰、竹、菊，其后是「自定义布局」（已存预设时改为按名列出各预设），最后是「随机风格」 | `swiss` (瑞士网格) |
| **外观与排版** | 卡片尺寸比例 | 默认比例、全屏、自定义比例 (0.30 - 1.00)；「默认」由风格自带，多数为 0.60，藏书邮票 0.92、阅读邮笺 0.94、自定义布局 1.00 | `default` |
| | 文字大小（大 / 中 / 小） | 预设 (-2, 0, +2, +4, +6) 及自定义数字输入 (-20 至 +20) | `0` |
| | 封面缩放 | `0.0` - `1.0`（设为 `0` 可隐藏封面） | `1.0` |
| | 边框与阴影 | 边框：无 / 细 / 粗；卡片背景色：淡灰 / 纯白 / 柔灰；阴影：开 / 关 | 无边框；淡灰；阴影关 |
| | 显示内容 → 内容 | 阅笺（默认）、摘录与进度、随机 | `reading_folio` |
| | 显示内容 → 15 项条目开关 | 书名、作者、封面、章节、页码、百分比、进度条、本章剩余、全书剩余、累计时长、今日时长、电量、时钟、书摘、自定义文字（自定义文字另需 KOReader 自身的「屏保信息」开关，且仅在真正休眠时出现） | 全部默认开启 |
| | 屏幕背景 | 白色、透明、灰色、黑色、随机图片、书籍封面；另含图片透明度（100/75/50/25%）与背景图片显示方式（适应屏幕 / 拉伸填满 / 居中且不缩放） | `white`；100%；`stretch` |
| **自定义布局设计器** | 编辑自定义布局 | 全屏编辑器：15 个项目分别显示/隐藏；相对坐标移动；50%–200% 缩放；0°–359° 旋转；文字项目可选横向/竖向与自动/黑/灰/白独立配色；壁纸支持白/灰/黑/透明/书籍封面/随机图/自定义图片及 25%–100% 图片透明度；「步长」内选移动 1%/3%/5%/10% 与旋转 15°/30°/45°/90° | 步长 3%；旋转 90° |
| | 预设存储与管理 | 保存当前布局为预设、应用、更新为当前编辑布局、重命名、删除；重名保存会被拒绝。已存预设会直接出现在「显示风格」列表里 | 无预设 |
| | 主题包导入导出 | 导出 / 导入 `.readingfolio-theme.json`（自定义图片壁纸内嵌，单包 ≤ 24 MiB、单图 ≤ 16 MiB）；重名主题自动追加序号 | 存放于 `DataStorage/reading_folio_themes/` |
| | 时钟局刷设置 | 静态或每分钟局刷；UI / 快速波形；周期全刷可关闭或设为 1/10/30/60 分钟 | 静态；UI 波形；30 分钟全刷 |
| **系统联动与屏保** | 设为休眠屏幕 | 勾选后接管 KOReader 休眠屏保，横屏构图自动转屏；取消勾选还原原设置 | 未勾选（不改动 `screensaver_type`） |
| | 跟随文笺 Folio 场景 | 临时映射静读→日式留白、研读→引文海报、编辑→阅读邮笺、章节聚焦→阅读构成 | 开启；无有效场景时不生效 |
| | 语言 | 阅读卡片显示语言：跟随系统、English、简体中文；菜单文案恒随 KOReader 系统语言 | `system` |

### 手势快捷方式与安装

- **安装方法**：将 `readingfolio.koplugin` 复制到 KOReader 的 `plugins/` 目录下并重启 KOReader。在阅读界面顶部菜单栏 **“工具 (Tools)”** 中即可找到 **“阅笺”**。
- **手势绑定**：设置 → 手势（或快捷方式）→ 选一个手势 → 阅读器 → 阅笺（事件 `ShowReadingFolio`，动作 ID `reading_folio_preview`；该动作注册为 `reader = true` 且未指定分组，因此直接列在「阅读器」一节下，没有再下一层）。

---

### 工作原理与设置键全景表

#### 屏保与渲染机制
1. **屏保适配**：截获 `Screensaver.show`，当 `screensaver_type` 为 `reading_folio` 时由本插件托管生成全屏 `ScreenSaverWidget`；未在阅读界面时自动回退至 KOReader 默认屏保。
2. **转屏控制**：读取所选样式的 `defaults.landscape`，休眠时用 `Screen:setRotationMode` 转为横屏、唤醒时恢复原方向；选中非横屏样式而屏幕本来是横屏时会反向转为竖屏。自定义布局带 `use_screen_orientation`，完全沿用当前屏幕方向、不做任何转屏。
3. **随机背景图路径**：`DataStorage:getDataDir()/reading_folio_background/`。
4. **主题包路径**：`DataStorage:getDataDir()/reading_folio_themes/`。壁纸设为「自定义图片」的主题包会把图片以 base64 内嵌；导入时解包到 `reading_folio_themes/assets/`（文件名带时间戳，重复则追加序号），并把预设里的 `custom_bg_path` 改指到解包后的文件。
5. **场景消费**：优先读取当前书的内存预览场景，其次读取 `typefolio_folio_scene`；只覆盖本次构建所用的样式/内容模式。

#### 设置键参考 (`G_reader_settings`)

| 键名 | 作用 / 取值 |
| --- | --- |
| `screensaver_type` | KOReader 官方屏保键；本插件注册值为 `reading_folio` |
| `reading_folio_previous_screensaver_type` | 设为休眠屏保前的原 `screensaver_type`；取消勾选时还原，无记录则回到 `cover` |
| `reading_folio_style` | 风格 ID（`swiss` / `terminal` / `quote` / `ticket` / `cover` / `gallery` / `dossier` / `archive` / `bookpost` / `architecture` / `zen` / `mei` / `lan` / `zhu` / `ju` / `custom` / `random`） |
| `reading_folio_follow_folio_scenes` | 是否消费 Type Folio 的每书 Folio Scene；默认开启 |
| `reading_folio_language` | 卡片/海报显示的语言设置（`system` / `en` / `zh_CN`；菜单维持 KOReader 系统语言） |
| `reading_folio_content_mode` | 内容模式（`reading_folio` / `highlight_progress` / `random`） |
| `reading_folio_screensaver_background` | 屏幕背景（`white` / `gray` / `transparent` / `black` / `random_image` / `book_cover` / `custom_image`） |
| `reading_folio_bg_image_opacity` | 图片壁纸透明度（`1` / `0.75` / `0.5` / `0.25`，默认 `1`） |
| `reading_folio_custom_background_path` | 自定义布局壁纸文件路径 |
| `reading_folio_custom_layout` | 版本 2 的项目可见性、相对坐标、缩放、旋转角度、文字方向（`h` / `v`）与独立文字颜色数据表 |
| `reading_folio_custom_presets` | 命名预设表：每项含布局项目快照、壁纸设置、卡片外观、封面缩放、卡片比例与三档字号偏移及保存时间戳 |
| `reading_folio_active_custom_preset` | 当前生效的预设名称，用于在菜单中标出已应用项 |
| `reading_folio_editor_move_step` | 编辑器移动步长（`0.01` / `0.03` / `0.05` / `0.10`，默认 `0.03`，按相对坐标计） |
| `reading_folio_editor_rotate_step` | 编辑器旋转步长（`15` / `30` / `45` / `90`，默认 `90`，单位度） |
| `reading_folio_clock_refresh_mode` | 时钟刷新方式（`static` / `minute`，默认 `static`）；预览与休眠屏保共用 |
| `reading_folio_clock_refresh_waveform` | 分钟时钟的局刷波形（`ui` / `fast`，默认 `ui`） |
| `reading_folio_clock_full_refresh_interval` | 周期全刷间隔分钟数（`0` / `1` / `10` / `30` / `60`，默认 `30`；`0` 为关闭） |
| `reading_folio_bg_image_mode` | 背景图拉伸（`stretch` / `fit` / `center`） |
| `reading_folio_card_ratio_mode` | 卡片比例模式（`default` / `fullscreen` / `custom`） |
| `reading_folio_card_ratio_custom` | `custom` 模式下的自定义数值（`0.30`–`1.00`） |
| `reading_folio_card_border` | 卡片边框（`none` / `thin` / `thick`） |
| `reading_folio_card_bg` | 卡片背景色（`light_gray` / `pure_white` / `soft_gray`） |
| `reading_folio_card_shadow` | 卡片阴影布尔值 (`true` / `false`) |
| `reading_folio_font_delta_big`/`mid`/`small` | 大/中/小字号全局偏移量（`-20` 至 `+20`） |
| `reading_folio_cover_scale` | 封面缩放比例（`0.0`–`1.0`） |
| `reading_folio_show_*` | 15 个显示条目开关（`title`, `author`, `cover`, `chapter`, `page_number`, `percentage`, `progress_bar`, `chapter_time_left`, `book_time_left`, `total_time`, `today_time`, `battery`, `clock`, `highlights`, `custom_message`） |

---

### 开发者扩展指南

```text
readingfolio.koplugin/
├── _meta.lua                    插件元数据
├── main.lua                     生命周期、预览、屏保适配与预设/主题包入口
├── core/
│   ├── constants.lua            常量与设置键名
│   ├── data.lua                 书籍与会话数据提取
│   ├── folio_scene.lua          Type Folio 场景快照解析
│   └── theme_bundle.lua         主题包导入导出与校验
├── i18n/
│   ├── i18n.lua                 翻译入口
│   ├── locale_interface.lua     语言包契约校验
│   ├── locale_registry.lua      语言包注册表
│   └── locales/                 多语言包 (en.lua, zh_CN.lua)
├── rendering/
│   ├── background.lua           屏幕与卡片背景绘制
│   ├── custom_layout.lua        自定义布局设置模型
│   └── renderer.lua             样式调度与渲染器
├── styles/                      15 种内置样式 + custom.lua，附样式契约与注册表
│   ├── style_interface.lua      样式契约校验
│   └── style_registry.lua       样式注册表
├── ui/
│   ├── editor.lua               全屏实时布局编辑器
│   └── menu.lua                 设置菜单与交互
├── assets/                      梅兰竹菊四款样式的配图 (mei/lan/zhu/ju.png)
├── tests/                       回归测试（语法与 `bit` 禁用、场景、预设、屏保回退）与共用桩件
├── tools/package.py             发布打包脚本
├── DEVELOPMENT_SPEC.md          开发与审查规范
└── .agents/AGENTS.md            AI Agent 工作区配置
```

#### 扩展新样式
1. 参照契约在 `styles/my_style.lua` 中实现 `render(ctx)`。
2. 在 `styles/style_registry.lua` 的 `STYLE_FILES` 列表中注册 `"my_style"`。
3. 在 `i18n/locales/en.lua` 与 `i18n/locales/zh_CN.lua` 添加样式名称及文案翻译。

##### 样式接口示例 (Style Contract)
```lua
local VerticalGroup = require("ui/widget/verticalgroup")

return {
    interface_version = 1,
    id = "my_style",
    label = "My Style",
    defaults = {
        big = 24,
        mid = 17,
        small = 13,
        padding_h = 24,
        padding_v = 24,
        title_limit = 28,
        dark = false,
        allow_cover = true,
        full_bleed = false,
    },
    render = function(ctx)
        -- 使用 ctx.data、ctx.layout、ctx.theme、ctx.fonts 与 ctx.translate
        return {
            body = VerticalGroup:new{ ... },
        }
    end,
}
```

#### 扩展新语言
1. 新建 `i18n/locales/my_locale.lua` 并实现 `strings` 映射。
2. 在 `i18n/locale_registry.lua` 的 `LOCALE_FILES` 中添加文件名。

#### 回归测试

`tests/` 下的 spec 在插件根目录用任意 Lua 5.2+ 解释器直接执行即可，不需要装 KOReader（`support.lua` 用到带 `mode` 与 `env` 参数的 `load`，这是 5.2 起的写法）。前三个由 `tests/support.lua` 提供 KOReader 桩件，它按函数定义行从 `main.lua` 或 `rendering/renderer.lua` 里切出源码片段再 `load`，因此跑的是真实代码而非测试里另写一份实现。

- `preset_spec.lua`：预设保存、重名被拒、「更新为当前编辑布局」仍可覆盖、空名与 `nil` 名被拒。
- `folio_scene_spec.lua`：场景快照解析与风格解析，含 `style_id = "random"` 的随机取样（多次抽样需覆盖全部非自定义风格且永不抽到自定义布局）；若同级目录下有 Type Folio，会顺带核对它发布的快照形状。
- `screensaver_fallback_spec.lua`：回退到 KOReader 自带屏保时临时替换的 `readSetting` 必须在每条出口上还原，包括 `setup()` 与 `show()` 抛异常的路径。
- `clock_refresh_spec.lua`：分钟刷新的定时器不会随休眠次数叠加、只刷时钟所在区域、没有区域时才退回整屏，以及风格提供的重建函数抛异常时仍显示正确时间。
- `style_render_spec.lua`：在桩件化的 KOReader 上跑真实的 `Renderer:build`，逐个渲染 15 个内置风格，核对登记的时钟在控件树里可达、显示的是时间、带着刷新区域，并在关掉时钟或电量后不再登记/不再显示。这个 spec 不检查像素，只检查接线。
- `syntax_spec.lua`：从 `main.lua` 与 `_meta.lua` 出发遍历 dofile 图（含样式与语言包注册表按名拼出的路径），对走到的每个文件 `loadfile` 解析，并禁止 LuaJIT 专有的 `bit` 库。这两类问题都只在比 LuaJIT 新的 Lua 上暴露，且解析错误对不加载该文件的测试完全隐形。dofile 指向的文件不存在也算失败，所以改名或移走模块同样会被抓到；`styles/custom.lua` 里的 `require("ffi")` 是有意放行的例外，原因写在 spec 头部。

---

## English

Reading Folio is a standalone KOReader plugin that formats your book cover, reading progress, session statistics, chapter info, and highlights into beautifully styled reading cards. It supports full-screen live preview, sleep screen adaptation with automatic landscape rotation, and extensive visual customization.

### Core Features

- **15 Built-in Layout Styles**, plus Custom layout and Random style: Swiss grid, Terminal, Quote poster, Ticket stub, Cover first, Gallery folio, Reading dossier, Library archive, Book post, Reading architecture, Japanese minimal, and the Four Gentlemen (Plum, Orchid, Bamboo, Chrysanthemum). Style names here are the menu labels.
- **Sleep Screen & Auto Rotation**: Easily set as your KOReader sleep screen. Landscape styles automatically rotate orientation when entering sleep mode and restore upon wake; the custom layout follows the screen as-is.
- **Live Preview Menu**: All menu adjustments (styles, backgrounds, ratio, font size deltas, item toggles) refresh the preview live with `keep_menu_open`.
- **Flexible Card & Font Controls**: Customize card aspect ratio (0.30–1.00), border width, background color, drop shadow, cover scale, and precise font size deltas (-20 to +20).
- **15 Toggleable Content Items**: Individually show/hide title, author, cover, chapter, page count, percentage, progress bar, chapter/book time remaining, total/today reading time, battery level, clock, highlights, and custom messages.
- **Live Custom Layout Editor**: Choose a white, gray, black, transparent, or image wallpaper; blend image opacity from 25% to 100% over the underlying reading view; show or hide each of the 15 items; move, rotate, and scale the selected item; and set horizontal or vertical text direction plus transparent-layer automatic, black, gray, or white color independently per text item. Move and rotate step sizes are selectable (1/3/5/10% and 15/30/45/90°). Every change is saved and rendered immediately.
- **Presets**: Save the current layout — together with wallpaper, card appearance, cover scale, card ratio, and font deltas — as a named preset, then apply, update, rename, or delete it. Saved presets are listed directly in the Style menu. A duplicate name is rejected rather than silently replacing the stored preset; use "Overwrite with current" in that preset's submenu to update it on purpose.
- **Theme Packages**: Export any preset as a `.readingfolio-theme.json` package — a custom-image wallpaper is embedded with it — and import it back on another device. Imports are checked against the format version and size limits (24 MiB per package, 16 MiB per image), and a clashing name gets a numeric suffix.
- **Minute Clock Refresh**: The clock is static by default. Switch it to per-minute and only the clock region is repainted at each minute boundary, with a choice of UI or fast local-refresh waveforms and an optional full refresh every 1, 10, 30, or 60 minutes. Preview and the real sleep screen share this path; the timer stops when either goes away.
- **Folio Scenes**: Optionally follow Type Folio 2.4+ per-book scenes for both preview and sleep-screen rendering without changing the saved Reading Folio style or content mode. A published "random style" scene samples a real built-in style.

---

## 更新记录 / Changelog

### v1.6.1 (2026-08-17)

- 修复**每分钟局刷时钟从未真正工作**。这一个功能有四处独立缺陷，合在一起的效果是：时间不变、整屏每分钟刷一次、部分风格的电量被吃掉，而且每睡一次就多叠一条刷新链。
  - 屏保侧的定时器句柄恒为 `nil`：代码存的是 `UIManager:scheduleIn(...)` 的返回值，而 KOReader 这个函数根本没有 `return`。于是「是否已在运行」的判断永不生效、`Screensaver.close` 里的反注册是死代码；`Screensaver` 是单例，每次休眠都新起一条链，旧链因为看到新 widget 非 `nil` 而继续跑。现改为保存函数本身（`UIManager:unschedule` 匹配的也正是它），并在每次接管屏保前先停掉上一轮。
  - 局刷从来没局刷过：判断条件是 `if clock.dimen`，而 `TextWidget` 从不记录自己被画在哪里（基类只在 `getSize` 里读 `dimen`），所以 15 个内置风格永远走整屏 `setDirty`，菜单里的「局刷波形」一并失效。现在渲染器把时钟所在的一行包进一个带卡片底色的 `FrameContainer` 并登记为刷新区域——底色是必需的，否则新时间会画在旧时间上糊成一团。
  - 自定义布局是另一种坏法：它的时钟是个把文字当蒙版直接叠上去的控件，本身带 `dimen`，所以旧代码确实只重画了它——但它不铺底色，于是上一分钟的字留在原地，新字叠上去。现在改为把整张卡交给 `setDirty` 重画（壁纸随之复原），同时仍只把时钟那一小块推给墨水屏刷新：`setDirty` 的区域参数只限制推屏范围，不限制重绘范围。
  - `clock:setText()` 会把整行状态吃掉：瑞士网格、梅、兰、竹、菊把时间和电量（以及今日时长、页码）拼在同一个 `TextWidget` 里，刷新时整串被替换成 `"14:32"`，第一次刷新后电量就消失了。现在这些风格改为登记一个重建整行的函数。
  - 5 个风格刷的是不在屏幕上的 widget：渲染器无条件把公共页脚的时钟塞进 runtime，而典藏画廊、阅读卷宗、藏书邮票、阅读构成、阅读邮笺都设了 `common_footer = false`，那个 widget 根本没进控件树。现在只有页脚真正被用上时才登记。其中阅读邮笺的时间嵌在日期戳里（`2026.08.17 · 14:31`），暂不参与分钟刷新；其余四个本来就不显示时间。
  - 12 小时制下时间会变窄（12:59 → 1:00），刷新区域按构建时的行宽预留，避免被丢掉的那一位数字留在屏幕上。
- 修复**梅、兰、竹、菊四个风格无视「电量」显示开关**：它们读的是 `battery_text`，这个字段是给阅读构成、阅读邮笺、阅读卷宗那种固定电量槽位准备的、不受开关控制；尊重开关的是 `battery`。
- 补齐 **`Applied preset: %s` 的翻译**：`ui/menu.lua` 里应用预设的提示在两个语言包里都没有条目，中文界面显示英文；它的三个兄弟（保存/更新/删除）都在。
- 新增 **`tests/style_render_spec.lua`**：在桩件化的 KOReader 上真正渲染全部 15 个内置风格，检查登记的时钟确实在控件树里、确实显示时间、带着可刷新的区域，以及关掉时钟/电量后不再登记也不再显示。上面「刷不在屏幕上的 widget」那条正是它抓出来的。
- 新增 **`tests/clock_refresh_spec.lua`**：切片加载 `main.lua` 里的刷新逻辑，覆盖定时器叠加、区域刷新与整屏回退、格式化函数抛异常时的退路、周期全刷的开关。

### v1.6.0 (2026-08-16)

- 新增**预设存储与管理**：可将当前自定义布局保存为命名预设，并在菜单中应用、更新为当前布局、重命名或删除；预设保存于 `reading_folio_custom_presets`，当前生效项记录在 `reading_folio_active_custom_preset`。
- 新增**主题包导入导出**：预设可导出为 `.readingfolio-theme.json` 主题包（内嵌壁纸图片，含格式版本与体积校验），导入时自动为重名主题追加序号。
- 新增**编辑器旋转步长**：自定义布局编辑器支持按步长旋转选中项目（`reading_folio_editor_rotate_step`）。
- 修复**同名预设静默覆盖**：「保存为预设」遇到已存在的名称时不再直接替换原预设，改为提示名称已被占用；更新既有预设请使用菜单中的「更新为当前编辑布局」。
- 修复**随机风格场景不生效**：Type Folio 发布 `style_id = "random"` 的场景时，预览与休眠屏保会从内置风格中随机取样，而不再落回原有固定风格。
- 修复**屏保回退可能污染全局设置读取**：回退至 KOReader 默认屏保时临时替换的 `readSetting` 现在由统一的 `pcall` 保护，`setup` 抛出异常也会恢复原方法。
- 修复**时钟局刷默认值与菜单不一致**：菜单里「静态」标着（默认）且未保存设置时就是勾选状态，但代码两处读取都写成 `or "minute"`，于是从没进过这个子菜单的人实际每分钟被局刷一次，还会按周期计数每 30 分钟全刷一次。现改为默认 `static`，与菜单显示一致——墨水屏不该为没人要求的刷新买单。
- **前向兼容 Lua 5.4 / 5.5**：移除 `require("bit")`。`bit` 是 LuaJIT 扩展，标准 Lua 5.3+ 并不提供；唯一的用处是判断屏幕方向的奇偶（`bit.band(rotation, 1)`），已改为 `rotation % 2`——Lua 的取模是向下取整，对包括负数在内的所有整数与取低位完全等价。
- 新增 **`tests/syntax_spec.lua`** 守住上面这条：从 `main.lua` 与 `_meta.lua` 出发遍历 dofile 图，逐个解析插件实际加载的 34 个文件并禁止 `bit`。之所以不写死文件清单——这类问题的要点是覆盖下个月新增的模块，而不是今天已有的那些；顺带地，dofile 指向的文件不存在也会失败，改名或移走模块同样报错。`styles/custom.lua` 的 `require("ffi")` 是有意保留的例外：KOReader 的 Blitbuffer 本身基于 FFI 并以 cdata 交出像素，布局旋转的逐像素访问没有可移植替代。
- 补齐并校正 **README**：功能与参数全景表、设置键参考与结构图此前没写过预设、主题包与编辑器步长；结构图还把 `menu.lua` 等文件画在仓库根目录（实际在 `ui/`、`core/`、`rendering/`、`i18n/` 下）。现按真实目录树与真实菜单层级重写，并补上 `tests/` 的回归测试说明。同时逐条核对后修正了若干与代码不符的旧描述：编辑器不能增删项目（只能逐项显示/隐藏）、文字方向（横向/竖向）此前完全没写、主题包只在壁纸为「自定义图片」时内嵌图片、屏幕背景漏了「灰色」、周期全刷漏了 1 分钟档、时钟局刷不限于自定义布局的手势预览（休眠屏保同样适用）、「默认」卡片比例随风格而异（藏书邮票 0.92、阅读邮笺 0.94、自定义布局 1.00）、语言选项只影响卡片文案而非菜单、手势路径没有「工具」这一层、英文段落的风格名与实际菜单标签不符。

### v1.5.1 (2026-08-08)

- 修复**自定义编辑器菜单层级**：项目、壁纸、字体颜色及图片选择窗口现在会正确显示在全屏编辑器上方，不再需要关闭编辑器后才能看到。
- 修复**编辑器入口层级**：进入全屏编辑器前会关闭原设置菜单，避免编辑器与其子菜单处于不兼容的窗口层级。

### v1.5.0 (2026-08-07)

- 新增 **Folio Scenes 消费端**：支持 Type Folio 2.4+ 发布的静读、研读、编辑与章节聚焦场景。
- 即时预览与休眠屏保复用同一场景解析路径；联动只覆盖当前构建，不改写用户既有风格或内容模式。
- 新增“跟随 Type Folio 场景”总开关，默认开启；无有效快照、关闭场景或未知版本时自动退回原设置。

### v1.4.0 (2026-08-07)

- 新增**自定义布局与全屏实时编辑器**：支持独立项目开关、选中项目四向移动、缩放及即时持久化预览。
- 新增**自定义壁纸选择**：支持图片文件选择、适应/拉伸/居中显示以及白底、黑底、书籍封面和随机图片。
- 新增**壁纸透明度与灰阶背景**：支持完全透明及白/灰/黑纯色背景，图片壁纸可选 25%/50%/75%/100% 透明度并即时预览。
- 新增**项目独立字体颜色**：每个文字项目均可单独选择自动、黑、灰或白色；选择封面与进度条时颜色按钮自动禁用。
- 新增**手势预览时钟局刷**：自定义布局支持静态或每分钟刷新，更新时仅提交时钟区域；局刷可选 UI/快速波形，并可关闭周期全刷或设为每 10/30/60 分钟全刷。

### v1.3.0 (2026-08-06)

- 新增**随机风格模式 (Random Style)**：在显示风格菜单最后添加「随机风格」选项，开启后每次预览或生成屏保时将从内置 15 种风格中随机挑选呈现。
- 新增**规范与标准文档**：对齐「文笺 / Type Folio」规范，建立项目开发与审查规范（`DEVELOPMENT_SPEC.md`）及 AI Agent 工作区配置（`.agents/AGENTS.md`）。
- 强化**输入参数弹窗校验与反馈**：为字号偏移、封面缩放、卡片比例等自定义输入增加范围校验与 `Notification` 错误提示，防止非法输入。
- 规范**插件元数据**：`_meta.lua` 补全 `name` 和 `version` 标注，确保版本与元数据全对齐。
- 修复**透明屏幕背景息屏问题**：修复在息屏屏保托管（`_showScreensaver`）过程中调用 `Screen:clear()` 清屏导致透明背景失效变白的问题，确保透明背景下底层阅读页面完美透出。
- 优化**语言设置独立解耦**：菜单中的「语言」选项改为仅控制阅读卡片/海报显示的语言，插件本身的菜单语言恒定保持与 KOReader 系统语言一致。
- 优化**菜单交互与即时预览 (Live Preview & Keep Menu Open)**：所有样式选择、语言切换、背景模式、字号微调及卡片外观调整在菜单中更改时自动刷新全屏预览，并保持菜单开启状态。
- 新增**自定义字号偏移输入 (Custom Font Size Delta)**：大 / 中 / 小字号微调新增「自定义」数额弹窗，支持自由输入 `-20` 至 `+20` 的精细偏移值。

### 2026-07-27

- 初始版本发布：引入 15 种阅读卡片排版风格、多语言 I18n 框架、横屏构图休眠自动转屏及卡片参数高度定制支持。
