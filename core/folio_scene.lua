local FolioScene = {}
FolioScene.__index = FolioScene

local SNAPSHOT_KEY = "typefolio_folio_scene"
local SCENES = {
    quiet = { style_id = "zen", content_mode = "reading_folio" },
    study = { style_id = "quote", content_mode = "highlight_progress" },
    editorial = { style_id = "bookpost", content_mode = "reading_folio" },
    chapter = { style_id = "architecture", content_mode = "reading_folio" },
}

function FolioScene.new()
    return setmetatable({}, FolioScene)
end

local function readSnapshot(ui)
    if type(ui) ~= "table" then return nil end
    if type(ui.typefolio_folio_scene_preview) == "table" then
        return ui.typefolio_folio_scene_preview
    end
    if not ui.doc_settings or type(ui.doc_settings.readSetting) ~= "function" then return nil end
    local ok, snapshot = pcall(ui.doc_settings.readSetting, ui.doc_settings, SNAPSHOT_KEY)
    return ok and snapshot or nil
end

function FolioScene:resolve(ui, follow)
    if follow ~= true then return nil end
    local snapshot = readSnapshot(ui)
    if type(snapshot) ~= "table"
            or snapshot.format ~= "folio-scene"
            or snapshot.interface_version ~= 1
            or snapshot.source ~= "typefolio"
            or snapshot.enabled ~= true then
        return nil
    end
    local mapped = SCENES[snapshot.scene]
    if not mapped then return nil end
    return {
        id = snapshot.scene,
        mode = snapshot.mode,
        style_id = mapped.style_id,
        content_mode = mapped.content_mode,
    }
end

return FolioScene
