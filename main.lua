local item_path = debug.getinfo(1, "S").source:sub(2)
local PLUGIN_ROOT = item_path:match("(.*[/\\])") or "plugins/readingfolio.koplugin/"

local Background = dofile(PLUGIN_ROOT .. "background.lua")
local Constants = dofile(PLUGIN_ROOT .. "constants.lua")
local Data = dofile(PLUGIN_ROOT .. "data.lua")
local Menu = dofile(PLUGIN_ROOT .. "menu.lua")
local Renderer = dofile(PLUGIN_ROOT .. "renderer.lua")
local Registry = dofile(PLUGIN_ROOT .. "style_registry.lua")
local I18n = dofile(PLUGIN_ROOT .. "i18n.lua")
local menu_translate = I18n.new(PLUGIN_ROOT)
local display_translate = I18n.new(PLUGIN_ROOT, { language_setting = Constants.LANGUAGE_SETTING })

local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local ffiUtil = require("ffi/util")
local Font = require("ui/font")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local ReaderUI = require("apps/reader/readerui")
local Screensaver = require("ui/screensaver")
local ScreenSaverLockWidget = require("ui/widget/screensaverlockwidget")
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
            TextWidget:new{ text = menu_translate("Reading Folio unavailable"), face = Font:getFace("cfont", 20) },
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
    if self.plugin and self.plugin.quick_look_widget == self then
        self.plugin.quick_look_widget = nil
    end
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
    self.data_provider = Data.new(Constants, display_translate)
    self.renderer = Renderer.new{
        constants = Constants,
        data_provider = self.data_provider,
        registry = self.registry,
        translate = display_translate,
    }
    self.background = Background.new(Constants)
    self.menu_builder = Menu.new{
        constants = Constants,
        registry = self.registry,
        translate = menu_translate,
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
        title = menu_translate("Reading Folio"),
        reader = true,
    })
end

function ReadingFolio:onShowReadingFolio()
    self:showReceipt()
end

function ReadingFolio:showReceipt()
    local ui = self.ui
    UIManager:nextTick(function()
        if not ui or not ui.document then return end
        if self.quick_look_widget then
            UIManager:close(self.quick_look_widget)
            self.quick_look_widget = nil
        end
        self.quick_look_widget = QuickLook:new{
            plugin = self,
            ui = ui,
            state = ui.view and ui.view.state,
        }
        UIManager:show(self.quick_look_widget)
    end)
end

function ReadingFolio:addToMainMenu(menu_items)
    menu_items.reading_folio = {
        sorting_hint = "tools",
        text = menu_translate("Reading Folio"),
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
    local prefixed_key = saver.prefix and saver.prefix ~= "" and (saver.prefix .. "screensaver_type") or nil

    local orig_readSetting = settings.readSetting
    settings.readSetting = function(self, key, default)
        if key == "screensaver_type" or (prefixed_key and key == prefixed_key) then
            return fallback
        end
        return orig_readSetting(self, key, default)
    end

    local event = saver.prefix and saver.prefix ~= "" and saver.prefix:sub(1, -2) or nil
    if type(saver.setup) == "function" then
        saver:setup(event, saver.event_message)
    end
    saver.screensaver_type = fallback

    local ok, err = pcall(original_show, saver)

    settings.readSetting = orig_readSetting
    saver.screensaver_type = original_type

    if not ok then
        error(err)
    end
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
    if saver.screensaver_lock_widget then
        UIManager:close(saver.screensaver_lock_widget)
        saver.screensaver_lock_widget = nil
    end

    Device.screen_saver_mode = true
    local rotation = Screen:getRotationMode()
    local selected_style = self.renderer:selectedStyle()
    local landscape = selected_style and selected_style.defaults.landscape == true
    local with_gesture_lock = Device:isTouchDevice()
        and G_reader_settings:readSetting("screensaver_delay") == "gesture"
    local orig_dimen = with_gesture_lock and {
        w = Screen:getWidth(),
        h = Screen:getHeight(),
    } or nil
    Device.orig_rotation_mode = rotation
    if landscape and bit.band(rotation, 1) == 0 then
        Screen:setRotationMode(Screen.DEVICE_ROTATED_CLOCKWISE or 1)
    elseif not landscape and bit.band(rotation, 1) == 1 then
        Screen:setRotationMode(Screen.DEVICE_ROTATED_UPRIGHT)
    else
        Device.orig_rotation_mode = nil
        orig_dimen = nil
    end

    local bg_setting = G_reader_settings:readSetting(Constants.BG_SETTING) or "white"
    if Device:hasEinkScreen() and (bg_setting ~= "transparent" or Device.orig_rotation_mode ~= nil) then
        Screen:clear()
        Screen:refreshFull(0, 0, Screen:getWidth(), Screen:getHeight())
        if Device:isKobo() and Device:isSunxi() then
            ffiUtil.usleep(150 * 1000)
        end
    end

    local receipt, style = self.renderer:build(ui, ui.view and ui.view.state, selected_style)
    if not receipt then
        logger.warn("Reading Folio: render failed; using the default screensaver")
        if Device.orig_rotation_mode then
            Screen:setRotationMode(Device.orig_rotation_mode)
            Device.orig_rotation_mode = nil
        end
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
    if with_gesture_lock then
        saver.screensaver_lock_widget = ScreenSaverLockWidget:new{
            ui = ui,
            orig_dimen = orig_dimen,
        }
        UIManager:show(saver.screensaver_lock_widget)
    end
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
