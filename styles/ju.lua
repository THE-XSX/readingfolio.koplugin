local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local ImageWidget = require("ui/widget/imagewidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local lfs = require("libs/libkoreader-lfs")
local T = require("ffi/util").template

local style_path = debug.getinfo(1, "S").source:sub(2)
local STYLE_DIR = style_path:match("(.*[/\\])") or ""
local INK_ASSET = STYLE_DIR .. "../assets/ju.png"
-- assets/ju.png is 989x1000.
local INK_RATIO = 1000 / 989

local Style = {
    interface_version = 1,
    id = "ju",
    label = "Chrysanthemum",
    defaults = {
        allow_cover = false,
        full_bleed = true,
        big = 23,
        mid = 16,
        small = 13,
        title_limit = 14,
    },
}

local function centered(width, widget)
    return CenterContainer:new{
        dimen = Geom:new{ w = width, h = widget:getSize().h },
        widget,
    }
end

function Style.render(ctx)
    local d, l, t, f, s, tr = ctx.data, ctx.layout, ctx.theme, ctx.fonts, ctx.scaled, ctx.translate
    local width = math.max(1, l.width)
    local height = math.max(s(360), l.target_height)
    local padding_h = s(18)
    local padding_v = s(14)
    local inner_width = math.max(1, width - padding_h * 2)
    local inner_height = math.max(1, height - padding_v * 2)

    local header_label = TextWidget:new{
        text = T(tr("EASTERN HEDGE · %1"), os.date("%m/%d")),
        face = Font:getFace("cfont", math.max(s(8), f.small - s(2))),
        fgcolor = t.muted,
        padding = 0,
    }
    local seal = FrameContainer:new{
        radius = s(3),
        bordersize = 0,
        padding = s(6),
        background = t.foreground,
        TextWidget:new{
            text = "菊",
            face = Font:getFace("cfont", f.big - s(3)),
            fgcolor = t.inverse_foreground,
            padding = 0,
        },
    }
    local header = HorizontalGroup:new{
        align = "top",
        header_label,
        HorizontalSpan:new{
            width = math.max(0, inner_width - header_label:getSize().w - seal:getSize().w),
        },
        seal,
    }

    local ink
    local ink_height = 0
    if lfs.attributes(INK_ASSET, "mode") == "file" then
        local ink_width = math.min(math.floor(inner_width * 0.74),
            math.floor(inner_height * 0.46 / INK_RATIO))
        ink_height = math.floor(ink_width * INK_RATIO)
        ink = centered(inner_width, ImageWidget:new{
            file = INK_ASSET,
            width = ink_width,
            height = ink_height,
            alpha = true,
        })
    end

    local percent
    if d.show.percentage then
        percent = centered(inner_width, TextWidget:new{
            text = string.format("%d%%", d.percentage),
            face = Font:getFace("cfont", f.big + s(8)),
            fgcolor = t.foreground,
            bold = true,
            padding = 0,
        })
    end

    local title = centered(inner_width, TextWidget:new{
        text = d.clean_title ~= "" and d.clean_title or "--",
        face = Font:getFace("cfont", f.mid + s(3)),
        fgcolor = t.foreground,
        bold = true,
        padding = 0,
    })
    local byline_parts = {}
    if d.author ~= "" then table.insert(byline_parts, d.author) end
    if d.chapter ~= "" and d.chapter ~= d.title then table.insert(byline_parts, d.chapter) end
    local byline
    if #byline_parts > 0 then
        byline = centered(inner_width, TextWidget:new{
            text = table.concat(byline_parts, " · "),
            face = Font:getFace("cfont", f.small),
            fgcolor = t.muted,
            padding = 0,
        })
    end

    -- One widget carries the whole status line, so the minute refresh has to rebuild
    -- it rather than replace it with the bare time. d.battery already honors the
    -- battery display toggle; d.battery_text does not.
    local function statusText(now)
        local status_parts = {}
        if d.show.today_time then
            table.insert(status_parts,
                string.format(tr("TODAY %d MIN"), math.floor((d.today_duration or 0) / 60)))
        end
        if d.clock ~= "" then table.insert(status_parts, now or d.clock) end
        if d.battery ~= "" then
            table.insert(status_parts, tr("POWER") .. " " .. d.battery)
        end
        return table.concat(status_parts, "    ")
    end
    local clock_widget = TextWidget:new{
        text = statusText(),
        face = Font:getFace("cfont", f.small),
        fgcolor = t.muted,
        padding = 0,
    }
    local status = centered(inner_width, clock_widget)
    if d.clock ~= "" then
        status = ctx.registerClock(clock_widget, statusText, status, inner_width)
    end

    local poem = centered(inner_width, TextWidget:new{
        text = tr("Picking chrysanthemums by the eastern hedge, the southern hills come into view."),
        face = Font:getFace("cfont", math.max(s(8), f.small - s(1))),
        fgcolor = t.faint,
        padding = 0,
    })

    local rule = ctx.progress(inner_width, s(1), 1, { background = t.faint, fill = t.faint })

    local fixed = header:getSize().h
        + (ink and (ink_height + s(10)) or 0)
        + (percent and (percent:getSize().h + s(8)) or 0)
        + title:getSize().h
        + (byline and (s(4) + byline:getSize().h) or 0)
        + rule:getSize().h + s(8) + status:getSize().h + s(8) + poem:getSize().h
    local flexible = math.max(0, inner_height - fixed)
    local flex_top = math.max(s(10), math.floor(flexible * 0.45))
    local flex_bottom = math.max(s(10), flexible - flex_top)

    local children = VerticalGroup:new{ align = "left" }
    table.insert(children, header)
    table.insert(children, VerticalSpan:new{ width = flex_top })
    if ink then
        table.insert(children, ink)
        table.insert(children, VerticalSpan:new{ width = s(10) })
    end
    if percent then
        table.insert(children, percent)
        table.insert(children, VerticalSpan:new{ width = s(8) })
    end
    table.insert(children, title)
    if byline then
        table.insert(children, VerticalSpan:new{ width = s(4) })
        table.insert(children, byline)
    end
    table.insert(children, VerticalSpan:new{ width = flex_bottom })
    table.insert(children, rule)
    table.insert(children, VerticalSpan:new{ width = s(8) })
    table.insert(children, status)
    table.insert(children, VerticalSpan:new{ width = s(8) })
    table.insert(children, poem)

    local page = FrameContainer:new{
        radius = 0,
        bordersize = 0,
        padding_top = padding_v,
        padding_right = padding_h,
        padding_bottom = padding_v,
        padding_left = padding_h,
        background = t.background,
        children,
    }

    return {
        body = page,
        common_footer = false,
        shadow = false,
        frame = { full_bleed = true, background = t.background },
    }
end

return Style
