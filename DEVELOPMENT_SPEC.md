# KOReader 插件开发与审查规范 (Plugin Development & Review Standard)

本规范用于指导 KOReader 插件（如 `readingfolio`、`typefolio` 等）的日常功能开发、重构及发布前审查，确保**“代码无隐患、文档不超前、状态不串乱、交互有防错”**。

---

## 一、 开发完成对照检查表 (Review Checklist)

每次功能开发或 Bug 修复完成后，请逐项对照检查并打勾 `[x]`：

### 1. 版本与元数据一致性
- [ ] **版本号统一**：`_meta.lua` 中的 `version` 与 `README.md` changelog 中的版本号完全一致。
- [ ] **更新日志完整**：本次改动的关键点已记录在 `README.md` 的更新日志中。

### 2. 文档-实现完全对齐
- [ ] **功能零虚标**：README、菜单项、应用内帮助中声称的功能、设置键（Setting Key），在代码中均有完整实现。
- [ ] **废弃功能清理**：删除或未实现的逻辑，已从 README、帮助弹窗、语言包中彻底移除。
- [ ] **已知限制显式化**：受 KOReader 架构限制的逻辑（如屏保托管仅在阅读界面生效、屏保随机背景图目录依赖等），已在 README 中明确说明。

### 3. 多书生命周期与屏保/转屏重置
- [ ] **屏保优雅退化与切换**：截获 `Screensaver.show` 时，非阅读界面（无 `ui.document`）自动回退至系统默认屏保。
- [ ] **横屏转屏安全恢复**：休眠屏保根据样式偏好（`prefersLandscape`）自动转屏，唤醒（`onResume`）或关闭预览时必须严格恢复原始屏幕方向（`restoreRotationMode`）。
- [ ] **即时预览 (Live Preview) 无残留**：菜单调参刷新预览（`keep_menu_open`）时，及时销毁前一个 QuickLook/预览 Widget，避免内存泄漏或 UI 重叠。

### 4. 渲染与 UI 边界防崩溃 (E-Ink & Safe Math)
- [ ] **数值缩放 (DPI Scaling)**：所有 Layout 尺寸计算统一使用 `scaled(n)` 或 `Screen:scaleBySize(n)` 适配不同分辨率显示屏。
- [ ] **空值防御 (Nil-coalescing)**：无封面、无章节名、无阅读时长统计、无书摘或数据解析异常时优雅降级（显示占位/隐藏对应模块），绝不抛出 Lua 运行时崩溃。
- [ ] **字号与比例界限保护**：字号偏移 (`FONT_DELTA`) 必须限制在 `-20` 至 `+20`；卡片比例限制在 `0.30` 至 `1.00`。

### 5. UI 交互与输入框校验
- [ ] **保持菜单开启 (`keep_menu_open`) 体验一致**：单选/开关改动后通过 `keep_menu_open = true` 保持菜单开启，并触发 background/preview 即时刷新。
- [ ] **自定义输入严格校验**：所有 `InputDialog`（如自定义卡片比例、自定义字号偏移）在保存前做 `tonumber` 与范围判断，非法输入阻止保存并弹出 `Notification` 提示。

### 6. i18n 多语言与 Style / Locale 契约
- [ ] **双语 1:1 镜像对齐**：`locales/zh_CN.lua` 与 `locales/en.lua` 键位完全一致，无遗漏通用词（如 `Save`），无废弃死键。
- [ ] **Style 契约校验 (Interface v1)**：所有新增或重构样式必须包含 `interface_version = 1`，`id` 严格为小写 ASCII 标识符，`render(ctx)` 返回符合规范的 `body` Widget。
- [ ] **Locale 接口校验**：所有新增语言必须通过 `locale_interface.lua` 契约校验。

---

## 二、 核心开发规范与落地标准

### 1. 生命周期、屏保与转屏恢复规范
```lua
-- 示例：屏保拦截与转屏恢复
function ReadingFolio:showScreensaver()
    if not self.ui or not self.ui.document then
        return false -- 优雅退化为 KOReader 默认屏保
    end
    self:applyRotationForStyle(style)
    -- ... 绘制屏保 Widget
end

function ReadingFolio:onResume()
    self:restoreRotationMode() -- 唤醒时必须恢复屏幕方向
end
```
- **原则**：屏保或预览触发转屏时，必须记录原始方向，唤醒或关闭预览时无条件恢复，绝不损坏用户的日常阅读方向设置。

### 2. Style 契约接口开发规范 (Style Contract v1)
```lua
-- 示例： styles/my_style.lua
local VerticalGroup = require("ui/widget/verticalgroup")

return {
    interface_version = 1,
    id = "my_style",
    label = "My Custom Style",
    defaults = {
        big = 24,
        mid = 17,
        small = 13,
        padding_h = 24,
        padding_v = 24,
        dark = false,
        landscape = false,
    },
    render = function(ctx)
        -- 使用 ctx.data, ctx.layout, ctx.theme, ctx.fonts, ctx.translate
        return {
            body = VerticalGroup:new{ ... },
        }
    end,
}
```
- **原则**：所有样式必须在 `style_registry.lua` 注册，并通过 `style_interface.lua` 的强类型与格式校验。

### 3. 输入框与设置项校验规范
```lua
-- 示例：输入框回调校验
local num = tonumber(input_text)
if not num or num < -20 or num > 20 then
    UIManager:show(Notification:new{ text = translate("Font size delta must be between -20 and +20.") })
    return true -- 返回 true 阻止对话框关闭
end
```
- **原则**：非法数值严禁写入 `G_reader_settings`，必须向用户给出明确的错误提示。

### 4. DPI 动态缩放与安全渲染规范
```lua
-- 示例：针对不同 E-Ink 屏幕分屏适配
local padding = ctx.scaled(16)
local font_size = ctx.fonts.big
```
- **原则**：避免硬编码静态像素偏移，所有内边距、外边距、线条粗细均需使用 `scaled()` 适配不同 PPI 设备的显示效果。

---

## 三、 审查流程执行指南

1. **功能开发完成后**：打开本文件 `DEVELOPMENT_SPEC.md`。
2. **逐条核对**：逐项对照 Review Checklist 进行静态代码检查。
3. **真机/模拟器测试**：
   - 在阅读界面与主菜单界面分别测试休眠屏保及唤醒，验证屏幕旋转是否正常恢复。
   - 切换不同图书测试数据提取与排版，验证无封面或缺失章节数据时是否会抛出崩溃。
   - 尝试非法输入（如在自定义字号/比例弹窗输入字母或超出界限的数字），验证校验提示是否正常响应。
   - 尝试在即时预览模式下连续切换样式与开关，验证预览是否正常刷刷且无内存泄漏。
4. **测试无误后打勾提交**。

---

## 四、 Release 发布规范与打包标准 (Release Specification)

### 1. 版本与发布前检查
- **三处版本号一致**：检查 `_meta.lua` 中的 `version`、`README.md` changelog 中的最新版本号、Git Tag 保持完全一致（格式如 `v1.3.0`）。
- **打包排除杂质**：Zip 安装包根目录必须包含插件根文件夹（如 `readingfolio.koplugin/`），且严格排除 `.git/`、`.DS_Store` 及临时构建缓存。
- **用脚本打包，不要手工 zip**：在仓库根目录执行 `python3 tools/package.py`，产物为 `readingfolio.koplugin.zip`。在仓库内直接 `zip -r … .` 会把 `main.lua`、`core/` 等摊在压缩包根目录，解压进 `koreader/plugins/` 后文件散落一地、插件根本不会加载——这正是脚本存在的原因。脚本会在写出后重新打开压缩包自检：全部条目位于 `readingfolio.koplugin/` 之下、`_meta.lua` 与 `main.lua` 存在、`tests/`、`.git/`、`.agents/`、`.DS_Store`、`*.py`、旧 zip 均未混入，任一项不满足即报错退出（`-l` 可列出全部打包文件）。

### 2. Release Notes / 变更说明模板格式
版本发布时，Release 文档/页面描述须统一采用**标准 Markdown 中英双语分块格式**，每条均使用无序列表及加粗标题简明总结变动：

```markdown
# Release vX.Y.Z

## What's Changed / 变更说明

### 中文 (Simplified Chinese)
- **模块/功能名**：变更说明...
- **模块/功能名**：变更说明...

### English
- **Module/Feature**: Change description...
- **Module/Feature**: Change description...
```
