-- Folio scenes: Type Folio publishes style_id = "random", which is a pseudo-id with no
-- style file behind it. Reading Folio has to turn that into a real style, or the preview
-- silently renders nothing and the sleep screen falls back to the user's saved style.

local Support = dofile("tests/support.lua")
local Constants = dofile("core/constants.lua")
local Registry = dofile("styles/style_registry.lua")
local FolioScene = dofile("core/folio_scene.lua")

-- Registry.new() dofiles every style file, and those pull in KOReader widgets, so build a
-- registry by hand: resolve()/randomStyle() only ever touch `ordered` and `by_id`.
local function registryWith(ids)
    local instance = setmetatable({ ordered = {}, by_id = {} }, Registry)
    for _, id in ipairs(ids) do
        local style = { id = id, defaults = {} }
        instance.by_id[id] = style
        table.insert(instance.ordered, style)
    end
    return instance
end

local registry = registryWith({ "swiss", "terminal", "quote", "zen", "custom" })

Support.check("a real id still resolves to itself",
    registry:resolve("zen") == registry:get("zen"))
Support.check("an unknown id still resolves to nil", registry:resolve("nope") == nil)

local resolved = registry:resolve("random")
Support.check("random resolves to a concrete style", resolved ~= nil)
Support.check("random never resolves to the custom layout",
    resolved ~= nil and resolved.id ~= "custom")
Support.check("random resolves to a style the registry knows",
    resolved ~= nil and registry:get(resolved.id) == resolved)

-- Sampling: over many draws every non-custom style should appear and custom never should.
local seen, draws = {}, 400
for _ = 1, draws do
    local style = registry:resolve("random")
    seen[style.id] = (seen[style.id] or 0) + 1
end
Support.check("random never draws custom across " .. draws .. " draws", seen.custom == nil)
Support.check("random reaches every non-custom style",
    seen.swiss and seen.terminal and seen.quote and seen.zen and true or false)

-- The scene snapshot Type Folio writes for "random style". Read from the sibling plugin
-- when it is checked out next door, so a change to the published shape breaks this spec
-- rather than silently disagreeing with it.
local typefolio_scene = loadfile("../typefolio.koplugin/core/folio_scene.lua")
local snapshot
if typefolio_scene then
    snapshot = typefolio_scene().snapshot({ folio_scene = "random" })
    Support.check("Type Folio still publishes style_id = random", snapshot.style_id == "random")
else
    print("note: ../typefolio.koplugin not found, using a recorded snapshot")
    snapshot = {
        format = "folio-scene",
        interface_version = 1,
        source = "typefolio",
        enabled = true,
        mode = "random",
        scene = "random",
        style_id = "random",
        content_mode = "reading_folio",
    }
end

local ui = { doc_settings = { readSetting = function() return snapshot end } }
local scene = FolioScene.new():resolve(ui, true)
Support.check("the random scene is accepted", scene ~= nil)
Support.check("the scene keeps the random style id", scene.style_id == "random")

-- This is the pairing that was broken: scene.style_id straight into the registry.
local scene_style = registry:resolve(scene.style_id)
Support.check("a random scene yields a renderable style", scene_style ~= nil)
Support.check("a random scene never yields the custom layout",
    scene_style ~= nil and scene_style.id ~= "custom")

-- Mapped scenes must keep working unchanged.
local study = FolioScene.new():resolve({
    typefolio_folio_scene_preview = {
        format = "folio-scene",
        interface_version = 1,
        source = "typefolio",
        enabled = true,
        scene = "study",
    },
}, true)
Support.check("study still maps to the quote style", study.style_id == "quote")
Support.check("study still asks for highlight progress",
    study.content_mode == "highlight_progress")
Support.check("registry resolves the mapped style",
    registry:resolve(study.style_id) == registry:get("quote"))

-- normalize() passes "random" through untouched, so anything downstream of it has to
-- resolve rather than get; DEFAULT_STYLE is the backstop.
Support.check("normalize keeps random as a pseudo-id",
    registry:normalize("random", Constants) == "random")
Support.check("normalize falls back to the default style",
    registry:normalize("bogus", Constants) == Constants.DEFAULT_STYLE)

-- Renderer:selectedStyle() is the sleep-screen path. renderer.lua requires KOReader
-- widgets at the top so it cannot be dofile()d here; slice the one method out instead.
local settings = Support.settings()
local renderer_exports = Support.slice("rendering/renderer.lua",
    "function Renderer:selectedStyle()",
    "function Renderer:prefersLandscape()",
    "return { Renderer = Renderer }",
    { Renderer = {}, G_reader_settings = settings })

local renderer = setmetatable({
    constants = Constants,
    registry = registryWith({ "swiss", "terminal", "quote", "zen", "custom" }),
}, { __index = renderer_exports.Renderer })

settings:saveSetting(Constants.STYLE_SETTING, "zen")
Support.check("selectedStyle honours a saved style",
    renderer:selectedStyle() == renderer.registry:get("zen"))

settings:saveSetting(Constants.STYLE_SETTING, "random")
local drawn = renderer:selectedStyle()
Support.check("selectedStyle resolves random to a real style", drawn ~= nil)
Support.check("selectedStyle never draws the custom layout",
    drawn ~= nil and drawn.id ~= "custom")

-- These lock in selectedStyle's contract rather than proving a fix: the pre-1.6.0 body
-- passed them too. It carried its own copy of the random-draw loop, now delegated to
-- registry:randomStyle(), so the point here is that the delegation changed nothing.
settings:saveSetting(Constants.STYLE_SETTING, "removed_in_1_5")
Support.check("selectedStyle never returns nil for an unknown id",
    renderer:selectedStyle() ~= nil)
settings:delSetting(Constants.STYLE_SETTING)
Support.check("selectedStyle survives an unset style setting",
    renderer:selectedStyle() ~= nil)

print("folio_scene_spec: ok")
