local Registry = {}
Registry.__index = Registry

local STYLE_FILES = {
    "swiss",
    "terminal",
    "quote",
    "ticket",
    "cover",
    "gallery",
    "dossier",
    "archive",
    "bookpost",
    "architecture",
    "zen",
    "mei",
    "lan",
    "zhu",
    "ju",
    "custom",
}

function Registry.new(plugin_root)
    local interface = dofile(plugin_root .. "styles/style_interface.lua")
    local self = setmetatable({
        interface = interface,
        ordered = {},
        by_id = {},
    }, Registry)

    for _, filename in ipairs(STYLE_FILES) do
        local source = "styles/" .. filename .. ".lua"
        local style = interface.validate(dofile(plugin_root .. source), source)
        style.defaults = style.defaults or {}
        if self.by_id[style.id] then
            error("Duplicate Reading Folio style id: " .. style.id)
        end
        self.by_id[style.id] = style
        table.insert(self.ordered, style)
    end
    return self
end

function Registry:list()
    return self.ordered
end

function Registry:get(id)
    return self.by_id[id]
end

-- "random" is a pseudo-id used by the style setting and by TypeFolio folio scenes; no
-- style file answers to it, so it has to be drawn from the real styles. "custom" is
-- excluded because it renders the user's own saved layout, which is not a surprise.
function Registry:randomStyle()
    local candidates = {}
    for _, style in ipairs(self.ordered) do
        if style.id ~= "custom" then
            table.insert(candidates, style)
        end
    end
    if #candidates == 0 then return nil end
    return candidates[math.random(#candidates)]
end

-- Use this instead of get() wherever the id may have come from a setting or a scene
-- snapshot, so the "random" pseudo-id resolves to a concrete style instead of nil.
function Registry:resolve(id)
    if id == "random" then
        return self:randomStyle()
    end
    return self:get(id)
end

function Registry:normalize(id, constants)
    if id == "random" then return "random" end
    if id and self.by_id[id] then
        return id
    end
    return constants.DEFAULT_STYLE
end

function Registry:render(id, ctx)
    local style = assert(self.by_id[id], "Unknown Reading Folio style: " .. tostring(id))
    return self.interface.validateResult(style, style.render(ctx))
end

return Registry
