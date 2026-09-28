-- Embedded zone map for the journal's book page. The zone's map art is drawn from
-- C_Map.GetMapArtLayerTextures (+ the explored overlays from C_MapExplorationInfo, as the world
-- map shows them) into a clipped frame, with our own book pins on top. No Blizzard map code
-- runs: an addon-made MapCanvas would call ClearCachedActivitiesForPlayer from tainted code on
-- every frame, and that replaces caches the world map's own quest / POI providers read.
-- Opens filled to the box and centred on the book; mouse wheel zooms around the cursor
-- (from the whole zone up to MAX_ZOOM x the fill), left-drag pans.
local _, ns = ...
local L = ns.L

local WHITE = "Interface\\Buttons\\WHITE8X8"
local BORDER = {
    missing = { 1, 0.31, 0.31 },
    found = { 1, 0.82, 0 },
    delivered = { 0.25, 1, 0.25 },
}
local PIN, PIN_FOCUS = 20, 28
local MAX_ZOOM, ZOOM_STEP = 3, 1.25

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- ---------------------------------------------------------------------------------------
-- Pins: the world map pin's look (icon inside a state-coloured square, glow on the focus).

local function pinOnEnter(pin)
    local e = pin.entry
    local s = e.spot
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:AddLine(ns:BookName(e.book))
    GameTooltip:AddLine(ns:StatusText((ns:Status(e.book))), 1, 1, 1)
    local where = ns:WhereText(s)
    GameTooltip:AddLine(("%s%.1f, %.1f"):format(where and (where .. "  ") or "", s.x, s.y), 1, 1, 1)
    if not pin.focused then
        GameTooltip:AddLine(L["Click: show this book"], 0.5, 0.5, 0.5)
    end
    GameTooltip:Show()
end

local function newPin(map)
    local p = CreateFrame("Button", nil, map.canvas)
    p:SetFrameLevel(map.canvas:GetFrameLevel() + 5)
    p.glow = p:CreateTexture(nil, "BACKGROUND")
    p.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    p.glow:SetBlendMode("ADD")
    p.glow:SetPoint("CENTER")
    p.border = p:CreateTexture(nil, "BORDER")
    p.border:SetTexture(WHITE)
    p.border:SetAllPoints()
    p.icon = p:CreateTexture(nil, "ARTWORK")
    p.icon:SetPoint("TOPLEFT", 2, -2)
    p.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    p.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    p:SetScript("OnEnter", pinOnEnter)
    p:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p:SetScript("OnClick", function(self)
        if not self.focused and map.onPinClick then map.onPinClick(self.entry) end
    end)
    return p
end

-- ---------------------------------------------------------------------------------------
-- Art

local function releaseTextures(list)
    for _, t in ipairs(list) do t:Hide() end
end

local function getTexture(map, list, i, layer, sub)
    local t = list[i]
    if not t then
        t = map.canvas:CreateTexture(nil, layer)
        list[i] = t
    end
    t:SetDrawLayer(layer, sub)
    t:Show()
    return t
end

-- Reads the zone's art: base tiles of layer 1 and the explored overlays, in art pixels.
local function loadArt(map, mapID)
    map.art = nil
    local layers = C_Map.GetMapArtLayers and C_Map.GetMapArtLayers(mapID)
    local layer = layers and layers[1]
    if not layer then return end
    local art = {
        w = layer.layerWidth, h = layer.layerHeight,
        tileW = layer.tileWidth, tileH = layer.tileHeight,
        tiles = C_Map.GetMapArtLayerTextures(mapID, 1) or {},
        overlays = {},
    }
    art.cols = math.ceil(art.w / art.tileW)
    art.rows = math.ceil(art.h / art.tileH)
    -- Explored overlays: split into tile-sized pieces exactly as Blizzard's
    -- MapExplorationPinMixin:RefreshOverlays does; mouse-over-only overlays are left out.
    local explored = C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures
        and C_MapExplorationInfo.GetExploredMapTextures(mapID)
    for _, info in ipairs(explored or {}) do
        if not info.isShownByMouseOver then
            local wide = math.ceil(info.textureWidth / art.tileW)
            local tall = math.ceil(info.textureHeight / art.tileH)
            for j = 1, tall do
                local ph, fh = art.tileH, art.tileH
                if j == tall then
                    ph = info.textureHeight % art.tileH
                    if ph == 0 then ph = art.tileH end
                    fh = 16
                    while fh < ph do fh = fh * 2 end
                end
                for k = 1, wide do
                    local pw, fw = art.tileW, art.tileW
                    if k == wide then
                        pw = info.textureWidth % art.tileW
                        if pw == 0 then pw = art.tileW end
                        fw = 16
                        while fw < pw do fw = fw * 2 end
                    end
                    art.overlays[#art.overlays + 1] = {
                        file = info.fileDataIDs[(j - 1) * wide + k],
                        x = info.offsetX + art.tileW * (k - 1), y = info.offsetY + art.tileH * (j - 1),
                        w = pw, h = ph, u = pw / fw, v = ph / fh, top = info.isDrawOnTopLayer,
                    }
                end
            end
        end
    end
    map.art = art
end

-- Places the canvas (scale + offset) and everything on it.
local function layout(map)
    local art = map.art
    local bw, bh = map:GetWidth(), map:GetHeight()
    if not art or bw < 1 or bh < 1 then return end
    local s = map.scale
    local cw, ch = art.w * s, art.h * s
    -- a side smaller than the box is centred; a larger one is kept covering the box
    map.ox = cw <= bw and (bw - cw) / 2 or clamp(map.ox, bw - cw, 0)
    map.oy = ch <= bh and (bh - ch) / 2 or clamp(map.oy, bh - ch, 0)
    local canvas = map.canvas
    canvas:ClearAllPoints()
    canvas:SetPoint("TOPLEFT", map, "TOPLEFT", map.ox, -map.oy)
    canvas:SetSize(cw, ch)
    if map.drawnScale == s and map.drawnArt == art then return end
    map.drawnScale, map.drawnArt = s, art
    releaseTextures(map.tiles)
    for row = 1, art.rows do
        for col = 1, art.cols do
            local i = (row - 1) * art.cols + col
            local t = getTexture(map, map.tiles, i, "BACKGROUND", -7)
            t:SetTexture(art.tiles[i], nil, nil, "TRILINEAR")
            t:SetSize(art.tileW * s, art.tileH * s)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", (col - 1) * art.tileW * s, -(row - 1) * art.tileH * s)
        end
    end
    releaseTextures(map.overlays)
    for i, o in ipairs(art.overlays) do
        local t = getTexture(map, map.overlays, i, "BACKGROUND", o.top and -5 or -6)
        t:SetTexture(o.file, nil, nil, "TRILINEAR")
        t:SetTexCoord(0, o.u, 0, o.v)
        t:SetSize(o.w * s, o.h * s)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", o.x * s, -o.y * s)
    end
    for _, p in ipairs(map.pins) do
        if p:IsShown() then
            p:ClearAllPoints()
            p:SetPoint("CENTER", canvas, "TOPLEFT", p.entry.spot.x / 100 * cw, -p.entry.spot.y / 100 * ch)
        end
    end
end

-- Scale bounds: the whole zone fits the box .. MAX_ZOOM x the scale that fills it.
local function scales(map)
    local art = map.art
    local bw, bh = map:GetWidth(), map:GetHeight()
    local fit = math.min(bw / art.w, bh / art.h)
    local fill = math.max(bw / art.w, bh / art.h)
    return fit, fill, fill * MAX_ZOOM
end

-- Fill the box and centre on the focused book.
local function resetView(map)
    local art = map.art
    if not art or map:GetWidth() < 1 then
        map.needsReset = true
        return
    end
    map.needsReset = nil
    local _, fill = scales(map)
    map.scale = fill
    local f = map.focus
    local fx, fy = f and f.spot.x / 100 or 0.5, f and f.spot.y / 100 or 0.5
    map.ox = map:GetWidth() / 2 - fx * art.w * fill
    map.oy = map:GetHeight() / 2 - fy * art.h * fill
    layout(map)
end

local function cursorInMap(map)
    local x, y = GetCursorPosition()
    local es = map:GetEffectiveScale()
    return x / es - map:GetLeft(), map:GetTop() - y / es
end

local function onWheel(map, delta)
    if not map.art then return end
    local lo, _, hi = scales(map)
    local s = clamp(map.scale * (delta > 0 and ZOOM_STEP or 1 / ZOOM_STEP), lo, hi)
    if s == map.scale then return end
    -- keep the art point under the cursor where it is
    local cx, cy = cursorInMap(map)
    local u = (cx - map.ox) / (map.art.w * map.scale)
    local v = (cy - map.oy) / (map.art.h * map.scale)
    map.scale = s
    map.ox = cx - u * map.art.w * s
    map.oy = cy - v * map.art.h * s
    layout(map)
end

local function onDragUpdate(map)
    local cx, cy = cursorInMap(map)
    map.ox = map.dragOX + cx - map.dragX
    map.oy = map.dragOY + cy - map.dragY
    layout(map)
end

-- ---------------------------------------------------------------------------------------
-- API

-- map:SetZone(mapID, entries, focus) - entries = { { book, spot }, ... } of that zone, focus =
-- the entry of the page's book (drawn larger, with a glow). The view resets when the zone or
-- the focused book changes. map:Refresh() redraws the pins (states). map.onPinClick(entry).
function ns:CreateBookMap(parent)
    local map = CreateFrame("Frame", nil, parent)
    map:SetClipsChildren(true)
    map.tiles, map.overlays, map.pins = {}, {}, {}
    map.scale, map.ox, map.oy = 1, 0, 0
    local bg = map:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetTexture(WHITE)
    bg:SetVertexColor(0, 0, 0, 0.6)
    bg:SetAllPoints()
    map.canvas = CreateFrame("Frame", nil, map)
    map.canvas:SetClipsChildren(true) -- edge tiles reach past the art's size
    map:EnableMouse(true)
    map:EnableMouseWheel(true)
    map:SetScript("OnMouseWheel", onWheel)
    map:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or not self.art then return end
        self.dragX, self.dragY = cursorInMap(self)
        self.dragOX, self.dragOY = self.ox, self.oy
        self:SetScript("OnUpdate", onDragUpdate)
    end)
    map:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    map:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
    map:SetScript("OnSizeChanged", function(self)
        if self.needsReset then resetView(self) else layout(self) end
    end)

    function map:SetZone(mapID, entries, focus)
        local newZone = self.mapID ~= mapID
        local newFocus = not (self.focus and focus and self.focus.book == focus.book and self.focus.spot == focus.spot)
        self.mapID, self.entries, self.focus = mapID, entries, focus
        if newZone or not self.art then
            loadArt(self, mapID)
            self.drawnArt = nil
        end
        self:Refresh()
        if newZone or newFocus then resetView(self) else layout(self) end
    end

    function map:Refresh()
        for _, p in ipairs(self.pins) do p:Hide() end
        for i, e in ipairs(self.entries or {}) do
            local p = self.pins[i] or newPin(self)
            self.pins[i] = p
            local focused = self.focus and self.focus.book == e.book and self.focus.spot == e.spot
            local status = ns:Status(e.book)
            p.entry, p.focused = e, focused
            p.icon:SetTexture(C_Item.GetItemIconByID(e.book.item) or ns.ICON)
            p.icon:SetDesaturated(status ~= ns.MISSING)
            local c = BORDER[status]
            p.border:SetVertexColor(c[1], c[2], c[3])
            local size = focused and PIN_FOCUS or PIN
            p:SetSize(size, size)
            p.glow:SetSize(size * 2.1, size * 2.1)
            p.glow:SetShown(focused)
            -- the page's own book sits above the others where pins overlap
            p:SetFrameLevel(self.canvas:GetFrameLevel() + (focused and 6 or 5))
            p:Show()
        end
        self.drawnScale = nil -- re-anchor the pins on the next layout
        layout(self)
    end

    return map
end
