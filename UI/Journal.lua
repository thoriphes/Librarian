-- Journal window: home page = goal progress, summary cards and one card per book; book page =
-- one book's details, the other books of its zone, an embedded zone map (UI/BookMap.lua), the
-- manual mark and a waypoint button. Built from Blizzard's stock textures; no art of our own shipped.
local _, ns = ...
local L = ns.L

local W, H = 760, 624 -- tall enough for the summary row + two full card rows
local PAD = 16
local CONTENT_TOP = 64 -- below the title bar, clear of the template's portrait ring (~55 px down)
local COLS, CARD_H, GAP = 3, 80, 10
local CHECK_ICON = "Interface\\RaidFrame\\ReadyCheck-Ready"
local BAG_ICON = "Interface\\Icons\\INV_Misc_Bag_08"
-- The target frame's PvP badges: the emblem sits in the top-left ~62% of the 64x64 file.
local PVP_COORDS = { 0, 0.62, 0, 0.62 }
local FACTION_ICON = {
    Alliance = { "Interface\\TargetingFrame\\UI-PVP-Alliance", PVP_COORDS },
    Horde = { "Interface\\TargetingFrame\\UI-PVP-Horde", PVP_COORDS },
    Contested = { "Interface\\TargetingFrame\\UI-PVP-FFA", PVP_COORDS },
}
local WHITE = "Interface\\Buttons\\WHITE8X8"

local C = {
    bg = { 0.07, 0.055, 0.04, 0.97 },
    header = { 0.16, 0.11, 0.06, 1 },
    gold = { 0.78, 0.6, 0.25 },
    title = { 1, 0.82, 0.3 },
    panel = { 0.12, 0.09, 0.06, 0.95 },
    card = { 0.1, 0.08, 0.05, 0.95 },
    cardBorder = { 0.4, 0.3, 0.16 },
    cardHover = { 1, 0.78, 0.25 },
    text = { 0.95, 0.9, 0.8 },
    muted = { 0.62, 0.57, 0.48 },
    status = { missing = { 1, 0.31, 0.31 }, found = { 1, 0.82, 0 }, delivered = { 0.25, 1, 0.25 } },
}

local frame, home, bookPage, rewardsPage, optionsPage
local cards, zoneCards, dividers = {}, {}, {}

local function setBackdrop(f, bg, border, edge)
    f:SetBackdrop({
        bgFile = WHITE,
        edgeFile = edge or "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = edge and 24 or 12,
        insets = { left = edge and 6 or 3, right = edge and 6 or 3, top = edge and 6 or 3, bottom = edge and 6 or 3 },
    })
    f:SetBackdropColor(unpack(bg))
    if border then f:SetBackdropBorderColor(unpack(border)) end
end

local function font(parent, template, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", template)
    if color then fs:SetTextColor(unpack(color)) end
    fs:SetJustifyH(justify or "LEFT")
    fs:SetShadowOffset(1, -1)
    return fs
end

local function line(parent, color, alpha)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture(WHITE)
    t:SetVertexColor(color[1], color[2], color[3], alpha or 1)
    t:SetHeight(1)
    return t
end

-- Progress bar with a tick mark per goal.
local function scrollArea(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(1, 1)
    sf:SetScrollChild(child)
    sf:SetScript("OnSizeChanged", function(self, w) child:SetWidth(w) end)
    return sf, child
end

-- ---------------------------------------------------------------------------------------
-- Window

-- Skin: the textures of Forever's Legacy Points window (Blizzard_LegacySystem, Progress Track
-- page): PortraitFrameTemplate frame + title bar, the page background, the reward cards and
-- their icon frames. Every atlas is checked; without it the older flat look is used.
local ATLAS = {
    background = "Legacy-Rewards-Tracker-background",
    card = "Legacy-Rewards-Tracker-Cards-Disable", -- the grey card of the Progress Track page
    cardLit = "Legacy-Rewards-Tracker-Cards",      -- hover / the zone you are in
    iconFrame = "Legacy-Rewards-Tracker-Icons-Frame",
}
local CARD_CORNER = 24 -- 9-slice corner, in atlas pixels (drawn 1:1)
-- Card content inset: clears the Legacy card border (the old flat card used 10). CARD_EDGE =
-- where the border ends, for the hover highlight.
local CARD_PAD, CARD_EDGE = 22, 10
-- The card atlas has a transparent margin around its border: section titles and their rules are
-- inset by it so they line up with the cards' visible edges (Nacho: "bleeds outside"), not
-- with the card frames.
local CARD_INSET = 5

local function hasAtlas(name)
    local info = C_Texture.GetAtlasInfo(name)
    return info and info.file and info.width > 0 and info or nil
end

-- A card atlas is one picture (background + border). Cut into 9 so the border and corners keep
-- their size on cards of any size; the edges and the centre stretch.
local function createSlices(parent)
    local s = {}
    for i = 1, 9 do s[i] = parent:CreateTexture(nil, "BACKGROUND") end
    local c = CARD_CORNER
    s[1]:SetPoint("TOPLEFT") s[1]:SetSize(c, c)
    s[3]:SetPoint("TOPRIGHT") s[3]:SetSize(c, c)
    s[7]:SetPoint("BOTTOMLEFT") s[7]:SetSize(c, c)
    s[9]:SetPoint("BOTTOMRIGHT") s[9]:SetSize(c, c)
    s[2]:SetPoint("TOPLEFT", s[1], "TOPRIGHT") s[2]:SetPoint("BOTTOMRIGHT", s[3], "BOTTOMLEFT")
    s[8]:SetPoint("TOPLEFT", s[7], "TOPRIGHT") s[8]:SetPoint("BOTTOMRIGHT", s[9], "BOTTOMLEFT")
    s[4]:SetPoint("TOPLEFT", s[1], "BOTTOMLEFT") s[4]:SetPoint("BOTTOMRIGHT", s[7], "TOPRIGHT")
    s[6]:SetPoint("TOPLEFT", s[3], "BOTTOMLEFT") s[6]:SetPoint("BOTTOMRIGHT", s[9], "TOPRIGHT")
    s[5]:SetPoint("TOPLEFT", s[1], "BOTTOMRIGHT") s[5]:SetPoint("BOTTOMRIGHT", s[9], "TOPLEFT")
    return s
end

local function paintSlices(s, info)
    local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
    local cu = (r - l) * CARD_CORNER / info.width
    local cv = (b - t) * CARD_CORNER / info.height
    local us = { l, l + cu, r - cu, r }
    local vs = { t, t + cv, b - cv, b }
    for row = 1, 3 do
        for col = 1, 3 do
            local tex = s[(row - 1) * 3 + col]
            tex:SetTexture(info.file)
            tex:SetTexCoord(us[col], us[col + 1], vs[row], vs[row + 1])
        end
    end
end

-- Card / panel skin. f:SetLit(true) = the brighter card (hover, the zone you are in).
local function skinCard(f)
    local base, lit = hasAtlas(ATLAS.card), hasAtlas(ATLAS.cardLit)
    if base then
        f.slices = createSlices(f)
        paintSlices(f.slices, base)
        function f:SetLit(on)
            paintSlices(self.slices, (on and lit) or base)
        end
    else
        setBackdrop(f, C.card, C.cardBorder)
        function f:SetLit(on)
            self:SetBackdropBorderColor(unpack(on and C.cardHover or C.cardBorder))
        end
    end
end

local function createFrame()
    -- Named: the template names children "$parentBg" / "$parentPortrait", and a named frame
    -- can join UISpecialFrames (ESC closes it).
    frame = CreateFrame("Frame", "LibrarianFrame", UIParent, "PortraitFrameTemplateNoCloseButton")
    table.insert(UISpecialFrames, "LibrarianFrame")
    frame:SetSize(W, H)
    -- HIGH = Blizzard's Settings panel strata: raised windows then stack by click order, so
    -- the settings panel is never stuck under the journal
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint(1)
        ns.db.window = { point = p, relPoint = rp, x = x, y = y }
    end)
    local pos = ns.db.window
    if pos.point then
        frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        frame:SetPoint("CENTER", 0, 20)
    end
    frame:SetTitle("Librarian")
    frame:SetPortraitToAsset(ns.ICON)
    -- the Legacy page background over the template's rock tile (same inner rect)
    if hasAtlas(ATLAS.background) then
        local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -5)
        bg:SetAtlas(ATLAS.background)
        bg:SetPoint("TOPLEFT", 2, -21)
        bg:SetPoint("BOTTOMRIGHT", -2, 2)
    end
    local header = frame.TitleContainer

    -- Header buttons: two retail icons, desaturated and tinted the same gold so they share one
    -- tone, 13 px, centred in the template's 20 px title bar and 6 px in from its right edge.
    -- Hover = an additive copy of the icon (Blizzard's settings-gear button does the same).
    local BTN, BTN_PAD = 13, 6
    local function headerButton(atlas, fallback, tip, onClick)
        local b = CreateFrame("Button", nil, frame)
        b:SetSize(BTN, BTN)
        b:SetFrameLevel(frame:GetFrameLevel() + 520) -- above the template's title bar (510)
        local icon = b:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetBlendMode("ADD")
        hl:SetAlpha(0.4)
        if C_Texture.GetAtlasInfo(atlas) then
            icon:SetAtlas(atlas)
            hl:SetAtlas(atlas)
        else
            icon:SetTexture(fallback)
            hl:SetTexture(fallback)
        end
        icon:SetDesaturated(true) -- grey first, so both icons take the gold the same way
        icon:SetVertexColor(unpack(C.title))
        b:SetScript("OnClick", onClick)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:AddLine(tip)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return b
    end
    -- close: the bevelled red X (common-icon-redx) through the same grey + gold as the gear
    local close = headerButton("common-icon-redx", "Interface\\Buttons\\UI-StopButton", CLOSE or "Close",
        function() frame:Hide() end)
    close:SetPoint("RIGHT", frame, "TOPRIGHT", -(4 + BTN_PAD), -11)
    -- the X's atlas is darker than the gear's once greyed; a faint additive copy lifts it
    -- (a vertex tint can only darken)
    local lift = close:CreateTexture(nil, "OVERLAY")
    lift:SetAllPoints()
    lift:SetAtlas("common-icon-redx")
    lift:SetDesaturated(true)
    lift:SetVertexColor(unpack(C.title))
    lift:SetBlendMode("ADD")
    lift:SetAlpha(0.35)
    lift:SetShown(C_Texture.GetAtlasInfo("common-icon-redx") ~= nil)
    -- options: retail's settings gear (questlog-icon-setting)
    local gear = headerButton("questlog-icon-setting", "Interface\\Worldmap\\Gear_64Grey", L["Options"],
        function()
            -- toggles: the gear on the options page goes back to the books
            if optionsPage and optionsPage:IsShown() then ns:OpenJournal() else ns:OpenOptions() end
        end)
    gear:SetPoint("RIGHT", close, "LEFT", -5, 0)
    header:SetPoint("TOPRIGHT", gear, "TOPLEFT", -4, 0) -- title stays clear of the buttons

    frame:SetScript("OnShow", function() PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN) end)
    frame:SetScript("OnHide", function() PlaySound(SOUNDKIT.IG_SPELLBOOK_CLOSE) end)
    frame:Hide()
end

-- ---------------------------------------------------------------------------------------
-- Home page

local function cardOnEnter(self)
    self:SetLit(true)
end

local function cardOnLeave(self)
    self:SetLit(self.isCurrent)
end

-- Card text is the stock font objects one point smaller (Nacho: every card font -1).
local function smaller(fs)
    local file, size, flags = fs:GetFont()
    if file and size then fs:SetFont(file, size - 1, flags) end
    return fs
end

-- The Legacy reward icon frame around an icon (1.25x), else a 1 px gold square behind it.
local function iconFrame(parent, icon, size)
    local t
    if hasAtlas(ATLAS.iconFrame) then
        t = parent:CreateTexture(nil, "OVERLAY")
        t:SetAtlas(ATLAS.iconFrame)
        t:SetPoint("CENTER", icon)
        t:SetSize(size * 1.25, size * 1.25)
    else
        t = parent:CreateTexture(nil, "BORDER")
        t:SetTexture(WHITE)
        t:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 0.9)
        t:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
        t:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    end
    return t
end

local function newCard(parent)
    local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
    card:SetHeight(CARD_H)
    skinCard(card)
    card.hl = card:CreateTexture(nil, "HIGHLIGHT")
    card.hl:SetTexture(WHITE)
    card.hl:SetVertexColor(1, 0.8, 0.3, 0.06)
    card.hl:SetPoint("TOPLEFT", CARD_EDGE, -CARD_EDGE)
    card.hl:SetPoint("BOTTOMRIGHT", -CARD_EDGE, CARD_EDGE)
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(34, 34)
    card.icon:SetPoint("TOPLEFT", CARD_PAD, -CARD_PAD)
    card.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    card.iconBorder = iconFrame(card, card.icon, 34)
    card.name = smaller(font(card, "GameFontNormal", C.title)) -- book title, up to two lines
    card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 8, 0)
    card.name:SetPoint("RIGHT", -(CARD_PAD + 28), 0) -- room for the state icon
    card.name:SetJustifyV("TOP")
    card.name:SetMaxLines(2)
    -- Top-right state icon: check = delivered, bag = in your bags, faction badge = missing.
    card.check = card:CreateTexture(nil, "OVERLAY")
    card.check:SetSize(20, 20)
    card.check:SetTexture(CHECK_ICON)
    card.bag = card:CreateTexture(nil, "OVERLAY")
    card.bag:SetSize(20, 20)
    card.bag:SetTexture(BAG_ICON)
    card.bag:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    card.faction = card:CreateTexture(nil, "OVERLAY") -- missing books: the zone's side
    card.faction:SetSize(22, 22)
    card.quest = card:CreateTexture(nil, "OVERLAY") -- reward card: quest giver "!" / "?"
    card.meta = smaller(font(card, "GameFontHighlightSmall", C.muted))
    card.meta:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -3)
    card.meta:SetPoint("RIGHT", -CARD_PAD, 0)
    card.where = smaller(font(card, "GameFontHighlightSmall", { 1, 1, 1 })) -- container, place, coords
    card.where:SetJustifyV("TOP")
    card.state = smaller(font(card, "GameFontHighlight", C.text))
    card.state:SetPoint("BOTTOMLEFT", CARD_PAD, CARD_PAD)
    card.here = smaller(font(card, "GameFontNormalSmall", C.gold, "RIGHT"))
    card.here:SetPoint("BOTTOMRIGHT", -CARD_PAD, CARD_PAD)
    card.here:SetText(L["You are here"])
    -- summary cards only: what the card is ("Recommended next", ...)
    card.caption = smaller(font(card, "GameFontNormalSmall", C.gold))
    -- Reward card only: the icon shows the picked item's tooltip and a click switches to the
    -- next suitable choice (mouse off on other cards so they stay clickable).
    card.iconHit = CreateFrame("Frame", nil, card)
    card.iconHit:SetAllPoints(card.icon)
    card.iconHit:EnableMouse(false)
    card.iconHit:SetScript("OnEnter", function(self)
        cardOnEnter(card)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(card.tooltipItem)
        if card.canSwitch then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["Click: next reward choice"], 0.5, 0.8, 1)
        end
        GameTooltip:Show()
    end)
    card.iconHit:SetScript("OnLeave", function()
        cardOnLeave(card)
        GameTooltip:Hide()
    end)
    card.iconHit:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and card.canSwitch and card.goal then
            ns:NextRewardPick(card.goal)
            if self:IsMouseOver() then self:GetScript("OnEnter")(self) end
        end
    end)
    card.caption:SetPoint("TOPLEFT", CARD_PAD, -(CARD_PAD - 2))
    card:SetScript("OnEnter", cardOnEnter)
    card:SetScript("OnLeave", cardOnLeave)
    card:SetScript("OnClick", function(self)
        if self.onClick then
            self.onClick(self)
        elseif self.entry then
            ns:OpenBook(self.entry.book, self.entry.spot)
        end
    end)
    return card
end

-- Quest giver marks: "!" = quest to work on, "?" = ready to turn in (the quest log's own
-- atlases; else the gossip frame's icons).
local QUEST_ICON = {
    [false] = { "QuestNormal", "Interface\\GossipFrame\\AvailableQuestIcon" },
    [true] = { "QuestTurnin", "Interface\\GossipFrame\\ActiveQuestIcon" },
}
local function setQuestIcon(tex, ready)
    local atlas, file = QUEST_ICON[ready][1], QUEST_ICON[ready][2]
    local info = hasAtlas(atlas)
    if info then
        tex:SetAtlas(atlas)
        tex:SetSize(24 * info.width / info.height, 24)
    else
        tex:SetTexture(file)
        tex:SetTexCoord(0, 1, 0, 1)
        tex:SetSize(22, 22)
    end
end

local function getListCard(i)
    cards[i] = cards[i] or newCard(home.child)
    return cards[i]
end

-- Caption on/off; returns the vertical offset the card content starts at.
local CAPTION_H = 18
local function setCaption(card, caption)
    card.caption:SetText(caption or "")
    card.caption:SetShown(caption ~= nil)
    local top = caption and CAPTION_H or 0
    card.icon:ClearAllPoints()
    card.icon:SetPoint("TOPLEFT", CARD_PAD, -(CARD_PAD + top))
    for _, tex in ipairs({ card.faction, card.bag, card.check, card.quest }) do
        tex:ClearAllPoints()
        tex:SetPoint("TOPRIGHT", -CARD_PAD, -(CARD_PAD + top))
        tex:Hide()
    end
    card.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    card.iconBorder:Show()
    card.here:Hide()
    card.entry, card.isCurrent = nil, false
    card.tooltipItem, card.goal, card.canSwitch, card.onClick = nil, nil, false, nil
    card.iconHit:EnableMouse(false)
    card:SetLit(false)
    return top
end

-- Header (icon or title + meta, whichever is taller), then `where`, then the state line.
local function layoutCard(card, top, hasState)
    local headH = math.max(34, card.name:GetStringHeight() + 3 + card.meta:GetStringHeight())
    card.where:ClearAllPoints()
    card.where:SetPoint("TOPLEFT", CARD_PAD, -(CARD_PAD + top + headH + 8))
    card.where:SetPoint("RIGHT", -CARD_PAD, 0)
    local whereH = card.where:GetText() ~= "" and card.where:GetStringHeight() or 0
    return CARD_PAD + top + headH + 8 + whereH + (hasState and (10 + 14) or 0) + CARD_PAD
end

local function getDivider(i)
    local d = dividers[i]
    if d then return d end
    d = CreateFrame("Frame", nil, home.child)
    d:SetHeight(24)
    d.text = font(d, "GameFontNormalLarge", C.title)
    d.text:SetPoint("LEFT", 0, 0)
    d.rule = line(d, C.gold, 0.4)
    d.rule:SetPoint("LEFT", d.text, "RIGHT", 10, 0)
    d.rule:SetPoint("RIGHT")
    dividers[i] = d
    return d
end

-- One card per book. e = { book, spot, others } from ns:BookList(); others = the book's other
-- spots (Rumi sits in two zones). caption = summary-card title, nil in the list.
local function fillCard(card, e, here, caption)
    local b, spot = e.book, e.spot
    local mapID = spot.map
    local z = ns.Zones[mapID]
    local status = ns:Status(b)
    local top = setCaption(card, caption)
    card.entry = e
    card.isCurrent = mapID == here
    card.icon:SetTexture(C_Item.GetItemIconByID(b.item) or ns.ICON)
    card.name:SetMaxLines(2)
    card.name:SetTextColor(unpack(C.title))
    card.name:SetText(ns:BookName(b))
    local side = ns:ZoneSide(mapID)
    -- zone + level on one line, the side on its own line
    card.meta:SetText(ns:ZoneName(mapID) .. (z.level and (" (" .. z.level .. ")") or "") .. "\n" .. ns:SideName(side))
    local where = ns:WhereText(spot)
    local text = ("%s%.1f, %.1f"):format(where and (where .. "  ") or "", spot.x, spot.y)
    for _, o in ipairs(e.others) do
        text = text .. "\n" .. L["Also: %s  %.1f, %.1f"]:format(ns:ZoneName(o.map), o.x, o.y)
    end
    card.where:SetText(text)
    card.state:SetText(ns:StatusText(status) .. (b.trainer and ("  |cff999999" .. L["(trainer turn-in)"] .. "|r") or ""))
    local fac = FACTION_ICON[side] or FACTION_ICON.Contested
    card.faction:SetTexture(fac[1])
    card.faction:SetTexCoord(unpack(fac[2]))
    for tex, st in pairs({ [card.faction] = ns.MISSING, [card.bag] = ns.FOUND, [card.check] = ns.DELIVERED }) do
        tex:SetShown(status == st)
    end
    card.here:SetShown(card.isCurrent)
    card:SetLit(card.isCurrent)
    return layoutCard(card, top, true)
end

-- Summary card with nothing to show: green check + a congratulations line.
local function fillEmpty(card, caption, text)
    local top = setCaption(card, caption)
    card.icon:SetTexture(CHECK_ICON)
    card.icon:SetTexCoord(0, 1, 0, 1)
    card.iconBorder:Hide() -- the check is transparent: a frame would show through as a square
    card.name:SetMaxLines(3)
    card.name:SetText(text)
    card.name:SetTextColor(unpack(C.status.delivered))
    card.meta:SetText("")
    card.where:SetText("")
    card.state:SetText("")
    return layoutCard(card, top, false)
end

-- Summary card for the next reward: quest title, progress, the items to choose from, who
-- takes the books, and "ready" once enough are delivered.
local function fillReward(card, caption, goal, delivered)
    local top = setCaption(card, caption)
    local pick, index, choices = ns:RewardPick(goal)
    card.icon:SetTexture(pick and C_Item.GetItemIconByID(pick.item) or ns.ICON)
    if pick then
        card.tooltipItem, card.goal, card.canSwitch = pick.item, goal, #choices > 1
        card.iconHit:EnableMouse(true)
    end
    card.name:SetText(ns:QuestTitle(goal.quest, goal.title))
    card.name:SetMaxLines(2)
    card.name:SetTextColor(unpack(C.title))
    card.meta:SetText(L["%d / %d books delivered"]:format(math.min(delivered, goal.books), goal.books))
    local lines = {}
    if pick then
        local name = C_Item.GetItemNameByID(pick.item) or pick.name
        lines[#lines + 1] = #choices > 1 and L["Your pick: %s (%d/%d)"]:format(name, index, #choices)
            or L["Reward: %s"]:format(name)
    end
    for _, npc in ipairs(ns.Librarians) do
        if npc.side == ns:PlayerFaction() then
            lines[#lines + 1] = L["Turn in at %s, %s"]:format(npc.name, ns:ZoneName(npc.map))
        end
    end
    lines[#lines + 1] = "|cff80ccff" .. L["Click to see all possible rewards"] .. "|r"
    card.where:SetText(table.concat(lines, "\n"))
    card.onClick = ns.OpenRewards
    local left = goal.books - delivered
    -- quest giver mark: "!" while collecting, "?" once the books are there to turn in
    setQuestIcon(card.quest, left <= 0)
    card.quest:Show()
    card.state:SetText(left > 0 and ("|cffffd100" .. L["%d more to go"]:format(left) .. "|r")
        or ("|cff40ff40" .. L["Ready to turn in"] .. "|r"))
    return layoutCard(card, top, true)
end

local function refreshGoals()
    local n = ns:DeliveredTotal()
    local g2 = ns.Goals[2]
    local top = g2 and g2.books or 20
    home.goalBar:SetProgress(n / top)
    home.goalText:SetText("|cffffffff" .. L["%d books delivered."]:format(n) .. "|r")
    -- right: only the next reward (the first goal not turned in), "ready" once enough are in
    local next
    for _, g in ipairs(ns.Goals) do
        if not ns:GoalDone(g) then next = g break end
    end
    home.goalNext:SetText(next and ("%s (%d)%s"):format(ns:QuestTitle(next.quest, next.title), next.books,
        n >= next.books and (" |cffffd100" .. L["ready"] .. "|r") or "") or "")
end

-- The three summary cards above the list, always shown (empty states congratulate):
-- Recommended next = the first Missing book; Current zone = the first unfinished book where
-- you are (missing before in bags); Next reward = the first goal not turned in yet.
local summary = {}

local function currentZoneEntry(groups, here)
    if not here then return end
    for _, state in ipairs({ ns.MISSING, ns.FOUND }) do -- missing first, then in bags
        for _, e in ipairs(ns:Group(groups, state).entries) do
            if e.spot.map == here then return e end
            for _, o in ipairs(e.others) do
                if o.map == here then return { book = e.book, spot = o, others = { e.spot } } end
            end
        end
    end
end

local function refreshSummary(groups, here, cardW)
    for i = 1, 3 do
        summary[i] = summary[i] or newCard(home.child)
    end
    local h = {}
    local cur = currentZoneEntry(groups, here)
    h[1] = cur and fillCard(summary[1], cur, here, L["Current zone"])
        or fillEmpty(summary[1], L["Current zone"], L["Nothing left to find in this zone. Congratulations!"])
    local rec = ns:Group(groups, ns.MISSING).entries[1]
    h[2] = rec and fillCard(summary[2], rec, here, L["Recommended next"])
        or fillEmpty(summary[2], L["Recommended next"], L["Every missing book is found. Congratulations!"])
    local n, goal = ns:DeliveredTotal()
    for _, g in ipairs(ns.Goals) do
        if not ns:GoalDone(g) then goal = g break end
    end
    h[3] = goal and fillReward(summary[3], L["Next reward"], goal, n)
        or fillEmpty(summary[3], L["Next reward"], L["Every reward earned. Congratulations!"])
    -- the reward card always wears the lit Legacy card (Nacho: give it some personality)
    summary[3].isCurrent = true
    summary[3]:SetLit(true)
    local rowH = math.max(CARD_H, h[1], h[2], h[3])
    for i, card in ipairs(summary) do
        card:SetWidth(cardW)
        card:SetHeight(rowH)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", (i - 1) * (cardW + GAP), 0)
        card:Show()
    end
    return rowH + GAP + 8
end

local function refreshHome()
    local child = home.child
    local width = home.scroll:GetWidth()
    child:SetWidth(width)
    local cardW = (width - GAP * (COLS - 1)) / COLS
    local here = ns:CurrentZone()
    local y, ci, di = 0, 0, 0
    for _, c in ipairs(cards) do c:Hide() end
    for _, d in ipairs(dividers) do d:Hide() end
    local groups = ns:BookList()
    y = refreshSummary(groups, here, cardW)
    for _, group in ipairs(groups) do
        if #group.entries > 0 then
            di = di + 1
            local d = getDivider(di)
            d.text:SetText(L[group.name])
            d.text:SetTextColor(unpack(C.status[group.state]))
            d:ClearAllPoints()
            d:SetPoint("TOPLEFT", CARD_INSET, -y)
            d:SetPoint("RIGHT", child, "RIGHT", -CARD_INSET, 0)
            d:Show()
            y = y + 30
            -- A row takes the height of its tallest card (titles wrap, Rumi has two spots).
            local row, rowH = {}, CARD_H
            for i, e in ipairs(group.entries) do
                ci = ci + 1
                local card = getListCard(ci)
                local col = (i - 1) % COLS
                card:SetWidth(cardW)
                card:ClearAllPoints()
                card:SetPoint("TOPLEFT", col * (cardW + GAP), -y)
                card:Show()
                rowH = math.max(rowH, fillCard(card, e, here))
                row[#row + 1] = card
                if col == COLS - 1 or i == #group.entries then
                    for _, c in ipairs(row) do c:SetHeight(rowH) end
                    y = y + rowH + GAP
                    row, rowH = {}, CARD_H
                end
            end
            y = y + 8
        end
    end
    child:SetHeight(math.max(1, y))
    refreshGoals()
end

local function createHome()
    home = CreateFrame("Frame", nil, frame)
    home:SetPoint("TOPLEFT", PAD, -CONTENT_TOP)
    home:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    home.goalText = font(home, "GameFontNormal", C.text)
    home.goalText:SetPoint("TOPLEFT", 2, -2)
    home.goalNext = font(home, "GameFontNormal", C.text, "RIGHT")
    home.goalNext:SetPoint("TOPRIGHT", -2, -2)
    home.goalBar = ns:CreateSkillBar(home)
    home.goalBar:SetPoint("TOPLEFT", 0, -22)
    home.goalBar:SetPoint("RIGHT", 0, 0) -- no scrollbar beside it: full width
    local g1, g2 = ns.Goals[1], ns.Goals[2]
    home.goalBar:AddMark((g1 and g1.books or 10) / (g2 and g2.books or 20))
    home.scroll, home.child = scrollArea(home)
    home.scroll:SetPoint("TOPLEFT", 0, -60)
    home.scroll:SetPoint("BOTTOMRIGHT", -24, 0)
end

-- ---------------------------------------------------------------------------------------
-- Book page: "< Books", the book's details, a gold rule (titled "Other books in <zone>" with
-- small cards for them when the zone has other books), the embedded zone map, and at the bottom right
-- the manual mark + "Add marker" (waypoint only: the map is already on the page).

local MARK_NEXT = { [ns.MISSING] = ns.FOUND, [ns.FOUND] = ns.DELIVERED, [ns.DELIVERED] = false }
local ZONE_CARD_H, BTN_H = 76, 22
local openEntry -- the page's { book, spot, others }

local function markButtonText(b)
    local s, manual = ns:Status(b)
    if manual then return L["Clear mark"] end
    local nxt = MARK_NEXT[s]
    return nxt == ns.FOUND and L["Mark in bags"] or nxt == ns.DELIVERED and L["Mark delivered"] or nil
end

local function bookNotes(b, spot)
    local notes = {}
    if b.trainer then
        notes[#notes + 1] = L["Turned in to a mage trainer (Jennea Cannon / Oran Snakewrithe), not a librarian;"
            .. " whether it counts toward the library rewards is not known."]
    end
    local side = ns:ZoneSide(spot.map)
    if (side == "Alliance" or side == "Horde") and side ~= ns:PlayerFaction() then
        notes[#notes + 1] = L["In %s territory: expect guards."]:format(ns:SideName(side))
    end
    if b.noForeverQuest then
        notes[#notes + 1] = L["Its turn-in quest is missing from Forever's database: mark it by hand."]
    end
    if #b.spots > 1 then
        notes[#notes + 1] = L["Also found elsewhere; the same book counts once."]
    end
    if spot.note then notes[#notes + 1] = ns:DataText(spot.note) end
    return table.concat(notes, " ")
end

-- The book's details: plain on the page (no card), in two columns to keep it short.
-- Left: icon, title, zone (level) - side, location (+ "Also:" spots). Right: state on top,
-- then the notes and the flavour text.
local function createInfo(parent)
    local c = CreateFrame("Frame", nil, parent)
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(34, 34)
    c.icon:SetPoint("TOPLEFT", 2, -2)
    c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    iconFrame(c, c.icon, 34)
    c.name = font(c, "GameFontNormalLarge", C.title)
    c.name:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 10, 0)
    c.name:SetJustifyV("TOP")
    c.name:SetMaxLines(2)
    c.meta = font(c, "GameFontHighlightSmall", C.muted)
    c.meta:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -3)
    c.where = font(c, "GameFontHighlightSmall", { 1, 1, 1 })
    c.state = font(c, "GameFontNormal")
    c.note = font(c, "GameFontHighlightSmall", C.muted)
    c.flavour = font(c, "GameFontDisableSmall", C.muted)
    for _, fs in ipairs({ c.where, c.note, c.flavour }) do fs:SetJustifyV("TOP") end
    return c
end

-- Fills the details for a page `width` wide; returns their height.
local function fillInfo(c, e, width)
    local b, spot = e.book, e.spot
    local z = ns.Zones[spot.map]
    local s, manual = ns:Status(b)
    local mid = math.floor(width * 0.5)
    local textX = 2 + 34 + 10
    c.icon:SetTexture(C_Item.GetItemIconByID(b.item) or ns.ICON)
    c.name:SetWidth(mid - textX - 10)
    c.name:SetText(ns:BookName(b))
    c.meta:SetWidth(mid - textX - 10)
    c.meta:SetText(ns:ZoneName(spot.map) .. (z.level and (" (" .. z.level .. ")") or "") .. "  -  "
        .. ns:SideName(ns:ZoneSide(spot.map)))
    local where = ns:WhereText(spot)
    local text = ("%s%.1f, %.1f"):format(where and (where .. "  ") or "", spot.x, spot.y)
    for _, o in ipairs(e.others) do
        text = text .. "\n" .. L["Also: %s  %.1f, %.1f"]:format(ns:ZoneName(o.map), o.x, o.y)
    end
    c.where:SetText(text)
    local left = math.max(38, c.name:GetStringHeight() + 3 + c.meta:GetStringHeight()) + 8
    c.where:ClearAllPoints()
    c.where:SetPoint("TOPLEFT", textX, -left)
    c.where:SetWidth(mid - textX - 10)
    left = left + c.where:GetStringHeight()
    -- right column
    c.state:SetText(ns:StatusText(s) .. (manual and (" |cff999999" .. L["(marked)"] .. "|r") or ""))
    c.state:ClearAllPoints()
    c.state:SetPoint("TOPLEFT", mid + 10, -2)
    local right = 2 + c.state:GetStringHeight()
    c.note:SetText(bookNotes(b, spot))
    local flavour = ns:Flavour(b)
    c.flavour:SetText(flavour and ('"' .. flavour .. '"') or "")
    for _, fs in ipairs({ c.note, c.flavour }) do
        fs:ClearAllPoints()
        if fs:GetText() ~= "" then
            right = right + 6
            fs:SetPoint("TOPLEFT", mid + 10, -right)
            fs:SetWidth(width - mid - 10)
            right = right + fs:GetStringHeight()
        end
    end
    return math.max(left, right)
end

-- Small card for another book of the zone: icon, title, state. Click = that book's page.
local function getZoneCard(i)
    local card = zoneCards[i]
    if card then return card end
    card = CreateFrame("Button", nil, bookPage, "BackdropTemplate")
    card:SetHeight(ZONE_CARD_H)
    skinCard(card)
    local hl = card:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(WHITE)
    hl:SetVertexColor(1, 0.8, 0.3, 0.06)
    hl:SetPoint("TOPLEFT", CARD_EDGE, -CARD_EDGE)
    hl:SetPoint("BOTTOMRIGHT", -CARD_EDGE, CARD_EDGE)
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(28, 28)
    card.icon:SetPoint("LEFT", CARD_PAD, 0)
    card.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    iconFrame(card, card.icon, 28)
    card.name = smaller(font(card, "GameFontNormal", C.title))
    card.name:SetPoint("BOTTOMLEFT", card.icon, "RIGHT", 8, 1)
    card.name:SetPoint("RIGHT", -CARD_PAD, 0)
    card.name:SetMaxLines(1)
    card.state = smaller(font(card, "GameFontHighlightSmall", C.text))
    card.state:SetPoint("TOPLEFT", card.icon, "RIGHT", 8, -2)
    card:SetScript("OnEnter", function(self) self:SetLit(true) end)
    card:SetScript("OnLeave", function(self) self:SetLit(false) end)
    card:SetScript("OnClick", function(self) ns:OpenBook(self.entry.book, self.entry.spot) end)
    zoneCards[i] = card
    return card
end

local function refreshBook()
    local e = openEntry
    local b, spot = e.book, e.spot
    local width = bookPage:GetWidth()
    local y = BTN_H + 12
    local info = bookPage.info
    info:ClearAllPoints()
    info:SetPoint("TOPLEFT", 0, -y)
    info:SetPoint("RIGHT")
    local h = fillInfo(info, e, width)
    info:SetHeight(h)
    y = y + h + 10
    -- the other books of this zone, in the home list's column width, under a title divider
    -- (a plain gold rule when there are none)
    local entries = ns:ZoneEntries(spot.map)
    local others = #entries - 1
    local d = bookPage.divider
    d:ClearAllPoints()
    d:SetPoint("TOPLEFT", CARD_INSET, -y)
    d:SetPoint("RIGHT", -CARD_INSET, 0)
    d.text:SetText(others > 0 and L["Other books in %s"]:format(ns:ZoneName(spot.map)) or "")
    d.rule:ClearAllPoints()
    if others > 0 then
        d.rule:SetPoint("LEFT", d.text, "RIGHT", 10, 0)
    else
        d.rule:SetPoint("LEFT")
    end
    d.rule:SetPoint("RIGHT")
    y = y + (others > 0 and 30 or 11)
    local cardW = (width - GAP * (COLS - 1)) / COLS
    local n = 0
    for _, c in ipairs(zoneCards) do c:Hide() end
    for _, o in ipairs(entries) do
        if o.book ~= b then
            n = n + 1
            local card = getZoneCard(n)
            card.entry = o
            card:SetWidth(cardW)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", ((n - 1) % COLS) * (cardW + GAP),
                -(y + math.floor((n - 1) / COLS) * (ZONE_CARD_H + GAP)))
            card.icon:SetTexture(C_Item.GetItemIconByID(o.book.item) or ns.ICON)
            card.name:SetText(ns:BookName(o.book))
            card.state:SetText(ns:StatusText((ns:Status(o.book))))
            card:SetLit(false)
            card:Show()
        end
    end
    if n > 0 then
        y = y + math.ceil(n / COLS) * (ZONE_CARD_H + GAP)
    end
    bookPage.mapBox:ClearAllPoints()
    bookPage.mapBox:SetPoint("TOPLEFT", 0, -y)
    bookPage.mapBox:SetPoint("BOTTOMRIGHT", 0, BTN_H + 8)
    bookPage.map:SetZone(spot.map, entries, e)
    local mt = markButtonText(b)
    bookPage.mark:SetShown(mt ~= nil)
    if mt then bookPage.mark:SetText(mt) end
end

local function createBookPage()
    bookPage = CreateFrame("Frame", nil, frame)
    bookPage:SetPoint("TOPLEFT", PAD, -CONTENT_TOP)
    bookPage:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    local back = CreateFrame("Button", nil, bookPage, "UIPanelButtonTemplate")
    back:SetSize(90, BTN_H)
    back:SetPoint("TOPLEFT", 0, 0)
    back:SetText(L["< Books"])
    back:SetScript("OnClick", function() ns:OpenJournal() end)
    bookPage.info = createInfo(bookPage)
    local d = CreateFrame("Frame", nil, bookPage) -- as the home list's group dividers
    d:SetHeight(24)
    d.text = font(d, "GameFontNormalLarge", C.title)
    d.text:SetPoint("LEFT", 0, 0)
    d.rule = line(d, C.gold, 0.4)
    bookPage.divider = d
    -- the map under a tooltip border drawn on top of it (as on the goal bar)
    local box = CreateFrame("Frame", nil, bookPage)
    bookPage.mapBox = box
    bookPage.map = ns:CreateBookMap(box)
    bookPage.map:SetPoint("TOPLEFT", 3, -3)
    bookPage.map:SetPoint("BOTTOMRIGHT", -3, 3)
    bookPage.map.onPinClick = function(o) ns:OpenBook(o.book, o.spot) end
    local edge = CreateFrame("Frame", nil, box, "BackdropTemplate")
    edge:SetAllPoints()
    edge:SetFrameLevel(bookPage.map:GetFrameLevel() + 10)
    edge:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
    edge:SetBackdropBorderColor(0.6, 0.47, 0.24)
    -- bottom right: Add marker, the manual mark left of it
    local marker = CreateFrame("Button", nil, bookPage, "UIPanelButtonTemplate")
    marker:SetSize(120, BTN_H)
    marker:SetPoint("BOTTOMRIGHT", 0, 0)
    marker:SetText(L["Add marker"])
    marker:SetScript("OnClick", function()
        ns:SetWaypoint(openEntry.book, openEntry.spot)
        ns:Print(L["waypoint set: %s"]:format(ns:BookName(openEntry.book)))
    end)
    bookPage.marker = marker
    local mark = CreateFrame("Button", nil, bookPage, "UIPanelButtonTemplate")
    mark:SetSize(120, BTN_H)
    mark:SetPoint("RIGHT", marker, "LEFT", -6, 0)
    mark:SetScript("OnClick", function()
        local bk = openEntry.book
        local s, manual = ns:Status(bk)
        ns:SetMark(bk, (not manual) and MARK_NEXT[s] or nil)
    end)
    mark:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["Manual mark (this character)"])
        GameTooltip:AddLine(L["Use it when the game does not report the book: a book whose turn-in "
            .. "does not exist on Forever, or a detection miss."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    mark:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bookPage.mark = mark
    bookPage:Hide()
    ns.bookPage = bookPage -- for tools/librarian-smoke.lua
end

-- ---------------------------------------------------------------------------------------
-- Rewards page (click on the "Next reward" card): the librarian who takes the books (location +
-- "Show on Map"), then per goal a divider (quest title, books needed, where you stand) and one
-- card per reward choice - all of them; the ones that do not suit
-- the character are dimmed. Clicking a suitable card makes it the pick.

local ROLE_TEXT = { caster = "For casters", physical = "For physical fighters" }
local rewardCards, rewardRows = {}, {}

local function turnInNpc()
    for _, npc in ipairs(ns.Librarians) do
        if npc.side == ns:PlayerFaction() then return npc end
    end
end

local function getRewardRow(i)
    local r = rewardRows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, rewardsPage)
    r:SetHeight(24)
    r.text = font(r, "GameFontNormalLarge", C.title)
    r.text:SetPoint("LEFT", 0, 0)
    r.rule = line(r, C.gold, 0.4)
    r.rule:SetPoint("LEFT", r.text, "RIGHT", 10, 0)
    r.rule:SetPoint("RIGHT")
    rewardRows[i] = r
    return r
end

local function getRewardCard(i)
    rewardCards[i] = rewardCards[i] or newCard(rewardsPage)
    return rewardCards[i]
end

local function className(c)
    return LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c] or c
end

-- One reward choice: item icon (its tooltip on hover), name, who it is for, and the state:
-- your pick (lit, check) / click to pick / not for this character (dimmed).
local function fillRewardChoice(card, goal, r, pick, suits)
    local top = setCaption(card, nil)
    card.icon:SetTexture(C_Item.GetItemIconByID(r.item) or ns.ICON)
    card.tooltipItem = r.item
    card.iconHit:EnableMouse(true)
    card.name:SetMaxLines(2)
    card.name:SetTextColor(unpack(C.title))
    card.name:SetText(C_Item.GetItemNameByID(r.item) or r.name)
    local meta = { L[ROLE_TEXT[r.role] or "For any spec"] }
    if r.classes then
        local names = {}
        for _, c in ipairs(r.classes) do names[#names + 1] = className(c) end
        meta[#meta + 1] = L["Classes: %s"]:format(table.concat(names, ", "))
    end
    card.meta:SetText(table.concat(meta, "\n"))
    card.where:SetText("")
    local picked = pick and pick.item == r.item
    if picked then
        card.state:SetText("|cff40ff40" .. L["Your pick"] .. "|r")
    elseif suits then
        card.state:SetText("|cff80ccff" .. L["Click to pick"] .. "|r")
        card.onClick = function() ns:SetRewardPick(goal, r.item) end
    else
        card.state:SetText("|cff999999" .. L["Not for your class or spec"] .. "|r")
    end
    card.check:SetShown(picked)
    card.isCurrent = picked
    card:SetLit(picked)
    card:SetAlpha(suits and 1 or 0.55)
    return layoutCard(card, top, true)
end

local function refreshRewards()
    local width = rewardsPage:GetWidth()
    local cardW = (width - GAP * (COLS - 1)) / COLS
    local npc = turnInNpc()
    local delivered = ns:DeliveredTotal()
    for _, c in ipairs(rewardCards) do c:Hide() end
    for _, r in ipairs(rewardRows) do r:Hide() end
    local y, ci = BTN_H + 12, 0
    local where, show = rewardsPage.where, rewardsPage.show
    if npc then
        where:SetText(L["Turn in at %s, %s"]:format(npc.name, ns:ZoneName(npc.map))
            .. ("  %.1f, %.1f"):format(npc.x, npc.y))
        show.npc = npc
        y = y + 34
    end
    where:SetShown(npc ~= nil)
    show:SetShown(npc ~= nil)
    for gi, goal in ipairs(ns.Goals) do
        local row = getRewardRow(gi)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", CARD_INSET, -y)
        row:SetPoint("RIGHT", -CARD_INSET, 0)
        local status
        if ns:GoalDone(goal) then
            status = "|cff5ce65c" .. L["done"] .. "|r"
        elseif delivered >= goal.books then
            status = "|cffffd100" .. L["Ready to turn in"] .. "|r"
        else
            status = "|cffffd100" .. L["%d more to go"]:format(goal.books - delivered) .. "|r"
        end
        row.text:SetText(("%s (%d)  %s"):format(ns:QuestTitle(goal.quest, goal.title), goal.books, status))
        row:Show()
        y = y + 24 + 10
        local pick = ns:RewardPick(goal)
        local suits = {}
        for _, r in ipairs(ns:RewardChoices(goal)) do suits[r] = true end
        local rowH = CARD_H
        local placed = {}
        for i, r in ipairs(goal.rewards or {}) do
            ci = ci + 1
            local card = getRewardCard(ci)
            card:SetWidth(cardW)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", ((i - 1) % COLS) * (cardW + GAP), -y)
            card:Show()
            rowH = math.max(rowH, fillRewardChoice(card, goal, r, pick, suits[r]))
            placed[#placed + 1] = card
        end
        for _, c in ipairs(placed) do c:SetHeight(rowH) end
        y = y + rowH + 16
    end
end

local function createRewardsPage()
    rewardsPage = CreateFrame("Frame", nil, frame)
    rewardsPage:SetPoint("TOPLEFT", PAD, -CONTENT_TOP)
    rewardsPage:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    local back = CreateFrame("Button", nil, rewardsPage, "UIPanelButtonTemplate")
    back:SetSize(90, BTN_H)
    back:SetPoint("TOPLEFT", 0, 0)
    back:SetText(L["< Books"])
    back:SetScript("OnClick", function() ns:OpenJournal() end)
    -- the librarian, once for both goals: location + open the world map there (sets a waypoint too)
    local where = font(rewardsPage, "GameFontHighlight", C.text)
    where:SetPoint("TOPLEFT", 2, -(BTN_H + 16))
    rewardsPage.where = where
    local show = CreateFrame("Button", nil, rewardsPage, "UIPanelButtonTemplate")
    show:SetSize(120, BTN_H)
    show:SetPoint("LEFT", where, "RIGHT", 12, 0)
    show:SetText(L["Show on Map"])
    show:SetScript("OnClick", function(self) ns:ShowOnMap(self.npc.name, self.npc) end)
    rewardsPage.show = show
    rewardsPage:Hide()
    ns.rewardsPage = rewardsPage -- for tools/librarian-smoke.lua
end

-- ---------------------------------------------------------------------------------------
-- API

-- Options page: the same controls as Esc > Options > AddOns > Librarian, inside the journal.
-- (optionsPage is declared with the other pages at the top: the header gear reads it)
local function createOptionsPage()
    optionsPage = CreateFrame("Frame", nil, frame)
    optionsPage:SetPoint("TOPLEFT", PAD, -CONTENT_TOP)
    optionsPage:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    local back = CreateFrame("Button", nil, optionsPage, "UIPanelButtonTemplate")
    back:SetSize(90, 22)
    back:SetPoint("TOPLEFT", 0, 0)
    back:SetText(L["< Books"])
    back:SetScript("OnClick", function() ns:OpenJournal() end)
    local title = font(optionsPage, "GameFontNormalHuge", C.title)
    title:SetPoint("TOPLEFT", back, "BOTTOMLEFT", 2, -10)
    title:SetText(L["Options"])
    local rule = line(optionsPage, C.gold, 0.4)
    rule:SetPoint("TOPLEFT", 0, -84)
    rule:SetPoint("TOPRIGHT", 0, -84)
    optionsPage.refresh = ns:BuildOptionControls(optionsPage, 0, -96)
    optionsPage:Hide()
end

local function refresh()
    if not (frame and frame:IsShown()) then return end
    if optionsPage and optionsPage:IsShown() then
        optionsPage.refresh()
    elseif bookPage:IsShown() then
        refreshBook()
    elseif rewardsPage:IsShown() then
        refreshRewards()
    else
        refreshHome()
    end
end

-- which = "book" / "rewards" / "options" / nil (home). The home list keeps its scroll position, so
-- "< Books" lands where the book was clicked.
local function showPage(which)
    if not frame then
        createFrame()
        createHome()
        createBookPage()
        createRewardsPage()
        createOptionsPage()
    end
    frame:Show()
    home:Hide()
    bookPage:Hide()
    rewardsPage:Hide()
    optionsPage:Hide()
    local page = which == "book" and bookPage or which == "rewards" and rewardsPage
        or which == "options" and optionsPage or home
    page:Show()
    -- The scroll frames have no width until the first layout pass after Show.
    C_Timer.After(0, refresh)
    refresh()
end

-- page = "options" for the options page, nil for the home page.
function ns:OpenJournal(page)
    showPage(page == "options" and "options" or nil)
end

-- Every reward choice of both goals + where to turn the books in.
function ns:OpenRewards()
    showPage("rewards")
end

-- The book's page; spot = which of its spots (Rumi has two), default its first in zone order.
function ns:OpenBook(b, spot)
    if not (b and #b.spots > 0) then return ns:OpenJournal() end
    openEntry = ns:BookEntry(b, spot)
    showPage("book")
end

-- The zone's first missing book, else its first book, else the home page (toast, tracker).
function ns:OpenZoneBook(mapID)
    local e = mapID and (ns:ZoneMissing(mapID)[1] or ns:ZoneEntries(mapID)[1])
    if e then ns:OpenBook(e.book, e.spot) else ns:OpenJournal() end
end

function ns:ToggleJournal()
    if frame and frame:IsShown() then
        frame:Hide()
    else
        ns:OpenJournal()
    end
end

ns:On("STATUS", refresh)
ns:On("SPEC", refresh) -- talents changed or a reward pick switched
-- item / quest names arrive one by one after the first request: one refresh per burst
local namesPending
ns:On("NAMES", function()
    if namesPending then return end
    namesPending = true
    C_Timer.After(0.5, function()
        namesPending = nil
        refresh()
    end)
end)
ns:On("SETTING", refresh)
ns:On("LOADED", function()
    ns:RegisterEvent("ZONE_CHANGED_NEW_AREA", refresh)
end)
