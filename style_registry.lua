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
}

function Registry.new(plugin_root)
    local interface = dofile(plugin_root .. "style_interface.lua")
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
