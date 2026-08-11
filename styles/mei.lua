local Blitbuffer = require("ffi/blitbuffer")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local ImageWidget = require("ui/widget/imagewidget")
local OverlapGroup = require("ui/widget/overlapgroup")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local lfs = require("libs/libkoreader-lfs")
local T = require("ffi/util").template

local style_path = debug.getinfo(1, "S").source:sub(2)
local STYLE_DIR = style_path:match("(.*[/\\])") or ""
local INK_ASSET = STYLE_DIR .. "../assets/mei.png"
-- assets/mei.png is 1200x655; keep its aspect when scaling to card width.
local INK_RATIO = 655 / 1200

local Style = {
    interface_version = 1,
    id = "mei",
    label = "Plum blossom",
    defaults = {
        allow_cover = false,
        full_bleed = true,
        big = 22,
        mid = 16,
        small = 13,
        title_limit = 12,
    },
}

local CN_DIGITS = { "一", "二", "三", "四", "五", "六", "七", "八", "九", "十" }

local function utf8Chars(value)
    local chars = {}
    local index, length = 1, #value
    while index <= length do
        local byte = value:byte(index)
        local step = byte >= 0xF0 and 4 or (byte >= 0xE0 and 3 or (byte >= 0xC0 and 2 or 1))
        table.insert(chars, value:sub(index, index + step - 1))
        index = index + step
    end
    return chars
end

-- TextWidget is single-line (it ignores "\n"), so a vertical column must be
-- one TextWidget per character stacked in a VerticalGroup.
local function verticalColumn(value, face, color, bold, max_chars, spacing)
    local chars = utf8Chars(value)
    local count = #chars
    local truncated = max_chars and count > max_chars
    if truncated then count = max_chars - 1 end
    local column = VerticalGroup:new{}
    for index = 1, count do
        if index > 1 and spacing and spacing > 0 then
            table.insert(column, VerticalSpan:new{ width = spacing })
        end
        table.insert(column, TextWidget:new{
            text = chars[index],
            face = face,
            fgcolor = color,
            bold = bold,
            padding = 0,
        })
    end
    if truncated then
        table.insert(column, TextWidget:new{
            text = "…",
            face = face,
            fgcolor = color,
            bold = bold,
            padding = 0,
        })
    end
    return column
end

local function isCompactCjk(value, max_chars)
    if value == "" or value:find("[%z\1-\127]") then return false end
    return #utf8Chars(value) <= max_chars
end

function Style.render(ctx)
    local d, l, t, f, s, tr = ctx.data, ctx.layout, ctx.theme, ctx.fonts, ctx.scaled, ctx.translate
    local width = math.max(1, l.width)
    local height = math.max(s(360), l.target_height)
    local padding_h = s(16)
    local padding_v = s(14)
    local inner_width = math.max(1, width - padding_h * 2)
    local inner_height = math.max(1, height - padding_v * 2)

    local header_label = TextWidget:new{
        text = T(tr("COLD BOUGH · %1"), os.date("%m/%d")),
        face = Font:getFace("cfont", math.max(s(8), f.small - s(2))),
        fgcolor = t.muted,
        padding = 0,
    }
    local seal = FrameContainer:new{
        radius = s(3),
        bordersize = 0,
        padding = s(6),
        background = t.foreground,
        TextWidget:new{
            text = "梅",
            face = Font:getFace("cfont", f.big - s(2)),
            fgcolor = t.inverse_foreground,
            padding = 0,
        },
    }
    local header = HorizontalGroup:new{
        align = "top",
        header_label,
        HorizontalSpan:new{
            width = math.max(0, inner_width - header_label:getSize().w - seal:getSize().w),
        },
        seal,
    }

    -- Ink branch with the vertical title laid over its top-right whitespace.
    local image_height = math.floor(inner_width * INK_RATIO)
    local image_block
    if lfs.attributes(INK_ASSET, "mode") == "file" then
        local ink = ImageWidget:new{
            file = INK_ASSET,
            width = inner_width,
            height = image_height,
            alpha = true,
        }
        local title_column = verticalColumn(
            d.clean_title ~= "" and d.clean_title or "--",
            Font:getFace("cfont", f.big), t.foreground, true, 11, s(2))
        local title_block = HorizontalGroup:new{ align = "top" }
        -- Translated author strings ("[法] 安德烈·纪德") carry ASCII brackets
        -- and run long; only clean short CJK names read well vertically.
        local author_clean = d.author:gsub("%s+", "")
        if isCompactCjk(author_clean, 6) then
            table.insert(title_block, verticalColumn(author_clean,
                Font:getFace("cfont", f.small), t.muted, false, 6, s(2)))
            table.insert(title_block, HorizontalSpan:new{ width = s(8) })
        end
        table.insert(title_block, title_column)
        title_block.overlap_offset = {
            math.max(0, inner_width - title_block:getSize().w - s(6)),
            s(4),
        }
        image_block = OverlapGroup:new{
            dimen = Geom:new{ w = inner_width, h = image_height },
            ink,
            title_block,
        }
    else
        -- Asset missing: fall back to a plain horizontal title block.
        image_height = s(60)
        image_block = TextWidget:new{
            text = d.clean_title ~= "" and d.clean_title or "--",
            face = Font:getFace("cfont", f.big + s(4)),
            fgcolor = t.foreground,
            bold = true,
            padding = 0,
        }
    end

    local bloom_count = math.max(0, math.min(10, math.floor(d.percentage / 10 + 0.5)))
    local dot_total = 12
    local dot_filled = math.max(0, math.min(dot_total,
        math.floor(d.percentage / 100 * dot_total + 0.5)))
    local dots = TextWidget:new{
        text = string.rep("● ", dot_filled) .. string.rep("○ ", dot_total - dot_filled),
        face = Font:getFace("cfont", f.small),
        fgcolor = t.foreground,
        padding = 0,
    }

    local bloom_text
    if d.percentage < 5 then
        bloom_text = tr("Buds yet to open")
    else
        local number = tr:language() == "zh_CN"
            and CN_DIGITS[math.max(1, bloom_count)]
            or tostring(bloom_count)
        bloom_text = T(tr("Plum bloom: %1/10"), number)
    end
    local info_parts = {}
    -- The first TOC entry of many books is the book title itself; showing it
    -- again next to the vertical title reads as a duplicate.
    if d.chapter ~= "" and d.chapter ~= d.title then
        table.insert(info_parts, d.chapter)
    end
    table.insert(info_parts, bloom_text)
    local info_left = TextWidget:new{
        text = table.concat(info_parts, " · "),
        face = Font:getFace("cfont", f.mid),
        fgcolor = t.foreground,
        padding = 0,
    }
    local info_right = TextWidget:new{
        text = d.show.percentage and string.format("%d%%", d.percentage) or "",
        face = Font:getFace("cfont", f.mid),
        fgcolor = t.muted,
        padding = 0,
    }
    local info_row = HorizontalGroup:new{
        info_left,
        HorizontalSpan:new{
            width = math.max(0, inner_width - info_left:getSize().w - info_right:getSize().w),
        },
        info_right,
    }

    local poem = TextWidget:new{
        text = tr("Sparse shadows slant on shallow water; a hidden scent drifts in the dusk."),
        face = Font:getFace("cfont", math.max(s(8), f.small - s(1))),
        fgcolor = t.faint,
        padding = 0,
    }

    local pages_text = (d.page_label ~= "" and d.pages_label ~= "")
        and string.format("%s / %s", d.page_label, d.pages_label) or ""
    local bottom_left = TextWidget:new{
        text = pages_text,
        face = Font:getFace("cfont", f.small),
        fgcolor = t.muted,
        padding = 0,
    }
    local status_parts = {}
    if d.clock ~= "" then table.insert(status_parts, d.clock) end
    if d.battery_text ~= "" then table.insert(status_parts, d.battery_text) end
    local bottom_right = TextWidget:new{
        text = table.concat(status_parts, " · "),
        face = Font:getFace("cfont", f.small),
        fgcolor = t.muted,
        padding = 0,
    }
    if ctx.runtime and d.clock ~= "" then
        ctx.runtime.clock_widget = bottom_right
    end
    local bottom_row = HorizontalGroup:new{
        bottom_left,
        HorizontalSpan:new{
            width = math.max(0, inner_width - bottom_left:getSize().w - bottom_right:getSize().w),
        },
        bottom_right,
    }

    local rule = ctx.progress(inner_width, s(1), 1, { background = t.faint, fill = t.faint })

    local fixed_height = header:getSize().h + s(8) + image_height
        + dots:getSize().h + s(12) + rule:getSize().h + s(10) + info_row:getSize().h
        + poem:getSize().h + s(6) + bottom_row:getSize().h
    local flexible = math.max(0, inner_height - fixed_height)
    -- Split the slack around the ink painting and below the info row so the
    -- whitespace breathes like a scroll instead of pooling at the bottom.
    local flex_top = math.max(s(12), math.floor(flexible * 0.55))
    local flex_bottom = math.max(s(8), flexible - flex_top)

    local page = FrameContainer:new{
        radius = 0,
        bordersize = 0,
        padding_top = padding_v,
        padding_right = padding_h,
        padding_bottom = padding_v,
        padding_left = padding_h,
        background = t.background,
        VerticalGroup:new{
            align = "left",
            header,
            VerticalSpan:new{ width = s(8) },
            image_block,
            VerticalSpan:new{ width = flex_top },
            dots,
            VerticalSpan:new{ width = s(12) },
            rule,
            VerticalSpan:new{ width = s(10) },
            info_row,
            VerticalSpan:new{ width = flex_bottom },
            poem,
            VerticalSpan:new{ width = s(6) },
            bottom_row,
        },
    }

    return {
        body = page,
        common_footer = false,
        shadow = false,
        frame = { full_bleed = true, background = t.background },
    }
end

return Style
