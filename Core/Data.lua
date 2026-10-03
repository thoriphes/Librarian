-- Indexes over the generated Data/Books.lua.
local _, ns = ...

ns.byItem = {}      -- item -> book
ns.byQuest = {}     -- quest -> book
ns.byZone = {}      -- uiMapID -> { { book = b, spot = s }, ... }
ns.unavailable = {} -- books with no spot (unplaced / not in Forever)

for _, b in ipairs(ns.Books) do
    ns.byItem[b.item] = b
    if b.quest then ns.byQuest[b.quest] = b end
    if #b.spots == 0 then
        table.insert(ns.unavailable, b)
    end
    for _, s in ipairs(b.spots) do
        ns.byZone[s.map] = ns.byZone[s.map] or {}
        table.insert(ns.byZone[s.map], { book = b, spot = s })
    end
end

function ns:PlayerFaction()
    return (UnitFactionGroup("player"))
end

-- Zone entries for this character, in page order.
function ns:ZoneEntries(mapID)
    local out = {}
    for _, e in ipairs(ns.byZone[mapID] or {}) do
        table.insert(out, e)
    end
    return out
end

-- Zones that have at least one book for this character, in three groups by zone state:
-- Missing (any book missing) > In bags (any in the bags, none missing) > Delivered. Inside a
-- group: own faction's zones whose level you have first; then by zone level (the page's range,
-- else the classic range, else the lowest book's set level), then own faction's zones before
-- contested before the other faction's, then name.
local function zoneLevel(mapID)
    local z = ns.Zones[mapID]
    local lvl = z.level and tonumber(z.level:match("^(%d+)"))
    if lvl then return lvl end
    -- Capital cities have no level range: your own sorts first, the other faction's last.
    if z.side and z.side ~= "Contested" then
        return z.side == ns:PlayerFaction() and 1 or 60
    end
    local t
    for _, e in ipairs(ns.byZone[mapID] or {}) do
        if not t or (e.book.tier or 99) < t then t = e.book.tier or 99 end
    end
    return t or 99
end

local function factionRank(mapID)
    local side = ns:ZoneSide(mapID)
    if side == ns:PlayerFaction() then return 1 end
    if side == "Contested" then return 2 end
    return 3
end

-- UnitLevel can still read the old level during PLAYER_LEVEL_UP: the event's level wins.
local levelUp
local function playerLevel()
    return math.max(levelUp or 0, UnitLevel("player") or 0)
end
ns.PlayerLevel = playerLevel
ns:RegisterEvent("PLAYER_LEVEL_UP", function(_, level)
    levelUp = tonumber(level)
    ns:Fire("STATUS") -- re-sort: zones may have become reachable
end)

-- Own faction's zones you have the level for come first (Nacho, 2026-09-29).
local function reachableOwn(mapID, lvl)
    return factionRank(mapID) == 1 and lvl <= playerLevel()
end

-- The one zone order used everywhere: own reachable zones first, then level, side, name.
local function zoneBefore(a, b)
    local la, lb = zoneLevel(a), zoneLevel(b)
    local ra, rb = reachableOwn(a, la), reachableOwn(b, lb)
    if ra ~= rb then return ra end
    if la ~= lb then return la < lb end
    local fa, fb = factionRank(a), factionRank(b)
    if fa ~= fb then return fa < fb end
    return ns.Zones[a].name < ns.Zones[b].name
end

function ns:ZoneState(mapID)
    local d, f, t = ns:Count(ns:ZoneBooks(mapID))
    if t - d - f > 0 then return ns.MISSING end
    if f > 0 then return ns.FOUND end
    return ns.DELIVERED
end

-- Display order: In bags first (a trip to the librarian away), then Missing, then Delivered.
-- name = locale key (ns.L). Look groups up by state (ns:Group), never by position.
ns.StateGroups = {
    { state = "found", name = "In bags" },
    { state = "missing", name = "Missing" },
    { state = "delivered", name = "Delivered" },
}

function ns:Group(groups, state)
    for _, g in ipairs(groups) do
        if g.state == state then return g end
    end
end

function ns:ZoneList()
    local byState = {}
    for mapID in pairs(ns.Zones) do
        if #ns:ZoneEntries(mapID) > 0 then
            local st = ns:ZoneState(mapID)
            byState[st] = byState[st] or {}
            table.insert(byState[st], mapID)
        end
    end
    local groups = {}
    for _, g in ipairs(ns.StateGroups) do
        local list = byState[g.state] or {}
        table.sort(list, zoneBefore)
        table.insert(groups, { state = g.state, name = g.name, zones = list })
    end
    return groups
end

-- One entry per book for this character (books with no known spot excluded), in the same
-- three state groups and order as ZoneList. A book in two zones (Rumi) is placed by its best
-- spot (first in zone order); the rest go in `others`.
local function better(a, b)
    return zoneBefore(a.map, b.map)
end

-- { book, spot, others } for one book; spot = the given one, else its best spot.
function ns:BookEntry(b, spot)
    if not spot then
        spot = b.spots[1]
        for _, s in ipairs(b.spots) do
            if better(s, spot) then spot = s end
        end
    end
    local others = {}
    for _, s in ipairs(b.spots) do
        if s ~= spot then others[#others + 1] = s end
    end
    return { book = b, spot = spot, others = others }
end

function ns:BookList()
    local byState = {}
    for _, b in ipairs(ns.Books) do
        if #b.spots > 0 then
            local st = ns:Status(b)
            byState[st] = byState[st] or {}
            table.insert(byState[st], ns:BookEntry(b))
        end
    end
    local groups = {}
    for _, g in ipairs(ns.StateGroups) do
        local list = byState[g.state] or {}
        table.sort(list, function(a, b)
            if a.spot.map ~= b.spot.map then
                return zoneBefore(a.spot.map, b.spot.map)
            end
            return ns:BookName(a.book) < ns:BookName(b.book)
        end)
        table.insert(groups, { state = g.state, name = g.name, entries = list })
    end
    return groups
end

function ns:ZoneName(mapID)
    local info = C_Map.GetMapInfo(mapID)
    return (info and info.name) or (ns.Zones[mapID] and ns.Zones[mapID].name) or tostring(mapID)
end

-- The zone the player is in, walked up to the first map we have data for (so a cave or
-- sub-zone map counts as its parent zone).
function ns:CurrentZone()
    local mapID = C_Map.GetBestMapForUnit("player")
    local guard = 0
    while mapID and guard < 10 do
        if ns.Zones[mapID] then return mapID end
        local info = C_Map.GetMapInfo(mapID)
        mapID = info and info.parentMapID
        guard = guard + 1
    end
end

-- Alliance / Horde / Contested. The page tags only its own zone sections; every zone it leaves
-- untagged (Arathi, Badlands, the Plaguelands, Tanaris...) is contested in the classic world.
function ns:ZoneSide(mapID)
    local z = ns.Zones[mapID]
    return z and z.side or "Contested"
end
