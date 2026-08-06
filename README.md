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

1. **15 种精致内置风格与随机选择**：涵盖瑞士网格、黑底终端、复古票根、海报、藏书邮票、阅读邮笺、构成主义、日式留白及梅兰竹菊等多种排版主题，并支持置于最后的「随机风格」选项。
2. **休眠屏保与动态转屏**：一键设为休眠屏保。对于横屏构图样式（如“藏书邮票”和“阅读邮笺”），作为屏保时会自动切换为横屏，唤醒后恢复原阅读方向。
3. **即时预览与极速调参 (Live Preview)**：菜单所有单选/开关/字号调参均支持保持菜单打开（`keep_menu_open`），并在修改瞬间自动更新背景预览，无需重复进出菜单。
4. **高度自由的卡片定制**：支持卡片宽高比例（默认/全屏/0.30–1.00自定义）、边框粗细、背景色、卡片阴影、大/中/小字号偏移（-20 至 +20）及封面缩放（0-100%）。
5. **15 项数据条目显显开关**：可单独勾选显示/隐藏书名、作者、封面、章节、页码、阅读百分比、进度条、本章/全书剩余时间、累计/今日阅读时间、电量、时钟、书摘及自定义文字。

### 功能与参数全景表

| 菜单模块 | 可调参数 / 功能项 | 说明 / 取值范围 | 默认值 |
| --- | --- | --- | --- |
| **预览与屏保** | 预览阅笺 / 设为休眠屏幕 | 实时全屏预览；作为休眠屏保时根据样式自动转屏 | `reading_folio` |
| **显示风格** | 15 种风格选择及随机模式 | 瑞士网格、黑底终端、引文海报、阅读票根、封面主导、典藏画廊、阅读卷宗、藏书邮票、阅读邮笺、阅读构成、日式留白、梅、兰、竹、菊、随机风格 | `swiss` (瑞士网格) |
| **内容与模式** | 显示模式 | 阅笺（默认）、摘录与进度、随机 | `reading_folio` |
| | 屏幕背景 | 纯白、透明、纯黑、随机背景图、图书封面 | `white` (纯白) |
| | 背景图片适配 | 拉伸铺满、等比适应、居中且不缩放 | `stretch` (拉伸铺满) |
| **卡片外观与尺寸** | 卡片尺寸比例 | 默认比例 (0.60)、全屏、自定义比例 (0.30 - 1.00) | `default` (0.60) |
| | 卡片边框 | 无边框、细边框、粗边框 | `none` (无边框) |
| | 卡片背景颜色 | 淡灰（默认）、纯白、柔灰 | `light_gray` |
| | 卡片阴影 | 开 / 关 | 关 |
| **文字与封面微调** | 大 / 中 / 小字号偏移 | 预设 (-2, 0, +2, +4, +6) 及自定义数字输入 (-20 至 +20) | `0` |
| | 封面缩放比例 | `0.0` - `1.0`（设为 `0` 可隐藏封面） | `1.0` |
| **显示内容** | 15 项条目开关 | 书名、作者、封面、章节、页码、百分比、进度条、本章剩余、全书剩余、累计时长、今日时长、电量、时钟、书摘、自定义文字 | 全部默认开启 |
| **语言** | 界面与固定文案语言 | 跟随系统、English、简体中文 | `system` |

### 手势快捷方式与安装

- **安装方法**：将 `readingfolio.koplugin` 复制到 KOReader 的 `plugins/` 目录下并重启 KOReader。在阅读界面顶部菜单栏 **“工具 (Tools)”** 中即可找到 **“阅笺”**。
- **手势绑定**：设置 → 手势（或快捷方式）→ 选一个手势 → 阅读器 → 工具 → 阅笺（或绑定事件 `ShowReadingFolio` / 动作 `reading_folio_preview`）。

---

### 工作原理与设置键全景表

#### 屏保与渲染机制
1. **屏保适配**：截获 `Screensaver.show`，当 `screensaver_type` 为 `reading_folio` 时由本插件托管生成全屏 `ScreenSaverWidget`；未在阅读界面时自动回退至 KOReader 默认屏保。
2. **转屏控制**：根据所选样式是否偏好横屏（`prefersLandscape`），休眠时自动调整 `Screen:setRotationMode`，唤醒时自动恢复原始方向。
3. **随机背景图路径**：`DataStorage:getDataDir()/reading_folio_background/`。

#### 设置键参考 (`G_reader_settings`)

| 键名 | 作用 / 取值 |
| --- | --- |
| `screensaver_type` | KOReader 官方屏保键；本插件注册值为 `reading_folio` |
| `reading_folio_style` | 风格 ID（`swiss` / `terminal` / `quote` / `ticket` / `cover` / `gallery` / `dossier` / `archive` / `bookpost` / `architecture` / `zen` / `mei` / `lan` / `zhu` / `ju` / `random`） |
| `reading_folio_language` | 卡片/海报显示的语言设置（`system` / `en` / `zh_CN`；菜单维持 KOReader 系统语言） |
| `reading_folio_content_mode` | 内容模式（`reading_folio` / `highlight_progress` / `random`） |
| `reading_folio_screensaver_background` | 屏幕背景（`white` / `transparent` / `black` / `random_image` / `book_cover`） |
| `reading_folio_bg_image_mode` | 背景图拉伸（`stretch` / `fit` / `center`） |
| `reading_folio_card_ratio_mode` / `custom` | 卡片比例模式 (`default`/`fullscreen`/`custom`) 及自定义数值 (`0.30`-`1.00`) |
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
├── _meta.lua              插件元数据
├── main.lua               生命周期、预览与屏保适配
├── menu.lua               设置菜单与交互
├── data.lua               书籍与会话数据提取
├── background.lua         屏幕与卡片背景绘制
├── renderer.lua           样式调度与渲染器
├── constants.lua          常量与设置键名
├── i18n.lua / locale_*    多语言翻译体系与接口校验
├── style_interface.lua    样式契约校验
├── style_registry.lua     样式注册表
├── locales/               多语言包 (en.lua, zh_CN.lua)
└── styles/                15 种内置排版样式
```

#### 扩展新样式
1. 参照契约在 `styles/my_style.lua` 中实现 `render(ctx)`。
2. 在 `style_registry.lua` 的 `STYLE_FILES` 列表中注册 `"my_style"`。
3. 在 `locales/en.lua` 与 `locales/zh_CN.lua` 添加样式名称及文案翻译。

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
1. 新建 `locales/my_locale.lua` 并实现 `strings` 映射。
2. 在 `locale_registry.lua` 的 `LOCALE_FILES` 中添加文件名。

---

## English

Reading Folio is a standalone KOReader plugin that formats your book cover, reading progress, session statistics, chapter info, and highlights into beautifully styled reading cards. It supports full-screen live preview, sleep screen adaptation with automatic landscape rotation, and extensive visual customization.

### Core Features

- **15 Built-in Layout Styles**: Swiss grid, Terminal, Quote poster, Ticket, Cover dominant, Gallery, Dossier, Stamp, Book post, Architecture, Japanese Minimal, and Four Gentlemen (Plum, Orchid, Bamboo, Chrysanthemum).
- **Sleep Screen & Auto Rotation**: Easily set as your KOReader sleep screen. Landscape styles automatically rotate orientation when entering sleep mode and restore upon wake.
- **Live Preview Menu**: All menu adjustments (styles, backgrounds, ratio, font size deltas, item toggles) refresh the preview live with `keep_menu_open`.
- **Flexible Card & Font Controls**: Customize card aspect ratio (0.30–1.00), border width, background color, drop shadow, cover scale, and precise font size deltas (-8 to +12).
- **15 Toggleable Content Items**: Individually show/hide title, author, cover, chapter, page count, percentage, progress bar, chapter/book time remaining, total/today reading time, battery level, clock, highlights, and custom messages.

---

## 更新记录 / Changelog

### v1.3.0 (2026-08-06)

- 新增**随机风格模式 (Random Style)**：在显示风格菜单最后添加「随机风格」选项，开启后每次预览或生成屏保时将从内置 15 种风格中随机挑选呈现。
- 新增**规范与标准文档**：对齐「文笺 / Type Folio」规范，建立项目开发与审查规范（`DEVELOPMENT_SPEC.md`）及 AI Agent 工作区配置（`.agents/AGENTS.md`）。
- 强化**输入参数弹窗校验与反馈**：为字号偏移、封面缩放、卡片比例等自定义输入增加范围校验与 `Notification` 错误提示，防止非法输入。
- 规范**插件元数据**：`_meta.lua` 补全 `name` 和 `version` 标注，确保版本与元数据全对齐。
- 修复**透明屏幕背景息屏问题**：修复在息屏屏保托管（`_showScreensaver`）过程中调用 `Screen:clear()` 清屏导致透明背景失效变白的问题，确保透明背景下底层阅读页面完美透出。
- 优化**语言设置独立解耦**：菜单中的「语言」选项改为仅控制阅读卡片/海报显示的语言，插件本身的菜单语言恒定保持与 KOReader 系统语言一致。
- 优化**菜单交互与即时预览 (Live Preview & Keep Menu Open)**：所有样式选择、语言切换、背景模式、字号微调及卡片外观调整在菜单中更改时自动刷新全屏预览，并保持菜单开启状态。
- 新增**自定义字号偏移输入 (Custom Font Size Delta)**：大 / 中 / 小字号微调新增「自定义」数额弹窗，支持自由输入 `-8` 至 `+12` 的精细偏移值。

### 2026-07-27

- 初始版本发布：引入 15 种阅读卡片排版风格、多语言 I18n 框架、横屏构图休眠自动转屏及卡片参数高度定制支持。
