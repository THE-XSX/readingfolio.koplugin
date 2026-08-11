local item_path = debug.getinfo(1, "S").source:sub(2)
local PLUGIN_ROOT = item_path:match("(.*[/\\])") or "plugins/readingfolio.koplugin/"

local Background = dofile(PLUGIN_ROOT .. "rendering/background.lua")
local Constants = dofile(PLUGIN_ROOT .. "core/constants.lua")
local CustomLayout = dofile(PLUGIN_ROOT .. "rendering/custom_layout.lua")
local Data = dofile(PLUGIN_ROOT .. "core/data.lua")
local Editor = dofile(PLUGIN_ROOT .. "ui/editor.lua")
local FolioScene = dofile(PLUGIN_ROOT .. "core/folio_scene.lua")
local Menu = dofile(PLUGIN_ROOT .. "ui/menu.lua")
local Renderer = dofile(PLUGIN_ROOT .. "rendering/renderer.lua")
local Registry = dofile(PLUGIN_ROOT .. "styles/style_registry.lua")
local I18n = dofile(PLUGIN_ROOT .. "i18n/i18n.lua")
local menu_translate = I18n.new(PLUGIN_ROOT)
local display_translate = I18n.new(PLUGIN_ROOT, { language_setting = Constants.LANGUAGE_SETTING })

local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local datetime = require("datetime")
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
    self.runtime = {}
    local scene = self.plugin:_folioScene(self.ui)
    local selected_style = scene and self.plugin.registry:get(scene.style_id) or nil
    local receipt, style = self.plugin.renderer:build(self.ui, self.state, selected_style, {
        runtime = self.runtime,
        scene = scene,
    })
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
    self:_setupClockRefresh()
end

function QuickLook:_setupClockRefresh()
    if self.clock_refresh_action then return end
    local mode = G_reader_settings:readSetting(Constants.CLOCK_REFRESH_MODE) or "minute"
    if mode == "static" then return end
    if not self.runtime.clock_widget then return end
    self.clock_refresh_action = function()
        if not self.plugin or self.plugin.quick_look_widget ~= self then return end
        local clock = self.runtime.clock_widget
        if not clock then return end
        local text = datetime.secondsToHour(os.time(), G_reader_settings:isTrue("twelve_hour_clock"))
            or os.date("%H:%M")
        if clock.setText then
            clock:setText(text)
        elseif clock._inner and clock._inner.setText then
            clock._inner:setText(text)
        else
            clock.text = text
        end
        self.clock_refresh_count = (self.clock_refresh_count or 0) + 1
        local full_refresh_interval = tonumber(G_reader_settings:readSetting(
            Constants.CLOCK_FULL_REFRESH_INTERVAL
        )) or 30
        if full_refresh_interval > 0 and self.clock_refresh_count >= full_refresh_interval then
            self.clock_refresh_count = 0
            UIManager:setDirty(self, "full")
        else
            local waveform = G_reader_settings:readSetting(Constants.CLOCK_REFRESH_WAVEFORM)
            waveform = waveform == "fast" and "fast" or "ui"
            if clock.dimen then
                UIManager:widgetRepaint(clock, clock.dimen.x, clock.dimen.y)
                UIManager:setDirty(nil, waveform, clock.dimen:copy())
            else
                UIManager:setDirty(self, waveform)
            end
        end
        self:_scheduleNextClockRefresh()
    end
    self:_scheduleNextClockRefresh()
end

function QuickLook:_scheduleNextClockRefresh()
    if not self.clock_refresh_action then return end
    UIManager:scheduleIn(61 - tonumber(os.date("%S")), self.clock_refresh_action)
end

function QuickLook:_stopClockRefresh()
    if self.clock_refresh_action then
        UIManager:unschedule(self.clock_refresh_action)
        self.clock_refresh_action = nil
    end
end

function QuickLook:onClose()
    self:_stopClockRefresh()
    if self.plugin and self.plugin.quick_look_widget == self then
        self.plugin.quick_look_widget = nil
    end
    UIManager:close(self)
    return true
end

QuickLook.onTap = QuickLook.onClose
QuickLook.onMultiSwipe = QuickLook.onClose
QuickLook.onAnyKeyPressed = QuickLook.onClose

function QuickLook:onCloseWidget()
    self:_stopClockRefresh()
end

function QuickLook:onSuspend()
    self:_stopClockRefresh()
end

function QuickLook:onResume()
    if self.plugin and self.plugin.quick_look_widget == self then
        self:_setupClockRefresh()
    end
end

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
    self.custom_layout = CustomLayout.new(Constants)
    self.data_provider = Data.new(Constants, display_translate)
    self.renderer = Renderer.new{
        constants = Constants,
        data_provider = self.data_provider,
        registry = self.registry,
        translate = display_translate,
        custom_layout = self.custom_layout,
    }
    self.background = Background.new(Constants)
    self.folio_scene = FolioScene.new()
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

function ReadingFolio:_folioScene(ui)
    return self.folio_scene:resolve(ui,
        G_reader_settings:nilOrTrue(Constants.FOLLOW_FOLIO_SCENES))
end

function ReadingFolio:showCustomEditor()
    local ui = self.ui
    G_reader_settings:saveSetting(Constants.STYLE_SETTING, "custom")
    G_reader_settings:flush()
    if ui and ui.menu and ui.menu.onCloseReaderMenu then
        ui.menu:onCloseReaderMenu()
    end
    UIManager:nextTick(function()
        if not ui or not ui.document then return end
        if self.quick_look_widget then
            UIManager:close(self.quick_look_widget)
            self.quick_look_widget = nil
        end
        if self.custom_editor_widget then
            UIManager:close(self.custom_editor_widget)
        end
        self.custom_editor_widget = Editor:new{
            plugin = self,
            ui = ui,
            state = ui.view and ui.view.state,
            constants = Constants,
            translate = menu_translate,
        }
        UIManager:show(self.custom_editor_widget)
    end)
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

function ReadingFolio:getCustomPresets()
    local presets = G_reader_settings:readSetting(Constants.CUSTOM_PRESETS_SETTING)
    return type(presets) == "table" and presets or {}
end

function ReadingFolio:saveCustomPreset(name)
    if not name or name:match("%S") == nil then return false end
    local presets = self:getCustomPresets()
    presets[name] = {
        name = name,
        timestamp = os.time(),
        layout = self.custom_layout:get().items,
        bg_setting = G_reader_settings:readSetting(Constants.BG_SETTING),
        custom_bg_path = G_reader_settings:readSetting(Constants.CUSTOM_BG_PATH),
        bg_image_opacity = G_reader_settings:readSetting(Constants.BG_IMAGE_OPACITY_SETTING),
        bg_image_mode = G_reader_settings:readSetting(Constants.BG_IMAGE_MODE_SETTING),
        border = G_reader_settings:readSetting(Constants.BORDER),
        card_bg = G_reader_settings:readSetting(Constants.CARD_BG),
        shadow = G_reader_settings:readSetting(Constants.SHADOW),
        cover_scale = G_reader_settings:readSetting(Constants.COVER_SCALE_SETTING),
        card_ratio_mode = G_reader_settings:readSetting(Constants.CARD_RATIO_MODE),
        card_ratio_custom = G_reader_settings:readSetting(Constants.CARD_RATIO_CUSTOM),
        font_delta_big = G_reader_settings:readSetting(Constants.FONT_DELTA_BIG),
        font_delta_mid = G_reader_settings:readSetting(Constants.FONT_DELTA_MID),
        font_delta_small = G_reader_settings:readSetting(Constants.FONT_DELTA_SMALL),
    }
    G_reader_settings:saveSetting(Constants.CUSTOM_PRESETS_SETTING, presets)
    G_reader_settings:flush()
    return true
end

function ReadingFolio:applyCustomPreset(name)
    local presets = self:getCustomPresets()
    local preset = presets[name]
    if not preset then return false end
    if preset.layout then self.custom_layout:set(preset.layout) end
    local function restore(key, val)
        if val == nil then G_reader_settings:delSetting(key) else G_reader_settings:saveSetting(key, val) end
    end
    restore(Constants.BG_SETTING, preset.bg_setting)
    restore(Constants.CUSTOM_BG_PATH, preset.custom_bg_path)
    restore(Constants.BG_IMAGE_OPACITY_SETTING, preset.bg_image_opacity)
    restore(Constants.BG_IMAGE_MODE_SETTING, preset.bg_image_mode)
    restore(Constants.BORDER, preset.border)
    restore(Constants.CARD_BG, preset.card_bg)
    restore(Constants.SHADOW, preset.shadow)
    restore(Constants.COVER_SCALE_SETTING, preset.cover_scale)
    restore(Constants.CARD_RATIO_MODE, preset.card_ratio_mode)
    restore(Constants.CARD_RATIO_CUSTOM, preset.card_ratio_custom)
    restore(Constants.FONT_DELTA_BIG, preset.font_delta_big)
    restore(Constants.FONT_DELTA_MID, preset.font_delta_mid)
    restore(Constants.FONT_DELTA_SMALL, preset.font_delta_small)
    G_reader_settings:saveSetting(Constants.STYLE_SETTING, "custom")
    G_reader_settings:flush()
    self:showReceipt()
    return true
end

function ReadingFolio:deleteCustomPreset(name)
    local presets = self:getCustomPresets()
    if not presets[name] then return false end
    presets[name] = nil
    G_reader_settings:saveSetting(Constants.CUSTOM_PRESETS_SETTING, presets)
    G_reader_settings:flush()
    return true
end

function ReadingFolio:renameCustomPreset(old_name, new_name)
    if not new_name or new_name:match("%S") == nil or old_name == new_name then return false end
    local presets = self:getCustomPresets()
    if not presets[old_name] or presets[new_name] then return false end
    local data = presets[old_name]
    data.name = new_name
    presets[new_name] = data
    presets[old_name] = nil
    G_reader_settings:saveSetting(Constants.CUSTOM_PRESETS_SETTING, presets)
    G_reader_settings:flush()
    return true
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
    local scene = self:_folioScene(ui)
    local selected_style = scene and self.registry:get(scene.style_id) or self.renderer:selectedStyle()
    local landscape = selected_style and selected_style.defaults.landscape == true
    local use_screen_orientation = selected_style
        and selected_style.defaults.use_screen_orientation == true
    local with_gesture_lock = Device:isTouchDevice()
        and G_reader_settings:readSetting("screensaver_delay") == "gesture"
    local orig_dimen = with_gesture_lock and {
        w = Screen:getWidth(),
        h = Screen:getHeight(),
    } or nil
    Device.orig_rotation_mode = rotation
    if use_screen_orientation then
        Device.orig_rotation_mode = nil
        orig_dimen = nil
    elseif landscape and bit.band(rotation, 1) == 0 then
        Screen:setRotationMode(Screen.DEVICE_ROTATED_CLOCKWISE or 1)
    elseif not landscape and bit.band(rotation, 1) == 1 then
        Screen:setRotationMode(Screen.DEVICE_ROTATED_UPRIGHT)
    else
        Device.orig_rotation_mode = nil
        orig_dimen = nil
    end

    if Device:hasEinkScreen()
            and (not self.background:isTranslucent() or Device.orig_rotation_mode ~= nil) then
        Screen:clear()
        Screen:refreshFull(0, 0, Screen:getWidth(), Screen:getHeight())
        if Device:isKobo() and Device:isSunxi() then
            ffiUtil.usleep(150 * 1000)
        end
    end

    self.runtime = {}
    local receipt, style = self.renderer:build(ui, ui.view and ui.view.state, selected_style, {
        scene = scene,
        runtime = self.runtime,
    })
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
    self:_setupScreensaverClockRefresh(saver, self.runtime)
end

function ReadingFolio:_setupScreensaverClockRefresh(saver, runtime)
    if not saver or not runtime or not runtime.clock_widget then return end
    local mode = G_reader_settings:readSetting(Constants.CLOCK_REFRESH_MODE) or "minute"
    if mode == "static" then return end

    if saver._reading_folio_clock_timer then
        UIManager:unschedule(saver._reading_folio_clock_timer)
        saver._reading_folio_clock_timer = nil
    end

    local clock = runtime.clock_widget
    local count = 0

    local function refreshClock()
        if not saver.screensaver_widget or not clock then return end
        local now_str = datetime.secondsToHour(os.time(), G_reader_settings:isTrue("twelve_hour_clock"))
            or os.date("%H:%M")

        if clock.setText then
            clock:setText(now_str)
        elseif clock._inner and clock._inner.setText then
            clock._inner:setText(now_str)
        else
            clock.text = now_str
        end

        count = count + 1
        local full_refresh_interval = tonumber(G_reader_settings:readSetting(
            Constants.CLOCK_FULL_REFRESH_INTERVAL
        )) or 30

        if full_refresh_interval > 0 and count >= full_refresh_interval then
            count = 0
            UIManager:setDirty(saver.screensaver_widget, "full")
        else
            local waveform = G_reader_settings:readSetting(Constants.CLOCK_REFRESH_WAVEFORM)
            waveform = waveform == "fast" and "fast" or "ui"
            if clock.dimen then
                UIManager:widgetRepaint(clock, clock.dimen.x, clock.dimen.y)
                UIManager:setDirty(nil, waveform, clock.dimen:copy())
            else
                UIManager:setDirty(saver.screensaver_widget, waveform)
            end
        end

        local delay = 61 - tonumber(os.date("%S"))
        saver._reading_folio_clock_timer = UIManager:scheduleIn(delay, refreshClock)
    end

    local delay = 61 - tonumber(os.date("%S"))
    saver._reading_folio_clock_timer = UIManager:scheduleIn(delay, refreshClock)
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
        local orig_close = Screensaver.close or Screensaver.hide
        if orig_close then
            Screensaver._reading_folio_original_close = orig_close
            Screensaver.close = function(saver)
                if saver and saver._reading_folio_clock_timer then
                    UIManager:unschedule(saver._reading_folio_clock_timer)
                    saver._reading_folio_clock_timer = nil
                end
                return Screensaver._reading_folio_original_close(saver)
            end
        end
    end
    Screensaver._reading_folio_plugin = self
end

return ReadingFolio
