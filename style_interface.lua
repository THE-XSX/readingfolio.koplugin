-- Style module interface, version 1.
--
-- A style file must return:
--   interface_version: contract version, currently 1
--   id:     stable setting value, lowercase ASCII
--   label:  locale source string used in the menu
--   render: function(ctx) -> result
--
-- ctx is immutable by convention and contains:
--   data      normalized book/session data
--   layout    width, content_width, target_height and compact
--   theme     foreground, muted, faint and background colors
--   fonts     big, mid and small font sizes
--   translate(text) locale-aware translation for fixed style text
--   cover     the default cover widget when allow_cover is enabled
--   scaled(n) device-aware integer scaling
--   spacer(n), progress(...), center(...), coverFor(w, h), appendHighlights(...)
--
-- result must contain:
--   body: a KOReader widget
-- Optional result fields:
--   common_footer: append message/battery/clock (default true)
--   frame: padding, radius, background and full_bleed overrides
--   shadow: whether the global shadow setting applies (default true)
-- A style may set defaults.landscape, defaults.aspect_ratio and
-- defaults.default_ratio to request a landscape-oriented card canvas.

local Interface = {
    VERSION = 1,
}

local function fail(source, message)
    error(string.format("Invalid Reading Folio style %s: %s", source or "<unknown>", message), 3)
end

function Interface.validate(style, source)
    if type(style) ~= "table" then
        fail(source, "module must return a table")
    end
    if style.interface_version ~= Interface.VERSION then
        fail(source, "interface_version must be " .. Interface.VERSION)
    end
    if type(style.id) ~= "string" or not style.id:match("^[a-z][a-z0-9_]*$") then
        fail(source, "id must be lowercase ASCII and start with a letter")
    end
    if type(style.label) ~= "string" or style.label == "" then
        fail(source, "label must be a non-empty locale source string")
    end
    if type(style.render) ~= "function" then
        fail(source, "render(ctx) is required")
    end
    if style.defaults ~= nil and type(style.defaults) ~= "table" then
        fail(source, "defaults must be a table when present")
    end
    if style.defaults then
        if style.defaults.landscape ~= nil and type(style.defaults.landscape) ~= "boolean" then
            fail(source, "defaults.landscape must be a boolean")
        end
        if style.defaults.aspect_ratio ~= nil
                and (type(style.defaults.aspect_ratio) ~= "number" or style.defaults.aspect_ratio <= 0) then
            fail(source, "defaults.aspect_ratio must be a positive number")
        end
        if style.defaults.default_ratio ~= nil
                and (type(style.defaults.default_ratio) ~= "number"
                    or style.defaults.default_ratio <= 0 or style.defaults.default_ratio > 1) then
            fail(source, "defaults.default_ratio must be greater than 0 and at most 1")
        end
    end
    return style
end

function Interface.validateResult(style, result)
    if type(result) ~= "table" or not result.body then
        fail(style.id, "render(ctx) must return a table containing body")
    end
    if result.frame ~= nil and type(result.frame) ~= "table" then
        fail(style.id, "result.frame must be a table when present")
    end
    return result
end

return Interface
