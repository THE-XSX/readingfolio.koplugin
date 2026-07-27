local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local OverlapGroup = require("ui/widget/overlapgroup")
local TextBoxWidget = require("ui/widget/textboxwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Widget = require("ui/widget/widget")

local Style = {
    interface_version = 1,
    id = "bookpost",
    label = "Book post",
    defaults = {
        allow_cover = true,
        defer_cover = true,
        force_cover = true,
        full_bleed = true,
        landscape = true,
        aspect_ratio = 1.40,
        default_ratio = 0.94,
        big = 22,
        mid = 16,
        small = 13,
        title_limit = 24,
        highlight_lines = 3,
    },
}

local BACKGROUND = Blitbuffer.COLOR_GRAY_E
local PAPER = Blitbuffer.COLOR_GRAY_E
local INK = Blitbuffer.COLOR_BLACK
local MUTED = Blitbuffer.COLOR_GRAY_9
local PALE = Blitbuffer.COLOR_GRAY_D

local function textBlock(width, height, text, face, color, bold, alignment)
    width, height = math.max(1, width), math.max(1, height)
    return CenterContainer:new{
        dimen = Geom:new{ w = width, h = height },
        TextBoxWidget:new{
            text = tostring(text or ""),
            face = face,
            width = width,
            height = height,
            height_overflow_show_ellipsis = true,
            fgcolor = color,
            bgcolor = PAPER,
            bold = bold,
            alignment = alignment or "left",
        },
    }
end

local function drawLine(bb, x1, y1, x2, y2, thickness, color)
    local dx, dy = x2 - x1, y2 - y1
    local steps = math.max(math.abs(dx), math.abs(dy))
    if steps == 0 then
        bb:paintRect(x1, y1, thickness, thickness, color)
        return
    end
    local stride = math.max(1, thickness)
    for step = 0, steps, stride do
        local x = math.floor(x1 + dx * step / steps + 0.5)
        local y = math.floor(y1 + dy * step / steps + 0.5)
        bb:paintRect(x, y, thickness, thickness, color)
    end
    bb:paintRect(x2, y2, thickness, thickness, color)
end

local EnvelopeArt = Widget:extend{
    width = 1,
    height = 1,
    line_width = 1,
}

function EnvelopeArt:getSize()
    return Geom:new{ w = self.width, h = self.height }
end

function EnvelopeArt:paintTo(bb, x, y)
    local width, height = self.width, self.height
    local line = math.max(1, self.line_width)
    local right = x + width - line
    local bottom = y + height - line
    local fold_y = y + math.floor(height * 0.72)
    local top_y = y + math.floor(height * 0.18)
    local middle_x = x + math.floor(width * 0.50)

    bb:paintRect(middle_x, y, line, height, PALE)
    drawLine(bb, x, top_y, middle_x, fold_y, line, PALE)
    drawLine(bb, right, top_y, middle_x, fold_y, line, PALE)
    drawLine(bb, x, bottom, middle_x, fold_y, line, PALE)
    drawLine(bb, right, bottom, middle_x, fold_y, line, PALE)
end

local DashedBorder = Widget:extend{
    width = 1,
    height = 1,
    line_width = 1,
    dash = 4,
    gap = 3,
}

function DashedBorder:getSize()
    return Geom:new{ w = self.width, h = self.height }
end

function DashedBorder:paintTo(bb, x, y)
    local line = math.max(1, self.line_width)
    local stride = math.max(1, self.dash + self.gap)
    for offset = 0, self.width - 1, stride do
        local length = math.min(self.dash, self.width - offset)
        bb:paintRect(x + offset, y, length, line, INK)
        bb:paintRect(x + offset, y + self.height - line, length, line, INK)
    end
    for offset = 0, self.height - 1, stride do
        local length = math.min(self.dash, self.height - offset)
        bb:paintRect(x, y + offset, line, length, INK)
        bb:paintRect(x + self.width - line, y + offset, line, length, INK)
    end
end

local CancellationArt = Widget:extend{
    width = 1,
    height = 1,
    line_width = 1,
}

function CancellationArt:getSize()
    return Geom:new{ w = self.width, h = self.height }
end

function CancellationArt:paintTo(bb, x, y)
    local line = math.max(1, self.line_width)
    local start_x = x + math.floor(self.width * 0.03)
    local end_x = x + math.floor(self.width * 0.58)
    local middle_y = y + math.floor(self.height * 0.58)
    local spacing = math.max(line * 3, math.floor(self.height * 0.035))
    for index = -2, 2 do
        local y1 = middle_y + index * spacing
        drawLine(bb, start_x, y1, end_x, y1 - spacing, line, INK)
    end
end

local function positioned(width, height, left, top, widget)
    local size = widget:getSize()
    left = math.max(0, math.min(left, width - math.min(width, size.w)))
    top = math.max(0, math.min(top, height - math.min(height, size.h)))
    return VerticalGroup:new{
        VerticalSpan:new{ width = top },
        HorizontalGroup:new{
            HorizontalSpan:new{ width = left },
            widget,
            HorizontalSpan:new{ width = math.max(0, width - left - size.w) },
        },
        VerticalSpan:new{ width = math.max(0, height - top - size.h) },
    }
end

local function compactDuration(seconds, translate)
    if seconds == nil then return "--" end
    local total_minutes = math.max(0, math.floor(seconds / 60))
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

local function pageLabels(data)
    if not data.show.page_number then return "--", "--" end
    local current = data.page_label ~= "" and data.page_label or tostring(data.page or "--")
    local total = data.pages_label ~= "" and data.pages_label or tostring(data.pages or "--")
    return current, total
end

local function batteryValue(data)
    if not data.battery_text or data.battery_text == "" then return "--" end
    return data.battery_text:match("(%d+%%)") or data.battery_text
end

local function timestampValue(data)
    local value = os.date("%Y.%m.%d")
    if data.show.clock and data.clock ~= "" then return value .. " · " .. data.clock end
    return value
end

local function titleValue(data, translate)
    if data.clean_title == "" then return "--" end
    return string.format(translate("《%s》"), data.clean_title)
end

local function labelValue(ctx, width, height, label, value)
    local f, s = ctx.fonts, ctx.scaled
    local label_height = math.max(1, math.floor(height * 0.30))
    return VerticalGroup:new{
        textBlock(width, label_height, label,
            Font:getFace("cfont", math.max(s(8), f.small - s(2))), MUTED, false, "left"),
        textBlock(width, math.max(1, height - label_height), value,
            Font:getFace("cfont", f.small), INK, true, "left"),
    }
end

local function letterColumn(ctx, width, height)
    local d, s, tr = ctx.data, ctx.scaled, ctx.translate
    local padding = s(8)
    local inner_width = math.max(1, width - padding * 2)
    local from_height = math.floor(height * 0.30)
    local to_height = math.floor(height * 0.18)
    local date_height = math.floor(height * 0.17)
    local air_height = math.floor(height * 0.15)
    local number_height = height - from_height - to_height - date_height - air_height

    local from_parts = {}
    if d.author ~= "" then table.insert(from_parts, d.author) end
    if d.clean_title ~= "" then table.insert(from_parts, titleValue(d, tr)) end
    local from_value = #from_parts > 0 and table.concat(from_parts, "\n") or "--"
    local current, total = pageLabels(d)
    local number_content_height = math.max(1, number_height - s(1) - s(5))

    local content = VerticalGroup:new{
        labelValue(ctx, inner_width, from_height, tr("FROM"), from_value),
        labelValue(ctx, inner_width, to_height, tr("TO"), tr("You, reading now")),
        labelValue(ctx, inner_width, date_height, tr("DATE"), os.date("%Y.%m.%d")),
        VerticalSpan:new{ width = air_height },
        ctx.progress(inner_width, s(1), 1, { background = PALE, fill = PALE }),
        VerticalSpan:new{ width = s(5) },
        labelValue(ctx, inner_width, number_content_height, tr("LETTER NO."),
            string.format("%s / %s", current, total)),
    }
    return positioned(width, height, padding, 0, content)
end

local function postageStamp(ctx, width, height)
    local d, f, s, tr = ctx.data, ctx.fonts, ctx.scaled, ctx.translate
    local padding = s(4)
    local inner_width = math.max(1, width - padding * 2)
    local inner_height = math.max(1, height - padding * 2)
    local label_height = math.max(1, math.floor(inner_height * 0.18))
    local cover_height = math.max(1, inner_height - label_height)
    local cover = ctx.coverFor(inner_width, cover_height)
    local cover_layers = {
        dimen = Geom:new{ w = inner_width, h = cover_height },
        ctx.progress(inner_width, cover_height, 1, {
            background = Blitbuffer.COLOR_BLACK,
            fill = Blitbuffer.COLOR_BLACK,
        }),
    }
    if cover then
        table.insert(cover_layers, CenterContainer:new{
            dimen = Geom:new{ w = inner_width, h = cover_height },
            cover,
        })
    end
    local cover_stage = OverlapGroup:new(cover_layers)
    local label_value = d.show.percentage and string.format("%d", d.percentage) or "--"
    local preferred_label_font = math.max(s(6),
        f.small - (ctx.layout.compact and s(4) or s(2)))
    local label_font = math.max(1, math.min(preferred_label_font,
        math.floor(label_height * 0.70)))
    local content = VerticalGroup:new{
        CenterContainer:new{
            dimen = Geom:new{ w = inner_width, h = cover_height },
            cover_stage,
        },
        textBlock(inner_width, label_height, string.format(tr("BOOK · %s"), label_value),
            Font:getFace("cfont", label_font), INK, true, "center"),
    }
    return OverlapGroup:new{
        dimen = Geom:new{ w = width, h = height },
        DashedBorder:new{
            width = width,
            height = height,
            line_width = s(1),
            dash = s(4),
            gap = s(3),
        },
        positioned(width, height, padding, padding, content),
    }
end

local function roundSeal(ctx, size, label, value, muted)
    local f, s = ctx.fonts, ctx.scaled
    local border = s(1)
    local padding = s(5)
    local inner = math.max(1, size - (border + padding) * 2)
    local label_height = math.floor(inner * 0.45)
    return FrameContainer:new{
        radius = math.floor(size / 2),
        bordersize = border,
        padding = padding,
        background = PAPER,
        color = muted and MUTED or INK,
        VerticalGroup:new{
            textBlock(inner, label_height, label,
                Font:getFace("cfont", math.max(s(7), f.small - s(4))),
                muted and MUTED or INK, false, "center"),
            textBlock(inner, inner - label_height, value,
                Font:getFace("cfont", f.mid + s(1)), INK, true, "center"),
        },
    }
end

local function postagePanel(ctx, width, height)
    local s, tr = ctx.scaled, ctx.translate
    local stamp_width = math.max(s(54), math.floor(width * 0.38))
    local stamp_height = math.max(s(72), math.floor(height * 0.84))
    stamp_width = math.min(stamp_width, width)
    stamp_height = math.min(stamp_height, height)
    local seal_size = math.max(s(48), math.min(math.floor(height * 0.58), math.floor(width * 0.38)))
    seal_size = math.min(seal_size, width, height)
    local seal = roundSeal(ctx, seal_size, tr("READING POST"), os.date("%m.%d"), false)
    local stamp = postageStamp(ctx, stamp_width, stamp_height)
    local stamp_left = math.max(0, width - stamp_width - s(2))
    local seal_left = math.max(0, stamp_left - math.floor(seal_size * 0.58))
    local seal_top = math.max(0, math.floor((height - seal_size) * 0.58))
    return OverlapGroup:new{
        dimen = Geom:new{ w = width, h = height },
        CancellationArt:new{ width = width, height = height, line_width = s(1) },
        positioned(width, height, seal_left, seal_top, seal),
        positioned(width, height, stamp_left, s(2), stamp),
    }
end

local function salutationPanel(ctx, width, height)
    local d, f, s, tr = ctx.data, ctx.fonts, ctx.scaled, ctx.translate
    local row_height = math.max(1, math.floor(height * 0.30))
    local left_width = math.floor(width * 0.46)
    local chapter = d.chapter ~= "" and d.chapter or "--"
    return VerticalGroup:new{
        HorizontalGroup:new{
            textBlock(left_width, row_height, tr("Dear reader:"),
                Font:getFace("cfont", f.small), INK, true, "left"),
            textBlock(width - left_width, row_height, chapter,
                Font:getFace("cfont", f.small), INK, false, "left"),
        },
        ctx.progress(width, s(1), 1, { background = PALE, fill = PALE }),
        VerticalSpan:new{ width = math.max(0, height - row_height - s(1)) },
    }
end

local function quotePanel(ctx, width, height)
    local d, f, s, tr = ctx.data, ctx.fonts, ctx.scaled, ctx.translate
    local quote = d.message or d.highlight_text
        or tr("Every distant arrival begins with the next page you choose to turn.")
    local padding_h = s(9)
    local mark_width = s(20)
    local inner_width = math.max(1, width - padding_h * 2)
    return positioned(width, height, padding_h, 0,
        HorizontalGroup:new{
            textBlock(mark_width, height, "“",
                Font:getFace("cfont", f.big + s(4)), MUTED, true, "center"),
            textBlock(math.max(1, inner_width - mark_width), height, quote,
                Font:getFace("cfont", f.mid + s(1)), INK, false, "left"),
        })
end

local function metadataPanel(ctx, width, height)
    local d, f, s, tr = ctx.data, ctx.fonts, ctx.scaled, ctx.translate
    local current, total = pageLabels(d)
    local source_width = math.floor(width * 0.70)
    local title = d.clean_title ~= "" and titleValue(d, tr) or "--"
    local source = string.format(tr("Excerpt from %s"), title)
        .. "\n" .. string.format(tr("Page %s"), current)
    local page_serial = d.show.page_number and string.format("%04d", math.max(0, d.page or 0)) or "----"
    local total_serial = d.show.page_number and string.format("%04d", math.max(0, d.pages or 0)) or "----"
    local percent_serial = d.show.percentage and string.format("%03d", d.percentage) or "---"
    return HorizontalGroup:new{
        textBlock(source_width, height, source,
            Font:getFace("cfont", math.max(s(8), f.small - s(1))), MUTED, false, "center"),
        textBlock(width - source_width, height,
            string.format("%s %s %s", page_serial, total_serial, percent_serial),
            Font:getFace("cfont", math.max(s(7), f.small - s(3))), INK, false, "center"),
    }
end

local function readingPanel(ctx, width, height)
    local d, s, tr = ctx.data, ctx.scaled, ctx.translate
    local top_height = math.floor(height * 0.34)
    local quote_height = math.floor(height * 0.36)
    local metadata_height = height - top_height - quote_height
    local postal_width = math.floor(width * 0.34)
    local salutation_width = width - postal_width
    local quote_width = math.floor(width * 0.74)
    local seal_width = width - quote_width
    local seal_size = math.max(s(54), math.min(math.floor(quote_height * 0.68), seal_width - s(12)))
    seal_size = math.min(seal_size, quote_height, seal_width)
    local percent = d.show.percentage and string.format("%d%%", d.percentage) or "--"
    return VerticalGroup:new{
        HorizontalGroup:new{
            salutationPanel(ctx, salutation_width, top_height),
            postagePanel(ctx, postal_width, top_height),
        },
        HorizontalGroup:new{
            quotePanel(ctx, quote_width, quote_height),
            CenterContainer:new{
                dimen = Geom:new{ w = seal_width, h = quote_height },
                roundSeal(ctx, seal_size, tr("READ"), percent, true),
            },
        },
        metadataPanel(ctx, width, metadata_height),
    }
end

local function footerPanel(ctx, width, height)
    local d, f, s, tr = ctx.data, ctx.fonts, ctx.scaled, ctx.translate
    local current, total = pageLabels(d)
    local percent = d.show.percentage and string.format("%d%%", d.percentage) or "--"
    local remaining = d.show.book_time_left and d.book_time_left or "--"
    local today = d.show.today_time and compactDuration(d.today_duration, tr) or "--"
    local status = string.format(tr("READ %s · PAGE %s / %s · %s LEFT"),
        percent, current, total, remaining)
    local session = string.format(tr("TODAY %s · POWER %s"), today, batteryValue(d))
    local rule_height = s(1)
    local progress_height = math.max(s(3), math.floor(height * 0.10))
    local bottom_gap = math.min(s(2), math.max(0, height - rule_height - progress_height - 1))
    local row_height = math.max(1, height - rule_height - progress_height - bottom_gap)
    local left_width = math.floor(width * 0.73)
    local footer_font = math.max(s(7), f.small - (ctx.layout.compact and s(5) or s(3)))
    return VerticalGroup:new{
        ctx.progress(width, rule_height, 1, { background = PALE, fill = PALE }),
        HorizontalGroup:new{
            textBlock(left_width, row_height, status,
                Font:getFace("cfont", footer_font), INK, false, "left"),
            textBlock(width - left_width, row_height, session,
                Font:getFace("cfont", footer_font), INK, false, "right"),
        },
        HorizontalGroup:new{
            ctx.progress(left_width, progress_height,
                d.show.progress_bar and d.percentage / 100 or 0,
                { background = PALE, fill = INK }),
            HorizontalSpan:new{ width = width - left_width },
        },
        VerticalSpan:new{ width = bottom_gap },
    }
end

local function compactPostcard(ctx, width, height)
    local d, f, s, tr = ctx.data, ctx.fonts, ctx.scaled, ctx.translate
    local border = s(1)
    local padding = math.min(s(5), math.floor(math.min(width, height) * 0.04))
    local inner_width = math.max(1, width - (border + padding) * 2)
    local inner_height = math.max(1, height - (border + padding) * 2)
    local header_height = math.max(1, math.floor(inner_height * 0.18))
    local footer_height = math.max(1, math.floor(inner_height * 0.20))
    local main_height = math.max(1, inner_height - header_height - footer_height)
    local divider = s(1)
    local stamp_width = math.max(1, math.floor(inner_width * 0.31))
    local copy_width = math.max(1, inner_width - stamp_width - divider)
    local title_height = math.max(1, math.floor(main_height * 0.27))
    local current, total = pageLabels(d)
    local percent = d.show.percentage and string.format("%d%%", d.percentage) or "--"
    local quote = d.message or d.highlight_text
        or tr("Every distant arrival begins with the next page you choose to turn.")
    local title = d.clean_title ~= "" and titleValue(d, tr) or "--"
    local header_left = math.floor(inner_width * 0.62)
    local small_size = math.max(1, math.min(math.max(s(6), f.small - s(5)),
        math.floor(header_height * 0.60)))
    local title_size = math.max(1, math.min(math.max(s(7), f.mid - s(3)),
        math.floor(title_height * 0.65)))
    local quote_height = math.max(1, main_height - title_height)
    local quote_size = math.max(1, math.min(math.max(s(6), f.small - s(3)),
        math.floor(quote_height / 3.9)))
    local small_face = Font:getFace("cfont", small_size)

    local header = HorizontalGroup:new{
        textBlock(header_left, header_height, tr("BOOK POST"),
            small_face, MUTED, false, "left"),
        textBlock(inner_width - header_left, header_height, timestampValue(d),
            small_face, MUTED, false, "right"),
    }
    local copy = VerticalGroup:new{
        textBlock(copy_width, title_height, title,
            Font:getFace("cfont", title_size), INK, true, "left"),
        textBlock(copy_width, quote_height, quote,
            Font:getFace("cfont", quote_size), INK, false, "left"),
    }
    local stamp = postageStamp(ctx,
        math.max(1, stamp_width - s(4)), math.max(1, main_height - s(4)))
    local main = HorizontalGroup:new{
        copy,
        ctx.progress(divider, main_height, 1, { background = PALE, fill = PALE }),
        CenterContainer:new{
            dimen = Geom:new{ w = stamp_width, h = main_height },
            stamp,
        },
    }

    local rule_height = s(1)
    local progress_height = math.max(s(2), math.floor(footer_height * 0.16))
    local status_height = math.max(1, footer_height - rule_height - progress_height)
    local footer = VerticalGroup:new{
        ctx.progress(inner_width, rule_height, 1, { background = PALE, fill = PALE }),
        textBlock(inner_width, status_height,
            string.format(tr("READ %s · %s / %s"), percent, current, total),
            small_face, INK, false, "left"),
        ctx.progress(inner_width, progress_height,
            d.show.progress_bar and d.percentage / 100 or 0,
            { background = PALE, fill = INK }),
    }

    return FrameContainer:new{
        radius = 0,
        bordersize = border,
        padding = padding,
        background = PAPER,
        color = INK,
        VerticalGroup:new{ header, main, footer },
    }
end

function Style.render(ctx)
    local d, l, f, s, tr = ctx.data, ctx.layout, ctx.fonts, ctx.scaled, ctx.translate
    local width = math.max(1, l.width)
    local height = math.max(1, l.target_height)
    if width < s(430) or height < s(300) then
        return {
            body = compactPostcard(ctx, width, height),
            common_footer = false,
            shadow = false,
            frame = { full_bleed = true, background = BACKGROUND },
        }
    end
    local padding_h = math.min(s(14), math.floor(width * 0.025))
    local padding_v = math.min(s(10), math.floor(height * 0.025))
    local inner_width = math.max(1, width - padding_h * 2)
    local inner_height = math.max(1, height - padding_v * 2)
    local header_height = math.max(1, math.floor(inner_height * 0.09))
    local stage_height = math.max(1, inner_height - header_height)

    local header_left = math.floor(inner_width * 0.64)
    local header = HorizontalGroup:new{
        textBlock(header_left, header_height, tr("BOOK POST · LANDSCAPE EDITION"),
            Font:getFace("cfont", f.small), MUTED, false, "left"),
        textBlock(inner_width - header_left, header_height, timestampValue(d),
            Font:getFace("cfont", f.small), MUTED, false, "right"),
    }

    local shadow_offset = s(10)
    local sheet_width = math.max(1, inner_width - shadow_offset)
    local sheet_height = math.max(1, stage_height - shadow_offset)
    local sheet_border = s(1)
    local sheet_padding = s(8)
    local content_width = math.max(1, sheet_width - (sheet_border + sheet_padding) * 2)
    local content_height = math.max(1, sheet_height - (sheet_border + sheet_padding) * 2)
    local footer_height = math.max(1, math.floor(content_height * 0.14))
    local main_height = math.max(1, content_height - footer_height)
    local separator = s(1)
    local left_width = math.floor(content_width * 0.21)
    local right_width = math.max(1, content_width - left_width - separator)

    local content = VerticalGroup:new{
        HorizontalGroup:new{
            letterColumn(ctx, left_width, main_height),
            ctx.progress(separator, main_height, 1, { background = PALE, fill = PALE }),
            readingPanel(ctx, right_width, main_height),
        },
        footerPanel(ctx, content_width, footer_height),
    }
    local decorated = OverlapGroup:new{
        dimen = Geom:new{ w = content_width, h = content_height },
        EnvelopeArt:new{
            width = content_width,
            height = main_height,
            line_width = s(1),
        },
        content,
    }
    local sheet = FrameContainer:new{
        radius = 0,
        bordersize = sheet_border,
        padding = sheet_padding,
        background = PAPER,
        color = INK,
        decorated,
    }
    local stage = OverlapGroup:new{
        dimen = Geom:new{ w = inner_width, h = stage_height },
        positioned(inner_width, stage_height, shadow_offset, shadow_offset,
            ctx.progress(sheet_width, sheet_height, 1, { background = PALE, fill = PALE })),
        positioned(inner_width, stage_height, math.floor(shadow_offset * 0.55),
            math.floor(shadow_offset * 0.45),
            ctx.progress(sheet_width, sheet_height, 1, { background = PALE, fill = PALE })),
        positioned(inner_width, stage_height, 0, 0, sheet),
    }

    return {
        body = FrameContainer:new{
            radius = 0,
            bordersize = 0,
            padding_top = padding_v,
            padding_right = padding_h,
            padding_bottom = padding_v,
            padding_left = padding_h,
            background = BACKGROUND,
            VerticalGroup:new{ header, stage },
        },
        common_footer = false,
        shadow = false,
        frame = { full_bleed = true, background = BACKGROUND },
    }
end

return Style
