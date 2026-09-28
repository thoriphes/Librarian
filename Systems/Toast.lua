-- Zone-enter toast: entering a zone that still has a missing book shows one toast, once per
-- zone per session. Looks like Blizzard's Battle.net "friend online" toast (SocialToastTemplate /
-- BNToastFrame in Blizzard_SocialToast + Blizzard_BNet): toast backdrop, 40 px icon, blue top
-- line + grey lines in FriendsFont_Normal, the toast close button, flair glow, 0.2 s fade in, 7 s
-- hold, 1.5 s fade out, paused while hovered. Own sound (quest-list open), not the BNet one. Rebuilt with the same parts instead of inheriting
-- the template: that one is an AlertFrame-managed frame and nothing of Blizzard's alert queue
-- should run our code. Click = open the journal on that zone.
local _, ns = ...
local L = ns.L

local shown = {}   -- mapID -> true, this session
local toast
local FADE_IN, HOLD, FADE_OUT = 0.2, 7, 1.5
local WIDTH, MIN_HEIGHT = 250, 50
-- Tinted to the journal's wood / gold palette (UI/Journal.lua C): the toast textures are grey,
-- vertex colours turn them brown with a gold border.
local TOP_COLOR = { 1, 0.82, 0.3 }        -- journal title gold
local LINE_COLOR = { 0.95, 0.9, 0.8 }     -- journal text
local BG_TINT = { 0.62, 0.45, 0.28, 0.97 }
local BORDER_TINT = { 0.85, 0.66, 0.3 }
local CLOSE_TINT = { 1, 0.8, 0.4 }
-- Blizzard_SharedXML/Backdrop.lua; copied in case the global is renamed
local BACKDROP = BACKDROP_TOAST_12_12 or {
    bgFile = "Interface\\FriendsFrame\\UI-Toast-Background",
    edgeFile = "Interface\\FriendsFrame\\UI-Toast-Border",
    tile = true, tileEdge = true, tileSize = 12, edgeSize = 12,
    insets = { left = 5, right = 5, top = 5, bottom = 5 },
}

local function create()
    local f = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    f:SetSize(WIDTH, MIN_HEIGHT)
    f:SetPoint("TOP", UIParent, "TOP", 0, -150)
    f:SetFrameStrata("LOW")
    f:SetToplevel(true)
    f:SetBackdrop(BACKDROP)
    f:SetBackdropColor(unpack(BG_TINT))
    f:SetBackdropBorderColor(unpack(BORDER_TINT))

    f.icon = f:CreateTexture(nil, "BORDER")
    -- inside the border: Blizzard's 40 px toast icons carry their own transparent margin, ours is
    -- a full-bleed item icon
    f.icon:SetSize(34, 34)
    f.icon:SetPoint("LEFT", 10, 0)
    f.icon:SetTexture(ns.ICON)
    f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    f.top = f:CreateFontString(nil, "BORDER", "FriendsFont_Normal")
    f.top:SetPoint("TOPLEFT", 52, -10)
    f.top:SetPoint("RIGHT", -20, 0)
    f.top:SetJustifyH("LEFT")
    f.top:SetTextColor(unpack(TOP_COLOR))
    f.lines = f:CreateFontString(nil, "BORDER", "FriendsFont_Normal")
    f.lines:SetPoint("TOPLEFT", f.top, "BOTTOMLEFT", 0, -4)
    f.lines:SetPoint("RIGHT", -20, 0)
    f.lines:SetJustifyH("LEFT")
    f.lines:SetJustifyV("TOP")
    f.lines:SetSpacing(4)
    f.lines:SetTextColor(unpack(LINE_COLOR))

    -- flair glow on arrival
    f.glow = f:CreateTexture(nil, "OVERLAY")
    f.glow:SetTexture("Interface\\FriendsFrame\\UI-Toast-Flair")
    f.glow:SetBlendMode("ADD")
    f.glow:SetPoint("TOPLEFT", -1, 3)
    f.glow:SetPoint("BOTTOMRIGHT", 1, -3)
    f.glow:Hide()
    local ag = f.glow:CreateAnimationGroup()
    local a1 = ag:CreateAnimation("Alpha")
    a1:SetFromAlpha(0) a1:SetToAlpha(1) a1:SetDuration(0.2) a1:SetOrder(1)
    local a2 = ag:CreateAnimation("Alpha")
    a2:SetFromAlpha(1) a2:SetToAlpha(0) a2:SetDuration(0.5) a2:SetOrder(2)
    ag:SetScript("OnFinished", function() f.glow:Hide() end)
    f.glowAnim = ag

    -- the toast close button
    local close = CreateFrame("Button", nil, f)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", -4, -3)
    close:SetNormalTexture("Interface\\FriendsFrame\\UI-Toast-CloseButton-Up")
    close:SetPushedTexture("Interface\\FriendsFrame\\UI-Toast-CloseButton-Down")
    close:SetHighlightTexture("Interface\\FriendsFrame\\UI-Toast-CloseButton-Highlight", "ADD")
    close:GetNormalTexture():SetVertexColor(unpack(CLOSE_TINT))
    close:GetPushedTexture():SetVertexColor(unpack(CLOSE_TINT))
    close:SetScript("OnClick", function() f:Hide() end)

    f:RegisterForClicks("LeftButtonUp")
    f:SetScript("OnClick", function(self)
        self:Hide()
        ns:OpenZoneBook(self.mapID)
    end)
    -- fade in, hold, fade out; the clock stops while the mouse is over the toast (or its X)
    f:SetScript("OnUpdate", function(self, dt)
        if self:IsMouseOver() then
            if self.elapsed > FADE_IN then
                self.elapsed = FADE_IN
                self:SetAlpha(1)
            end
            return
        end
        self.elapsed = self.elapsed + dt
        local t = self.elapsed
        if t < FADE_IN then
            self:SetAlpha(t / FADE_IN)
        elseif t < FADE_IN + HOLD then
            self:SetAlpha(1)
        elseif t < FADE_IN + HOLD + FADE_OUT then
            self:SetAlpha(1 - (t - FADE_IN - HOLD) / FADE_OUT)
        else
            self:Hide()
        end
    end)
    f:Hide()
    return f
end

-- force = show even if already shown this session or switched off (/librarian toast).
function ns:ShowZoneToast(mapID, force)
    if not mapID then
        if force then ns:Print(L["no library books in this zone."]) end
        return
    end
    if not force and (shown[mapID] or not ns.db.toast) then return end
    local missing = ns:ZoneMissing(mapID)
    if #missing == 0 then
        if force then ns:Print(L["%s: no missing books."]:format(ns:ZoneName(mapID))) end
        return
    end
    shown[mapID] = true
    toast = toast or create()
    toast.mapID = mapID
    toast.top:SetText(#missing == 1 and L["1 library book missing in %s"]:format(ns:ZoneName(mapID))
        or L["%d library books missing in %s"]:format(#missing, ns:ZoneName(mapID)))
    local lines = {}
    for i, e in ipairs(missing) do
        if i > 3 then
            lines[#lines + 1] = L["and %d more"]:format(#missing - 3)
            break
        end
        lines[#lines + 1] = ("%s (%.1f, %.1f)"):format(ns:BookName(e.book), e.spot.x, e.spot.y)
    end
    toast.lines:SetText(table.concat(lines, "\n"))
    toast:SetHeight(math.max(MIN_HEIGHT, 10 + toast.top:GetStringHeight() + 4 + toast.lines:GetStringHeight() + 10))
    toast.elapsed = 0
    toast:SetAlpha(0)
    toast:Show()
    toast.glow:Show()
    toast.glowAnim:Stop()
    toast.glowAnim:Play()
    PlaySound(SOUNDKIT.IG_QUEST_LIST_OPEN) -- not the friend-online sound: that one would mislead
end

local function check()
    -- The map can report the old zone for a moment after a loading screen.
    C_Timer.After(2, function()
        ns:ShowZoneToast(ns:CurrentZone())
    end)
end

ns:On("LOADED", function()
    ns:RegisterEvent("ZONE_CHANGED_NEW_AREA", check)
    ns:RegisterEvent("PLAYER_ENTERING_WORLD", check)
end)
