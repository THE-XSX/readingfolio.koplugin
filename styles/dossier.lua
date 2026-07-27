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
local VerticalSpan = require("ui/widget/verticalspan")

local Style = {
    interface_version = 1,
    id = "dossier",
    label = "Reading dossier",
    defaults = {
        allow_cover = false,
        full_bleed = true,
        big = 24,
        mid = 16,
        small = 13,
        title_limit = 28,
    },
}

local PAGE_BACKGROUND = Blitbuffer.COLOR_GRAY_E
local FOREGROUND = Blitbuffer.COLOR_BLACK
local MUTED = Blitbuffer.COLOR_GRAY_9

local function detailRow(ctx, width, label, value)
    local s, f = ctx.scaled, ctx.fonts
    local label_width = math.floor(width * 0.36)
    local gap = s(8)
    local value_width = width - label_width - gap
    local label_widget = TextBoxWidget:new{
        text = label,
        face = Font:getFace("cfont", f.mid),
        width = label_width,
        fgcolor = MUTED,
        bgcolor = PAGE_BACKGROUND,
        alignment = "left",
    }
    local value_widget = TextBoxWidget:new{
        text = value,
        face = Font:getFace("cfont", f.mid),
        width = value_width,
        fgcolor = FOREGROUND,
        bgcolor = PAGE_BACKGROUND,
        bold = true,
        alignment = "left",
    }
    -- Size each row to its content: a fixed row height clipped tall CJK
    -- glyphs and wrapped values such as long chapter names.
    local row_height = math.max(label_widget:getSize().h, value_widget:getSize().h)
    return HorizontalGroup:new{
        CenterContainer:new{ dimen = Geom:new{ w = label_width, h = row_height }, label_widget },
        HorizontalSpan:new{ width = gap },
        CenterContainer:new{ dimen = Geom:new{ w = value_width, h = row_height }, value_widget },
    }
end

local function compactDuration(seconds, translate)
    local total_minutes = math.max(0, math.floor((seconds or 0) / 60))
    local hours = math.floor(total_minutes / 60)
    local minutes = total_minutes % 60
    local parts = {}
    if hours > 0 then
        table.insert(parts, string.format("%d %s", hours,
            hours == 1 and translate("hr") or translate("hrs")))
    end
    if minutes > 0 or hours == 0 then
        table.insert(parts, string.format("%d %s", minutes,
            minutes == 1 and translate("min") or translate("mins")))
    end
    return table.concat(parts, " ")
end

function Style.render(ctx)
    local d, l, f, s, tr = ctx.data, ctx.layout, ctx.fonts, ctx.scaled, ctx.translate
    local height = math.max(s(360), l.target_height)
    local spine_width = math.max(s(48), math.floor(l.width * 0.155))
    local page_width = l.width - spine_width
    local padding_h = l.ratio_mode == "fullscreen" and s(24) or s(18)
    local padding_v = l.ratio_mode == "fullscreen" and s(26) or s(20)
    local inner_width = math.max(s(150), page_width - padding_h * 2)
    local inner_height = math.max(s(260), height - padding_v * 2)

    local index = TextWidget:new{
        text = "02",
        face = Font:getFace("cfont", math.max(s(8), f.small - s(3))),
        fgcolor = Blitbuffer.COLOR_GRAY_9,
        padding = 0,
    }
    local heading = TextWidget:new{
        text = tr("READING DOSSIER"),
        face = Font:getFace("cfont", f.small),
        fgcolor = FOREGROUND,
        padding = 0,
    }
    local date = TextWidget:new{
        text = os.date("%Y.%m.%d"),
        face = Font:getFace("cfont", f.small),
        fgcolor = FOREGROUND,
        padding = 0,
    }
    local header_gap = s(12)
    local header = HorizontalGroup:new{
        index,
        HorizontalSpan:new{ width = header_gap },
        heading,
        HorizontalSpan:new{
            width = math.max(0, inner_width - index:getSize().w - heading:getSize().w
                - date:getSize().w - header_gap),
        },
        date,
    }

    local top_items = {
        header,
        VerticalSpan:new{ width = s(18) },
        ctx.progress(inner_width, s(1), 1, { background = MUTED, fill = MUTED }),
        VerticalSpan:new{ width = s(22) },
        TextBoxWidget:new{
            text = d.clean_title ~= "" and d.clean_title or "--",
            face = Font:getFace("cfont", f.big + s(6)),
            width = inner_width,
            fgcolor = FOREGROUND,
            bgcolor = PAGE_BACKGROUND,
            bold = true,
            alignment = "left",
        },
    }
    if d.author ~= "" then
        table.insert(top_items, VerticalSpan:new{ width = s(5) })
        table.insert(top_items, TextBoxWidget:new{
            text = d.author,
            face = Font:getFace("cfont", f.mid),
            width = inner_width,
            fgcolor = MUTED,
            bgcolor = PAGE_BACKGROUND,
            alignment = "left",
        })
    end
    table.insert(top_items, VerticalSpan:new{ width = s(20) })
    table.insert(top_items, ctx.progress(inner_width, s(1), 1, {
        background = MUTED,
        fill = MUTED,
    }))
    table.insert(top_items, VerticalSpan:new{ width = s(16) })

    local page_value = d.page_label ~= "" and d.pages_label ~= ""
        and string.format("%s / %s", d.page_label, d.pages_label)
        or "--"
    local rows = {
        { tr("Current chapter"), d.chapter ~= "" and d.chapter or "--" },
        { tr("Reading page"), page_value },
        { tr("Reading today"), d.show.today_time and compactDuration(d.today_duration, tr) or "--" },
        { tr("Estimated remaining"), d.book_time_left or "--" },
        { tr("Total reading"), d.show.total_time and compactDuration(d.total_duration, tr) or "--" },
        { tr("Power"), d.battery_text },
    }
    for i, row in ipairs(rows) do
        if i > 1 then
            table.insert(top_items, VerticalSpan:new{ width = s(7) })
        end
        table.insert(top_items, detailRow(ctx, inner_width, row[1], row[2]))
    end
    local top = VerticalGroup:new(top_items)

    local stamp_text = d.show.percentage
        and string.format(tr("IN READING · %d%%"), d.percentage)
        or tr("IN READING")
    local stamp_label = TextWidget:new{
        text = stamp_text,
        face = Font:getFace("cfont", f.small + s(1)),
        fgcolor = FOREGROUND,
        bold = true,
        padding = 0,
    }
    local stamp = FrameContainer:new{
        radius = 0,
        bordersize = s(2),
        padding_top = s(8),
        padding_right = s(10),
        padding_bottom = s(8),
        padding_left = s(10),
        background = PAGE_BACKGROUND,
        color = FOREGROUND,
        stamp_label,
    }
    local stamp_row = HorizontalGroup:new{
        HorizontalSpan:new{ width = math.max(0, inner_width - stamp:getSize().w) },
        stamp,
    }
    local flexible_space = math.max(0, inner_height - top:getSize().h - stamp_row:getSize().h)
    local page = FrameContainer:new{
        radius = 0,
        bordersize = 0,
        padding_top = padding_v,
        padding_right = padding_h,
        padding_bottom = padding_v,
        padding_left = padding_h,
        background = PAGE_BACKGROUND,
        VerticalGroup:new{
            top,
            VerticalSpan:new{ width = flexible_space },
            stamp_row,
        },
    }

    return {
        body = HorizontalGroup:new{
            ctx.progress(spine_width, height, 1, {
                background = Blitbuffer.COLOR_BLACK,
                fill = Blitbuffer.COLOR_BLACK,
            }),
            page,
        },
        common_footer = false,
        shadow = false,
        frame = { full_bleed = true, background = PAGE_BACKGROUND },
    }
end

return Style
