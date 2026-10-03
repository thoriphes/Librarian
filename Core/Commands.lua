-- /librarian [zone [name] | all | probe | mark <item> bags|delivered|clear | toast | options]
local _, ns = ...
local L = ns.L

local COLOR = { missing = "ffff5050", found = "ffffd100", delivered = "ff40ff40" } -- red / yellow / green

function ns:StatusText(status)
    local label = status == ns.DELIVERED and L["Delivered"] or status == ns.FOUND and L["In bags"] or L["Missing"]
    return "|c" .. COLOR[status] .. label .. "|r"
end

local function findZone(text)
    text = text and strtrim(text):lower() or ""
    if text == "" then return ns:CurrentZone() end
    for mapID in pairs(ns.Zones) do
        if ns:ZoneName(mapID):lower():find(text, 1, true) then return mapID end
    end
end

local function printZone(mapID)
    local books = ns:ZoneBooks(mapID)
    local d, f, t = ns:Count(books)
    ns:Print(ns:ZoneName(mapID) .. ": " .. L["%d/%d delivered, %d in bags"]:format(d, t, f))
    for _, e in ipairs(ns:ZoneEntries(mapID)) do
        local s, manual = ns:Status(e.book)
        print(("  %s  %s  (%.1f, %.1f)%s"):format(ns:StatusText(s), ns:BookName(e.book), e.spot.x, e.spot.y,
            manual and (" " .. L["[manual]"]) or ""))
    end
end

local function findBook(arg)
    local id = tonumber(arg)
    if id then return ns.byItem[id] end
    arg = arg:lower()
    for _, b in ipairs(ns.Books) do
        if b.name:lower():find(arg, 1, true) or ns:BookName(b):lower():find(arg, 1, true) then return b end
    end
end

-- The slash globals are the client's registration mechanism, not ours.
SLASH_LIBRARIAN1 = "/librarian"
SlashCmdList.LIBRARIAN = function(msg)
    local cmd, rest = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if cmd == "" then
        ns:ToggleJournal()
    elseif cmd == "zone" then
        local mapID = findZone(rest)
        if not mapID then
            ns:Print(rest == "" and L["no library books in this zone."] or L["no zone matches '%s'."]:format(rest))
        elseif #ns:ZoneEntries(mapID) == 0 then
            ns:Print(L["%s: no library books for your faction."]:format(ns:ZoneName(mapID)))
        else
            printZone(mapID)
        end
    elseif cmd == "all" then
        local goals = {}
        for _, g in ipairs(ns.Goals) do goals[#goals + 1] = g.books end
        ns:Print(L["%d books delivered (goals: %s)"]:format(ns:DeliveredTotal(), table.concat(goals, ", ")))
        for _, g in ipairs(ns:ZoneList()) do
            for _, mapID in ipairs(g.zones) do
                local d, f, t = ns:Count(ns:ZoneBooks(mapID))
                print("  " .. ns:ZoneName(mapID) .. ": " .. L["%d/%d delivered, %d in bags"]:format(d, t, f))
            end
        end
    elseif cmd == "probe" then
        -- Raw detection, no manual marks: quest flag and item count per book.
        for _, b in ipairs(ns.Books) do
            print(("%d q%s done=%s bags=%d bank=%d %s"):format(b.item, tostring(b.quest),
                tostring(b.quest and C_QuestLog.IsQuestFlaggedCompleted(b.quest)),
                C_Item.GetItemCount(b.item), C_Item.GetItemCount(b.item, true), b.name))
        end
    elseif cmd == "mark" then
        local arg, what = rest:match("^(.-)%s+(%S+)$")
        local b = arg and findBook(arg)
        what = what and what:lower()
        if what == "bags" then what = "found" end
        if not b or not (what == "found" or what == "delivered" or what == "clear") then
            ns:Print("usage: /librarian mark <item id or name> bags|delivered|clear")
            return
        end
        ns:SetMark(b, what ~= "clear" and what or nil)
        ns:Print(ns:BookName(b) .. ": " .. ns:StatusText((ns:Status(b))))
    elseif cmd == "spec" then
        -- what the reward filter sees: trees + points, the role picked, each goal's choices
        local trees = ns:TalentTrees()
        print(("class=%s role=%s"):format(tostring(ns:PlayerClass()), tostring(ns:PlayerRole())))
        if not trees then print("  talent trees: not readable") end
        for i, t in ipairs(trees or {}) do
            print(("  tree %d: %s = %d points"):format(i, tostring(t.name), t.points))
        end
        for _, g in ipairs(ns.Goals) do
            local names = {}
            for _, r in ipairs(ns:RewardChoices(g)) do names[#names + 1] = r.name end
            print(("  %s: %s"):format(g.title, table.concat(names, " / ")))
        end
    elseif cmd == "toast" then
        ns:ShowZoneToast(ns:CurrentZone(), true)
    elseif cmd == "options" or cmd == "config" then
        ns:OpenOptions()
    else
        ns:Print("/librarian - journal; zone [name]; all; probe; mark <book> bags|delivered|clear; toast; options")
    end
end
