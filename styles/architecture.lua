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
    id = "architecture",
    label = "Reading architecture",
    defaults = {
        allow_cover = true,
        defer_cover = true,
        force_cover = true,
        full_bleed = true,
        big = 23,
        mid = 16,
        small = 13,
        title_limit = 28,
    },
}

local BACKGROUND = Blitbuffer.COLOR_GRAY_E
local FOREGROUND = Blitbuffer.COLOR_BLACK
local MUTED = Blitbuffer.COLOR_GRAY_9

local function textBlock(width, height, text, face, color, bold, alignment)
    return CenterContainer:new{
        dimen = Geom:new{ w = width, h = height },
        TextBoxWidget:new{
            text = text,
            face = face,
            width = width,
            fgcolor = color,
            bgcolor = BACKGROUND,
            bold = bold,
            alignment = alignment or "left",
        },
    }
end

local function paddedPage(value)
    local number = tonumber(value)
    return number and string.format("%04d", number) or tostring(value or "--")
end

local function remainingValue(seconds, translate)
    if seconds == nil then return "--" end
    if seconds <= 0 then return string.format(translate("%dM"), 0) end
    if seconds >= 3600 then
        return string.format(translate("%dH"), math.max(1, math.ceil(seconds / 3600)))
    end
    return string.format(translate("%dM"), math.max(1, math.ceil(seconds / 60)))
end

local function chapterValue(chapter)
    if not chapter or chapter == "" then return "--" end
    return chapter:match("(%d+)") or chapter
end

local function batteryValue(battery)
    if not battery or battery == "" then return "--" end
    return battery:match("(%d+%%)") or battery
end

local function metric(ctx, width, height, label, value)
    local f, s = ctx.fonts, ctx.scaled
    local label_height = math.floor(height * 0.45)
    return VerticalGroup:new{
        textBlock(width, label_height, label,
            Font:getFace("cfont", f.small), MUTED, false, "center"),
        textBlock(width, height - label_height, value,
            Font:getFace("cfont", f.mid + s(1)), FOREGROUND, true, "center"),
    }
end

function Style.render(ctx)
    local d, l, f, s, tr = ctx.data, ctx.layout, ctx.fonts, ctx.scaled, ctx.translate
    local width = math.max(1, l.width)
    local height = math.max(1, l.target_height)
    local preferred_padding_h = l.ratio_mode == "fullscreen" and s(20) or s(16)
    local preferred_padding_v = l.ratio_mode == "fullscreen" and s(16) or s(12)
    local padding_h = math.min(preferred_padding_h, math.floor(width * 0.08))
    local padding_v = math.min(preferred_padding_v, math.floor(height * 0.05))
    local inner_width = math.max(1, width - padding_h * 2)
    local inner_height = math.max(1, height - padding_v * 2)

    local header_height = math.max(1, math.floor(inner_height * 0.06))
    local air_height = math.max(1, math.floor(inner_height * 0.04))
    local range_height = math.max(1, math.floor(inner_height * 0.06))
    local cover_height = math.max(1, math.floor(inner_height * 0.68))
    local metrics_height = math.max(1,
        inner_height - header_height - air_height - range_height - cover_height)

    local heading = TextWidget:new{
        text = tr("READING ARCHITECTURE"),
        face = Font:getFace("cfont", f.small + s(1)),
        fgcolor = FOREGROUND,
        padding = 0,
    }
    local reference = TextWidget:new{
        text = string.format("R-%04d", math.max(0, d.page or 0)),
        face = Font:getFace("cfont", f.small + s(1)),
        fgcolor = FOREGROUND,
        padding = 0,
    }
    local header = CenterContainer:new{
        dimen = Geom:new{ w = inner_width, h = header_height },
        HorizontalGroup:new{
            heading,
            HorizontalSpan:new{
                width = math.max(0, inner_width - heading:getSize().w - reference:getSize().w),
            },
            reference,
        },
    }

    local range_content_height = math.max(1, range_height - s(1))
    local range = VerticalGroup:new{
        HorizontalGroup:new{
            textBlock(math.floor(inner_width / 2), range_content_height,
                string.format(tr("BEGIN / %s"), "0001"),
                Font:getFace("cfont", f.small), FOREGROUND, false, "left"),
            textBlock(inner_width - math.floor(inner_width / 2), range_content_height,
                string.format(tr("END / %s"), paddedPage(d.pages_label ~= "" and d.pages_label or d.pages)),
                Font:getFace("cfont", f.small), FOREGROUND, false, "right"),
        },
        ctx.progress(inner_width, s(1), 1, { background = MUTED, fill = MUTED }),
    }

    local cover_width = math.max(1, math.floor(inner_width * 0.66))
    local cover_limit_height = math.max(1, cover_height - s(4))
    local cover = ctx.coverFor(cover_width, cover_limit_height)
    if not cover then
        cover = ctx.progress(cover_width, cover_limit_height, 1, {
            background = Blitbuffer.COLOR_BLACK,
            fill = Blitbuffer.COLOR_BLACK,
        })
    end
    local cover_stage = CenterContainer:new{
        dimen = Geom:new{ w = inner_width, h = cover_height },
        cover,
    }

    local metric_width = math.floor(inner_width / 3)
    local metrics = HorizontalGroup:new{
        metric(ctx, metric_width, metrics_height,
            tr("CHAPTER"), chapterValue(d.chapter)),
        metric(ctx, metric_width, metrics_height,
            tr("LEFT"), d.show.book_time_left
                and remainingValue(d.book_time_left_seconds, tr) or "--"),
        metric(ctx, inner_width - metric_width * 2, metrics_height,
            tr("POWER"), batteryValue(d.battery_text)),
    }

    local page = FrameContainer:new{
        radius = 0,
        bordersize = 0,
        padding_top = padding_v,
        padding_right = padding_h,
        padding_bottom = padding_v,
        padding_left = padding_h,
        background = BACKGROUND,
        VerticalGroup:new{
            header,
            VerticalSpan:new{ width = air_height },
            range,
            cover_stage,
            metrics,
        },
    }

    return {
        body = page,
        common_footer = false,
        shadow = false,
        frame = { full_bleed = true, background = BACKGROUND },
    }
end

return Style
