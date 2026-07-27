# 阅笺 / Reading Folio

[中文说明](#中文说明) · [English](#english)

## 鸣谢与灵感来源 / Acknowledgements

灵感来源：由 Reddit 用户 [hundredpercentcocoa](https://www.reddit.com/user/hundredpercentcocoa/) 创建的 `2-book-receipt-shortcut-and-lockscreen.lua`。

Inspired by `2-book-receipt-shortcut-and-lockscreen.lua` created by Reddit user [hundredpercentcocoa](https://www.reddit.com/user/hundredpercentcocoa/).

## 中文说明

“阅笺”（Reading Folio）是标准 KOReader 插件，可将当前书籍封面、阅读进度、
累计/今日阅读时长、章节进度以及书摘批注编排成可实时预览、并支持用作休眠屏保的阅读画面。

### 安装

将 `readingfolio.koplugin` 复制到 KOReader 的 `plugins` 目录下，然后重启 KOReader。
在阅读界面中点击顶部菜单栏的 **“工具 (Tools)”**，即可看到 **“阅笺”** 菜单项。

菜单及内置多种显示风格中的固定文字均支持简体中文与英文。默认跟随 KOReader
的界面语言，也可以在 **“阅笺 > 语言”** 中自由选择“跟随系统”、“English”或“简体中文”。

横屏构图样式（如“藏书邮票”和“阅读邮笺”）在作为休眠屏幕时会自动转为横向，
并在唤醒后恢复原阅读方向；在普通竖屏预览中则按横向比例缩放并居中显示。

### 扩展新样式

1. 参照 [样式接口示例](#样式接口示例--style-interface-example)，新建 `styles/my_style.lua`。
2. 将 `"my_style"` 加入 `style_registry.lua` 的 `STYLE_FILES` 列表中。
3. 为样式名称和固定文案分别在 `locales/en.lua`、`locales/zh_CN.lua` 中添加对应词条。

`render(ctx)` 接收整理后的书籍与会话数据，并返回包含 `body` 控件的表。
固定文字应使用 `ctx.translate("Source text")`，不要在样式文件中硬编码某种语言。
完整约定见 `style_interface.lua`。

### 扩展新语言

1. 参照 [语言包接口示例](#语言包接口示例--locale-interface-example)，新建 `locales/my_locale.lua`。
2. 将文件名加入 `locale_registry.lua` 的 `LOCALE_FILES` 列表中。

语言包缺少某个词条时，会自动回退到英文以及 KOReader 的 `gettext` 系统。语言包结构会在加载时通过 `locale_interface.lua` 进行校验。

## English

Reading Folio is a standalone KOReader plugin that composes the book cover, reading progress,
time statistics, chapter info, and highlights into a previewable reading card that can also be used as the sleep screen.

### Installation

Copy `readingfolio.koplugin` to KOReader's `plugins` directory and restart KOReader.
Open a document and tap the top menu bar under **Tools** to find **Reading Folio**.

The menu and all built-in styles support English and Simplified Chinese. The default language follows
KOReader's interface setting and can be configured under **Reading Folio > Language**.

Landscape styles (such as **Library stamp** and **Book post**) automatically switch orientation when used as a sleep screen and restore your reading orientation on wake.

### Adding a Style

1. Create `styles/my_style.lua` following the [style interface example](#样式接口示例--style-interface-example).
2. Add `"my_style"` to `STYLE_FILES` in `style_registry.lua`.
3. Add the style label and text entries to `locales/en.lua` and `locales/zh_CN.lua`.

### Adding a Language

1. Create `locales/my_locale.lua` following the [locale interface example](#语言包接口示例--locale-interface-example).
2. Add its filename to `LOCALE_FILES` in `locale_registry.lua`.

---

## 模块结构 / Module layout

```text
readingfolio.koplugin/
  _meta.lua              插件元数据 / plugin metadata
  main.lua               生命周期、预览与屏保适配 / lifecycle, preview, screensaver
  menu.lua               设置菜单 / settings menu
  data.lua               书籍与会话数据整理 / book and session data
  background.lua         屏幕背景 / screen backgrounds
  renderer.lua           样式调度与渲染 / style dispatcher and renderer
  constants.lua          设置键名与默认常量 / setting keys and constants
  i18n.lua               多语言翻译管理 / i18n translator
  locale_interface.lua   语言包契约校验 / locale schema validator
  locale_registry.lua    语言包注册表 / locale registry
  style_interface.lua    样式契约校验 / style schema validator
  style_registry.lua     样式注册表 / style registry
  locales/               语言包目录 / locale packs
    en.lua
    zh_CN.lua
  styles/                排版样式 / layout styles
    swiss.lua            瑞士网格
    terminal.lua         黑底终端
    quote.lua            引文海报
    ticket.lua           阅读票根
    cover.lua            封面主导
    gallery.lua          典藏画廊
    dossier.lua          阅读卷宗
    archive.lua          藏书邮票
    bookpost.lua         阅读邮笺
    architecture.lua     阅读构成
    zen.lua              日式留白
    mei.lua              梅
    lan.lua              兰
    zhu.lua              竹
    ju.lua               菊
```

## 设置键参考 / Settings keys

全部持久化在 `G_reader_settings`（`settings.reader.lua`），键名见 `constants.lua`：

| 键 | 取值 |
|---|---|
| `screensaver_type` | KOReader 官方键；本插件注册值 `reading_folio` |
| `reading_folio_style` | `swiss`（默认）/ `terminal` / `quote` / `ticket` / `cover` / `gallery` / `dossier` / `archive` / `bookpost` / `architecture` / `zen` / `mei` / `lan` / `zhu` / `ju` |
| `reading_folio_language` | `system`（默认）/ `en` / `zh_CN` |
| `reading_folio_previous_screensaver_type` | "设为休眠屏幕"取消时回退的原屏保类型 |
| `reading_folio_screensaver_background` | `white`（默认）/ `transparent` / `black` / `random_image` / `book_cover` |
| `reading_folio_bg_image_mode` | `stretch`（默认）/ `fit` / `center` |
| `reading_folio_content_mode` | `reading_folio`（默认）/ `highlight_progress` / `random` |
| `reading_folio_card_ratio_mode` / `reading_folio_card_ratio_custom` | `default`(0.60) / `fullscreen` / `custom`(0.30–1.00) |
| `reading_folio_card_border` | `none`（默认）/ `thin` / `thick` |
| `reading_folio_card_bg` | `light_gray`（默认）/ `pure_white` / `soft_gray` |
| `reading_folio_card_shadow` | 布尔，默认 false |
| `reading_folio_font_delta_big` / `_mid` / `_small` | 三档文字大小全局偏移 |
| `reading_folio_cover_scale` | 数字，默认 1.0；0 = 隐藏封面 |
| `reading_folio_show_*` | 15 个显示条目开关（未写 = 开）：`title / author / cover / chapter / page_number / percentage / progress_bar / chapter_time_left / book_time_left / total_time / today_time / battery / clock / highlights / custom_message` |

随机背景图目录：`DataStorage:getDataDir()/reading_folio_background/`。

## 样式接口示例 / Style interface example

```lua
local VerticalGroup = require("ui/widget/verticalgroup")

return {
    interface_version = 1,
    id = "my_style",
    label = "My style",
    defaults = {
        big = 24,
        mid = 17,
        small = 13,
        padding_h = 24,
        padding_v = 24,
        title_limit = 28,
        dark = false,
        allow_cover = false,
        full_bleed = false,
    },
    render = function(ctx)
        local children = {
            -- 使用 ctx.data、ctx.layout、ctx.theme、ctx.fonts 及辅助函数。
            -- Use ctx.data, ctx.layout, ctx.theme, ctx.fonts and helpers.
        }
        return {
            body = VerticalGroup:new(children),
        }
    end,
}
```

## 语言包接口示例 / Locale interface example

```lua
return {
    interface_version = 1,
    id = "fr",
    label = "Français",
    aliases = { "fr_FR", "fr-CA" },
    strings = {
        ["Reading Folio"] = "Carnet de lecture",
        ["Preview Reading Folio"] = "Aperçu du carnet de lecture",
    },
}
```
