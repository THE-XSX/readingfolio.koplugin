-- Shared harness for the Reading Folio specs.
--
-- Most of the interesting logic in `main.lua` is written against upvalues that only exist
-- once KOReader has loaded (Constants, G_reader_settings, UIManager, …) and is not
-- exported, so nothing can `require` it. Instead of reimplementing it in the tests — which
-- is how a real bug can pass a green suite — cut the source between two anchors and `load`
-- that slice with a supplied environment. The specs then run the real code.
--
-- Anchors are function-definition lines. If a function you need falls outside the slice,
-- widen the `to` anchor rather than copying the body into a test.

local Support = {}

local STDLIB = {
    "assert", "error", "ipairs", "math", "next", "os", "pairs", "pcall", "print",
    "rawget", "rawset", "select", "string", "table", "tonumber", "tostring", "type",
    "xpcall",
}

local function readFile(path)
    local handle = assert(io.open(path, "rb"), "cannot open " .. path)
    local source = handle:read("*a")
    handle:close()
    return source
end

-- Loads `path`'s text from `from_anchor` up to (but not including) `to_anchor`, appends
-- `tail` (normally a `return { … }` exposing the locals the spec needs) and runs it with
-- `env` as its environment. Returns whatever the tail returned, plus the environment.
function Support.slice(path, from_anchor, to_anchor, tail, env)
    local source = readFile(path)
    local from = source:find(from_anchor, 1, true)
    assert(from, path .. ": missing anchor " .. from_anchor)
    local to = source:find(to_anchor, from + #from_anchor, true)
    assert(to, path .. ": missing anchor " .. to_anchor)

    env = env or {}
    for _, name in ipairs(STDLIB) do
        if env[name] == nil then env[name] = _G[name] end
    end

    local chunk, err = load(source:sub(from, to - 1) .. "\n" .. tail, path .. " slice", "t", env)
    assert(chunk, tostring(err))
    return chunk(), env
end

-- Stand-in for G_reader_settings. Methods live on a metatable, exactly like a real
-- LuaSettings instance, so `rawget(settings, "readSetting")` is nil here too — the
-- screensaver spec depends on that to check the stub is removed rather than pinned.
local Settings = {}
Settings.__index = Settings

function Settings:readSetting(key, default)
    local value = self.data[key]
    if value == nil then return default end
    return value
end

function Settings:saveSetting(key, value)
    self.data[key] = value
    return self
end

function Settings:delSetting(key)
    self.data[key] = nil
    return self
end

function Settings:isTrue(key)
    return self.data[key] == true
end

function Settings:nilOrTrue(key)
    return self.data[key] == nil or self.data[key] == true
end

function Settings:flush()
    self.flushes = (self.flushes or 0) + 1
    return self
end

function Support.settings(initial)
    return setmetatable({ data = initial or {}, flushes = 0 }, Settings)
end

function Support.check(label, ok)
    print((ok and "ok   " or "FAIL ") .. label)
    if not ok then error(label, 0) end
end

return Support
