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
    id = "archive",
    label = "Library archive",
    defaults = {
        allow_cover = false,
        full_bleed = true,
        landscape = true,
        aspect_ratio = 2.05,
        default_ratio = 0.92,
        big = 23,
        mid = 16,
        small = 13,
        title_limit = 26,
        highlight_lines = 3,
    },
}

local PAPER = Blitbuffer.COLOR_GRAY_E
local INK = Blitbuffer.COLOR_BLACK
local MUTED = Blitbuffer.COLOR_GRAY_9
local PALE = Blitbuffer.COLOR_GRAY_D

local function textBlock(width, height, text, face, color, bold, alignment)
    return CenterContainer:new{
        dimen = Geom:new{ w = width, h = height },
        TextBoxWidget:new{
            text = text,
            face = face,
            width = width,
            fgcolor = color,
            bgcolor = PAPER,
            bold = bold,
            alignment = alignment or "left",
        },
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

local function archiveDate()
    local roman_months = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII" }
    local now = os.date("*t")
    return string.format("%02d · %s · %04d", now.day, roman_months[now.month], now.year)
end

local function perforationRow(ctx, width, height)
    local s = ctx.scaled
    local count = math.max(8, math.floor(width / math.max(s(8), 1)))
    return CenterContainer:new{
        dimen = Geom:new{ w = width, h = height },
        TextWidget:new{
            text = string.rep("○", count),
            face = Font:getFace("cfont", math.max(s(7), ctx.fonts.small - s(4))),
            fgcolor = PALE,
            padding = 0,
        },
    }
end

local function perforationColumn(ctx, width, height)
    local s = ctx.scaled
    local count = math.max(5, math.floor(height / math.max(s(9), 1)))
    return CenterContainer:new{
        dimen = Geom:new{ w = width, h = height },
        TextBoxWidget:new{
            text = string.rep("○\n", count - 1) .. "○",
            face = Font:getFace("cfont", math.max(s(7), ctx.fonts.small - s(4))),
            width = width,
            fgcolor = PALE,
            bgcolor = Blitbuffer.COLOR_WHITE,
            alignment = "center",
        },
    }
end

local function readingRate(ctx, width, height)
    local d, f, s, tr = ctx.data, ctx.fonts, ctx.scaled, ctx.translate
    local border = s(1)
    local padding = s(8)
    local inner_width = math.max(1, width - (border + padding) * 2)
    local inner_height = math.max(1, height - (border + padding) * 2)
    local label_height = math.floor(inner_height * 0.20)
    local value_height = math.floor(inner_height * 0.55)
    local mark_height = inner_height - label_height - value_height
    local value = d.show.percentage and tostring(d.percentage) or "--"
    local number = TextWidget:new{
        text = value,
        face = Font:getFace("cfont", f.big + s(18)),
        fgcolor = INK,
        bold = true,
        padding = 0,
    }
    local percent = TextWidget:new{
        text = d.show.percentage and "%" or "",
        face = Font:getFace("cfont", f.mid + s(2)),
        fgcolor = INK,
        padding = 0,
    }
    return FrameContainer:new{
        radius = 0,
        bordersize = border,
        padding = padding,
        background = PAPER,
        color = INK,
        VerticalGroup:new{
            textBlock(inner_width, label_height, tr("READING RATE"),
                Font:getFace("cfont", math.max(s(8), f.small - s(2))), MUTED, false, "center"),
            CenterContainer:new{
                dimen = Geom:new{ w = inner_width, h = value_height },
                HorizontalGroup:new{
                    number,
                    VerticalGroup:new{
                        VerticalSpan:new{ width = math.floor(number:getSize().h * 0.42) },
                        percent,
                    },
                },
            },
            textBlock(inner_width, mark_height, "⌄",
                Font:getFace("cfont", f.big + s(7)), INK, false, "center"),
        },
    }
end

local function volumeColumn(ctx, width, height)
    local d, f, s, tr = ctx.data, ctx.fonts, ctx.scaled, ctx.translate
    local padding = s(14)
    local inner_width = math.max(1, width - padding * 2)
    local quote = d.highlight_text or tr("A quiet page is a room of one's own.")
    local title = d.clean_title ~= "" and string.format(tr("《%s》"), d.clean_title) or "--"
    local items = {
        TextWidget:new{
            text = tr("CURRENT VOLUME"),
            face = Font:getFace("cfont", math.max(s(8), f.small - s(2))),
            fgcolor = MUTED,
            padding = 0,
        },
        VerticalSpan:new{ width = s(10) },
        TextBoxWidget:new{
            text = title,
            face = Font:getFace("cfont", f.big + s(5)),
            width = inner_width,
            fgcolor = INK,
            bgcolor = PAPER,
            bold = true,
            alignment = "left",
        },
    }
    if d.author ~= "" then
        table.insert(items, VerticalSpan:new{ width = s(5) })
        table.insert(items, TextBoxWidget:new{
            text = d.author,
            face = Font:getFace("cfont", f.small),
            width = inner_width,
            fgcolor = MUTED,
            bgcolor = PAPER,
            alignment = "left",
        })
    end
    table.insert(items, VerticalSpan:new{ width = s(12) })
    table.insert(items, ctx.progress(inner_width, s(1), 1, { background = PALE, fill = PALE }))
    table.insert(items, VerticalSpan:new{ width = s(10) })
    table.insert(items, TextBoxWidget:new{
        text = tr("CURRENT CHAPTER") .. "  " .. (d.chapter ~= "" and d.chapter or "--"),
        face = Font:getFace("cfont", math.max(s(8), f.small - s(1))),
        width = inner_width,
        fgcolor = MUTED,
        bgcolor = PAPER,
        alignment = "left",
    })
    table.insert(items, VerticalSpan:new{ width = s(7) })
    table.insert(items, TextBoxWidget:new{
        text = quote,
        face = Font:getFace("cfont", f.mid + s(1)),
        width = inner_width,
        fgcolor = INK,
        bgcolor = PAPER,
        bold = true,
        alignment = "left",
    })
    return CenterContainer:new{
        dimen = Geom:new{ w = width, h = height },
        VerticalGroup:new(items),
    }
end

local function pageSeal(ctx, width, height)
    local d, f, s, tr = ctx.data, ctx.fonts, ctx.scaled, ctx.translate
    local size = math.max(1, math.min(width - s(12), height - s(12)))
    local outer_border = s(2)
    local outer_padding = s(6)
    local inner_border = s(1)
    local content_size = math.max(1, size - (outer_border + outer_padding + inner_border) * 2)
    local content = VerticalGroup:new{
        textBlock(content_size, math.floor(content_size * 0.18), "★",
            Font:getFace("cfont", f.big + s(2)), INK, true, "center"),
        textBlock(content_size, math.floor(content_size * 0.34),
            d.page_label ~= "" and d.page_label or "--",
            Font:getFace("cfont", f.big + s(14)), INK, false, "center"),
        textBlock(content_size, math.floor(content_size * 0.18),
            string.format(tr("OF %s PAGES"), d.pages_label ~= "" and d.pages_label or "--"),
            Font:getFace("cfont", math.max(s(8), f.small - s(3))), MUTED, false, "center"),
        textBlock(content_size, math.floor(content_size * 0.20),
            string.format(tr("TODAY · %s"),
                d.show.today_time and compactDuration(d.today_duration, tr) or "--"),
            Font:getFace("cfont", math.max(s(8), f.small - s(2))), INK, true, "center"),
    }
    local inner = FrameContainer:new{
        radius = math.floor((content_size + inner_border * 2) / 2),
        bordersize = inner_border,
        padding = 0,
        background = PAPER,
        color = MUTED,
        CenterContainer:new{
            dimen = Geom:new{ w = content_size, h = content_size },
            content,
        },
    }
    local seal = FrameContainer:new{
        radius = math.floor(size / 2),
        bordersize = outer_border,
        padding = outer_padding,
        background = PAPER,
        color = INK,
        inner,
    }
    return CenterContainer:new{ dimen = Geom:new{ w = width, h = height }, seal }
end

function Style.render(ctx)
    local d, l, f, s, tr = ctx.data, ctx.layout, ctx.fonts, ctx.scaled, ctx.translate
    local width = math.max(1, l.width)
    local height = math.max(1, l.target_height)
    local perforation = s(9)
    local sheet_width = width - perforation * 2
    local sheet_height = height - perforation * 2
    local border = s(2)
    local padding = s(9)
    local inner_width = sheet_width - (border + padding) * 2
    local inner_height = sheet_height - (border + padding) * 2
    local header_height = math.floor(inner_height * 0.16)
    local footer_height = math.floor(inner_height * 0.14)
    local main_height = inner_height - header_height - footer_height

    local third = math.floor(inner_width / 3)
    local archive_number = string.format("%s · %s",
        string.format(tr("NO. %04d"), math.max(0, d.page or 0)), tr("READING ARCHIVE"))
    local rule_height = s(1)
    local rule_gap = s(4)
    local rule_block_height = rule_height * 2 + rule_gap
    local header_row = HorizontalGroup:new{
        textBlock(third, math.max(1, header_height - rule_block_height), archive_number,
            Font:getFace("cfont", math.max(s(8), f.small - s(2))), MUTED, false, "left"),
        textBlock(third, math.max(1, header_height - rule_block_height), tr("BIBLIOTHECA"),
            Font:getFace("cfont", f.mid + s(2)), INK, true, "center"),
        textBlock(inner_width - third * 2, math.max(1, header_height - rule_block_height), archiveDate(),
            Font:getFace("cfont", math.max(s(8), f.small - s(2))), MUTED, false, "right"),
    }
    local header = VerticalGroup:new{
        header_row,
        ctx.progress(inner_width, rule_height, 1, { background = PALE, fill = PALE }),
        VerticalSpan:new{ width = rule_gap },
        ctx.progress(inner_width, rule_height, 1, { background = PALE, fill = PALE }),
    }

    local separator = s(1)
    local left_width = math.floor(inner_width * 0.23)
    local right_width = math.floor(inner_width * 0.27)
    local center_width = inner_width - left_width - right_width - separator * 2
    local main = HorizontalGroup:new{
        CenterContainer:new{
            dimen = Geom:new{ w = left_width, h = main_height },
            readingRate(ctx, left_width - s(14), main_height - s(14)),
        },
        ctx.progress(separator, main_height, 1, { background = PALE, fill = PALE }),
        volumeColumn(ctx, center_width, main_height),
        ctx.progress(separator, main_height, 1, { background = PALE, fill = PALE }),
        pageSeal(ctx, right_width, main_height),
    }

    local progress_label = TextWidget:new{
        text = tr("PROGRESS"),
        face = Font:getFace("cfont", math.max(s(8), f.small - s(3))),
        fgcolor = MUTED,
        padding = 0,
    }
    local issued = TextWidget:new{
        text = tr("ISSUED FOR QUIET HOURS"),
        face = Font:getFace("cfont", math.max(s(8), f.small - s(3))),
        fgcolor = MUTED,
        padding = 0,
    }
    local footer_gap = s(10)
    local progress_width = math.max(s(60), inner_width - progress_label:getSize().w
        - issued:getSize().w - footer_gap * 2)
    local footer_row = HorizontalGroup:new{
        progress_label,
        HorizontalSpan:new{ width = footer_gap },
        ctx.progress(progress_width, s(9),
            d.show.progress_bar and d.percentage / 100 or 0,
            { background = PALE, fill = INK }),
        HorizontalSpan:new{ width = footer_gap },
        issued,
    }
    local footer = VerticalGroup:new{
        ctx.progress(inner_width, rule_height, 1, { background = PALE, fill = PALE }),
        VerticalSpan:new{ width = rule_gap },
        ctx.progress(inner_width, rule_height, 1, { background = PALE, fill = PALE }),
        CenterContainer:new{
            dimen = Geom:new{ w = inner_width, h = math.max(1, footer_height - rule_block_height) },
            footer_row,
        },
    }

    local sheet = FrameContainer:new{
        radius = 0,
        bordersize = border,
        padding = padding,
        background = PAPER,
        color = INK,
        VerticalGroup:new{ header, main, footer },
    }
    local middle = HorizontalGroup:new{
        perforationColumn(ctx, perforation, sheet_height),
        sheet,
        perforationColumn(ctx, perforation, sheet_height),
    }

    return {
        body = VerticalGroup:new{
            perforationRow(ctx, width, perforation),
            middle,
            perforationRow(ctx, width, perforation),
        },
        common_footer = false,
        shadow = false,
        frame = { full_bleed = true, background = Blitbuffer.COLOR_WHITE },
    }
end

return Style
