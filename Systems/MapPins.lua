-- World map pins: a MapCanvas data provider (Forever's world map is retail's MapCanvas).
-- Zone maps show their books; the Kalimdor / Eastern Kingdoms maps show every book of the
-- continent (an option). Missing books by default, found-not-delivered ones as an option.
-- Pin size = the mapPinSize option (percent).
-- Click = waypoint, shift-click = the book's journal page.
--
-- OpenMap (one stitched world map): the map underneath follows the view (world, continent,
-- zone) and its canvas shows past that map's edges, so placing books for the map underneath
-- only made them come and go with every zoom, and left the neighbouring zones empty. While it
-- stitches, every book is placed through OpenMapAPI onto whatever map is underneath, and the
-- pins are lifted above its art (they are made under it).
local _, ns = ...
local L = ns.L

-- OpenMapAPI while OpenMap shows its stitched map (major 1, version 2+: ArtTopLevel); nil otherwise
local function stitched()
    local api = _G.OpenMapAPI
    if type(api) ~= "table" or api.major ~= 1 or (tonumber(api.version) or 0) < 2 then return end
    local ok, on = pcall(api.IsStitched)
    if ok and on then return api end
end

-- Above OpenMap's art while it stitches. A frame level change on the map is restricted in combat:
-- skipped then, done again as combat ends (PLAYER_REGEN_ENABLED below).
local function liftAboveArt(pin)
    local api = stitched()
    if not api or InCombatLockdown() then return end
    local top = api.ArtTopLevel()
    if type(top) == "number" and pin:GetFrameLevel() <= top then pin:SetFrameLevel(top + 2) end
end

local TEMPLATE = "LibrarianBookPinTemplate"
local CONTINENT_IDS = { [1414] = true, [1415] = true }
local BORDER = {
    missing = { 1, 0.31, 0.31 },
    found = { 1, 0.82, 0 },
    delivered = { 0.25, 1, 0.25 },
}
local FOCUS_TIME = 10

local provider

-- ---------------------------------------------------------------------------------------
-- Pin

local function buildPinMixin()
    local PinMixin = CreateFromMixins(MapCanvasPinMixin)

    function PinMixin:OnLoad()
        self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
        self:SetScalingLimits(1, 1.0, 1.25)
    end

    -- Blizzard's AcquirePin re-sets the right-click pass-through on every acquire, and
    -- SetPassThroughButtons is protected in combat for addon frames (world map opened in combat
    -- = ADDON_ACTION_BLOCKED). Ours never changes: set it once, out of combat.
    function PinMixin:CheckMouseButtonPassthrough(...)
        if self.passThroughSet or InCombatLockdown() then return end
        MapCanvasPinMixin.CheckMouseButtonPassthrough(self, ...)
        self.passThroughSet = true
    end

    function PinMixin:OnAcquired(book, spot, x, y, status, focused)
        self.book, self.spot, self.status = book, spot, status
        self:SetPosition(x, y)
        self.Icon:SetTexture(C_Item.GetItemIconByID(book.item) or ns.ICON)
        self.Icon:SetDesaturated(status ~= ns.MISSING)
        local c = BORDER[status]
        self.Border:SetVertexColor(c[1], c[2], c[3])
        self.Glow:SetShown(focused)
        local scale = (ns.db.mapPinSize or 100) / 100
        local size = math.floor((focused and 28 or 22) * scale + 0.5)
        self:SetSize(size, size)
        self.Glow:SetSize(46 * scale, 46 * scale)
        -- Blizzard's level first (a pin lifted on the stitched map, reused on Blizzard's own map,
        -- goes back down), then above OpenMap's art if it stitches
        if self.ApplyFrameLevel then self:ApplyFrameLevel() end
        liftAboveArt(self)
    end

    function PinMixin:OnMouseEnter()
        local b, s = self.book, self.spot
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(ns:BookName(b))
        GameTooltip:AddLine(ns:StatusText(self.status), 1, 1, 1)
        GameTooltip:AddLine(("%s  %.1f, %.1f"):format(ns:ZoneName(s.map), s.x, s.y), 1, 1, 1)
        local where = ns:WhereText(s)
        if where then GameTooltip:AddLine(where, 0.8, 0.8, 0.8) end
        if s.note then GameTooltip:AddLine(ns:DataText(s.note), 0.8, 0.8, 0.8, true) end
        GameTooltip:AddLine(b.trainer and L["Turn in: mage trainer"] or L["Turn in: librarian"], 0.6, 0.6, 0.6)
        GameTooltip:AddLine(L["Click: waypoint   Shift-click: journal"], 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end

    function PinMixin:OnMouseLeave()
        GameTooltip:Hide()
    end

    function PinMixin:OnClick(button)
        if button ~= "LeftButton" then return end
        if IsShiftKeyDown() then
            ns:OpenBook(self.book, self.spot)
        else
            ns:SetWaypoint(self.book, self.spot)
            ns:Print(L["waypoint set: %s"]:format(ns:BookName(self.book)))
        end
    end

    ns.PinMixin = PinMixin
end

-- ---------------------------------------------------------------------------------------
-- Data provider

local function focused(book, spot)
    local f = ns.focus
    return f and f.book == book and f.spot == spot and (GetTime() - f.time) < FOCUS_TIME
end

local function shouldPin(book, spot)
    if focused(book, spot) then return true end
    if not ns.db.mapPins then return false end
    local s = ns:Status(book)
    return s == ns.MISSING or (s == ns.FOUND and ns.db.mapPinsFound)
end

-- The stitched map: every book, from its own zone through OpenMap's world onto the map
-- underneath (positions past 0..1 are on the canvas beyond that map, which OpenMap shows).
-- Zoomed out to a continent or the world, "Show on continent maps" still decides, as on
-- Blizzard's continent maps; zoomed in, the neighbouring zones' books show with the zone's.
local function refreshStitched(map, mapID, api)
    local info = C_Map.GetMapInfo(mapID)
    local continentType = Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2
    local wide = CONTINENT_IDS[mapID] or not (info and info.mapType) or info.mapType <= continentType
    local all = not wide or ns.db.mapPinsContinent
    for zoneID, list in pairs(ns.byZone) do
        for _, e in ipairs(list) do
            if (all or focused(e.book, e.spot)) and shouldPin(e.book, e.spot) then
                local u, v = api.WorldFromMap(zoneID, e.spot.x / 100, e.spot.y / 100)
                local x, y
                if u then x, y = api.MapFromWorld(mapID, u, v) end
                if x then
                    map:AcquirePin(TEMPLATE, e.book, e.spot, x, y, (ns:Status(e.book)), focused(e.book, e.spot))
                end
            end
        end
    end
end

local function buildProvider()
    provider = CreateFromMixins(MapCanvasDataProviderMixin)

    function provider:RemoveAllData()
        self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
    end

    function provider:RefreshAllData()
        self:RemoveAllData()
        local map = self:GetMap()
        local mapID = map:GetMapID()
        if not mapID then return end
        local api = stitched()
        if api then
            refreshStitched(map, mapID, api)
            -- (again once acquired: AcquirePin may set the level itself after OnAcquired)
            for pin in map:EnumeratePinsByTemplate(TEMPLATE) do liftAboveArt(pin) end
        elseif ns.Zones[mapID] then
            for _, e in ipairs(ns.byZone[mapID] or {}) do
                if shouldPin(e.book, e.spot) then
                    map:AcquirePin(TEMPLATE, e.book, e.spot, e.spot.x / 100, e.spot.y / 100,
                        (ns:Status(e.book)), focused(e.book, e.spot))
                end
            end
        elseif CONTINENT_IDS[mapID] then
            -- continent pins off: only a focused book (Show on map) still gets its pin
            local all = ns.db.mapPinsContinent
            for zoneID, z in pairs(ns.Zones) do
                if z.continent == mapID then
                    local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(zoneID, mapID)
                    if minX then
                        for _, e in ipairs(ns.byZone[zoneID] or {}) do
                            if (all or focused(e.book, e.spot)) and shouldPin(e.book, e.spot) then
                                map:AcquirePin(TEMPLATE, e.book, e.spot,
                                    minX + (maxX - minX) * e.spot.x / 100,
                                    minY + (maxY - minY) * e.spot.y / 100,
                                    (ns:Status(e.book)), focused(e.book, e.spot))
                            end
                        end
                    end
                end
            end
        end
    end

    function provider:OnMapChanged()
        self:RefreshAllData()
    end
end

function ns:RefreshMapPins()
    if provider and provider:GetMap() and WorldMapFrame:IsShown() then
        provider:RefreshAllData()
    end
end

local function setup()
    if provider or not (WorldMapFrame and MapCanvasPinMixin and MapCanvasDataProviderMixin) then return end
    buildPinMixin()
    buildProvider()
    WorldMapFrame:AddDataProvider(provider)
    -- OpenMap switching between its stitched map and Blizzard's (no map change of its own then)
    local api = _G.OpenMapAPI
    if type(api) == "table" and api.major == 1 and type(api.RegisterCallback) == "function" then
        api.RegisterCallback(ns, "OpenMap_StitchedChanged", function() ns:RefreshMapPins() end)
    end
end

-- pins placed in combat on the stitched map could not be lifted above its art: now they can
ns:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    if stitched() then ns:RefreshMapPins() end
end)

ns:On("LOADED", function()
    if WorldMapFrame then
        setup()
    else
        ns:RegisterEvent("ADDON_LOADED", function(_, name)
            if name == "Blizzard_WorldMap" then setup() end
        end)
    end
end)
ns:On("STATUS", ns.RefreshMapPins)
ns:On("SETTING", ns.RefreshMapPins)
ns:On("FOCUS", function(book, spot)
    ns.focus = { book = book, spot = spot, time = GetTime() }
    -- OpenWorldMap can land on the previously viewed zone for a moment; set it again.
    C_Timer.After(0.1, function()
        if WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() ~= spot.map then
            WorldMapFrame:SetMapID(spot.map)
        end
        ns:RefreshMapPins()
    end)
    C_Timer.After(FOCUS_TIME + 0.1, ns.RefreshMapPins)
end)
