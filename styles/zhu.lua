local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local ImageWidget = require("ui/widget/imagewidget")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local lfs = require("libs/libkoreader-lfs")
local T = require("ffi/util").template

local style_path = debug.getinfo(1, "S").source:sub(2)
local STYLE_DIR = style_path:match("(.*[/\\])") or ""
local INK_ASSET = STYLE_DIR .. "../assets/zhu.png"
-- assets/zhu.png is 731x1200.
local INK_RATIO = 731 / 1200

local Style = {
    interface_version = 1,
    id = "zhu",
    label = "Bamboo",
    defaults = {
        allow_cover = false,
        full_bleed = true,
        big = 22,
        mid = 16,
        small = 13,
        title_limit = 12,
    },
}

local SEGMENTS = 10

-- The bamboo culm doubles as the progress bar: solid segments grow from the
-- bottom, one per tenth of the book.
local function culmColumn(ctx, width, height, percentage)
    local t, s = ctx.theme, ctx.scaled
    local gap = s(2)
    local segment_height = math.max(s(6),
        math.floor((height - gap * (SEGMENTS - 1)) / SEGMENTS))
    local filled = math.max(0, math.min(SEGMENTS,
        math.floor(percentage / 100 * SEGMENTS + 0.5)))
    local column = VerticalGroup:new{}
    for index = SEGMENTS, 1, -1 do
        if index < SEGMENTS then
            table.insert(column, VerticalSpan:new{ width = gap })
        end
        if index <= filled then
            table.insert(column, ctx.progress(width, segment_height, 1, {
                background = t.foreground,
                fill = t.foreground,
            }))
        else
            table.insert(column, ctx.progress(width, segment_height, 0, {
                background = t.background,
                bordersize = s(1),
            }))
        end
    end
    return column
end

function Style.render(ctx)
    local d, l, t, f, s, tr = ctx.data, ctx.layout, ctx.theme, ctx.fonts, ctx.scaled, ctx.translate
    local width = math.max(1, l.width)
    local height = math.max(s(360), l.target_height)
    local padding_h = s(16)
    local padding_v = s(14)
    local inner_width = math.max(1, width - padding_h * 2)
    local inner_height = math.max(1, height - padding_v * 2)

    local header_label = TextWidget:new{
        text = T(tr("NODE BY NODE · %1"), os.date("%m/%d")),
        face = Font:getFace("cfont", math.max(s(8), f.small - s(2))),
        fgcolor = t.muted,
        padding = 0,
    }
    local seal = FrameContainer:new{
        radius = s(3),
        bordersize = s(1),
        color = t.foreground,
        padding = s(5),
        background = t.background,
        TextWidget:new{
            text = "竹",
            face = Font:getFace("cfont", f.big - s(3)),
            fgcolor = t.foreground,
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

    local main_height = math.floor(inner_height * 0.64)
    local culm_width = s(14)
    local gap = s(14)
    local ink, ink_width = nil, 0
    if lfs.attributes(INK_ASSET, "mode") == "file" then
        ink_width = math.min(math.floor(main_height * INK_RATIO),
            math.floor(inner_width * 0.52))
        ink = ImageWidget:new{
            file = INK_ASSET,
            width = ink_width,
            height = main_height,
            alpha = true,
        }
    end
    local column_width = math.max(s(90),
        inner_width - culm_width - gap - (ink and (ink_width + s(8)) or 0))

    local info_children = VerticalGroup:new{ align = "left" }
    table.insert(info_children, TextBoxWidget:new{
        text = d.clean_title ~= "" and d.clean_title or "--",
        face = Font:getFace("cfont", f.big + s(2)),
        width = column_width,
        fgcolor = t.foreground,
        bgcolor = t.background,
        bold = true,
    })
    if d.author ~= "" then
        table.insert(info_children, VerticalSpan:new{ width = s(6) })
        table.insert(info_children, TextWidget:new{
            text = d.author,
            face = Font:getFace("cfont", f.small),
            fgcolor = t.muted,
            padding = 0,
        })
    end
    table.insert(info_children, VerticalSpan:new{ width = s(14) })
    table.insert(info_children, ctx.progress(column_width, s(1), 1,
        { background = t.faint, fill = t.faint }))
    table.insert(info_children, VerticalSpan:new{ width = s(12) })
    if d.chapter ~= "" and d.chapter ~= d.title then
        table.insert(info_children, TextBoxWidget:new{
            text = d.chapter,
            face = Font:getFace("cfont", f.mid),
            width = column_width,
            fgcolor = t.foreground,
            bgcolor = t.background,
        })
        table.insert(info_children, VerticalSpan:new{ width = s(8) })
    end
    if d.page_label ~= "" and d.pages_label ~= "" then
        table.insert(info_children, TextWidget:new{
            text = string.format("%s / %s", d.page_label, d.pages_label),
            face = Font:getFace("cfont", f.small),
            fgcolor = t.muted,
            padding = 0,
        })
        table.insert(info_children, VerticalSpan:new{ width = s(6) })
    end
    if d.show.today_time then
        table.insert(info_children, TextWidget:new{
            text = string.format(tr("TODAY %d MIN"), math.floor((d.today_duration or 0) / 60)),
            face = Font:getFace("cfont", f.small),
            fgcolor = t.muted,
            padding = 0,
        })
    end

    local main_row = HorizontalGroup:new{ align = "top" }
    table.insert(main_row, culmColumn(ctx, culm_width, main_height, d.percentage))
    table.insert(main_row, HorizontalSpan:new{ width = gap })
    table.insert(main_row, info_children)
    if ink then
        table.insert(main_row, HorizontalSpan:new{
            width = math.max(0, inner_width - culm_width - gap - column_width - ink_width),
        })
        table.insert(main_row, ink)
    end

    local percent_widget = TextWidget:new{
        text = d.show.percentage and string.format("%d%%", d.percentage) or "",
        face = Font:getFace("cfont", f.big + s(8)),
        fgcolor = t.foreground,
        bold = true,
        padding = 0,
    }
    local status_parts = {}
    if d.clock ~= "" then table.insert(status_parts, d.clock) end
    if d.battery_text ~= "" then table.insert(status_parts, d.battery_text) end
    local status_widget = TextWidget:new{
        text = table.concat(status_parts, " · "),
        face = Font:getFace("cfont", f.small),
        fgcolor = t.muted,
        padding = 0,
    }
    if ctx.runtime and d.clock ~= "" then
        ctx.runtime.clock_widget = status_widget
    end
    local bottom_row = HorizontalGroup:new{
        align = "bottom",
        percent_widget,
        HorizontalSpan:new{
            width = math.max(0, inner_width - percent_widget:getSize().w - status_widget:getSize().w),
        },
        status_widget,
    }

    local poem = TextWidget:new{
        text = tr("Ten thousand strikes and still unbent, whatever wind may blow."),
        face = Font:getFace("cfont", math.max(s(8), f.small - s(1))),
        fgcolor = t.faint,
        padding = 0,
    }

    local rule = ctx.progress(inner_width, s(1), 1, { background = t.faint, fill = t.faint })
    local fixed = header:getSize().h + s(12) + main_height + s(14) + rule:getSize().h
        + s(10) + bottom_row:getSize().h + poem:getSize().h + s(6)
    local flexible = math.max(0, inner_height - fixed)

    local page = FrameContainer:new{
        radius = 0,
        bordersize = 0,
        padding_top = padding_v,
        padding_right = padding_h,
        padding_bottom = padding_v,
        padding_left = padding_h,
        background = t.background,
        VerticalGroup:new{
            align = "left",
            header,
            VerticalSpan:new{ width = s(12) },
            main_row,
            VerticalSpan:new{ width = s(14) },
            rule,
            VerticalSpan:new{ width = s(10) },
            bottom_row,
            VerticalSpan:new{ width = flexible },
            poem,
            VerticalSpan:new{ width = s(6) },
        },
    }

    return {
        body = page,
        common_footer = false,
        shadow = false,
        frame = { full_bleed = true, background = t.background },
    }
end

return Style
