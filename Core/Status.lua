-- Detection: missing / found / delivered per book.
--   delivered = the book's turn-in quest is flagged completed on this character
--   found     = the book item is in the bags or the bank
--   missing   = neither
-- A manual mark (per character) can raise a book to found or delivered: needed for books
-- whose turn-in does not exist on Forever, and as an escape hatch if detection is wrong.
local _, ns = ...

ns.MISSING, ns.FOUND, ns.DELIVERED = "missing", "found", "delivered"
local RANK = { missing = 0, found = 1, delivered = 2 }

local turnedIn = {} -- quests turned in this session (the completed flag can lag the event)
local cache = {}    -- item -> status, to fire STATUS only on a change

local function questDone(q)
    return q and (turnedIn[q] or C_QuestLog.IsQuestFlaggedCompleted(q)) or false
end

function ns:DetectedStatus(b)
    if questDone(b.quest) then return ns.DELIVERED end
    if C_Item.GetItemCount(b.item, true) > 0 then return ns.FOUND end
    return ns.MISSING
end

function ns:Status(b)
    local s = ns:DetectedStatus(b)
    local mark = ns.char and ns.char.marks[b.item]
    if mark and RANK[mark] > RANK[s] then
        return mark, true
    end
    return s, false
end

-- nil clears the mark.
function ns:SetMark(b, status)
    ns.char.marks[b.item] = status
    ns:Refresh()
end

-- Counts over a list of zone entries or books.
function ns:Count(books)
    local found, delivered, total = 0, 0, 0
    for _, b in ipairs(books) do
        total = total + 1
        local s = ns:Status(b)
        if s == ns.DELIVERED then
            delivered = delivered + 1
        elseif s == ns.FOUND then
            found = found + 1
        end
    end
    return delivered, found, total
end

function ns:ZoneBooks(mapID)
    local out, seen = {}, {}
    for _, e in ipairs(ns:ZoneEntries(mapID)) do
        if not seen[e.book] then
            seen[e.book] = true
            table.insert(out, e.book)
        end
    end
    return out
end

-- Missing books in a zone (what the toast and the tracker show): one entry per book, its first
-- spot there (a book can lie twice in one zone: The Knight and the Lady).
function ns:ZoneMissing(mapID)
    local out, seen = {}, {}
    for _, e in ipairs(ns:ZoneEntries(mapID)) do
        if not seen[e.book] and ns:Status(e.book) == ns.MISSING then
            seen[e.book] = true
            table.insert(out, e)
        end
    end
    return out
end

-- Distinct books delivered overall, for the 10 / 20 goals.
function ns:DeliveredTotal()
    local n = 0
    for _, b in ipairs(ns.Books) do
        if ns:Status(b) == ns.DELIVERED then n = n + 1 end
    end
    return n
end

function ns:GoalDone(goal)
    return questDone(goal.quest)
end

-- Recompute every status and fire STATUS(changedItems) when anything moved.
function ns:Refresh()
    local changed
    for _, b in ipairs(ns.Books) do
        local s = ns:Status(b)
        if cache[b.item] ~= s then
            changed = changed or {}
            changed[b.item] = s
            cache[b.item] = s
        end
    end
    if changed then ns:Fire("STATUS", changed) end
end

-- Coalesce bursts (BAG_UPDATE_DELAYED + QUEST_LOG_UPDATE after a turn-in) into one pass.
local pending
local function queueRefresh()
    if pending then return end
    pending = true
    C_Timer.After(0.2, function()
        pending = nil
        ns:Refresh()
    end)
end
ns.QueueRefresh = queueRefresh

ns:On("LOADED", function()
    ns:RegisterEvent("PLAYER_ENTERING_WORLD", queueRefresh)
    ns:RegisterEvent("BAG_UPDATE_DELAYED", queueRefresh)
    ns:RegisterEvent("QUEST_LOG_UPDATE", queueRefresh)
    ns:RegisterEvent("QUEST_TURNED_IN", function(_, questID)
        if ns.byQuest[questID] then
            turnedIn[questID] = true
        end
        for _, g in ipairs(ns.Goals) do
            if g.quest == questID then turnedIn[questID] = true end
        end
        queueRefresh()
    end)
end)
