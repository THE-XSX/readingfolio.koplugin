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
    id = "swiss",
    label = "Swiss grid",
    defaults = {
        full_bleed = true,
        big = 25,
        mid = 18,
        small = 15,
        title_limit = 30,
    },
}

function Style.render(ctx)
    local d, l, t, f, s, tr = ctx.data, ctx.layout, ctx.theme, ctx.fonts, ctx.scaled, ctx.translate
    local left_width = math.max(s(92), math.floor(l.width * 0.33))
    local right_width = l.width - left_width
    local padding = l.ratio_mode == "fullscreen" and s(32) or s(20)
    local width = right_width - padding * 2
    local children = {}

    table.insert(children, TextWidget:new{
        text = string.format(tr("READING FOLIO / %s"), os.date("%Y.%m.%d")),
        face = Font:getFace("cfont", f.small - s(2)),
        fgcolor = t.muted,
        padding = 0,
    })
    table.insert(children, VerticalSpan:new{ width = s(10) })
    table.insert(children, ctx.progress(width, s(1), 1, { background = t.faint, fill = t.faint }))
    table.insert(children, VerticalSpan:new{ width = s(14) })

    local title = d.title_display
    if title ~= "" and not title:find("^《") then title = string.format(tr("《%s》"), title) end
    table.insert(children, TextBoxWidget:new{
        text = title,
        face = Font:getFace("cfont", f.big + s(4)),
        width = width,
        fgcolor = t.foreground,
        bgcolor = t.background,
        bold = true,
        alignment = "center",
    })
    if d.author ~= "" then
        table.insert(children, VerticalSpan:new{ width = s(4) })
        local author = TextWidget:new{
            text = d.author,
            face = Font:getFace("cfont", f.small),
            fgcolor = t.muted,
            padding = 0,
        }
        table.insert(children, CenterContainer:new{ dimen = Geom:new{ w = width, h = author:getSize().h }, author })
    end

    table.insert(children, VerticalSpan:new{ width = s(24) })
    table.insert(children, TextWidget:new{
        text = tr("CURRENT PAGE"),
        face = Font:getFace("cfont", f.small - s(2)),
        fgcolor = t.muted,
        padding = 0,
    })
    table.insert(children, VerticalSpan:new{ width = s(6) })
    table.insert(children, TextWidget:new{
        text = string.format("%s  /  %s", d.page_label, d.pages_label),
        face = Font:getFace("cfont", f.big + s(8)),
        fgcolor = t.foreground,
        bold = true,
        padding = 0,
    })
    if d.show.progress_bar then
        table.insert(children, VerticalSpan:new{ width = s(10) })
        table.insert(children, ctx.progress(width, s(12), d.percentage / 100))
    end

    table.insert(children, VerticalSpan:new{ width = s(20) })
    table.insert(children, ctx.progress(width, s(1), 1, { background = t.faint, fill = t.faint }))
    table.insert(children, VerticalSpan:new{ width = s(16) })
    table.insert(children, TextWidget:new{
        text = tr("CHAPTER"),
        face = Font:getFace("cfont", f.small - s(2)),
        fgcolor = t.muted,
        padding = 0,
    })
    table.insert(children, VerticalSpan:new{ width = s(6) })
    table.insert(children, TextBoxWidget:new{
        text = d.chapter ~= "" and d.chapter or "--",
        face = Font:getFace("cfont", f.mid + s(2)),
        width = width,
        fgcolor = t.foreground,
        bgcolor = t.background,
        bold = true,
    })

    if d.content_mode == "highlight_progress" and d.highlight_text then
        table.insert(children, VerticalSpan:new{ width = s(14) })
        table.insert(children, ctx.progress(width, s(1), 1, { background = t.faint, fill = t.faint }))
        table.insert(children, VerticalSpan:new{ width = s(14) })
        table.insert(children, TextBoxWidget:new{
            text = d.highlight_text,
            face = Font:getFace("cfont", f.mid),
            width = width,
            fgcolor = t.foreground,
            bgcolor = t.background,
            bold = true,
            alignment = "center",
        })
    end

    table.insert(children, VerticalSpan:new{ width = s(22) })
    local today = TextWidget:new{
        text = d.show.today_time
            and string.format(tr("TODAY %d MIN"), math.floor((d.today_duration or 0) / 60))
            or "",
        face = Font:getFace("cfont", f.small - s(2)),
        fgcolor = t.muted,
        padding = 0,
    }
    -- d.battery/d.clock arrive already emptied when their display toggles are
    -- off, so joining the non-empty ones honors the display-item settings.
    -- Built through a function so the minute refresh can rebuild the whole line:
    -- this one widget also carries the battery reading.
    local function statusText(now)
        local status_parts = {}
        if d.battery ~= "" then table.insert(status_parts, d.battery) end
        if d.clock ~= "" then table.insert(status_parts, now or d.clock) end
        return table.concat(status_parts, "  ")
    end
    local clock = TextWidget:new{
        text = statusText(),
        face = Font:getFace("cfont", f.small - s(2)),
        fgcolor = t.muted,
        padding = 0,
    }
    local status_row = HorizontalGroup:new{
        today,
        HorizontalSpan:new{ width = math.max(0, width - today:getSize().w - clock:getSize().w) },
        clock,
    }
    if d.clock ~= "" then
        status_row = ctx.registerClock(clock, statusText, status_row, width)
    end
    table.insert(children, status_row)

    local vertical_padding = l.ratio_mode == "fullscreen" and s(48) or s(20)
    local right = FrameContainer:new{
        radius = 0,
        bordersize = 0,
        padding_top = vertical_padding,
        padding_right = padding,
        padding_bottom = vertical_padding,
        padding_left = padding,
        background = t.background,
        VerticalGroup:new(children),
    }
    local height = math.max(right:getSize().h, l.target_height)
    local percent = d.show.percentage and string.format("%d%%", d.percentage) or tr("READ")
    local vertical = {}
    if percent:find("[\128-\255]") then
        table.insert(vertical, percent)
    else
        for i = 1, #percent do table.insert(vertical, percent:sub(i, i)) end
    end
    local left = OverlapGroup:new{
        dimen = Geom:new{ w = left_width, h = height },
        ctx.progress(left_width, height, 1, { background = Blitbuffer.COLOR_BLACK, fill = Blitbuffer.COLOR_BLACK }),
        VerticalGroup:new{
            VerticalSpan:new{ width = s(20) },
            ctx.center(left_width, s(20), TextWidget:new{
                text = tr("READ"),
                face = Font:getFace("cfont", f.small),
                fgcolor = Blitbuffer.COLOR_WHITE,
                bold = true,
                padding = 0,
            }),
            ctx.center(left_width, math.max(s(40), height - s(50)), TextWidget:new{
                text = table.concat(vertical, "\n"),
                face = Font:getFace("cfont", f.big - s(2)),
                fgcolor = Blitbuffer.COLOR_WHITE,
                bold = true,
                padding = 0,
            }),
        },
    }

    return {
        body = HorizontalGroup:new{ left, right },
        common_footer = false,
        shadow = false,
        frame = { full_bleed = true },
    }
end

return Style
