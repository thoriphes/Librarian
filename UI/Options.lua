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
    { key = "mapPinsContinent", label = "Show on continent maps", tip = "Pins on the continent maps too. Off: zone maps only.", indent = true },
    { key = "mapPinsFound", label = "Also pin books in your bags", tip = "Pin books that are in your bags but not delivered yet.", indent = true },
    { key = "mapPinSize", label = "Pin size", tip = "Size of the book pins on zone and continent maps.", indent = true,
        slider = { min = 50, max = 200, step = 10 } },
    { key = "tracker", label = "Objective tracker section", tip = "List the zone's missing books in the objective tracker. Changes apply out of combat.",
        warn = "Warning: can cause Lua errors in combat and stop the objective tracker from updating (Blizzard's tracker does not really allow addon sections). Type /reload after turning it off." },
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

local function showTip(owner, o)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L[o.label])
    GameTooltip:AddLine(L[o.tip], 1, 1, 1, true)
    GameTooltip:Show()
end

local function round(v)
    return math.floor(v + 0.5)
end

-- Percent slider row: label where a checkbox's label would sit, Blizzard's stepper slider after
-- it, value on its right.
local function buildSlider(parent, o, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", parent, "TOPLEFT", x + (o.indent and 24 or 0) + 30, y - 16)
    label:SetText(L[o.label])
    local s = CreateFrame("Frame", nil, parent, "MinimalSliderWithSteppersTemplate")
    s:SetSize(200, 30)
    s:SetPoint("LEFT", label, "RIGHT", 6, 0)
    local right = MinimalSliderWithSteppersMixin.Label.Right
    s:Init(get(o.key), o.slider.min, o.slider.max, (o.slider.max - o.slider.min) / o.slider.step, {
        [right] = CreateMinimalSliderFormatter(right, function(v) return ("%d%%"):format(round(v)) end),
    })
    s:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, v)
        v = round(v)
        if v ~= get(o.key) then set(o.key, v) end
    end, s)
    s.Slider:HookScript("OnEnter", function(self) showTip(self, o) end)
    s.Slider:HookScript("OnLeave", function() GameTooltip:Hide() end)
    return s
end

local function buildCheckbox(parent, o, x, y)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x + (o.indent and 24 or 0), y)
    local label = cb.Text or cb.text
    label:SetText(L[o.label])
    label:SetFontObject("GameFontHighlight")
    cb:SetScript("OnClick", function(self) set(o.key, self:GetChecked() and true or false) end)
    cb:SetScript("OnEnter", function(self) showTip(self, o) end)
    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return cb
end

-- Checkboxes, sliders + help text under (x, y) of parent. Returns refresh() (re-reads the
-- settings into the controls) and the y below the last control.
function ns:BuildOptionControls(parent, x, y)
    local boxes, sliders = {}, {}
    for _, o in ipairs(OPTIONS) do
        if o.slider then
            sliders[o.key] = buildSlider(parent, o, x, y)
        else
            boxes[o.key] = buildCheckbox(parent, o, x, y)
        end
        y = y - 30
        if o.warn then -- red text under the control, always visible (not only in the tooltip)
            local w = parent:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
            w:SetPoint("TOPLEFT", x + 30, y + 4)
            w:SetWidth(440)
            w:SetJustifyH("LEFT")
            w:SetText(L[o.warn])
            y = y - w:GetStringHeight() - 4
        end
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
        for key, s in pairs(sliders) do s:SetValue(get(key)) end
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
