local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local OverlapGroup = require("ui/widget/overlapgroup")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")

local Style = {
    interface_version = 1,
    id = "cover",
    label = "Cover first",
    defaults = {
        allow_cover = true,
        big = 22,
        mid = 17,
        small = 14,
        padding_h = 18,
        padding_v = 18,
        title_limit = 32,
    },
}

function Style.render(ctx)
    local d, l, t, f, s, tr = ctx.data, ctx.layout, ctx.theme, ctx.fonts, ctx.scaled, ctx.translate
    local children = {
        TextWidget:new{
            text = tr("NOW READING"),
            face = Font:getFace("cfont", f.small - s(2)),
            fgcolor = t.muted,
            padding = 0,
        },
        ctx.spacer(s(16)),
    }
    local cover = ctx.cover
    if not cover then
        local width = math.floor(l.content_width * 0.88)
        local height = math.floor(l.screen_height * 0.36)
        cover = OverlapGroup:new{
            dimen = Geom:new{ w = width, h = height },
            ctx.progress(width, height, 1, { background = Blitbuffer.COLOR_BLACK, fill = Blitbuffer.COLOR_BLACK, radius = s(4) }),
            CenterContainer:new{
                dimen = Geom:new{ w = width, h = height },
                TextBoxWidget:new{
                    text = d.clean_title,
                    face = Font:getFace("cfont", f.big),
                    width = width - s(32),
                    fgcolor = Blitbuffer.COLOR_WHITE,
                    bgcolor = Blitbuffer.COLOR_BLACK,
                    bold = true,
                    alignment = "center",
                },
            },
        }
    end
    table.insert(children, ctx.center(l.content_width, cover:getSize().h, cover))
    table.insert(children, ctx.spacer(s(24)))

    local pages = TextWidget:new{
        text = string.format("%s / %s", d.page_label, d.pages_label),
        face = Font:getFace("cfont", f.big + s(4)),
        fgcolor = t.foreground,
        bold = true,
        padding = 0,
    }
    local percent = TextWidget:new{
        text = d.show.percentage and string.format("%d%%", d.percentage) or "",
        face = Font:getFace("cfont", f.mid),
        fgcolor = t.muted,
        padding = 0,
    }
    table.insert(children, HorizontalGroup:new{
        pages,
        HorizontalSpan:new{ width = math.max(0, l.content_width - pages:getSize().w - percent:getSize().w) },
        percent,
    })
    if d.show.progress_bar then
        table.insert(children, ctx.spacer(s(10)))
        table.insert(children, ctx.progress(l.content_width, s(12), d.percentage / 100))
    end
    table.insert(children, ctx.spacer(s(14)))
    table.insert(children, TextWidget:new{
        text = d.chapter ~= "" and d.chapter or "--",
        face = Font:getFace("cfont", f.small + s(2)),
        fgcolor = t.muted,
        padding = 0,
    })
    ctx.appendHighlights(children, s(14))
    return { body = VerticalGroup:new(children), frame = { radius = s(4) } }
end

return Style
