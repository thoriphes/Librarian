-- Objective tracker section (on by default): the current zone's missing books, plus a
-- "turn in" block when books sit in the bags. Forever runs retail's modular tracker, so this is
-- a module like Blizzard's own profession-recipe one: ObjectiveTrackerModuleTemplate +
-- LayoutContents, added to ObjectiveTrackerFrame through ObjectiveTrackerManager.
-- Blocks go through self:LayoutBlock(block) (marks them used + shows them), NOT AddBlock: a
-- block only AddBlock-ed is freed again at the end of the layout (header shows, no entries).
-- Taint: our LayoutContents runs inside Blizzard's tracker update. Everything we write
-- (MarkDirty, adding / removing the module) waits for out of combat; blocks use our own
-- templates (Tracker.xml).
local _, ns = ...
local L = ns.L

local UI_ORDER = 1000 -- after every Blizzard module
local module, attached, pendingDirty

local function build()
    module = CreateFrame("Frame", nil, UIParent, "ObjectiveTrackerModuleTemplate")
    module.blockTemplate = "LibrarianTrackerBlockTemplate"
    module.lineTemplate = "LibrarianTrackerLineTemplate"
    module.uiOrder = UI_ORDER
    module:SetHeader(L["Library Books"])

    function module:LayoutContents()
        local mapID = ns:CurrentZone()
        if mapID then
            for _, e in ipairs(ns:ZoneMissing(mapID)) do
                local block = self:GetBlock("book" .. e.book.item)
                block:SetHeader(ns:BookName(e.book))
                local where = e.spot.place and (ns:PlaceName(e.spot) .. ", ") or ""
                block:AddObjective("where", ("%s%.1f, %.1f"):format(where, e.spot.x, e.spot.y))
                block.entry = e
                if not self:LayoutBlock(block) then return end
            end
        end
        local lib, trainer = 0, 0
        for _, b in ipairs(ns.Books) do
            if ns:Status(b) == ns.FOUND then
                if b.trainer then trainer = trainer + 1 else lib = lib + 1 end
            end
        end
        if lib + trainer > 0 then
            local block = self:GetBlock("turnin")
            local n = lib + trainer
            block:SetHeader(n == 1 and L["Turn in 1 book"] or L["Turn in %d books"]:format(n))
            local faction = ns:PlayerFaction()
            for _, list in ipairs({ { lib, ns.Librarians }, { trainer, ns.Trainers } }) do
                if list[1] > 0 then
                    for _, npc in ipairs(list[2]) do
                        if npc.side == faction then
                            block:AddObjective("npc" .. npc.npc, L["%d to %s (%s)"]:format(list[1], npc.name,
                                ns:ZoneName(npc.map)))
                        end
                    end
                end
            end
            block.entry = nil
            self:LayoutBlock(block)
        end
    end

    function module:OnBlockHeaderClick(block, mouseButton)
        local e = block.entry
        if mouseButton == "RightButton" or not e then
            if e then ns:OpenBook(e.book, e.spot) else ns:OpenZoneBook(ns:CurrentZone()) end
        else
            ns:ShowOnMap(e.book, e.spot)
        end
    end
end

local function markDirty()
    if not attached then return end
    if InCombatLockdown() then
        pendingDirty = true
        return
    end
    module:MarkDirty()
end

local function trackerReady()
    return ObjectiveTrackerManager and ObjectiveTrackerFrame
        and ObjectiveTrackerManager.containers[ObjectiveTrackerFrame]
end

function ns:UpdateTracker()
    if InCombatLockdown() or not trackerReady() then
        pendingDirty = true
        return
    end
    if ns.db.tracker and not attached then
        if not module then build() end
        ObjectiveTrackerManager:SetModuleContainer(module, ObjectiveTrackerFrame)
        attached = true
        module:MarkDirty()
    elseif not ns.db.tracker and attached then
        ObjectiveTrackerFrame:RemoveModule(module)
        ObjectiveTrackerManager.moduleToContainerMap[module] = nil
        module:Hide()
        attached = false
    else
        markDirty()
    end
end

ns:On("LOADED", function()
    ns:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        -- The manager registers ObjectiveTrackerFrame after PLAYER_ENTERING_WORLD.
        C_Timer.After(1, ns.UpdateTracker)
    end)
    ns:RegisterEvent("ZONE_CHANGED_NEW_AREA", markDirty)
    ns:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if pendingDirty then
            pendingDirty = nil
            ns:UpdateTracker()
        end
    end)
end)
ns:On("STATUS", markDirty)
ns:On("SETTING", function(key)
    if key == "tracker" then ns:UpdateTracker() end
end)
