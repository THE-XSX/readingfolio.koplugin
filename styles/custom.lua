local Blitbuffer = require("ffi/blitbuffer")
local CustomPositionContainer = require("ui/widget/container/custompositioncontainer")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local OverlapGroup = require("ui/widget/overlapgroup")
local TextBoxWidget = require("ui/widget/textboxwidget")
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local Style = {
    interface_version = 1,
    id = "custom",
    label = "Custom layout",
    defaults = {
        allow_cover = true,
        force_cover = true,
        default_ratio = 1,
        full_bleed = true,
        use_screen_orientation = true,
        big = 28,
        mid = 20,
        small = 16,
    },
}

local ITEM_COLORS = {
    black = Blitbuffer.COLOR_BLACK,
    gray = Blitbuffer.COLOR_GRAY,
    white = Blitbuffer.COLOR_WHITE,
}

local function itemColor(ctx, item)
    return ITEM_COLORS[item.color] or ctx.theme.foreground
end

local ffi = require("ffi")

local function rotateBB8(src_bb, angle)
    angle = (angle or 0) % 360
    if angle < 0 then angle = angle + 360 end
    if angle == 0 then return src_bb, false end

    local w, h = src_bb:getWidth(), src_bb:getHeight()
    local src_ptr = ffi.cast("uint8_t*", src_bb.data)

    if angle == 90 or angle == 180 or angle == 270 then
        local dst_w, dst_h = w, h
        if angle == 90 or angle == 270 then
            dst_w, dst_h = h, w
        end
        local dst_bb = Blitbuffer.new(dst_w, dst_h, Blitbuffer.TYPE_BB8)
        dst_bb:fill(Blitbuffer.COLOR_BLACK)
        local dst_ptr = ffi.cast("uint8_t*", dst_bb.data)
        if angle == 90 then
            for y = 0, h - 1 do
                local src_row = y * w
                for x = 0, w - 1 do
                    dst_ptr[x * h + (h - 1 - y)] = src_ptr[src_row + x]
                end
            end
        elseif angle == 180 then
            for y = 0, h - 1 do
                local src_row = y * w
                local dst_row = (h - 1 - y) * w
                for x = 0, w - 1 do
                    dst_ptr[dst_row + (w - 1 - x)] = src_ptr[src_row + x]
                end
            end
        elseif angle == 270 then
            for y = 0, h - 1 do
                local src_row = y * w
                for x = 0, w - 1 do
                    dst_ptr[(w - 1 - x) * h + y] = src_ptr[src_row + x]
                end
            end
        end
        return dst_bb, true
    else
        local rad = math.rad(angle)
        local cos_a = math.cos(rad)
        local sin_a = math.sin(rad)
        local new_w = math.max(1, math.ceil(math.abs(w * cos_a) + math.abs(h * sin_a)))
        local new_h = math.max(1, math.ceil(math.abs(w * sin_a) + math.abs(h * cos_a)))

        local dst_bb = Blitbuffer.new(new_w, new_h, Blitbuffer.TYPE_BB8)
        dst_bb:fill(Blitbuffer.COLOR_BLACK)
        local dst_ptr = ffi.cast("uint8_t*", dst_bb.data)

        local cx_src, cy_src = w / 2, h / 2
        local cx_dst, cy_dst = new_w / 2, new_h / 2

        for dy = 0, new_h - 1 do
            local y_rel = dy - cy_dst
            local dst_row = dy * new_w
            for dx = 0, new_w - 1 do
                local x_rel = dx - cx_dst
                local sx = math.floor(x_rel * cos_a + y_rel * sin_a + cx_src + 0.5)
                local sy = math.floor(-x_rel * sin_a + y_rel * cos_a + cy_src + 0.5)
                if sx >= 0 and sx < w and sy >= 0 and sy < h then
                    dst_ptr[dst_row + dx] = src_ptr[sy * w + sx]
                end
            end
        end
        return dst_bb, true
    end
end

local function transparentTextBox(options)
    local inner_options = {}
    for key, value in pairs(options) do inner_options[key] = value end
    inner_options.fgcolor = Blitbuffer.COLOR_BLACK
    inner_options.bgcolor = Blitbuffer.COLOR_WHITE
    local inner = TextBoxWidget:new(inner_options)
    local widget = WidgetContainer:new{}
    widget.dimen = inner:getSize()
    widget.text = options.text
    widget._inner = inner
    widget._fgcolor = options.fgcolor or Blitbuffer.COLOR_BLACK
    widget._rotation = options.rotation or 0

    function widget:getSize()
        return self.dimen
    end

    function widget:paintTo(bb, x, y)
        self.dimen.x, self.dimen.y = x, y
        local inner_size = self._inner:getSize()
        local width, height = inner_size.w, inner_size.h
        if not self._mask_bb
                or self._mask_bb:getWidth() ~= width or self._mask_bb:getHeight() ~= height then
            if self._mask_bb then self._mask_bb:free() end
            self._mask_bb = Blitbuffer.new(width, height, Blitbuffer.TYPE_BB8)
        end
        self._mask_bb:fill(Blitbuffer.COLOR_WHITE)
        self._inner:paintTo(self._mask_bb, 0, 0)
        self._mask_bb:invertRect(0, 0, width, height)

        local render_mask, is_owned = rotateBB8(self._mask_bb, self._rotation)
        local render_w, render_h = render_mask:getWidth(), render_mask:getHeight()
        self.dimen.w, self.dimen.h = render_w, render_h
        bb:colorblitFromRGB32(render_mask, x, y, 0, 0, render_w, render_h, self._fgcolor)
        if is_owned then
            render_mask:free()
        end
    end

    function widget:setText(text)
        if text == self.text then return end
        self.text = text
        self._inner:setText(text)
        local size = self._inner:getSize()
        self.dimen.w, self.dimen.h = size.w, size.h
    end

    function widget:free(full)
        if self._inner then
            self._inner:free(full)
            self._inner = nil
        end
        if self._mask_bb then
            self._mask_bb:free()
            self._mask_bb = nil
        end
    end

    function widget:onCloseWidget()
        self:free()
    end

    return widget
end

local function toVerticalText(text)
    if not text or text == "" then return "" end
    local lines = {}
    local norm = (text:gsub("\r\n", "\n"):gsub("\r", "\n"))
    for paragraph in (norm .. "\n"):gmatch("(.-)\n") do
        local chars = {}
        local len = #paragraph
        local i = 1
        while i <= len do
            local b = paragraph:byte(i)
            local char_len = (b >= 0xF0 and 4) or (b >= 0xE0 and 3) or (b >= 0xC0 and 2) or 1
            local char = paragraph:sub(i, i + char_len - 1)
            table.insert(chars, char)
            i = i + char_len
        end
        if #chars > 0 then
            table.insert(lines, table.concat(chars, "\n"))
        end
    end
    return table.concat(lines, "\n")
end

local function getTextContentWidth(face, text, max_width)
    if not text or text == "" or not face or not face.getSize then return max_width end
    local max_line_w = 0
    local norm = (text:gsub("\r\n", "\n"):gsub("\r", "\n"))
    for line in (norm .. "\n"):gmatch("(.-)\n") do
        if line ~= "" then
            local ok, size = pcall(function() return face:getSize(line) end)
            if ok and size and size.w then
                if size.w > max_line_w then max_line_w = size.w end
            end
        end
    end
    if max_line_w > 0 then
        return math.min(max_width, max_line_w + 6)
    end
    return max_width
end

local function textWidget(ctx, text, item, tier, width_ratio, bold)
    if not text or text == "" then return nil end
    local is_vertical = item.orient == "v"
    local font_size = math.max(7, math.floor(ctx.fonts[tier] * item.scale + 0.5))
    local display_text = is_vertical and toVerticalText(text) or text
    local face = Font:getFace("cfont", font_size)
    local width
    if is_vertical then
        local max_w = math.max(ctx.scaled(28), math.floor(font_size * 1.5))
        width = getTextContentWidth(face, display_text, max_w)
    else
        local max_w = math.floor(ctx.layout.screen_width * math.min(0.95, width_ratio * item.scale))
        width = getTextContentWidth(face, display_text, max_w)
    end
    return transparentTextBox{
        text = display_text,
        face = face,
        width = width,
        fgcolor = itemColor(ctx, item),
        bold = bold == true,
        alignment = "center",
        rotation = item.rotation or 0,
    }
end

local function itemWidget(ctx, id, item)
    local data = ctx.data.custom or {}
    if id == "cover" then
        return ctx.customCover(
            math.floor(ctx.layout.screen_width * 0.36 * item.scale),
            math.floor(ctx.layout.screen_height * 0.42 * item.scale))
    elseif id == "progress_bar" then
        return ctx.progress(
            math.floor(ctx.layout.screen_width * math.min(0.92, 0.65 * item.scale)),
            math.max(ctx.scaled(4), math.floor(ctx.scaled(9) * item.scale)),
            (data.percentage or 0) / 100,
            { radius = ctx.scaled(2) })
    elseif id == "title" then
        return textWidget(ctx, data.title, item, "big", 0.62, true)
    elseif id == "author" then
        return textWidget(ctx, data.author, item, "mid", 0.52)
    elseif id == "chapter" then
        return textWidget(ctx, data.chapter, item, "mid", 0.68)
    elseif id == "percentage" then
        return textWidget(ctx, data.percentage_text, item, "big", 0.18, true)
    elseif id == "highlights" then
        local highlight = data.highlight
        return textWidget(ctx, highlight and highlight.text, item, "mid", 0.72)
    elseif id == "page_number" then
        return textWidget(ctx, data.page_number, item, "small", 0.25)
    elseif id == "clock" then
        local widget = textWidget(ctx, data.clock, item, "mid", 0.22, true)
        if ctx.runtime then ctx.runtime.clock_widget = widget end
        return widget
    elseif id == "battery" then
        return textWidget(ctx, data.battery, item, "small", 0.20)
    end
    return textWidget(ctx, data[id], item, "small", 0.62)
end

function Style.render(ctx)
    local size = Geom:new{ w = ctx.layout.screen_width, h = ctx.layout.screen_height }
    local group = OverlapGroup:new{ dimen = size }
    local layout = ctx.custom_layout:get()
    for _, definition in ipairs(ctx.custom_layout:list()) do
        local item = layout.items[definition.id]
        if item.visible then
            local widget = itemWidget(ctx, definition.id, item)
            if widget then
                if ctx.editor_selected == definition.id then
                    widget = FrameContainer:new{
                        bordersize = 0,
                        inner_bordersize = ctx.scaled(2),
                        padding = 0,
                        color = ctx.theme.foreground,
                        widget,
                    }
                end
                table.insert(group, CustomPositionContainer:new{
                    dimen = size,
                    horizontal_position = item.x,
                    vertical_position = item.y,
                    widget = widget,
                    widget,
                })
            end
        end
    end
    return {
        body = group,
        common_footer = false,
        shadow = false,
        frame = { full_bleed = true, transparent = true, no_border = true },
    }
end

return Style
