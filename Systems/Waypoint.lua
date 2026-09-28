-- Waypoints (the book page's "Add marker", map pin clicks) and ShowOnMap (tracker click: open
-- the world map on the book's zone, flash its pin, set a waypoint). Waypoint = TomTom when it
-- is loaded and enabled in the options, else Blizzard's user waypoint.
local _, ns = ...
local L = ns.L

local tomtomUID

local function setTomTom(b, s)
    local tt = _G.TomTom
    if not (ns.db.tomtom and tt and tt.AddWaypoint) then return false end
    if tomtomUID and tt.RemoveWaypoint then
        tt:RemoveWaypoint(tomtomUID)
    end
    tomtomUID = tt:AddWaypoint(s.map, s.x / 100, s.y / 100, {
        title = type(b) == "string" and b or ns:BookName(b),
        persistent = false,
        minimap = true,
        world = true,
        crazy = true,
        from = "Librarian",
    })
    return true
end

local function setBlizzard(s)
    if not (C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(s.map)) then return false end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(s.map, s.x / 100, s.y / 100))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
    return true
end

-- b = a book, or a plain title (the librarian); s = { map, x, y } in percent.
function ns:SetWaypoint(b, s)
    if not setTomTom(b, s) then
        setBlizzard(s)
    end
end

function ns:ShowOnMap(b, s)
    if InCombatLockdown() then
        ns:Print(L["the world map cannot be opened from an addon in combat."])
        return
    end
    ns:SetWaypoint(b, s)
    OpenWorldMap(s.map)
    ns:Fire("FOCUS", b, s)
end
