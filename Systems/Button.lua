-- Addon compartment entry (runtime registration, so no global click function) and a small
-- draggable minimap button. Both open the journal; right-click opens the options.
local _, ns = ...
local L = ns.L

ns.ICON = "Interface\\Icons\\INV_Misc_Book_12"

local function tooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:AddLine("Librarian")
    GameTooltip:AddLine(L["%d library books delivered"]:format(ns:DeliveredTotal()), 1, 1, 1)
    local mapID = ns:CurrentZone()
    if mapID then
        local d, f, t = ns:Count(ns:ZoneBooks(mapID))
        if t > 0 then
            GameTooltip:AddLine(ns:ZoneName(mapID) .. ": " .. L["%d/%d delivered, %d in bags"]:format(d, t, f), 1, 1, 1)
        end
    end
    GameTooltip:AddLine(L["Left-click: journal   Right-click: options"], 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function click(button)
    if button == "RightButton" then
        ns:OpenOptions()
    else
        ns:ToggleJournal()
    end
end

local function registerCompartment()
    local acf = _G.AddonCompartmentFrame
    if not (acf and acf.RegisterAddon) then return end
    acf:RegisterAddon({
        text = "Librarian",
        icon = ns.ICON,
        notCheckable = true,
        func = function(_, input)
            click(input and input.buttonName)
        end,
        funcOnEnter = function(btn) tooltip(btn) end,
        funcOnLeave = function() GameTooltip:Hide() end,
    })
end

-- Minimap button: 31x31 like the usual LibDBIcon look, built from Blizzard's own art.
local mm
local function placeButton()
    local angle = math.rad(ns.db.minimap.angle or 200)
    local r = (Minimap:GetWidth() / 2) + 5
    mm:ClearAllPoints()
    mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function createMinimapButton()
    -- Named on purpose (the one global frame name): minimap button collectors (EllesmereUI's
    -- minimap flyout, others) only gather named buttons, and the LibDBIcon10_ prefix is the
    -- convention they all recognise and strip for the label.
    mm = CreateFrame("Button", "LibDBIcon10_Librarian", Minimap)
    mm:SetSize(31, 31)
    mm:SetFrameStrata("MEDIUM")
    mm:SetFrameLevel(8)
    mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    mm:RegisterForDrag("LeftButton")
    mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local icon = mm:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture(ns.ICON)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local border = mm:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    mm:SetScript("OnClick", function(_, button) click(button) end)
    mm:SetScript("OnEnter", tooltip)
    mm:SetScript("OnLeave", function() GameTooltip:Hide() end)
    mm:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            ns.db.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
            placeButton()
        end)
    end)
    mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    placeButton()
end

function ns:UpdateMinimapButton()
    if ns.db.minimap.hide then
        if mm then mm:Hide() end
        return
    end
    if not mm then createMinimapButton() end
    mm:Show()
end

ns:On("LOADED", function()
    registerCompartment()
    ns:UpdateMinimapButton()
end)
ns:On("SETTING", function(key)
    if key == "minimap" then ns:UpdateMinimapButton() end
end)
