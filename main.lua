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
local ThemeBundle = dofile(PLUGIN_ROOT .. "core/theme_bundle.lua")
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

local Screen = Device.screen

local function currentClockText()
    return datetime.secondsToHour(os.time(), G_reader_settings:isTrue("twelve_hour_clock"))
        or os.date("%H:%M")
end

-- Writes the new time into the widget the style registered. Several styles put the time
-- in a widget they share with the battery reading or the page count, and those register
-- a formatter that rebuilds the whole line -- calling setText with just the time there
-- used to delete everything else on the row at the first refresh.
local function applyClockText(runtime)
    local clock = runtime and runtime.clock_widget
    if not clock then return false end
    local text = currentClockText()
    if runtime.clock_format then
        local ok, rebuilt = pcall(runtime.clock_format, text)
        if ok and type(rebuilt) == "string" then text = rebuilt end
    end
    if clock.setText then
        clock:setText(text)
    elseif clock._inner and clock._inner.setText then
        clock._inner:setText(text)
    else
        clock.text = text
    end
    return true
end

-- Repaints just the row the clock sits in. The region is the frame the renderer wraps
-- that row in: a bare TextWidget never records where it was painted, so this branch was
-- unreachable for every built-in style before and "local refresh" always redrew the
-- whole card -- once a minute, on an e-ink screen.
local function refreshClockRegion(runtime, fallback_widget)
    local waveform = G_reader_settings:readSetting(Constants.CLOCK_REFRESH_WAVEFORM)
    waveform = waveform == "fast" and "fast" or "ui"
    local region = runtime and runtime.clock_region
    if region and region.dimen then
        UIManager:widgetRepaint(region, region.dimen.x, region.dimen.y)
        local area = region.dimen:copy()
        -- dimen only covers what the row measures right now; the frame reserves a fixed
        -- width so a time that got narrower cannot strand its old digits outside it.
        area.w = math.max(area.w, region.width or 0)
        UIManager:setDirty(nil, waveform, area)
        return
    end
    -- The custom layout registers no region on purpose. Its clock paints itself as a
    -- transparent mask blitted straight over whatever is beneath -- often a wallpaper
    -- image -- so repainting that widget alone leaves the previous minute's glyphs
    -- showing through, and a solid background frame would erase the wallpaper instead.
    -- Hand the whole card to setDirty and let it paint in full: the region argument only
    -- limits what gets pushed to the panel, so the refresh still costs one small
    -- rectangle rather than a full screen.
    local clock = runtime and runtime.clock_widget
    local dimen = clock and clock.dimen
    if dimen then
        UIManager:setDirty(fallback_widget, waveform,
            dimen.copy and dimen:copy() or dimen)
    else
        UIManager:setDirty(fallback_widget, waveform)
    end
end

local function clockFullRefreshInterval()
    return tonumber(G_reader_settings:readSetting(Constants.CLOCK_FULL_REFRESH_INTERVAL)) or 30
end

local QuickLook = InputContainer:extend{
    modal = true,
    name = "reading_folio_quick_look",
    covers_fullscreen = true,
}

function QuickLook:init()
    self.dimen = Screen:getSize()
    self.runtime = {}
    local scene = self.plugin:_folioScene(self.ui)
    local selected_style = self.custom_style
    if type(selected_style) == "string" then
        selected_style = self.plugin.registry:resolve(selected_style)
    end
    if not selected_style and scene and scene.style_id then
        selected_style = self.plugin.registry:resolve(scene.style_id)
    end
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
    -- Static unless the reader asked otherwise. The menu already marks "Static" as the
    -- default and shows it checked while this key is unset, so defaulting to "minute" here
    -- meant a partial refresh every minute -- plus a full flash on the periodic counter --
    -- for someone who never opened the submenu.
    local mode = G_reader_settings:readSetting(Constants.CLOCK_REFRESH_MODE) or "static"
    if mode == "static" then return end
    if not self.runtime.clock_widget then return end
    self.clock_refresh_action = function()
        if not self.plugin or self.plugin.quick_look_widget ~= self then return end
        if not applyClockText(self.runtime) then return end
        self.clock_refresh_count = (self.clock_refresh_count or 0) + 1
        local full_refresh_interval = clockFullRefreshInterval()
        if full_refresh_interval > 0 and self.clock_refresh_count >= full_refresh_interval then
            self.clock_refresh_count = 0
            UIManager:setDirty(self, "full")
        else
            refreshClockRegion(self.runtime, self)
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
    self.theme_bundle = ThemeBundle.new(Constants, "1.6.0")
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

function ReadingFolio:restoreRotationMode()
    if Device.orig_rotation_mode then
        Screen:setRotationMode(Device.orig_rotation_mode)
        Device.orig_rotation_mode = nil
    end
end

function ReadingFolio:onResume()
    self:restoreRotationMode()
end

function ReadingFolio:onShowReadingFolio()
    self:showReceipt()
end

function ReadingFolio:showReceipt(custom_style)
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
            custom_style = custom_style,
        }
        UIManager:show(self.quick_look_widget)
    end)
end

function ReadingFolio:getCustomPresets()
    local presets = G_reader_settings:readSetting(Constants.CUSTOM_PRESETS_SETTING)
    return type(presets) == "table" and presets or {}
end

-- `allow_overwrite` must be set explicitly by callers that are updating a known
-- preset ("Overwrite with current"). The save-as entry points leave it unset so a
-- duplicate name is rejected instead of silently replacing the existing preset.
function ReadingFolio:saveCustomPreset(name, allow_overwrite)
    if not name or name:match("%S") == nil then return false end
    local presets = self:getCustomPresets()
    if presets[name] and not allow_overwrite then return false end
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
    G_reader_settings:saveSetting(Constants.ACTIVE_CUSTOM_PRESET, name)
    G_reader_settings:saveSetting(Constants.STYLE_SETTING, "custom")
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
    G_reader_settings:saveSetting(Constants.ACTIVE_CUSTOM_PRESET, name)
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
    if G_reader_settings:readSetting(Constants.ACTIVE_CUSTOM_PRESET) == name then
        G_reader_settings:delSetting(Constants.ACTIVE_CUSTOM_PRESET)
    end
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
    if G_reader_settings:readSetting(Constants.ACTIVE_CUSTOM_PRESET) == old_name then
        G_reader_settings:saveSetting(Constants.ACTIVE_CUSTOM_PRESET, new_name)
    end
    G_reader_settings:flush()
    return true
end

function ReadingFolio:getThemeFolder()
    return self.theme_bundle:folder()
end

function ReadingFolio:exportCustomTheme(name)
    local presets = self:getCustomPresets()
    local preset = presets[name]
    if not preset then
        return nil, "preset not found"
    end
    return self.theme_bundle:export(name, preset)
end

function ReadingFolio:importCustomTheme(path)
    local name, preset = self.theme_bundle:import(path)
    if not name or not preset then return nil, preset end
    local presets = self:getCustomPresets()
    local final_name = name
    local index = 1
    while presets[final_name] do
        index = index + 1
        final_name = string.format("%s (%d)", name, index)
    end
    presets[final_name] = preset
    G_reader_settings:saveSetting(Constants.CUSTOM_PRESETS_SETTING, presets)
    G_reader_settings:flush()
    return final_name
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

    -- readSetting normally resolves through the LuaSettings metatable, so only put an
    -- own field back if there really was one; otherwise clearing it is the clean restore.
    local had_own_readSetting = rawget(settings, "readSetting") ~= nil
    local orig_readSetting = settings.readSetting
    settings.readSetting = function(self, key, default)
        if key == "screensaver_type" or (prefixed_key and key == prefixed_key) then
            return fallback
        end
        return orig_readSetting(self, key, default)
    end

    local event = saver.prefix and saver.prefix ~= "" and saver.prefix:sub(1, -2) or nil

    -- setup() and show() share one pcall on purpose: the stub above is process-global
    -- state, so an error in either has to reach the restore below. Otherwise every later
    -- settings read in the session keeps seeing the fallback screensaver type.
    local ok, err = pcall(function()
        if type(saver.setup) == "function" then
            saver:setup(event, saver.event_message)
        end
        saver.screensaver_type = fallback
        original_show(saver)
    end)

    settings.readSetting = had_own_readSetting and orig_readSetting or nil
    saver.screensaver_type = original_type

    if not ok then
        error(err)
    end
end

function ReadingFolio:_showScreensaver(saver, original_show)
    -- Whatever the outcome below, any chain left over from the previous suspend has to
    -- go: it closes over that screensaver's widgets and would keep repainting them.
    self:_stopScreensaverClockRefresh(saver)
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
    local selected_style = scene and self.registry:resolve(scene.style_id) or self.renderer:selectedStyle()
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
    -- getRotationMode() returns 0-3, so "% 2" is the odd/even test that bit.band(x, 1) did.
    -- Same answer for every integer including negatives, and it drops the require("bit"):
    -- the bit library is a LuaJIT extension that stock Lua 5.3+ does not ship.
    elseif landscape and rotation % 2 == 0 then
        Screen:setRotationMode(Screen.DEVICE_ROTATED_CLOCKWISE or 1)
    elseif not landscape and rotation % 2 == 1 then
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
    local mode = G_reader_settings:readSetting(Constants.CLOCK_REFRESH_MODE) or "static"
    if mode == "static" then return end

    -- Screensaver is a singleton, so this runs again on every suspend with the same
    -- `saver`. What used to be stored here was the result of UIManager:scheduleIn --
    -- which returns nothing -- so the guard never fired and the unschedule in the
    -- patched close() was dead: each sleep cycle started another chain, and the old
    -- ones kept running because they only stop when screensaver_widget is nil, which
    -- the newly shown screensaver had just made non-nil again. Keep the function
    -- itself, which is also what UIManager:unschedule matches on.
    self:_stopScreensaverClockRefresh(saver)

    local count = 0

    local function refreshClock()
        if not saver.screensaver_widget then return end
        if not applyClockText(runtime) then return end

        count = count + 1
        local full_refresh_interval = clockFullRefreshInterval()

        if full_refresh_interval > 0 and count >= full_refresh_interval then
            count = 0
            UIManager:setDirty(saver.screensaver_widget, "full")
        else
            refreshClockRegion(runtime, saver.screensaver_widget)
        end

        UIManager:scheduleIn(61 - tonumber(os.date("%S")), refreshClock)
    end

    saver._reading_folio_clock_action = refreshClock
    UIManager:scheduleIn(61 - tonumber(os.date("%S")), refreshClock)
end

function ReadingFolio:_stopScreensaverClockRefresh(saver)
    if saver and saver._reading_folio_clock_action then
        UIManager:unschedule(saver._reading_folio_clock_action)
        saver._reading_folio_clock_action = nil
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
        local orig_close = Screensaver.close or Screensaver.hide
        if orig_close then
            Screensaver._reading_folio_original_close = orig_close
            Screensaver.close = function(saver)
                local plugin = Screensaver._reading_folio_plugin
                if plugin then plugin:_stopScreensaverClockRefresh(saver) end
                return Screensaver._reading_folio_original_close(saver)
            end
        end
    end
    Screensaver._reading_folio_plugin = self
end

return ReadingFolio
