local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local ImageWidget = require("ui/widget/imagewidget")
local OverlapGroup = require("ui/widget/overlapgroup")
local ProgressWidget = require("ui/widget/progresswidget")
local RenderImage = require("ui/renderimage")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local util = require("util")

local Renderer = {}
Renderer.__index = Renderer

function Renderer.new(options)
    return setmetatable({
        constants = assert(options.constants),
        data_provider = assert(options.data_provider),
        registry = assert(options.registry),
        translate = assert(options.translate),
        screen = Device.screen,
    }, Renderer)
end

local function trimUtf8(value, max_chars)
    value = value or ""
    local length, index, count, cut = #value, 1, 0
    while index <= length do
        local byte = value:byte(index)
        local char_length = byte >= 0xF0 and 4 or (byte >= 0xE0 and 3 or (byte >= 0xC0 and 2 or 1))
        count = count + 1
        if count == max_chars + 1 then cut = index break end
        index = index + char_length
    end
    return cut and (value:sub(1, cut - 1) .. "...") or value, count, cut ~= nil
end

local function compactTitle(title, max_chars)
    title = util.trim(title or "")
    title = util.trim(title:match("^([^\n]+)") or title)
    -- Strip a parenthesized suffix, matching the two bracket kinds as
    -- separate literals: a byte-oriented class like [%(（] also matches the
    -- lone 0xEF/0xBC/0x88 bytes inside other CJK characters (e.g. 传 =
    -- E4 BC A0) and cuts the title mid-character, leaving a broken glyph.
    local half = title:match("^(.-)%(")
    local full = title:match("^(.-)（")
    local core = (half and full) and (#half < #full and half or full) or half or full
    if core and util.trim(core) ~= "" then title = util.trim(core) end
    return trimUtf8(title, max_chars)
end

local function cleanTitle(title)
    return (title or ""):gsub("^《", ""):gsub("》$", "")
end

local function progressWidget(width, height, percentage, options)
    options = options or {}
    return ProgressWidget:new{
        width = width,
        height = height,
        percentage = math.max(0, math.min(percentage or 0, 1)),
        margin_v = 0,
        margin_h = 0,
        radius = options.radius or 0,
        bordersize = options.bordersize or 0,
        bgcolor = options.background,
        fillcolor = options.fill,
    }
end

function Renderer:_layout(defaults)
    local raw_width, raw_height = self.screen:getWidth(), self.screen:getHeight()
    local landscape = defaults.landscape == true
    local screen_width = landscape and raw_width or math.min(raw_width, raw_height)
    local screen_height = landscape and raw_height or math.max(raw_width, raw_height)
    local function scaled(value) return math.max(1, self.screen:scaleBySize(value)) end

    local ratio_mode = G_reader_settings:readSetting(self.constants.CARD_RATIO_MODE) or "default"
    local ratio = defaults.default_ratio or 0.60
    if ratio_mode == "fullscreen" then
        ratio = 1
    elseif ratio_mode == "custom" then
        ratio = tonumber(G_reader_settings:readSetting(self.constants.CARD_RATIO_CUSTOM)) or ratio
        ratio = math.max(0.30, math.min(1, ratio))
    end

    local width = math.floor(screen_width * ratio)
    local target_height = landscape
        and math.min(screen_height, math.floor(width / (defaults.aspect_ratio or 2)))
        or math.floor(screen_height * ratio)
    local full_bleed = defaults.full_bleed == true
    local padding_h = full_bleed and 0 or scaled(ratio_mode == "fullscreen" and 54 or (defaults.padding_h or 36))
    local padding_v = full_bleed and 0 or scaled(ratio_mode == "fullscreen" and 54 or (defaults.padding_v or 36))
    local compact
    if landscape then
        compact = width < 900 or target_height < 420
    else
        compact = screen_height < 1500 or screen_height / math.max(screen_width, 1) < 1.35
    end
    return {
        screen_width = screen_width,
        screen_height = screen_height,
        width = width,
        content_width = width - padding_h * 2,
        target_height = target_height,
        padding_h = padding_h,
        padding_v = padding_v,
        ratio_mode = ratio_mode,
        compact = compact,
        landscape = landscape,
        full_bleed = full_bleed,
        scaled = scaled,
    }
end

function Renderer:selectedStyle()
    local style_id = self.registry:normalize(
        G_reader_settings:readSetting(self.constants.STYLE_SETTING),
        self.constants
    )
    return self.registry:get(style_id)
end

function Renderer:prefersLandscape()
    local style = self:selectedStyle()
    return style and style.defaults.landscape == true
end

function Renderer:_theme(defaults)
    local background = Blitbuffer.COLOR_GRAY_E
    local setting = G_reader_settings:readSetting(self.constants.CARD_BG) or "light_gray"
    if setting == "pure_white" then
        background = Blitbuffer.COLOR_WHITE
    elseif setting == "soft_gray" then
        background = Blitbuffer.COLOR_GRAY_D
    end
    if defaults.dark then
        return {
            foreground = Blitbuffer.COLOR_WHITE,
            muted = Blitbuffer.COLOR_GRAY_9,
            faint = Blitbuffer.COLOR_GRAY_3,
            background = Blitbuffer.COLOR_BLACK,
            inverse_foreground = Blitbuffer.COLOR_BLACK,
            inverse_background = Blitbuffer.COLOR_WHITE,
        }
    end
    return {
        foreground = Blitbuffer.COLOR_BLACK,
        muted = Blitbuffer.COLOR_GRAY_3,
        faint = Blitbuffer.COLOR_GRAY_9,
        background = background,
        inverse_foreground = Blitbuffer.COLOR_WHITE,
        inverse_background = Blitbuffer.COLOR_BLACK,
    }
end

function Renderer:_coverWidget(data, layout, defaults, requested_width, requested_height)
    if not defaults.allow_cover or not data.show.cover then return nil end
    if not defaults.force_cover then
        if data.content_mode == self.constants.CONTENT_MODE_HIGHLIGHT_PROGRESS then return nil end
        if G_reader_settings:readSetting(self.constants.BG_SETTING) == "book_cover" then return nil end
    end
    if not data.ui.bookinfo or not data.ui.document then return nil end
    local buffer = data.ui.bookinfo:getCoverImage(data.ui.document)
    if not buffer then return nil end

    local scale_setting = tonumber(G_reader_settings:readSetting(self.constants.COVER_SCALE_SETTING)) or 1
    if scale_setting <= 0 then return nil end
    local width, height = buffer:getWidth(), buffer:getHeight()
    local bounded_scale = math.min(scale_setting, 1)
    local max_width = math.floor(requested_width
        and requested_width * bounded_scale
        or layout.content_width * scale_setting)
    local max_height = math.floor(requested_height
        and requested_height * bounded_scale
        or layout.screen_height * (layout.compact and 0.38 or 0.48) * scale_setting)
    local scale = math.min(1, max_width / width, max_height / height)
    if scale < 1 then
        width, height = math.max(1, math.floor(width * scale)), math.max(1, math.floor(height * scale))
        buffer = RenderImage:scaleBlitBuffer(buffer, width, height, true)
    end
    return CenterContainer:new{
        dimen = Geom:new{ w = requested_width or layout.content_width, h = height },
        ImageWidget:new{ image = buffer, width = width, height = height },
    }
end

function Renderer:_prepareHighlight(data, layout, theme, fonts, defaults)
    if not data.highlight or not data.highlight.text then return nil, nil, 0 end
    local capacity = math.max(14, math.floor(layout.content_width / math.max(layout.scaled(14), 1)))
    local limit = math.min(self.constants.MAX_HIGHLIGHT_SIZE, capacity * (defaults.highlight_lines or 5))
    local text, count = trimUtf8(util.trim(data.highlight.text), limit)
    if text == "" then return nil, nil, 0 end

    local metadata = {}
    if data.highlight.chapter and data.highlight.chapter ~= "" then
        table.insert(metadata, data.highlight.chapter)
    end
    local page = data.highlight.pageref or data.highlight.pageno
    if not page and type(data.highlight.page) == "string" and data.ui.document.getPageFromXPointer then
        local ok, resolved = pcall(data.ui.document.getPageFromXPointer, data.ui.document, data.highlight.page)
        if ok then page = resolved end
    end
    if page then table.insert(metadata, type(page) == "number" and string.format(self.translate("Page %s"), page) or page) end
    local meta = #metadata > 0 and string.format("(%s)", table.concat(metadata, ", ")) or nil

    local widgets = {
        TextBoxWidget:new{
            face = Font:getFace("cfont", fonts.big),
            text = text,
            width = layout.content_width,
            fgcolor = theme.foreground,
            bgcolor = theme.background,
            bold = true,
            alignment = "center",
        },
    }
    if meta then
        table.insert(widgets, VerticalSpan:new{ width = layout.scaled(8) })
        table.insert(widgets, TextWidget:new{
            text = meta,
            face = Font:getFace("cfont", fonts.small),
            fgcolor = theme.muted,
            padding = 0,
            align = "center",
        })
    end
    return widgets, text, count
end

function Renderer:_footer(data, layout, theme, fonts)
    local battery = data.battery ~= "" and TextWidget:new{
        text = data.battery,
        face = Font:getFace("cfont", fonts.small - layout.scaled(1)),
        fgcolor = theme.muted,
        padding = 0,
    } or nil
    local clock = data.clock ~= "" and TextWidget:new{
        text = data.clock,
        face = Font:getFace("cfont", fonts.small - layout.scaled(1)),
        fgcolor = theme.muted,
        padding = 0,
    } or nil
    if not battery and not clock then return nil end
    local left_width = battery and battery:getSize().w or 0
    local right_width = clock and clock:getSize().w or 0
    return HorizontalGroup:new{
        battery or HorizontalSpan:new{ width = 0 },
        HorizontalSpan:new{ width = math.max(0, layout.content_width - left_width - right_width) },
        clock or HorizontalSpan:new{ width = 0 },
    }
end

function Renderer:_context(data, style, layout, theme, fonts)
    local scaled = layout.scaled
    local highlight_widgets, highlight_text, highlight_length = self:_prepareHighlight(data, layout, theme, fonts, style.defaults)
    if data.content_mode == self.constants.CONTENT_MODE_HIGHLIGHT_PROGRESS and not highlight_widgets then
        data.content_mode = self.constants.CONTENT_MODE_READING_FOLIO
    end
    local title_limit = style.defaults.title_limit or (layout.compact and 30 or 36)
    data.title_display = compactTitle(data.title, title_limit)
    data.clean_title = cleanTitle(data.title_display)
    data.highlight_text = highlight_text
    data.highlight_length = highlight_length
    local cover
    if not style.defaults.defer_cover then
        cover = self:_coverWidget(data, layout, style.defaults)
    end

    local context = {
        data = data,
        layout = layout,
        theme = theme,
        fonts = fonts,
        cover = cover,
        highlight_widgets = highlight_widgets,
        footer = self:_footer(data, layout, theme, fonts),
        translate = self.translate,
        scaled = scaled,
    }
    function context.coverFor(max_width, max_height)
        return self:_coverWidget(data, layout, style.defaults, max_width, max_height)
    end
    function context.spacer(amount)
        return VerticalSpan:new{ width = amount or scaled(8) }
    end
    function context.progress(width, height, percentage, options)
        options = options or {}
        options.background = options.background or theme.faint
        options.fill = options.fill or theme.foreground
        return progressWidget(width, height, percentage, options)
    end
    function context.center(width, height, widget)
        return CenterContainer:new{ dimen = Geom:new{ w = width, h = height }, widget }
    end
    function context.appendHighlights(children, spacing)
        if highlight_widgets then
            table.insert(children, context.spacer(spacing or scaled(14)))
            util.arrayAppend(children, highlight_widgets)
        end
    end
    function context.divider(width, dashed)
        if dashed then
            return TextWidget:new{
                text = string.rep("-", math.max(12, math.floor(width / math.max(scaled(8), 1)))),
                face = Font:getFace("cfont", fonts.small),
                fgcolor = theme.muted,
                padding = 0,
                align = "center",
            }
        end
        return progressWidget(width, scaled(1), 1, { background = theme.faint, fill = theme.muted })
    end
    function context.terminalBar(percentage, blocks)
        blocks = blocks or 12
        local filled = math.floor(percentage / 100 * blocks + 0.5)
        return string.format("[%s%s]", string.rep("█", filled), string.rep("░", blocks - filled))
    end
    return context
end

function Renderer:build(ui, state)
    local data = self.data_provider:collect(ui, state)
    if not data then return nil end
    local style = self:selectedStyle()
    local style_id = style.id
    local defaults = style.defaults
    local layout = self:_layout(defaults)
    local theme = self:_theme(defaults)
    -- User-adjustable size deltas apply to the style's three base tiers, so
    -- every text element in every style scales together while keeping each
    -- style's internal size relationships intact.
    local function tier(base, delta_key, floor)
        local delta = tonumber(G_reader_settings:readSetting(self.constants[delta_key])) or 0
        return layout.scaled(math.max(floor, base + delta))
    end
    local fonts = {
        big = tier(defaults.big or 25, "FONT_DELTA_BIG", 10),
        mid = tier(defaults.mid or 18, "FONT_DELTA_MID", 8),
        small = tier(defaults.small or 15, "FONT_DELTA_SMALL", 7),
    }
    if layout.compact then
        layout.padding_h = math.max(layout.scaled(10), math.floor(layout.padding_h * 0.82))
        layout.padding_v = math.max(layout.scaled(10), math.floor(layout.padding_v * 0.82))
        layout.content_width = layout.width - layout.padding_h * 2
    end

    local ctx = self:_context(data, style, layout, theme, fonts)
    local result = self.registry:render(style_id, ctx)
    local frame = result.frame or {}
    local content = result.body

    if result.common_footer ~= false and (data.message or ctx.footer) then
        local children = { content }
        if data.message then
            table.insert(children, ctx.spacer(layout.scaled(12)))
            table.insert(children, TextBoxWidget:new{
                face = Font:getFace("cfont", fonts.mid),
                text = data.message,
                width = layout.content_width,
                fgcolor = theme.foreground,
                bgcolor = theme.background,
                bold = true,
                alignment = "center",
            })
        end
        if ctx.footer then
            table.insert(children, ctx.spacer(layout.scaled(12)))
            table.insert(children, ctx.footer)
        end
        content = VerticalGroup:new(children)
    end

    local padding_top = frame.padding_top or layout.padding_v
    local padding_right = frame.padding_right or layout.padding_h
    local padding_bottom = frame.padding_bottom or layout.padding_v
    local padding_left = frame.padding_left or layout.padding_h
    local full_bleed = frame.full_bleed == true or layout.full_bleed
    if full_bleed then padding_top, padding_right, padding_bottom, padding_left = 0, 0, 0, 0 end
    local target_inner = math.max(content:getSize().h, layout.target_height - padding_top - padding_bottom)
    if not full_bleed and target_inner > content:getSize().h then
        content = CenterContainer:new{
            dimen = Geom:new{ w = layout.width - padding_left - padding_right, h = target_inner },
            content,
        }
    end

    local border = 0
    local border_setting = G_reader_settings:readSetting(self.constants.BORDER) or "none"
    if border_setting == "thin" then border = layout.scaled(1)
    elseif border_setting == "thick" then border = layout.scaled(2) end

    local radius = frame.radius or 0
    local final = FrameContainer:new{
        radius = radius,
        bordersize = border,
        padding_top = padding_top,
        padding_right = padding_right,
        padding_bottom = padding_bottom,
        padding_left = padding_left,
        background = frame.background or theme.background,
        content,
    }

    local shadow_allowed = result.shadow ~= false and not defaults.dark and not full_bleed
    if shadow_allowed and G_reader_settings:isTrue(self.constants.SHADOW) then
        local offset = layout.scaled(10)
        local size = final:getSize()
        local shadow = progressWidget(size.w, size.h, 1, {
            radius = radius,
            background = Blitbuffer.COLOR_GRAY_3,
            fill = Blitbuffer.COLOR_GRAY_3,
        })
        final = OverlapGroup:new{
            dimen = Geom:new{ w = size.w + offset, h = size.h + offset },
            CenterContainer:new{
                dimen = Geom:new{ w = size.w + offset, h = size.h + offset },
                VerticalGroup:new{
                    VerticalSpan:new{ width = offset },
                    HorizontalGroup:new{ HorizontalSpan:new{ width = offset }, shadow },
                },
            },
            CenterContainer:new{
                dimen = Geom:new{ w = size.w + offset, h = size.h + offset },
                VerticalGroup:new{
                    HorizontalGroup:new{ final, HorizontalSpan:new{ width = offset } },
                    VerticalSpan:new{ width = offset },
                },
            },
        }
    end
    return CenterContainer:new{ dimen = self.screen:getSize(), final }, style
end

return Renderer
