local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local DataStorage = require("datastorage")
local Device = require("device")
local DocumentRegistry = require("document/documentregistry")
local ffiUtil = require("ffi/util")
local ImageWidget = require("ui/widget/imagewidget")
local lfs = require("libs/libkoreader-lfs")
local OverlapGroup = require("ui/widget/overlapgroup")
local ProgressWidget = require("ui/widget/progresswidget")
local util = require("util")

local Background = {}
Background.__index = Background

function Background.new(constants)
    return setmetatable({ constants = constants, screen = Device.screen }, Background)
end

function Background:_randomImage()
    local directory = DataStorage:getDataDir() .. "/reading_folio_background"
    if lfs.attributes(directory, "mode") ~= "directory" then return nil end
    local files = {}
    util.findFiles(directory, function(file)
        if not util.stringStartsWith(ffiUtil.basename(file), "._") and DocumentRegistry:isImageFile(file) then
            table.insert(files, file)
        end
    end, false, 512)
    return #files > 0 and files[math.random(#files)] or nil
end

function Background:_imageWidget(source)
    if not source then return nil end
    local mode = G_reader_settings:readSetting(self.constants.BG_IMAGE_MODE_SETTING) or "stretch"
    if mode ~= "center" and mode ~= "stretch" and mode ~= "fit" then mode = "stretch" end
    local size = self.screen:getSize()
    local options = { alpha = true, file_do_cache = false }
    if type(source) == "string" then options.file = source else options.image = source end
    if mode == "stretch" then
        options.width, options.height = size.w, size.h
    elseif mode == "fit" then
        options.width, options.height, options.scale_factor = size.w, size.h, 0
    end
    local widget = ImageWidget:new(options)
    if mode == "center" then return CenterContainer:new{ dimen = size, widget } end
    return widget
end

function Background:get(ui)
    local choice = G_reader_settings:readSetting(self.constants.BG_SETTING) or "white"
    if choice == "transparent" then
        return nil, nil
    elseif choice == "black" then
        return Blitbuffer.COLOR_BLACK, nil
    elseif choice == "random_image" then
        local widget = self:_imageWidget(self:_randomImage())
        if widget then return nil, widget end
    elseif choice == "book_cover" then
        local cover = ui and ui.document and ui.bookinfo and ui.bookinfo:getCoverImage(ui.document)
        local widget = self:_imageWidget(cover)
        if widget then return nil, widget end
    end
    return Blitbuffer.COLOR_WHITE, nil
end

function Background:compose(ui, receipt, dark)
    if not receipt then return nil end
    local color, image = self:get(ui)
    local choice = G_reader_settings:readSetting(self.constants.BG_SETTING) or "white"
    if dark and not image and choice ~= "transparent" then color = Blitbuffer.COLOR_BLACK end
    if not color and not image then return receipt end
    local size = self.screen:getSize()
    if not image then
        image = ProgressWidget:new{
            width = size.w,
            height = size.h,
            percentage = 1,
            margin_v = 0,
            margin_h = 0,
            radius = 0,
            bordersize = 0,
            bgcolor = color,
            fillcolor = color,
        }
    end
    return OverlapGroup:new{ dimen = size, image, receipt }
end

return Background
