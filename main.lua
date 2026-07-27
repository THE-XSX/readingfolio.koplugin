local item_path = debug.getinfo(1, "S").source:sub(2)
local PLUGIN_ROOT = item_path:match("(.*[/\\])") or "plugins/readingfolio.koplugin/"

local Background = dofile(PLUGIN_ROOT .. "background.lua")
local Constants = dofile(PLUGIN_ROOT .. "constants.lua")
local Data = dofile(PLUGIN_ROOT .. "data.lua")
local Menu = dofile(PLUGIN_ROOT .. "menu.lua")
local Renderer = dofile(PLUGIN_ROOT .. "renderer.lua")
local Registry = dofile(PLUGIN_ROOT .. "style_registry.lua")
local I18n = dofile(PLUGIN_ROOT .. "i18n.lua")
local translate = I18n.new(PLUGIN_ROOT, { language_setting = Constants.LANGUAGE_SETTING })

local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local Font = require("ui/font")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local ReaderUI = require("apps/reader/readerui")
local Screensaver = require("ui/screensaver")
local ScreenSaverWidget = require("ui/widget/screensaverwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local bit = require("bit")

local Screen = Device.screen

local QuickLook = InputContainer:extend{
    modal = true,
    name = "reading_folio_quick_look",
    covers_fullscreen = true,
}

function QuickLook:init()
    self.dimen = Screen:getSize()
    local receipt, style = self.plugin.renderer:build(self.ui, self.state)
    if receipt then
        self[1] = self.plugin.background:compose(self.ui, receipt, style.defaults.dark)
    else
        self[1] = CenterContainer:new{
            dimen = self.dimen,
            TextWidget:new{ text = translate("Reading Folio unavailable"), face = Font:getFace("cfont", 20) },
        }
    end
    if Device:hasKeys() then
        self.key_events.AnyKeyPressed = {{ Device.input.group.Any }}
    end
    if Device:isTouchDevice() then
        local function fullScreenGesture(name)
            return GestureRange:new{ ges = name, range = function() return self.dimen end }
        end
        self.ges_events.Tap = { fullScreenGesture("tap") }
        self.ges_events.Swipe = { fullScreenGesture("swipe") }
        self.ges_events.MultiSwipe = { fullScreenGesture("multiswipe") }
    end
end

function QuickLook:onClose()
    UIManager:close(self)
    return true
end

QuickLook.onTap = QuickLook.onClose
QuickLook.onMultiSwipe = QuickLook.onClose
QuickLook.onAnyKeyPressed = QuickLook.onClose

-- Diagonal swipes forward KOReader's screenshot action (same gesture as in
-- the reader) so the preview itself can be captured; other swipes close it.
function QuickLook:onSwipe(_, ges)
    local direction = ges and ges.direction
    if direction == "northeast" or direction == "northwest"
            or direction == "southeast" or direction == "southwest" then
        if self.ui then
            self.ui:handleEvent(Event:new("Screenshot"))
        end
        return true
    end
    return self:onClose()
end

local ReadingFolio = WidgetContainer:extend{
    name = "readingfolio",
    is_doc_only = true,
}

function ReadingFolio:init()
    self.registry = Registry.new(PLUGIN_ROOT)
    self.data_provider = Data.new(Constants, translate)
    self.renderer = Renderer.new{
        constants = Constants,
        data_provider = self.data_provider,
        registry = self.registry,
        translate = translate,
    }
    self.background = Background.new(Constants)
    self.menu_builder = Menu.new{
        constants = Constants,
        registry = self.registry,
        translate = translate,
    }
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)
    self:_installScreensaverAdapter()
    math.randomseed(os.time())
end

function ReadingFolio:onDispatcherRegisterActions()
    Dispatcher:registerAction("reading_folio_preview", {
        category = "none",
        event = "ShowReadingFolio",
        title = translate("Reading Folio"),
        reader = true,
    })
    Dispatcher:registerAction("reading_folio_quicklook", {
        category = "none",
        event = "QuickLook",
        title = translate("Reading Folio"),
        reader = true,
    })
end

function ReadingFolio:onShowReadingFolio()
    self:showReceipt()
end

ReadingFolio.onQuickLook = ReadingFolio.onShowReadingFolio

function ReadingFolio:showReceipt()
    local ui = self.ui
    UIManager:nextTick(function()
        if not ui or not ui.document then return end
        UIManager:show(QuickLook:new{
            plugin = self,
            ui = ui,
            state = ui.view and ui.view.state,
        })
    end)
end

function ReadingFolio:addToMainMenu(menu_items)
    menu_items.reading_folio = {
        sorting_hint = "tools",
        text = translate("Reading Folio"),
        sub_item_table = self.menu_builder:items(self),
    }
end

local function fallbackType()
    local random_directory = G_reader_settings:readSetting("screensaver_dir")
    if random_directory and lfs.attributes(random_directory, "mode") == "directory" then
        return "random_image"
    end
    local document_cover = G_reader_settings:readSetting("screensaver_document_cover")
    if document_cover and lfs.attributes(document_cover, "mode") == "file" then
        return "document_cover"
    end
    local last_file = G_reader_settings:readSetting("lastfile")
    if last_file and lfs.attributes(last_file, "mode") == "file" then return "cover" end
    return "random_image"
end

local function fallbackScreensaver(saver, original_show)
    local settings = G_reader_settings
    local original_type = saver.screensaver_type
    local fallback = fallbackType()
    local had_setting = settings:has("screensaver_type")
    local saved_setting = settings:readSetting("screensaver_type")
    settings:saveSetting("screensaver_type", fallback)

    local prefixed_key = saver.prefix and saver.prefix ~= "" and (saver.prefix .. "screensaver_type") or nil
    local had_prefixed, saved_prefixed
    if prefixed_key then
        had_prefixed = settings:has(prefixed_key)
        saved_prefixed = settings:readSetting(prefixed_key)
        settings:saveSetting(prefixed_key, fallback)
    end

    local event = saver.prefix and saver.prefix ~= "" and saver.prefix:sub(1, -2) or nil
    saver:setup(event, saver.event_message)
    saver.screensaver_type = fallback
    original_show(saver)

    if prefixed_key then
        if had_prefixed then settings:saveSetting(prefixed_key, saved_prefixed)
        else settings:delSetting(prefixed_key) end
    end
    if had_setting then settings:saveSetting("screensaver_type", saved_setting)
    else settings:delSetting("screensaver_type") end
    saver.screensaver_type = original_type
end

function ReadingFolio:_showScreensaver(saver, original_show)
    local ui = saver.ui or ReaderUI.instance
    if not ui or not ui.document then
        fallbackScreensaver(saver, original_show)
        return
    end
    if saver.screensaver_widget then
        UIManager:close(saver.screensaver_widget)
        saver.screensaver_widget = nil
    end

    Device.screen_saver_mode = true
    local rotation = Screen:getRotationMode()
    local landscape = self.renderer:prefersLandscape()
    Device.orig_rotation_mode = rotation
    if landscape and bit.band(rotation, 1) == 0 then
        Screen:setRotationMode(Screen.DEVICE_ROTATED_CLOCKWISE or 1)
    elseif not landscape and bit.band(rotation, 1) == 1 then
        Screen:setRotationMode(Screen.DEVICE_ROTATED_UPRIGHT)
    else
        Device.orig_rotation_mode = nil
    end

    local receipt, style = self.renderer:build(ui, ui.view and ui.view.state)
    if not receipt then
        logger.warn("Reading Folio: render failed; using the default screensaver")
        fallbackScreensaver(saver, original_show)
        return
    end
    local composed = self.background:compose(ui, receipt, style.defaults.dark)
    saver.screensaver_widget = ScreenSaverWidget:new{
        widget = composed,
        covers_fullscreen = true,
    }
    saver.screensaver_widget.modal = true
    saver.screensaver_widget.dithered = true
    UIManager:show(saver.screensaver_widget, "full")
end

function ReadingFolio:_installScreensaverAdapter()
    if not Screensaver._reading_folio_original_show then
        Screensaver._reading_folio_original_show = Screensaver.show
        Screensaver.show = function(saver)
            local plugin = Screensaver._reading_folio_plugin
            if not plugin or saver.screensaver_type ~= "reading_folio" then
                return Screensaver._reading_folio_original_show(saver)
            end
            return plugin:_showScreensaver(saver, Screensaver._reading_folio_original_show)
        end
    end
    Screensaver._reading_folio_plugin = self
end

return ReadingFolio
