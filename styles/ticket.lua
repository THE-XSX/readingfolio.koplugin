local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local ProgressWidget = require("ui/widget/progresswidget")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")

local Style = {
    interface_version = 1,
    id = "ticket",
    label = "Ticket stub",
    defaults = {
        big = 21,
        mid = 16,
        small = 13,
        padding_h = 14,
        padding_v = 14,
        title_limit = 32,
    },
}

local function barcode(width, height)
    local pattern = { 3, 1, 2, 1, 4, 1, 1, 2, 3, 1, 2, 1, 4, 1, 2, 1, 3, 1, 1, 2, 4, 1, 2, 1, 3 }
    local target = math.floor(width * 0.72)
    local units = 0
    for _, value in ipairs(pattern) do units = units + value end
    local unit = math.max(1, math.floor(target / units))
    local bars, black = {}, true
    for _, value in ipairs(pattern) do
        local bar_width = value * unit
        if black then
            table.insert(bars, ProgressWidget:new{
                width = bar_width,
                height = height,
                percentage = 1,
                margin_v = 0,
                margin_h = 0,
                radius = 0,
                bordersize = 0,
                bgcolor = Blitbuffer.COLOR_BLACK,
                fillcolor = Blitbuffer.COLOR_BLACK,
            })
        else
            table.insert(bars, HorizontalSpan:new{ width = bar_width })
        end
        black = not black
    end
    return CenterContainer:new{
        dimen = Geom:new{ w = width, h = height },
        HorizontalGroup:new(bars),
    }
end

function Style.render(ctx)
    local d, l, t, f, s, tr = ctx.data, ctx.layout, ctx.theme, ctx.fonts, ctx.scaled, ctx.translate
    local heading = TextWidget:new{
        text = tr("READING TICKET"),
        face = Font:getFace("cfont", f.small),
        fgcolor = t.muted,
        padding = 0,
    }
    local number = TextWidget:new{
        text = string.format(tr("NO. %04d"), math.max(0, d.page or 0)),
        face = Font:getFace("cfont", f.small),
        fgcolor = t.foreground,
        padding = 0,
    }
    local children = {
        HorizontalGroup:new{
            heading,
            HorizontalSpan:new{ width = math.max(0, l.content_width - heading:getSize().w - number:getSize().w) },
            number,
        },
        ctx.spacer(s(10)),
        ctx.divider(l.content_width, true),
        ctx.spacer(s(20)),
    }
    if d.show.percentage then
        local percent = TextWidget:new{
            text = string.format("%d%%", d.percentage),
            face = Font:getFace("cfont", f.big + s(16)),
            fgcolor = t.foreground,
            bold = true,
            padding = 0,
        }
        local admitted = TextWidget:new{
            text = tr("ADMITTED"),
            face = Font:getFace("cfont", f.small - s(2)),
            fgcolor = t.muted,
            padding = 0,
        }
        table.insert(children, HorizontalGroup:new{
            percent,
            HorizontalSpan:new{ width = math.max(0, l.content_width - percent:getSize().w - admitted:getSize().w) },
            admitted,
        })
        table.insert(children, ctx.spacer(s(20)))
    end
    table.insert(children, TextBoxWidget:new{
        text = d.clean_title,
        face = Font:getFace("cfont", f.big + s(4)),
        width = l.content_width,
        fgcolor = t.foreground,
        bgcolor = t.background,
        bold = true,
    })
    if d.author ~= "" then
        table.insert(children, ctx.spacer(s(4)))
        table.insert(children, TextWidget:new{
            text = d.author,
            face = Font:getFace("cfont", f.small + s(2)),
            fgcolor = t.muted,
            padding = 0,
        })
    end
    table.insert(children, ctx.spacer(s(24)))
    table.insert(children, ctx.progress(l.content_width, s(1), 1, { background = t.faint, fill = t.faint }))
    table.insert(children, ctx.spacer(s(20)))

    local page_label = TextWidget:new{ text = tr("PAGE"), face = Font:getFace("cfont", f.small), fgcolor = t.muted, padding = 0 }
    local page_value = TextWidget:new{
        text = string.format("%s  /  %s", d.page_label, d.pages_label),
        face = Font:getFace("cfont", f.mid + s(2)),
        fgcolor = t.foreground,
        padding = 0,
    }
    table.insert(children, HorizontalGroup:new{
        page_label,
        HorizontalSpan:new{ width = math.max(0, l.content_width - page_label:getSize().w - page_value:getSize().w) },
        page_value,
    })
    table.insert(children, ctx.spacer(s(14)))

    local today_label = TextWidget:new{ text = tr("TIME TODAY"), face = Font:getFace("cfont", f.small), fgcolor = t.muted, padding = 0 }
    local hours = math.floor((d.today_duration or 0) / 3600)
    local minutes = math.floor(((d.today_duration or 0) % 3600) / 60)
    local today_value = TextWidget:new{
        text = string.format("%02d:%02d", hours, minutes),
        face = Font:getFace("cfont", f.mid + s(2)),
        fgcolor = t.foreground,
        padding = 0,
    }
    table.insert(children, HorizontalGroup:new{
        today_label,
        HorizontalSpan:new{ width = math.max(0, l.content_width - today_label:getSize().w - today_value:getSize().w) },
        today_value,
    })
    ctx.appendHighlights(children, s(14))
    table.insert(children, ctx.spacer(s(20)))
    table.insert(children, barcode(l.content_width, s(26)))
    table.insert(children, ctx.spacer(s(16)))
    table.insert(children, TextWidget:new{
        text = tr("KEEP THIS TICKET FOR YOUR NEXT SESSION"),
        face = Font:getFace("cfont", f.small - s(2)),
        fgcolor = t.muted,
        padding = 0,
    })
    return { body = VerticalGroup:new(children), frame = { radius = 0 } }
end

return Style
