-- The per-minute clock refresh, end to end, minus the widgets.
--
-- Four separate defects lived here and each one is checked below:
--   * the screensaver stored `UIManager:scheduleIn(...)`, which returns nothing, so the
--     "already running?" guard never fired and every suspend added another chain;
--   * the partial-refresh branch tested `clock.dimen`, which a TextWidget never sets, so
--     "local refresh" always redrew the whole card once a minute;
--   * several styles keep the time in a widget shared with the battery reading, and
--     setText'ing the bare time deleted the rest of the line;
--   * the fallback for a style without a registered region has to stay whole-card.
--
-- Run from the plugin root: python3 runlua.py <plugin_dir> <plugin_dir>/tests/clock_refresh_spec.lua

local Support = dofile("tests/support.lua")
local check = Support.check

local MAIN = "main.lua"

local function newUIManager()
    local ui = { scheduled = {}, dirty = {}, repaints = {} }
    function ui:scheduleIn(delay, action)
        table.insert(self.scheduled, { delay = delay, action = action })
        -- The real one returns nothing. Keeping that here is the point: a spec that
        -- handed back a handle would have let the original bug pass.
    end
    function ui:unschedule(action)
        local kept = {}
        for _, entry in ipairs(self.scheduled) do
            if entry.action ~= action then table.insert(kept, entry) end
        end
        local removed = #self.scheduled - #kept
        self.scheduled = kept
        return removed
    end
    function ui:setDirty(widget, waveform, area)
        table.insert(self.dirty, { widget = widget, waveform = waveform, area = area })
    end
    function ui:widgetRepaint(widget, x, y)
        table.insert(self.repaints, { widget = widget, x = x, y = y })
    end
    function ui:runAll()
        local due = self.scheduled
        self.scheduled = {}
        for _, entry in ipairs(due) do entry.action() end
        return #due
    end
    return ui
end

local function newRegion(x, y, w, h, reserved)
    local dimen = { x = x, y = y, w = w, h = h }
    function dimen:copy() return { x = self.x, y = self.y, w = self.w, h = self.h } end
    return { dimen = dimen, width = reserved }
end

local function newTextWidget(text)
    local widget = { text = text }
    function widget:setText(value) self.text = value end
    return widget
end

local CONSTANTS = {
    CLOCK_REFRESH_MODE = "reading_folio_clock_refresh_mode",
    CLOCK_REFRESH_WAVEFORM = "reading_folio_clock_refresh_waveform",
    CLOCK_FULL_REFRESH_INTERVAL = "reading_folio_clock_full_refresh_interval",
}

-- The helpers sit between these two anchors at the top of main.lua.
local function loadHelpers(settings, uimanager)
    return Support.slice(MAIN,
        "local function currentClockText()",
        "local QuickLook = InputContainer:extend{",
        [[return {
            currentClockText = currentClockText,
            applyClockText = applyClockText,
            refreshClockRegion = refreshClockRegion,
            clockFullRefreshInterval = clockFullRefreshInterval,
        }]],
        {
            Constants = CONSTANTS,
            G_reader_settings = settings,
            UIManager = uimanager,
            Device = { screen = {} },
            datetime = {
                secondsToHour = function() return "14:32" end,
            },
        })
end

-- ---------------------------------------------------------------- applyClockText

do
    local ui = newUIManager()
    local H = loadHelpers(Support.settings(), ui)

    local plain = newTextWidget("09:41")
    check("no formatter: the widget gets the bare time",
        H.applyClockText({ clock_widget = plain }) == true and plain.text == "14:32")

    -- swiss/ju/lan/mei/zhu all share one widget between the clock and the battery
    -- reading; the formatter is how the whole line survives a refresh.
    local shared = newTextWidget("87%  09:41")
    local runtime = {
        clock_widget = shared,
        clock_format = function(now) return "87%  " .. now end,
    }
    H.applyClockText(runtime)
    check("formatter rebuilds the line, battery reading intact",
        shared.text == "87%  14:32")

    local thrower = newTextWidget("09:41")
    H.applyClockText({
        clock_widget = thrower,
        clock_format = function() error("style blew up") end,
    })
    check("a formatter that throws falls back to the bare time",
        thrower.text == "14:32")

    local wrong_type = newTextWidget("09:41")
    H.applyClockText({
        clock_widget = wrong_type,
        clock_format = function() return 42 end,
    })
    check("a formatter returning a non-string is ignored",
        wrong_type.text == "14:32")

    check("no registered clock reports failure rather than erroring",
        H.applyClockText({}) == false and H.applyClockText(nil) == false)

    local inner = newTextWidget("09:41")
    local wrapper = { _inner = inner }
    H.applyClockText({ clock_widget = wrapper })
    check("a wrapper delegating through _inner still updates", inner.text == "14:32")
end

-- ------------------------------------------------------------ refreshClockRegion

do
    local ui = newUIManager()
    local settings = Support.settings()
    local H = loadHelpers(settings, ui)

    local region = newRegion(10, 200, 300, 24, 340)
    H.refreshClockRegion({ clock_region = region }, "whole-card")

    check("the region is repainted where it was painted",
        #ui.repaints == 1 and ui.repaints[1].widget == region
            and ui.repaints[1].x == 10 and ui.repaints[1].y == 200)

    local dirty = ui.dirty[1]
    check("only the clock's own area is marked dirty, not a widget",
        #ui.dirty == 1 and dirty.widget == nil and type(dirty.area) == "table")
    check("the dirty area starts at the region",
        dirty.area.x == 10 and dirty.area.y == 200 and dirty.area.h == 24)
    -- 12:59 -> 1:00 makes the row narrower; the reserved width keeps the discarded
    -- digit inside the refreshed area instead of stranding it on screen.
    check("the reserved width widens the dirty area", dirty.area.w == 340)
    check("the default waveform is ui", dirty.waveform == "ui")

    settings:saveSetting(CONSTANTS.CLOCK_REFRESH_WAVEFORM, "fast")
    H.refreshClockRegion({ clock_region = newRegion(0, 0, 50, 10) }, "whole-card")
    check("the fast waveform is honored", ui.dirty[2].waveform == "fast")
    check("without a reserved width the region's own width is used",
        ui.dirty[2].area.w == 50)
end

do
    local ui = newUIManager()
    local H = loadHelpers(Support.settings(), ui)

    -- The custom layout registers no region: its clock blits a transparent mask over
    -- whatever is beneath, so repainting that widget alone would leave the previous
    -- minute showing through. It does record where it was painted, though, so the whole
    -- card is repainted and only the clock's rectangle is pushed to the panel.
    local clock = newTextWidget("14:32")
    clock.dimen = { x = 30, y = 400, w = 80, h = 22 }
    function clock.dimen:copy() return { x = self.x, y = self.y, w = self.w, h = self.h } end
    H.refreshClockRegion({ clock_widget = clock }, "whole-card")
    check("a positioned clock with no region repaints the card, not the widget",
        #ui.repaints == 0 and #ui.dirty == 1 and ui.dirty[1].widget == "whole-card")
    check("but still refreshes only the clock's rectangle",
        ui.dirty[1].area ~= nil and ui.dirty[1].area.x == 30 and ui.dirty[1].area.w == 80)

    -- Nothing to aim at: the whole card it is.
    H.refreshClockRegion({ clock_widget = newTextWidget("14:32") }, "whole-card")
    check("a clock that was never painted falls back to the whole card",
        #ui.repaints == 0 and ui.dirty[2].widget == "whole-card" and ui.dirty[2].area == nil)

    local unpainted = { dimen = nil, width = 100 }
    H.refreshClockRegion({ clock_region = unpainted }, "whole-card")
    check("a region that was never painted falls back too",
        #ui.repaints == 0 and ui.dirty[3].widget == "whole-card")
end

-- --------------------------------------------------- the screensaver clock chain

local function loadScreensaverClock(settings, uimanager, helpers)
    local ReadingFolio = {}
    Support.slice(MAIN,
        "function ReadingFolio:_setupScreensaverClockRefresh(saver, runtime)",
        "function ReadingFolio:_installScreensaverAdapter()",
        "return true",
        {
            ReadingFolio = ReadingFolio,
            Constants = CONSTANTS,
            G_reader_settings = settings,
            UIManager = uimanager,
            applyClockText = helpers.applyClockText,
            refreshClockRegion = helpers.refreshClockRegion,
            clockFullRefreshInterval = helpers.clockFullRefreshInterval,
        })
    return ReadingFolio
end

local function newRuntime()
    return {
        clock_widget = newTextWidget("09:41"),
        clock_region = newRegion(0, 0, 100, 20, 120),
    }
end

do
    local ui = newUIManager()
    local settings = Support.settings()
    local plugin = loadScreensaverClock(settings, ui, loadHelpers(settings, ui))

    local saver = { screensaver_widget = {} }
    plugin:_setupScreensaverClockRefresh(saver, newRuntime())
    check("the default (unset) mode schedules nothing", #ui.scheduled == 0)
end

do
    local ui = newUIManager()
    local settings = Support.settings({ [CONSTANTS.CLOCK_REFRESH_MODE] = "minute" })
    local plugin = loadScreensaverClock(settings, ui, loadHelpers(settings, ui))

    local saver = { screensaver_widget = {} }
    plugin:_setupScreensaverClockRefresh(saver, newRuntime())
    check("minute mode schedules one refresh", #ui.scheduled == 1)
    check("the scheduled action is remembered on the saver",
        saver._reading_folio_clock_action == ui.scheduled[1].action)

    -- Screensaver is a singleton: this is the same table on the next suspend.
    saver.screensaver_widget = {}
    plugin:_setupScreensaverClockRefresh(saver, newRuntime())
    check("a second setup replaces the chain instead of adding one",
        #ui.scheduled == 1)

    ui:runAll()
    check("one tick reschedules exactly one successor", #ui.scheduled == 1)

    plugin:_stopScreensaverClockRefresh(saver)
    check("stopping unschedules the chain",
        #ui.scheduled == 0 and saver._reading_folio_clock_action == nil)

    plugin:_stopScreensaverClockRefresh(saver)
    check("stopping twice is harmless", #ui.scheduled == 0)
end

do
    local ui = newUIManager()
    local settings = Support.settings({ [CONSTANTS.CLOCK_REFRESH_MODE] = "minute" })
    local plugin = loadScreensaverClock(settings, ui, loadHelpers(settings, ui))

    local saver = { screensaver_widget = {} }
    local runtime = newRuntime()
    plugin:_setupScreensaverClockRefresh(saver, runtime)

    ui:runAll()
    check("a tick repaints the clock region, not the screensaver widget",
        #ui.repaints == 1 and ui.dirty[1].widget == nil)
    check("the tick wrote the new time", runtime.clock_widget.text == "14:32")

    -- Whatever else happens, a chain must die once its screensaver is gone.
    saver.screensaver_widget = nil
    ui:runAll()
    check("the chain stops when the screensaver closes", #ui.scheduled == 0)
end

do
    local ui = newUIManager()
    local settings = Support.settings({
        [CONSTANTS.CLOCK_REFRESH_MODE] = "minute",
        [CONSTANTS.CLOCK_FULL_REFRESH_INTERVAL] = 2,
    })
    local plugin = loadScreensaverClock(settings, ui, loadHelpers(settings, ui))

    local saver = { screensaver_widget = {} }
    plugin:_setupScreensaverClockRefresh(saver, newRuntime())

    ui:runAll()
    ui:runAll()
    local last = ui.dirty[#ui.dirty]
    check("the periodic full refresh flashes the screensaver widget",
        last.waveform == "full" and last.widget == saver.screensaver_widget)

    settings:saveSetting(CONSTANTS.CLOCK_FULL_REFRESH_INTERVAL, 0)
    local before = #ui.dirty
    ui:runAll()
    ui:runAll()
    ui:runAll()
    local any_full = false
    for i = before + 1, #ui.dirty do
        if ui.dirty[i].waveform == "full" then any_full = true end
    end
    check("an interval of 0 turns the periodic full refresh off", not any_full)
end

print("clock_refresh_spec: ok")
