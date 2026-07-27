local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")

local Style = {
    interface_version = 1,
    id = "zen",
    label = "Japanese minimal",
    defaults = {
        big = 24,
        mid = 16,
        small = 13,
        padding_h = 26,
        padding_v = 26,
        title_limit = 24,
    },
}

function Style.render(ctx)
    local d, l, t, f, s, tr = ctx.data, ctx.layout, ctx.theme, ctx.fonts, ctx.scaled, ctx.translate
    local date = TextWidget:new{
        text = os.date("%m / %d"),
        face = Font:getFace("cfont", f.small + s(2)),
        fgcolor = t.muted,
        padding = 0,
    }
    local children = {
        HorizontalGroup:new{
            HorizontalSpan:new{ width = math.max(0, l.content_width - date:getSize().w) },
            date,
        },
        ctx.spacer(s(16)),
    }

    local circle = math.min(s(130), math.max(s(58), math.floor(l.content_width * 0.34)))
    local badge = CenterContainer:new{
        dimen = Geom:new{ w = circle, h = circle },
        FrameContainer:new{
            radius = math.floor(circle / 2),
            bordersize = 0,
            padding = 0,
            background = Blitbuffer.COLOR_BLACK,
            CenterContainer:new{
                dimen = Geom:new{ w = circle, h = circle },
                VerticalGroup:new{
                    TextWidget:new{
                        text = d.show.percentage and tostring(d.percentage) or tr("READ"),
                        face = Font:getFace("cfont", f.big + math.min(s(16), math.floor(circle * 0.12))),
                        fgcolor = Blitbuffer.COLOR_WHITE,
                        bold = true,
                        padding = 0,
                    },
                    TextWidget:new{
                        text = d.show.percentage and tr("PERCENT") or tr("READ"),
                        face = Font:getFace("cfont", math.max(s(8), f.small - s(3))),
                        fgcolor = Blitbuffer.COLOR_WHITE,
                        padding = 0,
                    },
                },
            },
        },
    }
    local gap = s(24)
    local title_width = math.max(s(60), l.content_width - circle - gap)
    local title_items = {
        TextBoxWidget:new{
            text = d.clean_title,
            face = Font:getFace("cfont", f.big + s(8)),
            width = title_width,
            fgcolor = t.foreground,
            bgcolor = t.background,
            bold = true,
        },
    }
    if d.author ~= "" then
        table.insert(title_items, ctx.spacer(s(8)))
        table.insert(title_items, TextBoxWidget:new{
            text = "—— " .. d.author,
            face = Font:getFace("cfont", f.small + s(2)),
            width = title_width,
            fgcolor = t.muted,
            bgcolor = t.background,
        })
    end
    local title_group = VerticalGroup:new(title_items)
    table.insert(children, HorizontalGroup:new{
        badge,
        HorizontalSpan:new{ width = gap },
        CenterContainer:new{
            dimen = Geom:new{ w = title_width, h = math.max(circle, title_group:getSize().h) },
            title_group,
        },
    })
    table.insert(children, ctx.spacer(s(24)))
    table.insert(children, ctx.progress(l.content_width, s(1), 1, { background = t.faint, fill = t.faint }))
    table.insert(children, ctx.spacer(s(20)))
    table.insert(children, TextWidget:new{
        text = d.chapter ~= "" and d.chapter or "--",
        face = Font:getFace("cfont", f.mid + s(4)),
        fgcolor = t.foreground,
        bold = true,
        padding = 0,
    })
    table.insert(children, ctx.spacer(s(10)))
    table.insert(children, TextWidget:new{
        text = string.format("%s  /  %s", d.page_label, d.pages_label),
        face = Font:getFace("cfont", f.mid),
        fgcolor = t.muted,
        padding = 0,
    })
    ctx.appendHighlights(children, s(14))
    table.insert(children, ctx.spacer(s(24)))
    table.insert(children, TextWidget:new{
        text = tr("Settle in and keep reading."),
        face = Font:getFace("cfont", f.small + s(2)),
        fgcolor = t.muted,
        padding = 0,
    })
    return { body = VerticalGroup:new(children) }
end

return Style
