local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local ImageWidget = require("ui/widget/imagewidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local lfs = require("libs/libkoreader-lfs")
local T = require("ffi/util").template

local style_path = debug.getinfo(1, "S").source:sub(2)
local STYLE_DIR = style_path:match("(.*[/\\])") or ""
local INK_ASSET = STYLE_DIR .. "../assets/lan.png"
-- assets/lan.png is 1100x530.
local INK_RATIO = 530 / 1100

local Style = {
    interface_version = 1,
    id = "lan",
    label = "Orchid",
    defaults = {
        allow_cover = false,
        full_bleed = true,
        big = 21,
        mid = 15,
        small = 13,
        title_limit = 14,
    },
}

local function centered(width, widget)
    return CenterContainer:new{
        dimen = Geom:new{ w = width, h = widget:getSize().h },
        widget,
    }
end

function Style.render(ctx)
    local d, l, t, f, s, tr = ctx.data, ctx.layout, ctx.theme, ctx.fonts, ctx.scaled, ctx.translate
    local width = math.max(1, l.width)
    local height = math.max(s(360), l.target_height)
    local padding_h = s(18)
    local padding_v = s(16)
    local inner_width = math.max(1, width - padding_h * 2)
    local inner_height = math.max(1, height - padding_v * 2)

    local header_label = TextWidget:new{
        text = T(tr("EMPTY VALE · %1"), os.date("%m/%d")),
        face = Font:getFace("cfont", math.max(s(8), f.small - s(2))),
        fgcolor = t.muted,
        padding = 0,
    }
    local seal = FrameContainer:new{
        radius = s(3),
        bordersize = s(1),
        color = t.foreground,
        padding = s(5),
        background = t.background,
        TextWidget:new{
            text = "兰",
            face = Font:getFace("cfont", f.big - s(3)),
            fgcolor = t.foreground,
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

    local title = centered(inner_width, TextWidget:new{
        text = d.clean_title ~= "" and d.clean_title or "--",
        face = Font:getFace("cfont", f.big + s(4)),
        fgcolor = t.foreground,
        bold = true,
        padding = 0,
    })
    local author
    if d.author ~= "" then
        author = centered(inner_width, TextWidget:new{
            text = d.author,
            face = Font:getFace("cfont", f.small),
            fgcolor = t.muted,
            padding = 0,
        })
    end

    local ink
    local ink_height = 0
    if lfs.attributes(INK_ASSET, "mode") == "file" then
        local ink_width = math.floor(inner_width * 0.86)
        ink_height = math.floor(ink_width * INK_RATIO)
        ink = ImageWidget:new{
            file = INK_ASSET,
            width = ink_width,
            height = ink_height,
            alpha = true,
        }
    end

    local info_parts = {}
    if d.chapter ~= "" and d.chapter ~= d.title then table.insert(info_parts, d.chapter) end
    if d.show.percentage then table.insert(info_parts, string.format("%d%%", d.percentage)) end
    if d.book_time_left then table.insert(info_parts, d.book_time_left) end
    local info = centered(inner_width, TextWidget:new{
        text = table.concat(info_parts, " · "),
        face = Font:getFace("cfont", f.mid),
        fgcolor = t.foreground,
        padding = 0,
    })

    local poem = centered(inner_width, TextWidget:new{
        text = tr("A quiet orchid in the front court, holding fragrance for the clear wind."),
        face = Font:getFace("cfont", math.max(s(8), f.small - s(1))),
        fgcolor = t.faint,
        padding = 0,
    })

    local bottom_parts = {}
    if d.page_label ~= "" and d.pages_label ~= "" then
        table.insert(bottom_parts, string.format("%s / %s", d.page_label, d.pages_label))
    end
    if d.clock ~= "" then table.insert(bottom_parts, d.clock) end
    if d.battery_text ~= "" then table.insert(bottom_parts, d.battery_text) end
    local bottom = centered(inner_width, TextWidget:new{
        text = table.concat(bottom_parts, " · "),
        face = Font:getFace("cfont", f.small),
        fgcolor = t.muted,
        padding = 0,
    })

    local rule = ctx.progress(inner_width, s(1), 1, { background = t.faint, fill = t.faint })

    local fixed = header:getSize().h + title:getSize().h
        + (author and (s(6) + author:getSize().h) or 0)
        + (ink and (ink_height + s(12)) or 0)
        + rule:getSize().h + s(8) + info:getSize().h + s(8) + poem:getSize().h
        + s(8) + bottom:getSize().h
    local flexible = math.max(0, inner_height - fixed)
    local flex_top = math.max(s(16), math.floor(flexible * 0.42))
    local flex_middle = math.max(s(12), flexible - flex_top)

    local children = VerticalGroup:new{ align = "left" }
    table.insert(children, header)
    table.insert(children, VerticalSpan:new{ width = flex_top })
    table.insert(children, title)
    if author then
        table.insert(children, VerticalSpan:new{ width = s(6) })
        table.insert(children, author)
    end
    table.insert(children, VerticalSpan:new{ width = flex_middle })
    if ink then
        table.insert(children, ink)
        table.insert(children, VerticalSpan:new{ width = s(12) })
    end
    table.insert(children, rule)
    table.insert(children, VerticalSpan:new{ width = s(8) })
    table.insert(children, info)
    table.insert(children, VerticalSpan:new{ width = s(8) })
    table.insert(children, poem)
    table.insert(children, VerticalSpan:new{ width = s(8) })
    table.insert(children, bottom)

    local page = FrameContainer:new{
        radius = 0,
        bordersize = 0,
        padding_top = padding_v,
        padding_right = padding_h,
        padding_bottom = padding_v,
        padding_left = padding_h,
        background = t.background,
        children,
    }

    return {
        body = page,
        common_footer = false,
        shadow = false,
        frame = { full_bleed = true, background = t.background },
    }
end

return Style
