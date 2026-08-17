-- Preset storage: a duplicate name must never silently replace an existing preset.
-- "Overwrite with current" is the one entry point allowed to replace one, and it says so.

local Support = dofile("tests/support.lua")
local Constants = dofile("core/constants.lua")

local settings = Support.settings()
local exports = Support.slice("main.lua",
    "function ReadingFolio:getCustomPresets()",
    "function ReadingFolio:applyCustomPreset(",
    "return { ReadingFolio = ReadingFolio }",
    {
        ReadingFolio = {},
        Constants = Constants,
        G_reader_settings = settings,
    })

local layout_items = { title = { visible = true } }
local plugin = setmetatable({
    custom_layout = { get = function() return { items = layout_items } end },
}, { __index = exports.ReadingFolio })

settings:saveSetting(Constants.BORDER, "thin")
Support.check("saving a new preset succeeds", plugin:saveCustomPreset("Desk") == true)
Support.check("preset is stored under its name",
    plugin:getCustomPresets()["Desk"] ~= nil)
Support.check("saved preset captures the current border setting",
    plugin:getCustomPresets()["Desk"].border == "thin")
Support.check("saving marks the preset active",
    settings:readSetting(Constants.ACTIVE_CUSTOM_PRESET) == "Desk")

-- The reported bug: the same name came back true and overwrote the stored preset.
settings:saveSetting(Constants.BORDER, "thick")
Support.check("re-using a name is rejected", plugin:saveCustomPreset("Desk") == false)
Support.check("rejected save leaves the original preset untouched",
    plugin:getCustomPresets()["Desk"].border == "thin")

Support.check("blank names are still rejected", plugin:saveCustomPreset("   ") == false)
Support.check("nil names are still rejected", plugin:saveCustomPreset(nil) == false)

-- The explicit update path stays able to replace it.
Support.check("overwrite with current succeeds",
    plugin:saveCustomPreset("Desk", true) == true)
Support.check("overwrite picks up the new border setting",
    plugin:getCustomPresets()["Desk"].border == "thick")
Support.check("overwrite did not create a second entry", (function()
    local count = 0
    for _ in pairs(plugin:getCustomPresets()) do count = count + 1 end
    return count == 1
end)())

Support.check("a different name still saves", plugin:saveCustomPreset("Sofa") == true)

print("preset_spec: ok")
