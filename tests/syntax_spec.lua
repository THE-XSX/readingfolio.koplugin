-- Every Lua file the plugin loads must parse, and no file may reach for the LuaJIT-only
-- `bit` library.
--
-- Both halves guard the same class of problem: KOReader ships LuaJIT (Lua 5.1), and code
-- written against it can be quietly invalid on a newer Lua. Two flavours have already bitten
-- this plugin's sibling: a generic-for control variable assigned in place (const from Lua 5.5
-- on, so a *parse* error, invisible to any test that never loads that file), and
-- `require("bit")`, which stock Lua 5.3+ does not ship -- used here for nothing more than an
-- odd/even test on the rotation mode, since replaced with `% 2`.
--
-- `require("ffi")` in styles/custom.lua is deliberately not banned. KOReader's own Blitbuffer
-- is built on the FFI and hands out pixel data as cdata, so raw pixel access for the layout
-- rotation has no portable equivalent -- and if KOReader ever left LuaJIT, Blitbuffer itself
-- would change shape first. `bit` was avoidable; this is not.
--
-- Discovery walks the dofile graph from main.lua rather than naming files, because a hand
-- list rots: the point is to cover the module added next month, not the ones present today.
-- There is no directory listing in the Lua standard library and this spec has to run without
-- KOReader, so the graph is read out of the sources -- every `.lua` string literal is a
-- candidate path, plus the form both registries use (a directory prefix concatenated with
-- names from a `*_FILES` list, which is how the styles and the locales are loaded).
--
-- Walking the graph also checks something a directory walk cannot: every path a dofile names
-- has to exist, so a moved or renamed module fails here too.
--
-- tests/ is deliberately outside the graph -- running the specs is a stronger check than
-- parsing them.

-- The `bit` ban reads code, not prose: main.lua's comment explains why the require was
-- dropped and names it, and the first version of this spec dutifully failed on that comment.
-- Cut each line at `--` before matching. That over-strips a line where `--` appears inside a
-- string literal, which at worst hides a `require("bit")` written after such a string on the
-- same line -- an easier trade than lexing Lua properly here.
local function codeLines(source)
    local code = {}
    for line in (source .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(code, (line:gsub("%-%-.*$", "")))
    end
    return code
end

local function usesBitLibrary(source)
    for _, line in ipairs(codeLines(source)) do
        if line:find('require%s*%(?%s*["\']bit["\']') then return true end
        -- Usage too, not just the require: the leading class keeps `orbit.band(` and
        -- `self.bit.band(` out of it.
        if (" " .. line):find("[^%w_.]bit%.[%w_]+%s*%(") then return true end
    end
    return false
end

local failed = 0
local function fail(message)
    failed = failed + 1
    print("FAIL " .. message)
end

local function readFile(path)
    local handle = io.open(path, "r")
    if not handle then return nil end
    local source = handle:read("*a")
    handle:close()
    return source
end

local function exists(path)
    local handle = io.open(path, "r")
    if not handle then return false end
    handle:close()
    return true
end

local function directoryOf(path)
    return path:match("^(.*/)") or ""
end

-- A literal with a slash is relative to the plugin root; a bare filename is relative to the
-- file that names it.
local function resolve(literal, referrer)
    local candidates = {}
    if literal:find("/", 1, true) then
        table.insert(candidates, literal)
    else
        table.insert(candidates, directoryOf(referrer) .. literal)
        table.insert(candidates, literal)
    end
    for _, candidate in ipairs(candidates) do
        if exists(candidate) then return candidate end
    end
    return nil, table.concat(candidates, " or ")
end

-- Two roots: main.lua is the graph, and _meta.lua is loaded by KOReader's plugin loader
-- rather than by any dofile, so nothing would reach it.
local seen = { ["main.lua"] = true, ["_meta.lua"] = true }
local queue = { "main.lua", "_meta.lua" }
local checked = 0

local function enqueue(literal, referrer)
    local path, tried = resolve(literal, referrer)
    if not path then
        return fail(referrer .. " loads " .. tried .. ", which does not exist")
    end
    if not seen[path] then
        seen[path] = true
        table.insert(queue, path)
    end
end

while #queue > 0 do
    local path = table.remove(queue, 1)
    local source = readFile(path)
    if not source then
        fail(path .. ": cannot be read")
    else
        local chunk, err = loadfile(path)
        if chunk then
            checked = checked + 1
        else
            fail(tostring(err))
        end
        if usesBitLibrary(source) then
            fail(path .. " uses the LuaJIT-only `bit` library; use arithmetic instead"
                .. " (bit.band(x, 1) is x % 2 for every integer, negatives included)")
        end
        for literal in source:gmatch('"([%w_%-/%.]+%.lua)"') do
            enqueue(literal, path)
        end
        -- styles/style_registry.lua and i18n/locale_registry.lua build their paths as
        -- "<folder>/" .. name .. ".lua" over a *_FILES list, so those file names never appear
        -- as .lua literals. Read the list out of the source, so a style or locale added later
        -- is covered on the day it is added.
        local prefix = source:match('"([%w_%-/%.]*/)"%s*%.%.%s*[%w_]+%s*%.%.%s*"%.lua"')
        local list = source:match("_FILES%s*=%s*{(.-)}")
        if prefix and list then
            for name in list:gmatch('"([%w_%-]+)"') do
                enqueue(prefix .. name .. ".lua", path)
            end
        end
    end
end

-- A wrong working directory, or a discovery pattern that stopped matching, would otherwise
-- show up as a cheerful "ok (2 files)". Name a few files from the far side of the graph.
for _, required in ipairs({
    "core/theme_bundle.lua",
    "i18n/locales/en.lua",
    "rendering/custom_layout.lua",
    "styles/custom.lua",
    "styles/ju.lua",
    "ui/editor.lua",
}) do
    if not seen[required] then
        fail(required .. " was never reached -- run this spec from the plugin root")
    end
end

print(string.format("syntax_spec: %s (%d files)", failed == 0 and "ok" or "FAILED", checked))
if failed > 0 then error("syntax_spec failed", 0) end
