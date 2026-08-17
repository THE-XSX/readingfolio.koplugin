local BottomContainer = require("ui/widget/container/bottomcontainer")
local ButtonDialog = require("ui/widget/buttondialog")
local ButtonTable = require("ui/widget/buttontable")
local Device = require("device")
local DocumentRegistry = require("document/documentregistry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local MultiConfirmBox = require("ui/widget/multiconfirmbox")
local OverlapGroup = require("ui/widget/overlapgroup")
local TopContainer = require("ui/widget/container/topcontainer")
local UIManager = require("ui/uimanager")

local Screen = Device.screen

local EditorPreview = InputContainer:extend{
    modal = true,
    name = "reading_folio_editor_preview",
    covers_fullscreen = true,
}

function EditorPreview:init()
    self.dimen = Screen:getSize()
    local style = self.plugin.registry:get("custom")
    local receipt = self.plugin.renderer:build(self.ui, self.state, style, {
        data = self.preview_data,
        editor_selected = nil,
    })
    self[1] = self.plugin.background:compose(self.ui, receipt, false, {
        random_image = self.random_background,
    })
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

function EditorPreview:onClose()
    UIManager:close(self)
    if self.editor then
        local dirty_widget = self.plugin.background:isTranslucent() and "all" or self.editor
        UIManager:setDirty(dirty_widget, "ui")
    end
    return true
end

EditorPreview.onTap = EditorPreview.onClose
EditorPreview.onSwipe = EditorPreview.onClose
EditorPreview.onMultiSwipe = EditorPreview.onClose
EditorPreview.onAnyKeyPressed = EditorPreview.onClose

local Editor = InputContainer:extend{
    -- ButtonDialog and PathChooser are non-modal. Keeping the editor in the
    -- same stack tier lets every child dialog appear above this fullscreen UI.
    modal = false,
    name = "reading_folio_custom_editor",
    covers_fullscreen = true,
}

local function save(key, value)
    if value == nil then
        G_reader_settings:delSetting(key)
    else
        G_reader_settings:saveSetting(key, value)
    end
    G_reader_settings:flush()
end

function Editor:init()
    self.dimen = Screen:getSize()
    self.preview_data = self.plugin.data_provider:collect(self.ui, self.state)
    self.selected_item = self:_firstVisibleItem()
    if G_reader_settings:readSetting(self.constants.BG_SETTING) == "random_image" then
        self.random_background = self.plugin.background:randomImage()
    end
    if Device:hasKeys() then
        self.key_events.Close = { { Device.input.group.Back } }
    end
    self:_rebuild()
end

function Editor:_firstVisibleItem(except_id)
    local layout = self.plugin.custom_layout:get()
    for _, definition in ipairs(self.plugin.custom_layout:list()) do
        if definition.id ~= except_id and layout.items[definition.id].visible then
            return definition.id
        end
    end
end

function Editor:_selectedLabel()
    local definition = self.plugin.custom_layout:item(self.selected_item)
    return definition and self.translate(definition.label) or self.translate("No item selected")
end

function Editor:_selectedCanSetColor()
    local definition = self.plugin.custom_layout:item(self.selected_item)
    return definition and definition.colorable == true
end

function Editor:_preview()
    local style = self.plugin.registry:get("custom")
    local receipt = self.plugin.renderer:build(self.ui, self.state, style, {
        data = self.preview_data,
        editor_selected = self.selected_item,
    })
    return self.plugin.background:compose(self.ui, receipt, false, {
        random_image = self.random_background,
    })
end

function Editor:_showSavePresetDialog()
    local InputDialog = require("ui/widget/inputdialog")
    local Notification = require("ui/widget/notification")
    local tr = self.translate
    local dialog
    dialog = InputDialog:new{
        title = tr("Save custom layout as preset"),
        input = "",
        buttons = {{{
            text = tr("Cancel"),
            callback = function() UIManager:close(dialog) end,
        }, {
            text = tr("Save"),
            is_enter_default = true,
            callback = function()
                local name = dialog:getInputText()
                if not name or name == "" then
                    UIManager:close(dialog)
                    return
                end
                if self.plugin:saveCustomPreset(name) then
                    UIManager:close(dialog)
                    UIManager:show(Notification:new{
                        text = string.format(tr("Saved preset: %s"), name),
                    })
                    self:onClose()
                else
                    UIManager:show(Notification:new{
                        text = tr("Preset name already in use or invalid."),
                    })
                end
            end,
        }}},
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function Editor:_getMoveStep()
    return tonumber(G_reader_settings:readSetting(self.constants.CUSTOM_EDITOR_MOVE_STEP)) or 0.03
end

function Editor:_getRotateStep()
    return tonumber(G_reader_settings:readSetting(self.constants.CUSTOM_EDITOR_ROTATE_STEP)) or 90
end

function Editor:_rotateClockwise()
    if not self.selected_item then return end
    local item = self.plugin.custom_layout:get().items[self.selected_item]
    if not item then return end
    local step = self:_getRotateStep()
    local new_angle = (item.rotation or 0) + step
    self.plugin.custom_layout:update(self.selected_item, { rotation = new_angle })
    self:_scheduleRefresh()
end

function Editor:_showStepSettingsDialog()
    local tr = self.translate
    local dialog
    local function moveChoice(text, value)
        return {
            text = text,
            checked_func = function() return self:_getMoveStep() == value end,
            callback = function()
                G_reader_settings:saveSetting(self.constants.CUSTOM_EDITOR_MOVE_STEP, value)
                G_reader_settings:flush()
                UIManager:close(dialog)
                self:_showStepSettingsDialog()
            end,
        }
    end
    local function rotateChoice(text, value)
        return {
            text = text,
            checked_func = function() return self:_getRotateStep() == value end,
            callback = function()
                G_reader_settings:saveSetting(self.constants.CUSTOM_EDITOR_ROTATE_STEP, value)
                G_reader_settings:flush()
                UIManager:close(dialog)
                self:_showStepSettingsDialog()
            end,
        }
    end
    dialog = ButtonDialog:new{
        title = tr("Step settings (Move & Rotate)"),
        buttons = {
            { { text = tr("--- Move step distance ---"), enabled = false } },
            { moveChoice(tr("1% (Fine)"), 0.01), moveChoice(tr("3% (Default)"), 0.03), moveChoice(tr("5% (Coarse)"), 0.05), moveChoice(tr("10% (Large)"), 0.10) },
            { { text = tr("--- Rotate step angle ---"), enabled = false } },
            { rotateChoice("15°", 15), rotateChoice("30°", 30), rotateChoice("45°", 45), rotateChoice(tr("90° (Default)"), 90) },
            { { text = tr("Close"), callback = function() UIManager:close(dialog) end } },
        },
    }
    UIManager:show(dialog)
end

function Editor:_showFullscreenPreview()
    if Device:hasEinkScreen() then
        Screen:clear()
        Screen:refreshFull(0, 0, Screen:getWidth(), Screen:getHeight())
    end
    local preview_widget = EditorPreview:new{
        plugin = self.plugin,
        ui = self.ui,
        state = self.state,
        preview_data = self.preview_data,
        random_background = self.random_background,
        editor = self,
    }
    UIManager:show(preview_widget, "full")
end

function Editor:_topBar()
    return ButtonTable:new{
        width = self.dimen.w,
        show_parent = self,
        buttons = {{
            { text = self.translate("Close"), callback = function() self:onClose() end },
            { text = self.translate("Preview"), callback = function() self:_showFullscreenPreview() end },
            { text = self.translate("Wallpaper"), callback = function() self:_showWallpaperDialog() end },
            { text = self.translate("Items"), callback = function() self:_showItemsDialog() end },
            { text = self.translate("Steps"), callback = function() self:_showStepSettingsDialog() end },
            { text = self.translate("Save"), callback = function() self:_showSavePresetDialog() end },
            { text = self.translate("Reset"), callback = function() self:_confirmReset() end },
        }},
    }
end

function Editor:_selectedCanSetOrient()
    local definition = self.plugin.custom_layout:item(self.selected_item)
    return definition and definition.colorable == true
end

function Editor:_bottomBar()
    local move_step = self:_getMoveStep()
    return ButtonTable:new{
        width = self.dimen.w,
        show_parent = self,
        buttons = {
            {{ text = string.format(self.translate("Selected: %s"), self:_selectedLabel()), enabled = false }},
            {
                { text = self.translate("Left"), enabled = self.selected_item ~= nil, callback = function() self:_move(-move_step, 0) end },
                { text = self.translate("Up"), enabled = self.selected_item ~= nil, callback = function() self:_move(0, -move_step) end },
                { text = self.translate("Down"), enabled = self.selected_item ~= nil, callback = function() self:_move(0, move_step) end },
                { text = self.translate("Right"), enabled = self.selected_item ~= nil, callback = function() self:_move(move_step, 0) end },
            },
            {
                { text = self.translate("Smaller"), enabled = self.selected_item ~= nil, callback = function() self:_scale(-0.10) end },
                { text = self.translate("Larger"), enabled = self.selected_item ~= nil, callback = function() self:_scale(0.10) end },
                {
                    text = self.translate("Font color"),
                    enabled = self:_selectedCanSetColor(),
                    callback = function() self:_showColorDialog() end,
                },
                {
                    text = self.translate("Text direction"),
                    enabled = self:_selectedCanSetOrient(),
                    callback = function() self:_showOrientationDialog() end,
                },
                {
                    text = self.translate("Rotate ↻"),
                    enabled = self.selected_item ~= nil,
                    callback = function() self:_rotateClockwise() end,
                },
            },
        },
    }
end

function Editor:_rebuild()
    local preview = self:_preview()
    if not preview then return end
    local old = self[1]
    self[1] = OverlapGroup:new{
        dimen = self.dimen,
        preview,
        TopContainer:new{ dimen = self.dimen, self:_topBar() },
        BottomContainer:new{ dimen = self.dimen, self:_bottomBar() },
    }
    if old and old.free then old:free() end
end

function Editor:_scheduleRefresh()
    if self.refresh_scheduled then return end
    self.refresh_scheduled = true
    UIManager:nextTick(function()
        if not self.plugin or self.plugin.custom_editor_widget ~= self then return end
        self.refresh_scheduled = nil
        self:_rebuild()
        local dirty_widget = self.plugin.background:isTranslucent() and "all" or self
        UIManager:setDirty(dirty_widget, "ui")
    end)
end

function Editor:_move(dx, dy)
    local item = self.plugin.custom_layout:get().items[self.selected_item]
    if not item then return end
    self.plugin.custom_layout:update(self.selected_item, { x = item.x + dx, y = item.y + dy })
    self:_scheduleRefresh()
end

function Editor:_scale(delta)
    local item = self.plugin.custom_layout:get().items[self.selected_item]
    if not item then return end
    self.plugin.custom_layout:update(self.selected_item, { scale = item.scale + delta })
    self:_scheduleRefresh()
end

function Editor:_showColorDialog()
    local definition = self.plugin.custom_layout:item(self.selected_item)
    if not definition or not definition.colorable then return end
    local id = definition.id
    local dialog
    local function choice(text, value)
        return {
            text = self.translate(text),
            checked_func = function()
                return self.plugin.custom_layout:get().items[id].color == value
            end,
            callback = function()
                UIManager:close(dialog)
                self.plugin.custom_layout:update(id, { color = value })
                self:_scheduleRefresh()
            end,
        }
    end
    dialog = ButtonDialog:new{
        title = string.format(self.translate("Text color: %s"), self.translate(definition.label)),
        buttons = {
            { choice("Automatic (default)", "auto") },
            { choice("Black", "black"), choice("Gray", "gray") },
            { choice("White", "white") },
        },
    }
    UIManager:show(dialog)
end

function Editor:_showOrientationDialog()
    local definition = self.plugin.custom_layout:item(self.selected_item)
    if not definition or not definition.colorable then return end
    local id = definition.id
    local dialog
    local function choice(text, value)
        return {
            text = self.translate(text),
            checked_func = function()
                return (self.plugin.custom_layout:get().items[id].orient or "h") == value
            end,
            callback = function()
                UIManager:close(dialog)
                self.plugin.custom_layout:update(id, { orient = value })
                self:_scheduleRefresh()
            end,
        }
    end
    dialog = ButtonDialog:new{
        title = string.format(self.translate("Text direction: %s"), self.translate(definition.label)),
        buttons = {
            { choice("Horizontal (default)", "h"), choice("Vertical", "v") },
        },
    }
    UIManager:show(dialog)
end

function Editor:_setBackground(choice)
    if choice == "random_image" then
        self.random_background = self.plugin.background:randomImage()
    else
        self.random_background = nil
    end
    save(self.constants.BG_SETTING, choice)
    self:_scheduleRefresh()
end

function Editor:_showPlacementDialog()
    local dialog
    local function choice(text, value)
        return {
            text = self.translate(text),
            checked_func = function()
                return (G_reader_settings:readSetting(self.constants.BG_IMAGE_MODE_SETTING) or "stretch") == value
            end,
            callback = function()
                UIManager:close(dialog)
                save(self.constants.BG_IMAGE_MODE_SETTING, value)
                self:_scheduleRefresh()
            end,
        }
    end
    dialog = ButtonDialog:new{
        title = self.translate("Background image placement"),
        buttons = {
            { choice("Fit to screen", "fit") },
            { choice("Stretch to screen", "stretch") },
            { choice("Center without scaling", "center") },
        },
    }
    UIManager:show(dialog)
end

function Editor:_showOpacityDialog()
    local dialog
    local function choice(text, value)
        return {
            text = self.translate(text),
            checked_func = function()
                return (tonumber(G_reader_settings:readSetting(
                    self.constants.BG_IMAGE_OPACITY_SETTING
                )) or 1) == value
            end,
            callback = function()
                UIManager:close(dialog)
                save(self.constants.BG_IMAGE_OPACITY_SETTING, value)
                self:_scheduleRefresh()
            end,
        }
    end
    dialog = ButtonDialog:new{
        title = self.translate("Image opacity"),
        buttons = {
            { choice("100% (opaque, default)", 1) },
            { choice("75% (slightly transparent)", 0.75) },
            { choice("50% (semi-transparent)", 0.50) },
            { choice("25% (highly transparent)", 0.25) },
        },
    }
    UIManager:show(dialog)
end

function Editor:_chooseCustomImage()
    local filemanagerutil = require("apps/filemanager/filemanagerutil")
    local current = G_reader_settings:readSetting(self.constants.CUSTOM_BG_PATH)
    filemanagerutil.showChooseDialog(
        self.translate("Current custom wallpaper:"),
        function(path)
            save(self.constants.CUSTOM_BG_PATH, path)
            self:_setBackground(path and "custom_image" or "white")
        end,
        current,
        nil,
        function(filename) return DocumentRegistry:isImageFile(filename) end,
        true)
end

function Editor:_showWallpaperDialog()
    local dialog
    local function choice(text, value)
        return {
            text = self.translate(text),
            checked_func = function()
                return (G_reader_settings:readSetting(self.constants.BG_SETTING) or "white") == value
            end,
            callback = function()
                UIManager:close(dialog)
                self:_setBackground(value)
            end,
        }
    end
    dialog = ButtonDialog:new{
        title = self.translate("Wallpaper"),
        buttons = {
            { choice("White fill", "white"), choice("Gray fill", "gray") },
            { choice("Black fill", "black"), choice("Transparent", "transparent") },
            { choice("Book cover", "book_cover"), choice("Random image", "random_image") },
            {{
                text = self.translate("Choose custom image"),
                checked_func = function()
                    return G_reader_settings:readSetting(self.constants.BG_SETTING) == "custom_image"
                end,
                callback = function()
                    UIManager:close(dialog)
                    self:_chooseCustomImage()
                end,
            }},
            {{
                text = self.translate("Image opacity"),
                callback = function()
                    UIManager:close(dialog)
                    self:_showOpacityDialog()
                end,
            }},
            {{
                text = self.translate("Image placement"),
                callback = function()
                    UIManager:close(dialog)
                    self:_showPlacementDialog()
                end,
            }},
        },
    }
    UIManager:show(dialog)
end

function Editor:_showItemsDialog()
    local dialog
    local buttons = {}
    for _, definition in ipairs(self.plugin.custom_layout:list()) do
        local id, label = definition.id, self.translate(definition.label)
        table.insert(buttons, {
            {
                text_func = function()
                    local visible = self.plugin.custom_layout:get().items[id].visible
                    return string.format("[%s] %s", visible and "x" or " ", label)
                end,
                no_refresh_checkmark = true,
                callback = function()
                    local item = self.plugin.custom_layout:get().items[id]
                    self.plugin.custom_layout:update(id, { visible = not item.visible })
                    if item.visible and self.selected_item == id then
                        self.selected_item = self:_firstVisibleItem(id)
                    elseif not item.visible then
                        self.selected_item = id
                    end
                    dialog:reinit()
                    self:_scheduleRefresh()
                end,
            },
            {
                text = self.translate("Select"),
                enabled_func = function() return self.plugin.custom_layout:get().items[id].visible end,
                callback = function()
                    self.selected_item = id
                    UIManager:close(dialog)
                    self:_scheduleRefresh()
                end,
            },
        })
    end
    table.insert(buttons, {{ text = self.translate("Close"), callback = function() UIManager:close(dialog) end }})
    dialog = ButtonDialog:new{
        title = self.translate("Display items"),
        rows_per_page = 7,
        buttons = buttons,
    }
    UIManager:show(dialog)
end

function Editor:_confirmReset()
    UIManager:show(MultiConfirmBox:new{
        text = self.translate("Reset the custom layout and wallpaper?"),
        choice1_text = self.translate("Reset layout"),
        choice1_callback = function()
            self.plugin.custom_layout:reset()
            self.selected_item = self:_firstVisibleItem() or "title"
            self:_scheduleRefresh()
        end,
        choice2_text = self.translate("Reset all"),
        choice2_callback = function()
            self.plugin.custom_layout:reset()
            save(self.constants.CUSTOM_BG_PATH, nil)
            save(self.constants.BG_SETTING, "white")
            save(self.constants.BG_IMAGE_MODE_SETTING, nil)
            save(self.constants.BG_IMAGE_OPACITY_SETTING, nil)
            self.selected_item = self:_firstVisibleItem() or "title"
            self:_scheduleRefresh()
        end,
    })
end

function Editor:onShow()
    UIManager:setDirty(self, "ui")
end

function Editor:onClose()
    UIManager:close(self)
    if self.plugin and self.plugin.ui and self.plugin.ui.menu then
        local menu = self.plugin.ui.menu
        UIManager:nextTick(function()
            if menu.onShowMenu then
                menu:onShowMenu()
            end
        end)
    end
    return true
end

function Editor:onCloseWidget()
    if self.plugin and self.plugin.custom_editor_widget == self then
        self.plugin.custom_editor_widget = nil
    end
    UIManager:setDirty(nil, "full")
end

return Editor
