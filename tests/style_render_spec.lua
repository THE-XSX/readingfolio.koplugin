-- Renders every registered style against a stub KOReader and checks the clock wiring.
--
-- The specs around it work on sliced-out logic; this one is the opposite -- it runs the
-- real style files and the real renderer, because the per-minute clock refresh depends
-- on things only visible once a card is actually built:
--
--   * a style that shows the time must register the widget holding it, and a region to
--     repaint -- the region is what makes a partial refresh possible at all;
--   * a style that opts out of the common footer must NOT register the footer's clock,
--     which is never painted (five styles were refreshing an invisible widget, so the
--     time never changed and the whole card was redrawn every minute anyway);
--   * a style whose clock shares a widget with the battery reading or the page count
--     must supply a formatter that rebuilds the whole line, since setText replaces it;
--   * turning the battery display off must actually remove it.
--
-- The KOReader widget layer is stubbed just enough to measure sizes. Nothing here checks
-- pixels -- it checks that the card builds at all and that the wiring is present.
--
-- Run from the plugin root:
--   python3 runlua.py <plugin_dir> <plugin_dir>/tests/style_render_spec.lua

local Support = dofile("tests/support.lua")

local checks, failures = 0, 0
local function check(label, ok)
    checks = checks + 1
    if ok then
        print("ok " .. label)
    else
        failures = failures + 1
        print("FAIL " .. label)
    end
end

-- ------------------------------------------------------------------ KOReader stubs

local function sized(w, h)
    return { w = w or 0, h = h or 0 }
end

local function widgetClass(measure)
    local class = {}
    class.__index = class
    function class:new(spec)
        spec = spec or {}
        return setmetatable(spec, class)
    end
    function class:getSize() return measure(self) end
    function class:setText(text) self.text = text end
    function class:free() end
    -- Styles subclass the base Widget to draw their own ornaments (bookpost's envelope
    -- art, its dashed border). Those subclasses define their own getSize/paintTo.
    function class:extend(spec)
        local subclass = spec or {}
        subclass.__index = subclass
        setmetatable(subclass, { __index = class })
        function subclass:new(instance)
            instance = instance or {}
            for key, value in pairs(subclass) do
                if instance[key] == nil and key ~= "__index" then instance[key] = value end
            end
            return setmetatable(instance, subclass)
        end
        return subclass
    end
    return class
end

local function childrenSize(group, horizontal)
    local w, h = 0, 0
    for _, child in ipairs(group) do
        local size = child.getSize and child:getSize() or sized(0, 0)
        if horizontal then
            w = w + (size.w or 0)
            h = math.max(h, size.h or 0)
        else
            w = math.max(w, size.w or 0)
            h = h + (size.h or 0)
        end
    end
    return sized(w, h)
end

-- A CJK glyph is about one em wide, an ASCII one about half; close enough to keep the
-- layout arithmetic honest.
local function textSize(widget)
    local text = tostring(widget.text or "")
    local size = (widget.face and widget.face.size) or 16
    local chars, i = 0, 1
    while i <= #text do
        local byte = text:byte(i)
        if byte >= 0xF0 then i, chars = i + 4, chars + 2
        elseif byte >= 0xE0 then i, chars = i + 3, chars + 2
        elseif byte >= 0xC0 then i, chars = i + 2, chars + 2
        else i, chars = i + 1, chars + 1 end
    end
    return sized(math.floor(chars * size / 2), size + 4)
end

local stubs = {}
stubs["ui/widget/textwidget"] = widgetClass(textSize)
stubs["ui/widget/textboxwidget"] = widgetClass(function(w)
    local line = textSize(w)
    local width = w.width or line.w
    local lines = math.max(1, math.ceil(line.w / math.max(1, width)))
    return sized(width, lines * (line.h))
end)
stubs["ui/widget/horizontalgroup"] = widgetClass(function(g) return childrenSize(g, true) end)
stubs["ui/widget/verticalgroup"] = widgetClass(function(g) return childrenSize(g, false) end)
stubs["ui/widget/horizontalspan"] = widgetClass(function(w) return sized(w.width or 0, 0) end)
stubs["ui/widget/verticalspan"] = widgetClass(function(w) return sized(0, w.width or 0) end)
stubs["ui/widget/overlapgroup"] = widgetClass(function(g)
    if g.dimen then return sized(g.dimen.w, g.dimen.h) end
    return childrenSize(g, false)
end)
stubs["ui/widget/progresswidget"] = widgetClass(function(w) return sized(w.width or 0, w.height or 0) end)
stubs["ui/widget/imagewidget"] = widgetClass(function(w) return sized(w.width or 0, w.height or 0) end)
stubs["ui/widget/widget"] = widgetClass(function(w) return sized(w.width or 0, w.height or 0) end)
stubs["ui/widget/container/centercontainer"] = widgetClass(function(c)
    if c.dimen then return sized(c.dimen.w, c.dimen.h) end
    return c[1] and c[1]:getSize() or sized(0, 0)
end)
stubs["ui/widget/container/custompositioncontainer"] = widgetClass(function(c)
    if c.dimen then return sized(c.dimen.w, c.dimen.h) end
    return c[1] and c[1]:getSize() or sized(0, 0)
end)
stubs["ui/widget/container/widgetcontainer"] = widgetClass(function(c)
    if c.dimen then return sized(c.dimen.w, c.dimen.h) end
    return c[1] and c[1].getSize and c[1]:getSize() or sized(0, 0)
end)
-- Mirrors the real one: getSize is content-based and ignores `width`, which only widens
-- the painted background.
stubs["ui/widget/container/framecontainer"] = widgetClass(function(f)
    local inner = f[1] and f[1].getSize and f[1]:getSize() or sized(0, 0)
    local pad = f.padding or 0
    local border = f.bordersize or 0
    local margin = f.margin or 0
    local extra = (pad + border + margin) * 2
    return sized(inner.w + extra, inner.h + extra)
end)

local Geom = {}
Geom.__index = Geom
function Geom:new(spec)
    return setmetatable(spec or {}, Geom)
end
function Geom:copy() return Geom:new{ x = self.x, y = self.y, w = self.w, h = self.h } end
stubs["ui/geometry"] = Geom

stubs["ui/font"] = { getFace = function(_, _, size) return { size = size or 16 } end }
stubs["ffi/blitbuffer"] = setmetatable({}, {
    __index = function(t, key)
        local value = { color = key }
        rawset(t, key, value)
        return value
    end,
})
stubs["ui/renderimage"] = {
    renderImageFile = function() return nil end,
    scaleBlitBuffer = function() return nil end,
}
stubs["libs/libkoreader-lfs"] = { attributes = function() return nil end, dir = function() return function() return nil end end }
stubs["util"] = {
    arrayAppend = function(target, extra)
        for _, item in ipairs(extra or {}) do table.insert(target, item) end
        return target
    end,
    trim = function(text)
        return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
    end,
    splitToChars = function(text)
        local out = {}
        for char in tostring(text):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
            table.insert(out, char)
        end
        return out
    end,
}
stubs["ffi/util"] = { template = function(fmt) return fmt end }
stubs["device"] = {
    screen = {
        getWidth = function() return 1072 end,
        getHeight = function() return 1448 end,
        getSize = function() return Geom:new{ w = 1072, h = 1448 } end,
        scaleBySize = function(_, value) return value end,
    },
    screen_saver_mode = false,
    isTouchDevice = function() return true end,
    hasKeys = function() return false end,
}

for name, module in pairs(stubs) do
    package.preload[name] = function() return module end
end
-- styles/custom.lua asks for LuaJIT's FFI on purpose (Blitbuffer hands out pixels as
-- cdata). The registry dofiles every style, so it has to resolve; it is only *used*
-- while rendering that style, which this spec does not do.
package.preload["ffi"] = function()
    return { cast = function() error("ffi.cast is not available in the spec", 0) end }
end

_G.G_reader_settings = Support.settings()

-- --------------------------------------------------------------------- the renderer

-- Everything below resolves relative to the plugin root, which is the cwd the runner
-- sets, so an empty plugin_root is the right thing to hand the registry.
local Constants = dofile("core/constants.lua")
local Registry = dofile("styles/style_registry.lua")
local Renderer = dofile("rendering/renderer.lua")
local CustomLayout = dofile("rendering/custom_layout.lua")

-- The real translator is a callable object with a language() method, which some styles
-- ask (mei picks Chinese numerals from it).
local translate = setmetatable({}, { __call = function(_, text) return text end })
function translate:language() return "en" end

local registry = Registry.new("")
local renderer = Renderer.new{
    constants = Constants,
    data_provider = { collect = function() return nil end },
    registry = registry,
    translate = translate,
    custom_layout = CustomLayout.new{ constants = Constants },
}

local function fixtureData(overrides)
    local data = {
        -- Data passes the ReaderUI through; an empty one means "no cover available",
        -- which _coverWidget handles by returning nil.
        ui = {},
        title = "凡人修仙传",
        author = "忘语",
        chapter = "第一章 山边小村",
        page = 42,
        pages = 800,
        page_label = "42",
        pages_label = "800",
        percentage = 5,
        chapter_done = 3,
        chapter_total = 20,
        chapter_time_left = "12 min",
        book_time_left = "9 h",
        chapter_time_left_seconds = 720,
        book_time_left_seconds = 32400,
        total_duration = 7200,
        today_duration = 2520,
        total_time_text = "Total time spent: 2 h",
        today_time_text = "Time spent today (Sunday): 42 min",
        battery = "87%",
        battery_text = "87%",
        clock = "14:31",
        highlight = nil,
        message = nil,
        content_mode = Constants.CONTENT_MODE_READING_FOLIO,
        show = {
            title = true, author = true, cover = true, chapter = true,
            page_number = true, percentage = true, progress_bar = true,
            chapter_time_left = true, book_time_left = true, total_time = true,
            today_time = true, battery = true, clock = true, highlights = true,
            custom_message = true,
        },
    }
    for key, value in pairs(overrides or {}) do data[key] = value end
    return data
end

-- Goes through the real Renderer:build, so the card returned here is assembled exactly
-- the way it is on the device -- including whether the shared footer was kept, which is
-- what decides if its clock may be registered at all.
local function render(style_id, data)
    local style = registry:resolve(style_id)
    assert(style, "no such style: " .. style_id)
    local runtime = {}
    local card = renderer:build(nil, nil, style, {
        runtime = runtime,
        data = data or fixtureData(),
    })
    return card, runtime
end

-- ----------------------------------------------------------------- every style builds

-- Walks the built card looking for a widget, so a registration can be checked against
-- what is actually on screen. Five styles used to register the shared footer's clock
-- while switching that footer off, i.e. they refreshed a widget that was never painted:
-- the time on the card never changed and the whole card was redrawn anyway.
local function reachable(node, target, seen)
    if node == target then return true end
    if type(node) ~= "table" then return false end
    seen = seen or {}
    if seen[node] then return false end
    seen[node] = true
    for _, child in pairs(node) do
        if type(child) == "table" and reachable(child, target, seen) then return true end
    end
    return false
end

local style_ids = {}
for _, style in ipairs(registry.ordered or {}) do
    -- The custom layout needs the FFI and a stored layout; it is out of scope here.
    if style.id ~= "custom" then table.insert(style_ids, style.id) end
end
check("the registry produced styles to render", #style_ids >= 15)

local registered = 0
for _, id in ipairs(style_ids) do
    local ok, card, runtime = pcall(render, id)
    check(id .. ": renders", ok and card ~= nil)
    if not ok then
        print("     " .. tostring(card))
    elseif runtime.clock_widget then
        registered = registered + 1
        check(id .. ": the registered clock is really on the card",
            reachable(card, runtime.clock_widget))
        check(id .. ": the registered clock shows the time",
            tostring(runtime.clock_widget.text or ""):find("14:31", 1, true) ~= nil)
        check(id .. ": a region to repaint comes with it",
            runtime.clock_region ~= nil)
        check(id .. ": the region wraps the clock",
            runtime.clock_region and reachable(runtime.clock_region, runtime.clock_widget))
        check(id .. ": the region is on the card too",
            reachable(card, runtime.clock_region))
    end
end
-- Ten styles show the time in a widget of their own: five through the shared footer,
-- five in a status row they build themselves. bookpost folds it into a date stamp and
-- is deliberately left static; the remaining four do not show a clock at all.
check("most styles register a refreshable clock (got " .. registered .. ")",
    registered == 10)

-- ------------------------------------------------- the clock text stays honest

for _, id in ipairs(style_ids) do
    local _, runtime = render(id)
    local widget, formatter = runtime.clock_widget, runtime.clock_format
    if widget then
        local before = widget.text
        if formatter then
            local rebuilt = formatter("14:32")
            check(id .. ": the formatter advances the time",
                rebuilt:find("14:32", 1, true) ~= nil)
            -- The bug this guards: setText'ing the bare time wiped everything else.
            check(id .. ": the formatter keeps the rest of the line",
                #rebuilt >= #before - 1)
            if before:find("87%%") then
                check(id .. ": the battery reading survives a refresh",
                    rebuilt:find("87%%") ~= nil)
            end
        else
            -- No formatter means the widget holds nothing but the time, so replacing
            -- its whole text is safe.
            check(id .. ": a formatter-less clock holds only the time",
                before == "14:31")
        end
    end
end

-- ------------------------------------------------------------ display toggles are honored

for _, id in ipairs(style_ids) do
    local data = fixtureData()
    data.show.battery = false
    data.battery = ""
    local _, runtime = render(id, data)
    local text = runtime.clock_widget and runtime.clock_widget.text or ""
    -- architecture/bookpost/dossier keep a fixed power slot and read battery_text on
    -- purpose; the others must not show a reading the reader switched off.
    if id ~= "architecture" and id ~= "bookpost" and id ~= "dossier" then
        check(id .. ": the battery toggle removes the reading",
            not text:find("87%%"))
    end
end

do
    local data = fixtureData()
    data.show.clock = false
    data.clock = ""
    for _, id in ipairs(style_ids) do
        local _, runtime = render(id, data)
        check(id .. ": no clock is registered when the clock is hidden",
            runtime.clock_widget == nil and runtime.clock_region == nil)
    end
end

print(string.format("style_render_spec: %s (%d checks, %d failures)",
    failures == 0 and "ok" or "FAILED", checks, failures))
if failures > 0 then error("style_render_spec failed", 0) end
