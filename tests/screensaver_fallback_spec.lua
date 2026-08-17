-- Sleep-screen fallback: while handing the screen back to KOReader's own screensaver, the
-- plugin temporarily swaps G_reader_settings.readSetting so the stock code reads a usable
-- screensaver_type. That stub is process-global state, so it has to come off again on every
-- path out — including when setup() throws, which used to leave it installed for the rest
-- of the session and skew every later settings read.

local Support = dofile("tests/support.lua")

local settings = Support.settings({
    screensaver_type = "reading_folio",
    screensaver_dir = "/mnt/onboard/screensavers",
})

local exports = Support.slice("main.lua",
    "local function fallbackType()",
    "function ReadingFolio:_showScreensaver(",
    "return { fallbackType = fallbackType, fallbackScreensaver = fallbackScreensaver }",
    {
        G_reader_settings = settings,
        -- No paths exist in the harness, so fallbackType() lands on "random_image".
        lfs = { attributes = function() return nil end },
    })

local fallbackScreensaver = exports.fallbackScreensaver
Support.check("fallbackType picks a stock screensaver type",
    exports.fallbackType() == "random_image")

local function freshSaver(overrides)
    local saver = {
        screensaver_type = "reading_folio",
        event_message = "Sleeping",
        setup = function() end,
    }
    for key, value in pairs(overrides or {}) do saver[key] = value end
    return saver
end

local function assertClean(label)
    Support.check(label .. ": no readSetting stub left behind",
        rawget(settings, "readSetting") == nil)
    Support.check(label .. ": screensaver_type reads through again",
        settings:readSetting("screensaver_type") == "reading_folio")
end

-- 1. Happy path.
local seen_during_show
local saver = freshSaver()
fallbackScreensaver(saver, function(self)
    seen_during_show = settings:readSetting("screensaver_type")
    Support.check("show() sees the fallback type on the saver",
        self.screensaver_type == "random_image")
end)
Support.check("show() reads the fallback type from settings", seen_during_show == "random_image")
Support.check("the saver's original type is restored",
    saver.screensaver_type == "reading_folio")
assertClean("happy path")

-- 2. setup() throws. This is the leak that was reported: the restore sat after the call.
local reached_show = false
saver = freshSaver{ setup = function() error("setup blew up") end }
local ok, err = pcall(fallbackScreensaver, saver, function() reached_show = true end)
Support.check("a setup() error still propagates", ok == false)
Support.check("the original error survives",
    type(err) == "string" and err:find("setup blew up", 1, true) ~= nil)
Support.check("show() is skipped when setup() fails", reached_show == false)
Support.check("the saver's type is restored after a setup() error",
    saver.screensaver_type == "reading_folio")
assertClean("setup error")

-- 3. show() throws.
saver = freshSaver()
ok, err = pcall(fallbackScreensaver, saver, function() error("show blew up") end)
Support.check("a show() error still propagates", ok == false)
Support.check("the original show error survives",
    type(err) == "string" and err:find("show blew up", 1, true) ~= nil)
assertClean("show error")

-- 4. Prefixed savers ask for a namespaced key; both spellings must answer the fallback.
local prefixed_keys = {}
saver = freshSaver{ prefix = "menu_" }
fallbackScreensaver(saver, function()
    prefixed_keys.prefixed = settings:readSetting("menu_screensaver_type")
    prefixed_keys.plain = settings:readSetting("screensaver_type")
    prefixed_keys.other = settings:readSetting("screensaver_dir")
end)
Support.check("the prefixed key answers the fallback",
    prefixed_keys.prefixed == "random_image")
Support.check("the plain key answers the fallback", prefixed_keys.plain == "random_image")
Support.check("unrelated keys still read through",
    prefixed_keys.other == "/mnt/onboard/screensavers")
assertClean("prefixed saver")

-- 5. A saver with no setup() at all must not break the contract.
saver = freshSaver{ setup = nil }
fallbackScreensaver(saver, function() end)
Support.check("a saver without setup() still runs",
    saver.screensaver_type == "reading_folio")
assertClean("no setup")

-- 6. An own readSetting field (something else already wrapping it) must be handed back.
local sentinel = function(self, key, default) return Support.settings.__wrapped end
settings.readSetting = sentinel
saver = freshSaver()
pcall(fallbackScreensaver, saver, function() error("boom") end)
Support.check("an existing wrapper is restored, not dropped",
    rawget(settings, "readSetting") == sentinel)
settings.readSetting = nil

print("screensaver_fallback_spec: ok")
