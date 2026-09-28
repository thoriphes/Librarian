-- Librarian: addon table, saved variables, events, callbacks.
local ADDON, ns = ...
Librarian = ns
ns.name = ADDON

-- Account-wide settings. Per-character manual marks live in LibrarianCharDB.
local DEFAULTS = {
    toast = true,           -- zone-enter toast
    mapPins = true,         -- world map pins for missing books
    mapPinsFound = false,   -- also pin books found but not yet delivered
    tracker = true,         -- objective tracker section
    tomtom = true,          -- waypoints go to TomTom when it is loaded
    minimap = { hide = false, angle = 200 },
    window = {},            -- point, x, y
}

local function applyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            applyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

-- Tiny callback list: ns:On("STATUS", fn) / ns:Fire("STATUS", ...).
local listeners = {}
function ns:On(event, fn)
    listeners[event] = listeners[event] or {}
    table.insert(listeners[event], fn)
end
function ns:Fire(event, ...)
    for _, fn in ipairs(listeners[event] or {}) do
        fn(...)
    end
end

function ns:Print(...)
    print("|cffc8a2ffLibrarian|r:", ...)
end

local frame = CreateFrame("Frame")
ns.eventFrame = frame
local handlers = {}
function ns:RegisterEvent(event, fn)
    handlers[event] = handlers[event] or {}
    table.insert(handlers[event], fn)
    frame:RegisterEvent(event)
end
frame:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(handlers[event]) do
        fn(event, ...)
    end
end)

ns:RegisterEvent("ADDON_LOADED", function(_, name)
    if name ~= ADDON then return end
    LibrarianDB = LibrarianDB or {}
    LibrarianCharDB = LibrarianCharDB or {}
    applyDefaults(LibrarianDB, DEFAULTS)
    applyDefaults(LibrarianCharDB, { marks = {} })
    ns.db = LibrarianDB
    ns.char = LibrarianCharDB
    ns:Fire("LOADED")
end)

-- Setting writes go through here so modules can react.
function ns:Set(key, value)
    ns.db[key] = value
    ns:Fire("SETTING", key, value)
end
