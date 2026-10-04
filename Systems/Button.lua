-- Addon compartment entry (runtime registration, so no global click function) and the
-- minimap button. Both open the journal; right-click opens the options.
local _, ns = ...
local L = ns.L

ns.ICON = "Interface\\Icons\\INV_Misc_Book_12"

local function fillTooltip(tt)
    tt:AddLine("Librarian")
    tt:AddLine(L["%d library books delivered"]:format(ns:DeliveredTotal()), 1, 1, 1)
    local mapID = ns:CurrentZone()
    if mapID then
        local d, f, t = ns:Count(ns:ZoneBooks(mapID))
        if t > 0 then
            tt:AddLine(ns:ZoneName(mapID) .. ": " .. L["%d/%d delivered, %d in bags"]:format(d, t, f), 1, 1, 1)
        end
    end
    tt:AddLine(L["Left-click: journal   Right-click: options"], 0.6, 0.6, 0.6)
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
        funcOnEnter = function(btn)
            GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
            fillTooltip(GameTooltip)
            GameTooltip:Show()
        end,
        funcOnLeave = function() GameTooltip:Hide() end,
    })
end

-- Minimap button through LibDataBroker + LibDBIcon (embedded, see .pkgmeta): button bags
-- (Leatrix Plus, EllesmereUI's minimap flyout, others) collect the buttons LibDBIcon registers.
-- LibDBIcon keeps hide/minimapPos in ns.db.minimap and handles the drag.
local ICON_NAME = "Librarian"
local icon = LibStub("LibDBIcon-1.0")

local function registerMinimapButton()
    local m = ns.db.minimap
    if m.angle then  -- 1.2.0 and earlier: our own button's angle, same convention as minimapPos
        m.minimapPos, m.angle = m.angle, nil
    end
    icon:Register(ICON_NAME, LibStub("LibDataBroker-1.1"):NewDataObject(ICON_NAME, {
        type = "launcher",
        icon = ns.ICON,
        OnClick = function(_, button) click(button) end,
        OnTooltipShow = fillTooltip,
    }), m)
end

function ns:UpdateMinimapButton()
    if ns.db.minimap.hide then
        icon:Hide(ICON_NAME)
    else
        icon:Show(ICON_NAME)
    end
end

ns:On("LOADED", function()
    registerCompartment()
    registerMinimapButton()
end)
ns:On("SETTING", function(key)
    if key == "minimap" then ns:UpdateMinimapButton() end
end)
