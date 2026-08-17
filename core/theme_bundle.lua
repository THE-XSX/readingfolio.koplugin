local DataStorage = require("datastorage")
local lfs = require("libs/libkoreader-lfs")
local sha2 = require("ffi/sha2")
local util = require("util")

local ThemeBundle = {}
ThemeBundle.__index = ThemeBundle

ThemeBundle.FORMAT = "readingfolio-theme"
ThemeBundle.FORMAT_VERSION = 1
ThemeBundle.FILE_SUFFIX = ".readingfolio-theme.json"

local MAX_THEME_BYTES = 24 * 1024 * 1024
local MAX_IMAGE_BYTES = 16 * 1024 * 1024

local ITEM_IDS = {
    title = true, author = true, cover = true, chapter = true,
    page_number = true, percentage = true, progress_bar = true,
    chapter_time_left = true, book_time_left = true, total_time = true,
    today_time = true, battery = true, clock = true, highlights = true,
    custom_message = true,
}

local IMAGE_EXTENSIONS = {
    bmp = true, gif = true, jpeg = true, jpg = true, png = true,
    tif = true, tiff = true, webp = true,
}

local function oneOf(value, values)
    for _, candidate in ipairs(values) do
        if value == candidate then return true end
    end
    return false
end

local function onlyKeys(value, allowed, label)
    for key in pairs(value) do
        if not allowed[key] then return nil, "unknown " .. label .. ": " .. tostring(key) end
    end
    return true
end

local function validNumber(value, low, high)
    return type(value) == "number" and value >= low and value <= high
end

local function validateLayout(layout)
    if type(layout) ~= "table" then return nil, "layout must be an object" end
    for id, item in pairs(layout) do
        if not ITEM_IDS[id] then return nil, "unknown layout item: " .. tostring(id) end
        if type(item) ~= "table" then return nil, "layout item must be an object" end
        local ok, err = onlyKeys(item, {
            visible = true, x = true, y = true, scale = true,
            color = true, orient = true, rotation = true,
        }, "layout field")
        if not ok then return nil, err end
        if item.visible ~= nil and type(item.visible) ~= "boolean" then
            return nil, id .. ".visible must be boolean"
        end
        if (item.x ~= nil and not validNumber(item.x, 0, 1))
                or (item.y ~= nil and not validNumber(item.y, 0, 1)) then
            return nil, id .. " position is out of range"
        end
        if item.scale ~= nil and not validNumber(item.scale, 0.5, 2) then
            return nil, id .. " scale is out of range"
        end
        if item.color ~= nil and not oneOf(item.color, { "auto", "black", "gray", "white" }) then
            return nil, id .. " has an unsupported color"
        end
        if item.orient ~= nil and not oneOf(item.orient, { "h", "v" }) then
            return nil, id .. " has an unsupported orientation"
        end
        if item.rotation ~= nil and not validNumber(item.rotation, 0, 359) then
            return nil, id .. " rotation is out of range"
        end
    end
    return true
end

local function validatePreset(preset)
    if type(preset) ~= "table" then return nil, "preset must be an object" end
    local ok, err = onlyKeys(preset, {
        layout = true, bg_setting = true, bg_image_opacity = true,
        bg_image_mode = true, border = true, card_bg = true, shadow = true,
        cover_scale = true, card_ratio_mode = true, card_ratio_custom = true,
        font_delta_big = true, font_delta_mid = true, font_delta_small = true,
    }, "preset field")
    if not ok then return nil, err end
    ok, err = validateLayout(preset.layout)
    if not ok then return nil, err end
    if not oneOf(preset.bg_setting, {
        "white", "gray", "transparent", "black", "random_image",
        "book_cover", "custom_image",
    }) then return nil, "unsupported background" end
    if not validNumber(preset.bg_image_opacity, 0.25, 1) then
        return nil, "image opacity is out of range"
    end
    if not oneOf(preset.bg_image_mode, { "stretch", "fit", "center" }) then
        return nil, "unsupported image placement"
    end
    if not oneOf(preset.border, { "none", "thin", "thick" }) then
        return nil, "unsupported border"
    end
    if not oneOf(preset.card_bg, { "light_gray", "pure_white", "soft_gray" }) then
        return nil, "unsupported card background"
    end
    if type(preset.shadow) ~= "boolean" then return nil, "shadow must be boolean" end
    if not validNumber(preset.cover_scale, 0, 1) then return nil, "cover scale is out of range" end
    if not oneOf(preset.card_ratio_mode, { "default", "fullscreen", "custom" }) then
        return nil, "unsupported card ratio mode"
    end
    if not validNumber(preset.card_ratio_custom, 0.30, 1) then
        return nil, "card ratio is out of range"
    end
    for _, key in ipairs({ "font_delta_big", "font_delta_mid", "font_delta_small" }) do
        local value = preset[key]
        if type(value) ~= "number" or value % 1 ~= 0 or value < -20 or value > 20 then
            return nil, key .. " is out of range"
        end
    end
    return true
end

local function safeName(name)
    local value = tostring(name or ""):gsub("[%c<>:\"/\\|%?%*]", "_"):gsub("%s+", "_")
    value = value:gsub("^%.*", ""):gsub("_+", "_"):sub(1, 100)
    return value ~= "" and value or "readingfolio_theme"
end

local function readFile(path, max_bytes)
    local size = lfs.attributes(path, "size")
    if not size then return nil, "file not found" end
    if size > max_bytes then return nil, "file is too large" end
    local file, err = io.open(path, "rb")
    if not file then return nil, err end
    local content = file:read("*a")
    file:close()
    return content
end

local function writeFile(path, content)
    local file, err = io.open(path, "wb")
    if not file then return nil, err end
    local ok, write_err = file:write(content)
    file:close()
    if not ok then return nil, write_err end
    return true
end

function ThemeBundle.new(constants, plugin_version)
    return setmetatable({
        constants = assert(constants),
        plugin_version = plugin_version,
    }, ThemeBundle)
end

function ThemeBundle:folder()
    local path = DataStorage:getDataDir() .. "/reading_folio_themes"
    util.makePath(path)
    return path
end

function ThemeBundle:_assetFolder()
    return self:folder() .. "/assets"
end

function ThemeBundle:_portablePreset(preset)
    return {
        layout = preset.layout,
        bg_setting = preset.bg_setting or "white",
        bg_image_opacity = tonumber(preset.bg_image_opacity) or 1,
        bg_image_mode = preset.bg_image_mode or "stretch",
        border = preset.border or "none",
        card_bg = preset.card_bg or "light_gray",
        shadow = preset.shadow == true,
        cover_scale = tonumber(preset.cover_scale) or 1,
        card_ratio_mode = preset.card_ratio_mode or "default",
        card_ratio_custom = tonumber(preset.card_ratio_custom) or 0.60,
        font_delta_big = tonumber(preset.font_delta_big) or 0,
        font_delta_mid = tonumber(preset.font_delta_mid) or 0,
        font_delta_small = tonumber(preset.font_delta_small) or 0,
    }
end

function ThemeBundle:export(name, preset)
    if type(name) ~= "string" or not name:match("%S") or #name > 120 then
        return nil, "invalid theme name"
    end
    local portable = self:_portablePreset(preset or {})
    local ok, err = validatePreset(portable)
    if not ok then return nil, err end

    local bundle = {
        format = self.FORMAT,
        format_version = self.FORMAT_VERSION,
        plugin_version = self.plugin_version,
        name = name,
        preset = portable,
    }
    if portable.bg_setting == "custom_image" then
        local path = preset.custom_bg_path
        if type(path) ~= "string" or lfs.attributes(path, "mode") ~= "file" then
            return nil, "custom background image is missing"
        end
        local image, image_err = readFile(path, MAX_IMAGE_BYTES)
        if not image then return nil, image_err end
        local extension = (path:match("%.([^.]+)$") or "png"):lower()
        if not IMAGE_EXTENSIONS[extension] then return nil, "unsupported background image format" end
        bundle.background_image = {
            extension = extension,
            data = sha2.bin_to_base64(image),
        }
    end

    local function encodeJson(data)
        local ok, JSON = pcall(require, "rapidjson")
        if ok and JSON and JSON.encode then
            local success, res = pcall(JSON.encode, data, { pretty = true })
            if success then return res end
        end
        ok, JSON = pcall(require, "json")
        if ok and JSON and JSON.encode then
            local success, res = pcall(JSON.encode, data)
            if success then return res end
        end
        return nil, "failed to encode JSON"
    end

    local encoded, enc_err = encodeJson(bundle)
    if not encoded then return nil, enc_err end
    if #encoded > MAX_THEME_BYTES then return nil, "theme package is too large" end
    local folder_ok, folder_err = util.makePath(self:folder())
    if not folder_ok then return nil, folder_err end
    local base = self:folder() .. "/" .. safeName(name)
    local path, index = base .. self.FILE_SUFFIX, 1
    while lfs.attributes(path, "mode") == "file" do
        index = index + 1
        path = string.format("%s_%d%s", base, index, self.FILE_SUFFIX)
    end
    local write_ok, write_err = writeFile(path, encoded)
    if not write_ok then return nil, write_err end
    return path
end

function ThemeBundle:_saveImage(name, image)
    local extension = image.extension
    if not IMAGE_EXTENSIONS[extension] then return nil, "unsupported background image format" end
    if type(image.data) ~= "string" or image.data == "" then return nil, "empty background image" end
    local decoded_ok, content = pcall(sha2.base64_to_bin, image.data)
    if not decoded_ok or type(content) ~= "string" then return nil, "invalid background image data" end
    if #content > MAX_IMAGE_BYTES then return nil, "background image is too large" end
    local folder_ok, folder_err = util.makePath(self:_assetFolder())
    if not folder_ok then return nil, folder_err end
    local base = safeName(name) .. "_" .. os.date("%Y%m%d_%H%M%S")
    local path, index = self:_assetFolder() .. "/" .. base .. "." .. extension, 1
    while lfs.attributes(path, "mode") == "file" do
        index = index + 1
        path = self:_assetFolder() .. "/" .. base .. "_" .. index .. "." .. extension
    end
    local ok, err = writeFile(path, content)
    if not ok then return nil, err end
    return path
end

function ThemeBundle:import(path)
    if type(path) ~= "string" or not path:lower():match("%.readingfolio%-theme%.json$") then
        return nil, "not a Reading Folio theme package"
    end
    local text, read_err = readFile(path, MAX_THEME_BYTES)
    if not text then return nil, read_err end

    local function decodeJson(str)
        local ok, JSON = pcall(require, "rapidjson")
        if ok and JSON and JSON.decode then
            local success, res = pcall(JSON.decode, str)
            if success and type(res) == "table" then return res end
        end
        ok, JSON = pcall(require, "json")
        if ok and JSON and JSON.decode then
            local success, res = pcall(JSON.decode, str)
            if success and type(res) == "table" then return res end
        end
        return nil, "invalid theme JSON"
    end

    local bundle, dec_err = decodeJson(text)
    if not bundle then return nil, dec_err end
    local ok, err = onlyKeys(bundle, {
        format = true, format_version = true, plugin_version = true,
        name = true, preset = true, background_image = true,
    }, "theme field")
    if not ok then return nil, err end
    if bundle.format ~= self.FORMAT then return nil, "unsupported theme format" end
    if bundle.format_version ~= self.FORMAT_VERSION then return nil, "unsupported theme version" end
    if type(bundle.name) ~= "string" or not bundle.name:match("%S") or #bundle.name > 120 then
        return nil, "invalid theme name"
    end
    ok, err = validatePreset(bundle.preset)
    if not ok then return nil, err end

    local preset = bundle.preset
    preset.name = bundle.name
    preset.timestamp = os.time()
    if preset.bg_setting == "custom_image" then
        if type(bundle.background_image) ~= "table" then return nil, "theme background image is missing" end
        ok, err = onlyKeys(bundle.background_image, { extension = true, data = true }, "image field")
        if not ok then return nil, err end
        local image_path, image_err = self:_saveImage(bundle.name, bundle.background_image)
        if not image_path then return nil, image_err end
        preset.custom_bg_path = image_path
    elseif bundle.background_image ~= nil then
        return nil, "unexpected background image"
    end
    return bundle.name, preset
end

function ThemeBundle:isThemeFile(path)
    return type(path) == "string" and path:lower():match("%.readingfolio%-theme%.json$") ~= nil
end

return ThemeBundle
