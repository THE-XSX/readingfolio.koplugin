local Font = require("ui/font")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")

local Style = {
    interface_version = 1,
    id = "quote",
    label = "Quote poster",
    defaults = {
        big = 27,
        mid = 17,
        small = 14,
        padding_h = 22,
        padding_v = 22,
        title_limit = 28,
        highlight_lines = 8,
    },
}

function Style.render(ctx)
    local d, l, t, f, s, tr = ctx.data, ctx.layout, ctx.theme, ctx.fonts, ctx.scaled, ctx.translate
    local quote = d.highlight_text or tr("The path that is truly yours\nis rarely the busiest one.")
    local children = {
        TextWidget:new{
            text = "“",
            face = Font:getFace("cfont", f.big + s(32)),
            fgcolor = t.foreground,
            bold = true,
            padding = 0,
        },
        ctx.spacer(s(16)),
        TextBoxWidget:new{
            text = quote,
            face = Font:getFace("cfont", f.big + s(4)),
            width = l.content_width,
            fgcolor = t.foreground,
            bgcolor = t.background,
            bold = true,
            alignment = "left",
        },
        ctx.spacer(s(24)),
        ctx.progress(l.content_width, s(2), 1),
        ctx.spacer(s(16)),
    }
    local citation = string.format(tr("《%s》"), d.clean_title)
    if d.chapter ~= "" then citation = citation .. "  ·  " .. d.chapter end
    table.insert(children, TextWidget:new{
        text = citation,
        face = Font:getFace("cfont", f.small + s(2)),
        fgcolor = t.muted,
        padding = 0,
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
    table.insert(children, ctx.spacer(s(36)))
    table.insert(children, TextWidget:new{
        text = string.format("%s  /  %s", d.page_label, d.pages_label),
        face = Font:getFace("cfont", f.mid + s(2)),
        fgcolor = t.foreground,
        padding = 0,
    })
    if d.show.progress_bar then
        table.insert(children, ctx.spacer(s(10)))
        table.insert(children, ctx.progress(l.content_width, s(12), d.percentage / 100))
    end
    return { body = VerticalGroup:new(children), frame = { radius = 0 } }
end

return Style
