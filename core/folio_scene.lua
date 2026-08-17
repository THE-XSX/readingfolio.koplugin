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

    local target_style_id = snapshot.style_id
    local content_mode = snapshot.content_mode

    if not target_style_id and snapshot.scene then
        local mapped = SCENES[snapshot.scene]
        if mapped then
            target_style_id = mapped.style_id
            content_mode = content_mode or mapped.content_mode
        else
            target_style_id = snapshot.scene
        end
    end

    if not target_style_id then return nil end

    return {
        id = snapshot.scene or target_style_id,
        mode = snapshot.mode or target_style_id,
        style_id = target_style_id,
        content_mode = content_mode or (target_style_id == "quote" and "highlight_progress" or "reading_folio"),
    }
end

return FolioScene
