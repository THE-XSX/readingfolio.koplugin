local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local OverlapGroup = require("ui/widget/overlapgroup")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

local Style = {
    interface_version = 1,
    id = "gallery",
    label = "Gallery folio",
    defaults = {
        allow_cover = true,
        defer_cover = true,
        force_cover = true,
        dark = true,
        full_bleed = true,
        big = 23,
        mid = 16,
        small = 13,
        title_limit = 24,
    },
}

local function centeredText(width, height, text, face, color, bold)
    return CenterContainer:new{
        dimen = Geom:new{ w = width, h = height },
        TextBoxWidget:new{
            text = text,
            face = face,
            width = width,
            fgcolor = color,
            bgcolor = Blitbuffer.COLOR_BLACK,
            bold = bold,
            alignment = "center",
        },
    }
end

local function tick(column_width, tick_width, height, color, ctx)
    return CenterContainer:new{
        dimen = Geom:new{ w = column_width, h = height },
        ctx.progress(tick_width, math.max(1, height), 1, {
            background = color,
            fill = color,
        }),
    }
end

local function metricScale(ctx, width, height, foreground, muted)
    local s = ctx.scaled
    local line_height = s(1)
    local gap = math.max(0, math.floor((height - line_height * 3) / 2))
    local long_tick = math.min(width, s(18))
    local short_tick = math.min(width, s(12))
    return OverlapGroup:new{
        dimen = Geom:new{ w = width, h = height },
        CenterContainer:new{
            dimen = Geom:new{ w = width, h = height },
            ctx.progress(s(1), height, 1, { background = muted, fill = muted }),
        },
        VerticalGroup:new{
            tick(width, long_tick, line_height, foreground, ctx),
            VerticalSpan:new{ width = gap },
            tick(width, short_tick, line_height, foreground, ctx),
            VerticalSpan:new{ width = gap },
            tick(width, long_tick, line_height, foreground, ctx),
        },
    }
end

local function metricColumn(ctx, width, height, label, value, unit, footer)
    local f, s = ctx.fonts, ctx.scaled
    local label_height = math.floor(height * 0.18)
    local value_height = math.floor(height * 0.20)
    local unit_height = math.floor(height * 0.12)
    local scale_height = math.floor(height * 0.34)
    local footer_height = height - label_height - value_height - unit_height - scale_height
    local value_font_size = math.max(s(12), math.min(f.big + s(5), math.floor(width / 2.3)))

    return VerticalGroup:new{
        centeredText(width, label_height, label,
            Font:getFace("cfont", math.max(s(8), f.small - s(3))),
            Blitbuffer.COLOR_GRAY_9, false),
        centeredText(width, value_height, value,
            Font:getFace("cfont", value_font_size),
            Blitbuffer.COLOR_WHITE, true),
        centeredText(width, unit_height, unit,
            Font:getFace("cfont", math.max(s(8), f.small - s(3))),
            Blitbuffer.COLOR_GRAY_9, false),
        metricScale(ctx, width, scale_height, Blitbuffer.COLOR_WHITE, Blitbuffer.COLOR_GRAY_3),
        centeredText(width, footer_height, footer,
            Font:getFace("cfont", math.max(s(8), f.small - s(3))),
            Blitbuffer.COLOR_GRAY_9, false),
    }
end

local function durationValue(seconds)
    local total_minutes = math.max(0, math.floor((seconds or 0) / 60))
    return string.format("%d:%02d", math.floor(total_minutes / 60), total_minutes % 60)
end

local function coverWidget(ctx, width, height)
    local s = ctx.scaled
    local padding = s(4)
    local cover = ctx.coverFor(
        math.max(s(60), width - padding * 2 - s(2)),
        math.max(s(90), height - padding * 2 - s(2))
    )
    if cover then
        return FrameContainer:new{
            radius = 0,
            bordersize = s(1),
            padding = padding,
            background = Blitbuffer.COLOR_WHITE,
            color = Blitbuffer.COLOR_WHITE,
            cover,
        }
    end

    return FrameContainer:new{
        radius = 0,
        bordersize = s(1),
        padding = padding,
        background = Blitbuffer.COLOR_WHITE,
        color = Blitbuffer.COLOR_WHITE,
        CenterContainer:new{
            dimen = Geom:new{
                w = math.max(s(60), width - padding * 2 - s(2)),
                h = math.max(s(90), height - padding * 2 - s(2)),
            },
            TextBoxWidget:new{
                text = ctx.data.clean_title ~= "" and ctx.data.clean_title or "--",
                face = Font:getFace("cfont", ctx.fonts.big),
                width = math.max(s(40), width - padding * 4),
                fgcolor = Blitbuffer.COLOR_BLACK,
                bgcolor = Blitbuffer.COLOR_WHITE,
                bold = true,
                alignment = "center",
            },
        },
    }
end

function Style.render(ctx)
    local d, l, f, s, tr = ctx.data, ctx.layout, ctx.fonts, ctx.scaled, ctx.translate
    local border = s(1)
    local padding = l.ratio_mode == "fullscreen" and s(14) or s(10)
    local inner_width = math.max(s(220), l.width - (padding + border) * 2)
    local inner_height = math.max(s(320), l.target_height - (padding + border) * 2)
    local top_height = math.floor(inner_height * 0.18)
    local bottom_height = math.floor(inner_height * 0.18)
    local middle_height = inner_height - top_height - bottom_height

    local gap = s(7)
    local maximum_side = math.floor((inner_width - s(120) - gap * 2) / 2)
    local side_width = math.max(s(54), math.min(math.floor(inner_width * 0.17), maximum_side))
    local center_width = inner_width - side_width * 2 - gap * 2
    local metric_height = math.max(s(1), middle_height - s(8))

    local header = VerticalGroup:new{
        centeredText(inner_width, math.floor(top_height * 0.32),
            string.format(tr("CURRENTLY READING · %03d"), math.max(0, d.page or 0)),
            Font:getFace("cfont", math.max(s(8), f.small - s(3))),
            Blitbuffer.COLOR_GRAY_9, false),
        centeredText(inner_width, math.floor(top_height * 0.48),
            d.clean_title ~= "" and d.clean_title or "--",
            Font:getFace("cfont", f.big + s(5)),
            Blitbuffer.COLOR_WHITE, true),
        CenterContainer:new{
            dimen = Geom:new{ w = inner_width, h = top_height - math.floor(top_height * 0.80) },
            ctx.progress(math.floor(inner_width * 0.28), s(1), 1, {
                background = Blitbuffer.COLOR_GRAY_9,
                fill = Blitbuffer.COLOR_GRAY_9,
            }),
        },
    }

    local left_value = d.show.total_time and durationValue(d.total_duration) or "--:--"
    local right_value = d.show.percentage and string.format("%d%%", d.percentage) or "--"
    local page_value = d.page_label ~= "" and d.pages_label ~= ""
        and string.format("%s / %s", d.page_label, d.pages_label)
        or tr("PROGRESS")
    local middle = HorizontalGroup:new{
        CenterContainer:new{
            dimen = Geom:new{ w = side_width, h = middle_height },
            metricColumn(ctx, side_width, metric_height,
                tr("READING TIME"), left_value, tr("HRS · MIN"), tr("TOTAL")),
        },
        HorizontalSpan:new{ width = gap },
        CenterContainer:new{
            dimen = Geom:new{ w = center_width, h = middle_height },
            coverWidget(ctx, center_width - s(4), middle_height - s(4)),
        },
        HorizontalSpan:new{ width = gap },
        CenterContainer:new{
            dimen = Geom:new{ w = side_width, h = middle_height },
            metricColumn(ctx, side_width, metric_height,
                tr("BOOK PROGRESS"), right_value, tr("COMPLETE"), page_value),
        },
    }

    local bottom_items = {}
    if d.author ~= "" then
        table.insert(bottom_items, TextBoxWidget:new{
            text = d.author,
            face = Font:getFace("cfont", f.mid + s(1)),
            width = inner_width,
            fgcolor = Blitbuffer.COLOR_WHITE,
            bgcolor = Blitbuffer.COLOR_BLACK,
            alignment = "center",
        })
        table.insert(bottom_items, VerticalSpan:new{ width = s(5) })
    end
    table.insert(bottom_items, TextBoxWidget:new{
        text = d.chapter ~= "" and d.chapter or page_value,
        face = Font:getFace("cfont", f.small),
        width = inner_width,
        fgcolor = Blitbuffer.COLOR_GRAY_9,
        bgcolor = Blitbuffer.COLOR_BLACK,
        alignment = "center",
    })
    table.insert(bottom_items, VerticalSpan:new{ width = s(8) })
    table.insert(bottom_items, TextWidget:new{
        text = os.date("%d · %m · %Y"),
        face = Font:getFace("cfont", math.max(s(8), f.small - s(3))),
        fgcolor = Blitbuffer.COLOR_GRAY_9,
        padding = 0,
    })
    local footer = CenterContainer:new{
        dimen = Geom:new{ w = inner_width, h = bottom_height },
        VerticalGroup:new(bottom_items),
    }

    return {
        body = FrameContainer:new{
            radius = 0,
            bordersize = border,
            padding = padding,
            background = Blitbuffer.COLOR_BLACK,
            color = Blitbuffer.COLOR_GRAY_9,
            VerticalGroup:new{ header, middle, footer },
        },
        common_footer = false,
        shadow = false,
        frame = { full_bleed = true, background = Blitbuffer.COLOR_BLACK },
    }
end

return Style
