-- World map pins: a MapCanvas data provider (Forever's world map is retail's MapCanvas).
-- Zone maps show their books; the Kalimdor / Eastern Kingdoms maps show every book of the
-- continent. Missing books by default, found-not-delivered ones as an option.
-- Click = waypoint, shift-click = the book's journal page.
local _, ns = ...
local L = ns.L

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
        self:SetSize(focused and 28 or 22, focused and 28 or 22)
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
        if ns.Zones[mapID] then
            for _, e in ipairs(ns.byZone[mapID] or {}) do
                if shouldPin(e.book, e.spot) then
                    map:AcquirePin(TEMPLATE, e.book, e.spot, e.spot.x / 100, e.spot.y / 100,
                        (ns:Status(e.book)), focused(e.book, e.spot))
                end
            end
        elseif CONTINENT_IDS[mapID] then
            for zoneID, z in pairs(ns.Zones) do
                if z.continent == mapID then
                    local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(zoneID, mapID)
                    if minX then
                        for _, e in ipairs(ns.byZone[zoneID] or {}) do
                            if shouldPin(e.book, e.spot) then
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
end

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
