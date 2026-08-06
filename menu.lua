local InputDialog = require("ui/widget/inputdialog")
local Notification = require("ui/widget/notification")
local UIManager = require("ui/uimanager")

local Menu = {}
Menu.__index = Menu

function Menu.new(options)
    return setmetatable({
        constants = options.constants,
        registry = options.registry,
        translate = options.translate,
    }, Menu)
end

local function save(key, value)
    G_reader_settings:saveSetting(key, value)
    G_reader_settings:flush()
end

function Menu:_preview()
    if self._plugin then
        self._plugin:showReceipt()
    end
end

function Menu:_radio(text, key, value, default)
    return {
        text = self.translate(text),
        checked_func = function()
            return (G_reader_settings:readSetting(key) or default) == value
        end,
        callback = function()
            save(key, value)
            self:_preview()
        end,
        radio = true,
        keep_menu_open = true,
    }
end

function Menu:_toggle(text, key)
    return {
        text = self.translate(text),
        checked_func = function() return G_reader_settings:nilOrTrue(key) end,
        callback = function()
            G_reader_settings:flipNilOrTrue(key)
            G_reader_settings:flush()
            self:_preview()
        end,
        keep_menu_open = true,
    }
end

function Menu:_styleItems()
    local items = {}
    for _, style in ipairs(self.registry:list()) do
        local style_id, style_label = style.id, style.label
        table.insert(items, {
            text = self.translate(style_label),
            checked_func = function()
                local raw = G_reader_settings:readSetting(self.constants.STYLE_SETTING)
                return raw == style_id or (not raw and style_id == self.constants.DEFAULT_STYLE)
            end,
            callback = function()
                save(self.constants.STYLE_SETTING, style_id)
                self:_preview()
            end,
            radio = true,
            keep_menu_open = true,
        })
    end
    table.insert(items, {
        text = self.translate("Random style"),
        checked_func = function()
            return G_reader_settings:readSetting(self.constants.STYLE_SETTING) == "random"
        end,
        callback = function()
            save(self.constants.STYLE_SETTING, "random")
            self:_preview()
        end,
        radio = true,
        keep_menu_open = true,
    })
    return items
end

function Menu:_languageItems()
    local K, tr = self.constants, self.translate
    local function selected()
        return G_reader_settings:readSetting(K.LANGUAGE_SETTING) or "system"
    end
    local items = {
        {
            text = tr("Follow system"),
            checked_func = function() return selected() == "system" end,
            callback = function()
                save(K.LANGUAGE_SETTING, "system")
                self:_preview()
            end,
            radio = true,
            keep_menu_open = true,
        },
    }
    for _, locale in ipairs(tr:locales()) do
        local locale_id, locale_label = locale.id, locale.label
        table.insert(items, {
            text = locale_label,
            checked_func = function() return selected() == locale_id end,
            callback = function()
                save(K.LANGUAGE_SETTING, locale_id)
                self:_preview()
            end,
            radio = true,
            keep_menu_open = true,
        })
    end
    return items
end

function Menu:_fontDeltaItems(key)
    local items = {}
    for _, delta in ipairs({ -2, 0, 2, 4, 6 }) do
        local text = delta == 0 and self.translate("Default")
            or (delta > 0 and ("+" .. delta) or tostring(delta))
        table.insert(items, {
            text = text,
            checked_func = function()
                return (tonumber(G_reader_settings:readSetting(key)) or 0) == delta
            end,
            callback = function()
                save(key, delta)
                self:_preview()
            end,
            radio = true,
            keep_menu_open = true,
        })
    end
    table.insert(items, self:_customFontDeltaItem(key))
    return items
end

function Menu:_customFontDeltaItem(key)
    local tr = self.translate
    return {
        text = tr("Custom"),
        checked_func = function()
            local current = tonumber(G_reader_settings:readSetting(key)) or 0
            for _, preset in ipairs({ -2, 0, 2, 4, 6 }) do
                if current == preset then return false end
            end
            return true
        end,
        callback = function()
            local dialog
            dialog = InputDialog:new{
                title = tr("Text size delta (-20 to +20)"),
                input = tostring(G_reader_settings:readSetting(key) or "0"),
                input_type = "number",
                buttons = {{
                    { text = tr("Cancel"), id = "close", callback = function() UIManager:close(dialog) end },
                    {
                        text = tr("Set"),
                        is_enter_default = true,
                        callback = function()
                            local text = (dialog:getInputText() or ""):gsub(",", ".")
                            local value = tonumber(text)
                            if not value or value < -20 or value > 20 then
                                UIManager:show(Notification:new{
                                    text = tr("Font size delta must be between -20 and +20."),
                                })
                                return true
                            end
                            value = math.floor(value + 0.5)
                            save(key, value)
                            UIManager:close(dialog)
                            self:_preview()
                        end,
                    },
                }},
            }
            UIManager:show(dialog)
        end,
        radio = true,
        keep_menu_open = true,
    }
end

function Menu:_coverScaleItems()
    local K, tr = self.constants, self.translate
    local function current()
        return tonumber(G_reader_settings:readSetting(K.COVER_SCALE_SETTING)) or 1
    end
    local items = {}
    for _, scale in ipairs({ 0.5, 0.75, 1 }) do
        table.insert(items, {
            text = scale == 1 and tr("100% (default)") or string.format("%d%%", scale * 100),
            checked_func = function() return math.abs(current() - scale) < 0.001 end,
            callback = function()
                save(K.COVER_SCALE_SETTING, scale)
                self:_preview()
            end,
            radio = true,
            keep_menu_open = true,
        })
    end
    table.insert(items, {
        text = tr("Custom"),
        checked_func = function()
            local value = current()
            for _, scale in ipairs({ 0.5, 0.75, 1 }) do
                if math.abs(value - scale) < 0.001 then return false end
            end
            return true
        end,
        callback = function()
            local dialog
            dialog = InputDialog:new{
                title = tr("Custom cover scale (0.00 - 1.00)"),
                input = string.format("%.2f", current()),
                input_type = "number",
                buttons = {{
                    { text = tr("Cancel"), id = "close", callback = function() UIManager:close(dialog) end },
                    {
                        text = tr("Set"),
                        is_enter_default = true,
                        callback = function()
                            local text = (dialog:getInputText() or ""):gsub(",", ".")
                            local value = tonumber(text)
                            if not value or value < 0 or value > 1 then
                                UIManager:show(Notification:new{
                                    text = tr("Cover scale must be between 0.00 and 1.00."),
                                })
                                return true
                            end
                            save(K.COVER_SCALE_SETTING, value)
                            UIManager:close(dialog)
                            self:_preview()
                        end,
                    },
                }},
            }
            UIManager:show(dialog)
        end,
        radio = true,
        keep_menu_open = true,
    })
    return items
end

function Menu:_ratioItems()
    local K, tr = self.constants, self.translate
    local items = {
        self:_radio("Default ratio", K.CARD_RATIO_MODE, "default", "default"),
        self:_radio("Fullscreen", K.CARD_RATIO_MODE, "fullscreen"),
    }
    table.insert(items, {
        text = tr("Custom ratio"),
        checked_func = function() return G_reader_settings:readSetting(K.CARD_RATIO_MODE) == "custom" end,
        callback = function()
            save(K.CARD_RATIO_MODE, "custom")
            local dialog
            dialog = InputDialog:new{
                title = tr("Custom card ratio (0.30 - 1.00)"),
                input = tostring(G_reader_settings:readSetting(K.CARD_RATIO_CUSTOM) or "0.60"),
                input_type = "number",
                buttons = {{
                    { text = tr("Cancel"), id = "close", callback = function() UIManager:close(dialog) end },
                    {
                        text = tr("Set"),
                        is_enter_default = true,
                        callback = function()
                            local text = (dialog:getInputText() or ""):gsub(",", ".")
                            local value = tonumber(text)
                            if value and value > 1 and value <= 100 then
                                value = value / 100
                            end
                            if not value or value < 0.30 or value > 1 then
                                UIManager:show(Notification:new{
                                    text = tr("Card ratio must be between 0.30 and 1.00."),
                                })
                                return true
                            end
                            save(K.CARD_RATIO_CUSTOM, value)
                            UIManager:close(dialog)
                            self:_preview()
                        end,
                    },
                }},
            }
            UIManager:show(dialog)
        end,
        radio = true,
        keep_menu_open = true,
    })
    return items
end

function Menu:items(plugin)
    local K, tr = self.constants, self.translate
    self._plugin = plugin
    return {
        {
            text = tr("Preview Reading Folio"),
            callback = function() plugin:showReceipt() end,
            keep_menu_open = true,
        },
        {
            text = tr("Use as sleep screen"),
            checked_func = function() return G_reader_settings:readSetting("screensaver_type") == "reading_folio" end,
            callback = function()
                local enabled = G_reader_settings:readSetting("screensaver_type") == "reading_folio"
                if enabled then
                    save("screensaver_type", G_reader_settings:readSetting(K.PREVIOUS_SCREENSAVER_TYPE) or "cover")
                else
                    local previous = G_reader_settings:readSetting("screensaver_type") or "cover"
                    save(K.PREVIOUS_SCREENSAVER_TYPE, previous)
                    save("screensaver_type", "reading_folio")
                end
                self:_preview()
            end,
            keep_menu_open = true,
        },
        { text = tr("Language"), sub_item_table = self:_languageItems() },
        { text = tr("Style"), sub_item_table = self:_styleItems() },
        {
            text = tr("Content"),
            sub_item_table = {
                self:_radio("Reading Folio (default)", K.CONTENT_MODE_SETTING, K.CONTENT_MODE_READING_FOLIO, K.CONTENT_MODE_READING_FOLIO),
                self:_radio("Highlight + progress", K.CONTENT_MODE_SETTING, K.CONTENT_MODE_HIGHLIGHT_PROGRESS),
                self:_radio("Random", K.CONTENT_MODE_SETTING, K.CONTENT_MODE_RANDOM),
            },
        },
        { text = tr("Card width mode"), sub_item_table = self:_ratioItems() },
        {
            text = tr("Appearance"),
            sub_item_table = {
                {
                    text = tr("Card border"),
                    sub_item_table = {
                        self:_radio("No border", K.BORDER, "none", "none"),
                        self:_radio("Thin border", K.BORDER, "thin"),
                        self:_radio("Thick border", K.BORDER, "thick"),
                    },
                },
                {
                    text = tr("Card background color"),
                    sub_item_table = {
                        self:_radio("Light gray (default)", K.CARD_BG, "light_gray", "light_gray"),
                        self:_radio("Pure white", K.CARD_BG, "pure_white"),
                        self:_radio("Soft gray", K.CARD_BG, "soft_gray"),
                    },
                },
                {
                    text = tr("Card drop shadow"),
                    checked_func = function() return G_reader_settings:isTrue(K.SHADOW) end,
                    callback = function()
                        save(K.SHADOW, not G_reader_settings:isTrue(K.SHADOW))
                        self:_preview()
                    end,
                    keep_menu_open = true,
                },
                {
                    text = tr("Cover scale"),
                    sub_item_table = self:_coverScaleItems(),
                },
                {
                    text = tr("Text size"),
                    sub_item_table = {
                        { text = tr("Large text"), sub_item_table = self:_fontDeltaItems(K.FONT_DELTA_BIG) },
                        { text = tr("Medium text"), sub_item_table = self:_fontDeltaItems(K.FONT_DELTA_MID) },
                        { text = tr("Small text"), sub_item_table = self:_fontDeltaItems(K.FONT_DELTA_SMALL) },
                    },
                },
            },
        },
        {
            text = tr("Background"),
            sub_item_table = {
                self:_radio("White fill", K.BG_SETTING, "white", "white"),
                self:_radio("Transparent", K.BG_SETTING, "transparent"),
                self:_radio("Black fill", K.BG_SETTING, "black"),
                self:_radio("Random image", K.BG_SETTING, "random_image"),
                self:_radio("Book cover", K.BG_SETTING, "book_cover"),
                {
                    text = tr("Background image placement"),
                    sub_item_table = {
                        self:_radio("Fit to screen", K.BG_IMAGE_MODE_SETTING, "fit"),
                        self:_radio("Stretch to screen", K.BG_IMAGE_MODE_SETTING, "stretch", "stretch"),
                        self:_radio("Center without scaling", K.BG_IMAGE_MODE_SETTING, "center"),
                    },
                },
            },
        },
        {
            text = tr("Display items"),
            sub_item_table = {
                self:_toggle("Book title", K.SHOW_TITLE),
                self:_toggle("Author", K.SHOW_AUTHOR),
                self:_toggle("Cover", K.SHOW_COVER),
                self:_toggle("Current chapter", K.SHOW_CHAPTER),
                self:_toggle("Page count", K.SHOW_PAGE_NUMBER),
                self:_toggle("Reading percentage", K.SHOW_PERCENTAGE),
                self:_toggle("Progress bar", K.SHOW_PROGRESS_BAR),
                self:_toggle("Chapter time left", K.SHOW_CHAPTER_TIME_LEFT),
                self:_toggle("Book time left", K.SHOW_BOOK_TIME_LEFT),
                self:_toggle("Total time spent", K.SHOW_TOTAL_TIME),
                self:_toggle("Time spent today", K.SHOW_TODAY_TIME),
                self:_toggle("Battery level", K.SHOW_BATTERY),
                self:_toggle("Current time", K.SHOW_CLOCK),
                self:_toggle("Highlights & annotations", K.SHOW_HIGHLIGHTS),
                self:_toggle("Custom screensaver message", K.SHOW_CUSTOM_MESSAGE),
            },
        },
    }
end

return Menu
