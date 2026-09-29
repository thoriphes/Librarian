-- Localisation. Keys are the English strings (enUS is the key itself); a locale table only lists
-- what it translates, anything missing falls back to English. Names that come from the game
-- (book titles, zones, quest titles, factions) are read from the client instead - see
-- ns:BookName / ns:QuestTitle / ns:SideName; data texts (notes, containers) come from
-- Data/Strings.lua - see ns:DataText below.
local _, ns = ...

local L = setmetatable({}, { __index = function(_, k) return k end })
ns.L = L

-- Translations: Data/Locales.lua (generated from tools/librarian-i18n/ui/*.json) builds only
-- the running client's table.
for k, v in pairs(ns.UIL or {}) do rawset(L, k, v) end
ns.UIL = nil

-- ---------------------------------------------------------------------------------------
-- Names from the client (localised); the data file's English names are the fallback until
-- the item / quest is cached.

function ns:BookName(b)
    return C_Item.GetItemNameByID(b.item) or b.name
end

function ns:QuestTitle(questID, fallback)
    return C_QuestLog.GetTitleForQuestID(questID) or fallback
end

function ns:SideName(side)
    if side == "Alliance" then return FACTION_ALLIANCE or side end
    if side == "Horde" then return FACTION_HORDE or side end
    return L[side]
end

-- ---------------------------------------------------------------------------------------
-- Book data text. Places come from the game (area ID -> localised name, every client locale);
-- containers, notes and the "cannot be had" texts from Data/Strings.lua (ns.DataL, generated:
-- Blizzard's strings + hand translations); flavour from the client's own item tooltip, else
-- Blizzard's text in Strings.lua, else the site's English.

local function dataL()
    return ns.DataL or { strings = {}, flavour = {} }
end

function ns:DataText(s)
    return s and (dataL().strings[s] or s)
end

function ns:PlaceName(spot)
    if spot.area then
        local name = C_Map.GetAreaInfo(spot.area)
        if name and name ~= "" then return name end
    end
    return ns:DataText(spot.place)
end

-- "Scrolls at Moonbrook" / "Scrolls" / "Moonbrook" / nil
function ns:WhereText(spot)
    local c, p = ns:DataText(spot.container), spot.place and ns:PlaceName(spot)
    if c and p then return L["%s at %s"]:format(c, p) end
    return c or p
end

local flavourCache = {}
local function clientFlavour(item)
    if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return end
    local data = C_TooltipInfo.GetItemByID(item)
    for _, line in ipairs(data and data.lines or {}) do
        local text = line.leftText
        local inner = type(text) == "string" and text:match('^"(.+)"$')
        if inner then return inner end
    end
end

function ns:Flavour(b)
    local official = dataL().flavour[b.item]
    if official then return official end
    if GetLocale() == "enUS" or GetLocale() == "enGB" then return b.flavour end
    if flavourCache[b.item] == nil then
        flavourCache[b.item] = clientFlavour(b.item) or false
    end
    return flavourCache[b.item] or b.flavour
end

-- Ask the client for every book's item data once; refresh the UI when names arrive.
ns:On("LOADED", function()
    local pending = {}
    for _, b in ipairs(ns.Books) do
        if not C_Item.GetItemNameByID(b.item) then
            pending[b.item] = true
            C_Item.RequestLoadItemDataByID(b.item)
        end
    end
    for _, g in ipairs(ns.Goals) do
        if C_QuestLog.RequestLoadQuestByID then C_QuestLog.RequestLoadQuestByID(g.quest) end
        for _, r in ipairs(g.rewards or {}) do
            if not C_Item.GetItemNameByID(r.item) then
                pending[r.item] = true
                C_Item.RequestLoadItemDataByID(r.item)
            end
        end
    end
    ns:RegisterEvent("ITEM_DATA_LOAD_RESULT", function(_, itemID, success)
        if pending[itemID] and success then
            pending[itemID] = nil
            flavourCache[itemID] = nil
            ns:Fire("NAMES")
        end
    end)
    ns:RegisterEvent("QUEST_DATA_LOAD_RESULT", function() ns:Fire("NAMES") end)
end)
