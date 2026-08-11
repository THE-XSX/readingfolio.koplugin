local CustomLayout = {}
CustomLayout.__index = CustomLayout

local ITEMS = {
    { id = "title", label = "Book title", x = 0.50, y = 0.07, scale = 1.35, visible = true },
    { id = "author", label = "Author", x = 0.50, y = 0.14, scale = 1.00, visible = true },
    { id = "cover", label = "Cover", x = 0.50, y = 0.37, scale = 1.00, visible = true },
    { id = "chapter", label = "Current chapter", x = 0.50, y = 0.66, scale = 1.00, visible = true },
    { id = "page_number", label = "Page count", x = 0.18, y = 0.78, scale = 1.00, visible = false },
    { id = "percentage", label = "Reading percentage", x = 0.82, y = 0.76, scale = 1.25, visible = true },
    { id = "progress_bar", label = "Progress bar", x = 0.50, y = 0.82, scale = 1.00, visible = true },
    { id = "chapter_time_left", label = "Chapter time left", x = 0.25, y = 0.87, scale = 0.90, visible = false },
    { id = "book_time_left", label = "Book time left", x = 0.75, y = 0.87, scale = 0.90, visible = false },
    { id = "total_time", label = "Total time spent", x = 0.50, y = 0.89, scale = 0.85, visible = false },
    { id = "today_time", label = "Time spent today", x = 0.50, y = 0.92, scale = 0.85, visible = false },
    { id = "battery", label = "Battery level", x = 0.10, y = 0.96, scale = 0.90, visible = true },
    { id = "clock", label = "Current time", x = 0.90, y = 0.96, scale = 1.00, visible = true },
    { id = "highlights", label = "Highlights & annotations", x = 0.50, y = 0.58, scale = 0.90, visible = false },
    { id = "custom_message", label = "Custom screensaver message", x = 0.50, y = 0.50, scale = 1.00, visible = false },
}

local BY_ID = {}
local NON_TEXT_ITEMS = { cover = true, progress_bar = true }
local VALID_COLORS = { auto = true, black = true, gray = true, white = true }
local VALID_ORIENTS = { h = true, v = true }
for _, item in ipairs(ITEMS) do
    item.colorable = not NON_TEXT_ITEMS[item.id]
    BY_ID[item.id] = item
end

local function clamp(value, low, high)
    value = tonumber(value) or low
    return math.max(low, math.min(value, high))
end

local function clampAngle(value)
    value = tonumber(value) or 0
    value = math.floor(value + 0.5) % 360
    if value < 0 then value = value + 360 end
    return value
end

local function normalizedItem(saved, defaults)
    saved = type(saved) == "table" and saved or {}
    return {
        visible = saved.visible == nil and defaults.visible or saved.visible == true,
        x = clamp(saved.x or defaults.x, 0, 1),
        y = clamp(saved.y or defaults.y, 0, 1),
        scale = clamp(saved.scale or defaults.scale, 0.5, 2),
        color = VALID_COLORS[saved.color] and saved.color or "auto",
        orient = VALID_ORIENTS[saved.orient] and saved.orient or "h",
        rotation = clampAngle(saved.rotation or defaults.rotation or 0),
    }
end

function CustomLayout.new(constants)
    return setmetatable({ constants = assert(constants) }, CustomLayout)
end

function CustomLayout:list()
    return ITEMS
end

function CustomLayout:item(id)
    return BY_ID[id]
end

function CustomLayout:get()
    local saved = G_reader_settings:readSetting(self.constants.CUSTOM_LAYOUT_SETTING)
    local layout = { version = 2, items = {} }
    local saved_items = type(saved) == "table" and type(saved.items) == "table" and saved.items or {}
    for _, defaults in ipairs(ITEMS) do
        layout.items[defaults.id] = normalizedItem(saved_items[defaults.id], defaults)
    end
    return layout
end

function CustomLayout:save(layout)
    G_reader_settings:saveSetting(self.constants.CUSTOM_LAYOUT_SETTING, layout)
    G_reader_settings:flush()
end

function CustomLayout:set(saved_items)
    local layout = { version = 2, items = {} }
    saved_items = type(saved_items) == "table" and saved_items or {}
    for _, defaults in ipairs(ITEMS) do
        layout.items[defaults.id] = normalizedItem(saved_items[defaults.id], defaults)
    end
    self:save(layout)
    return layout
end

function CustomLayout:update(id, changes)
    if not BY_ID[id] then return nil end
    local layout = self:get()
    local item = layout.items[id]
    for key, value in pairs(changes or {}) do item[key] = value end
    layout.items[id] = normalizedItem(item, BY_ID[id])
    self:save(layout)
    return layout.items[id]
end

function CustomLayout:reset()
    G_reader_settings:delSetting(self.constants.CUSTOM_LAYOUT_SETTING)
    G_reader_settings:flush()
end

return CustomLayout
