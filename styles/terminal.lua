local Blitbuffer = require("ffi/blitbuffer")
local Font = require("ui/font")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")

local Style = {
    interface_version = 1,
    id = "terminal",
    label = "Terminal",
    defaults = {
        dark = true,
        big = 23,
        mid = 16,
        small = 13,
        padding_h = 16,
        padding_v = 16,
        title_limit = 34,
    },
}

function Style.render(ctx)
    local d, l, t, f, s, tr = ctx.data, ctx.layout, ctx.theme, ctx.fonts, ctx.scaled, ctx.translate
    local children = {
        TextWidget:new{
            text = tr("READING_FOLIO // SLEEP_MODE"),
            face = Font:getFace("cfont", f.small),
            fgcolor = Blitbuffer.COLOR_WHITE,
            bold = true,
            padding = 0,
        },
        ctx.spacer(s(28)),
    }
    if d.show.percentage then
        table.insert(children, TextWidget:new{
            text = string.format("%d%%", d.percentage),
            face = Font:getFace("cfont", f.big + s(22)),
            fgcolor = Blitbuffer.COLOR_WHITE,
            bold = true,
            padding = 0,
        })
        table.insert(children, ctx.spacer(s(24)))
    end
    if d.show.progress_bar then
        table.insert(children, TextWidget:new{
            text = ctx.terminalBar(d.percentage, l.compact and 12 or 16),
            face = Font:getFace("cfont", f.mid + s(4)),
            fgcolor = Blitbuffer.COLOR_WHITE,
            bold = true,
            padding = 0,
        })
        table.insert(children, ctx.spacer(s(32)))
    end
    if d.title_display ~= "" then
        table.insert(children, TextBoxWidget:new{
            text = string.format(tr("title: %s"), d.clean_title),
            face = Font:getFace("cfont", f.mid + s(2)),
            width = l.content_width,
            fgcolor = Blitbuffer.COLOR_WHITE,
            bgcolor = Blitbuffer.COLOR_BLACK,
        })
    end
    if d.author ~= "" then
        table.insert(children, ctx.spacer(s(8)))
        table.insert(children, TextBoxWidget:new{
            text = string.format(tr("author: %s"), d.author),
            face = Font:getFace("cfont", f.small + s(2)),
            width = l.content_width,
            fgcolor = Blitbuffer.COLOR_GRAY_9,
            bgcolor = Blitbuffer.COLOR_BLACK,
        })
    end
    if d.content_mode ~= "highlight_progress" and d.chapter ~= "" then
        table.insert(children, ctx.spacer(s(8)))
        table.insert(children, TextBoxWidget:new{
            text = string.format(tr("chapter: %s"), d.chapter),
            face = Font:getFace("cfont", f.small + s(2)),
            width = l.content_width,
            fgcolor = Blitbuffer.COLOR_GRAY_9,
            bgcolor = Blitbuffer.COLOR_BLACK,
        })
    else
        ctx.appendHighlights(children, s(16))
    end
    table.insert(children, ctx.spacer(s(40)))
    table.insert(children, TextWidget:new{
        text = string.format(tr("status: reading (%s / %s p)"), d.page_label, d.pages_label),
        face = Font:getFace("cfont", f.small + s(2)),
        fgcolor = Blitbuffer.COLOR_WHITE,
        padding = 0,
    })
    return {
        body = VerticalGroup:new(children),
        shadow = false,
        frame = { background = Blitbuffer.COLOR_BLACK },
    }
end

return Style
