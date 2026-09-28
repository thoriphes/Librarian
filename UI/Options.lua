-- Options. The controls are built by ns:BuildOptionControls into two places:
-- - the journal's own options page (the gear, the minimap right-click, /librarian options):
--   opening Blizzard's Settings panel from there sent the player back to the game menu when it
--   closed (SettingsPanel:TransitionBackOpeningPanel -> ToggleGameMenu), which makes no sense
--   for a panel opened from an addon window;
-- - a canvas-layout Settings category (Esc > Options > AddOns), for players who look there. The
--   vertical-layout Settings panels are the ones known to taint the Social page on 12.x clients.
local _, ns = ...
local L = ns.L

local OPTIONS = {
    { key = "toast", label = "Zone toast", tip = "Entering a zone with a missing book shows a toast, once per zone per session." },
    { key = "mapPins", label = "World map pins", tip = "Pins for missing books on zone and continent maps." },
    { key = "mapPinsFound", label = "Also pin books in your bags", tip = "Pin books that are in your bags but not delivered yet.", indent = true },
    { key = "tracker", label = "Objective tracker section", tip = "List the zone's missing books in the objective tracker. Changes apply out of combat." },
    { key = "tomtom", label = "TomTom waypoints", tip = "Waypoints (Add marker, map pins, the tracker) go to TomTom when it is loaded (otherwise Blizzard's map pin)." },
    { key = "minimapHide", label = "Hide the minimap button", tip = "The addon compartment entry stays." },
}

local function get(key)
    if key == "minimapHide" then return ns.db.minimap.hide end
    return ns.db[key]
end

local function set(key, value)
    if key == "minimapHide" then
        ns.db.minimap.hide = value
        ns:Fire("SETTING", "minimap", value)
    else
        ns:Set(key, value)
    end
end

-- Checkboxes + help text under (x, y) of parent. Returns refresh() (re-reads the settings into
-- the boxes) and the y below the last control.
function ns:BuildOptionControls(parent, x, y)
    local boxes = {}
    for _, o in ipairs(OPTIONS) do
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", x + (o.indent and 24 or 0), y)
        local label = cb.Text or cb.text
        label:SetText(L[o.label])
        label:SetFontObject("GameFontHighlight")
        cb:SetScript("OnClick", function(self) set(o.key, self:GetChecked() and true or false) end)
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(L[o.label])
            GameTooltip:AddLine(L[o.tip], 1, 1, 1, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        boxes[o.key] = cb
        y = y - 30
    end
    local help = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", x, y - 14)
    help:SetJustifyH("LEFT")
    help:SetText("/librarian - journal    /librarian zone [name] - zone status in chat\n"
        .. "/librarian all - every zone    /librarian mark <book> bags|delivered|clear\n"
        .. "/librarian probe - raw detection per book    /librarian spec - reward filter\n"
        .. "/librarian toast - test the toast")
    local function refresh()
        for key, cb in pairs(boxes) do cb:SetChecked(get(key) and true or false) end
    end
    return refresh, y - 14 - help:GetStringHeight()
end

-- Esc > Options > AddOns > Librarian
local function buildBlizzardCategory()
    local panel = CreateFrame("Frame")
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Librarian")
    local sub = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetText(L["Library book tracker. %d books."]:format(#ns.Books - #ns.unavailable))
    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(140, 24)
    open:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -12)
    open:SetText(L["Open Journal"])
    open:SetScript("OnClick", function() ns:OpenJournal() end)
    local refresh = ns:BuildOptionControls(panel, 16, -100)
    panel:SetScript("OnShow", refresh)
    local category = Settings.RegisterCanvasLayoutCategory(panel, "Librarian")
    Settings.RegisterAddOnCategory(category)
end

-- The journal's options page.
function ns:OpenOptions()
    ns:OpenJournal("options")
end

ns:On("LOADED", buildBlizzardCategory)
