local item_path = debug.getinfo(1, "S").source:sub(2)
local PLUGIN_ROOT = item_path:match("(.*[/\\])") or "plugins/readingfolio.koplugin/"
local Constants = dofile(PLUGIN_ROOT .. "constants.lua")
local I18n = dofile(PLUGIN_ROOT .. "i18n.lua")
local translate = I18n.new(PLUGIN_ROOT)

return {
    name = "readingfolio",
    fullname = translate("Reading Folio"),
    description = translate([[Show a configurable reading folio as a preview or sleep screen.]]),
    version = "1.3.0",
}
