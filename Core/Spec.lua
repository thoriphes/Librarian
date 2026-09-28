-- Current spec = the talent tree with the most points spent, and which reward choices suit it.
-- Forever keeps Classic's three trees per class but runs them on the retail traits system (one
-- "starter spec" per class, IDs 1482-1491): the trees are trait node GROUPS of the class tree,
-- each with its own spent-points currency - read the way Blizzard's Camelot talent frame does
-- (Blizzard_PlayerSpells/Camelot/ClassTalents/Blizzard_ClassTalentsFrame.lua, RefreshTreeHeaders).
local _, ns = ...

-- Role of each tree in Classic's tab order. Pure classes need no talents to know their role.
local TREE_ROLES = {
    WARRIOR = { "physical", "physical", "physical" },
    ROGUE = { "physical", "physical", "physical" },
    HUNTER = { "physical", "physical", "physical" },
    MAGE = { "caster", "caster", "caster" },
    WARLOCK = { "caster", "caster", "caster" },
    PRIEST = { "caster", "caster", "caster" },
    PALADIN = { "caster", "physical", "physical" },  -- Holy / Protection / Retribution
    SHAMAN = { "caster", "physical", "caster" },     -- Elemental / Enhancement / Restoration
    DRUID = { "caster", "physical", "caster" },      -- Balance / Feral / Restoration
}

function ns:PlayerClass()
    return select(2, UnitClass("player"))
end

-- { { name, icon, points }, ... } in the tree's own group order; nil if unreadable.
function ns:TalentTrees()
    if not (C_SpecializationInfo and C_ClassTalents and C_Traits) then return end
    local spec = C_SpecializationInfo.GetSpecialization()
    local specID = spec and C_SpecializationInfo.GetSpecializationInfo(spec)
    local treeID = specID and C_ClassTalents.GetTraitTreeForSpec(specID)
    local configID = C_ClassTalents.GetActiveConfigID()
    if not (treeID and configID) then return end
    local displays = C_Traits.GetGroupDisplayInfoByTreeID(treeID)
    if not displays or #displays == 0 then return end
    local ids = {}
    for _, d in ipairs(displays) do ids[#ids + 1] = d.groupID end
    local spent = {}
    for _, g in ipairs(C_Traits.GetGroupCurrencyInfo(configID, ids) or {}) do
        local c = g.currencyInfos and g.currencyInfos[1]
        spent[g.traitNodeGroupID] = c and c.spent or 0
    end
    local out = {}
    for _, d in ipairs(displays) do
        out[#out + 1] = { name = d.displayName, icon = d.icon, points = spent[d.groupID] or 0 }
    end
    return out
end

-- "caster" / "physical" / nil (hybrid with no points yet, or unknown class).
function ns:PlayerRole()
    local roles = TREE_ROLES[ns:PlayerClass()]
    if not roles then return end
    if roles[1] == roles[2] and roles[2] == roles[3] then return roles[1] end
    local trees = ns:TalentTrees()
    local best, most = nil, 0
    for i, t in ipairs(trees or {}) do
        if t.points > most then best, most = i, t.points end
    end
    return best and roles[best] or nil
end

-- The goal's rewards this character should see: class restrictions first, then role (items with
-- no role always stay). If the role filter leaves nothing, the class-legal list is used.
function ns:RewardChoices(goal)
    local class, role = ns:PlayerClass(), ns:PlayerRole()
    local legal = {}
    for _, r in ipairs(goal.rewards or {}) do
        local ok = not r.classes
        for _, c in ipairs(r.classes or {}) do
            if c == class then ok = true end
        end
        if ok then legal[#legal + 1] = r end
    end
    if #legal == 0 then legal = goal.rewards or {} end
    local fit = {}
    for _, r in ipairs(legal) do
        if not role or not r.role or r.role == role then fit[#fit + 1] = r end
    end
    return #fit > 0 and fit or legal
end

-- The choice shown on the reward card: the character's own pick (switched by clicking the
-- card's icon), else the first suitable one.
function ns:RewardPick(goal)
    local choices = ns:RewardChoices(goal)
    local picked = ns.char.rewardPick and ns.char.rewardPick[goal.quest]
    for i, r in ipairs(choices) do
        if r.item == picked then return r, i, choices end
    end
    return choices[1], 1, choices
end

function ns:NextRewardPick(goal)
    local _, i, choices = ns:RewardPick(goal)
    if #choices < 2 then return end
    ns.char.rewardPick = ns.char.rewardPick or {}
    ns.char.rewardPick[goal.quest] = choices[i % #choices + 1].item
    ns:Fire("SPEC")
end

-- Make `item` the goal's pick (the rewards page); only a suitable choice can be picked.
function ns:SetRewardPick(goal, item)
    for _, r in ipairs(ns:RewardChoices(goal)) do
        if r.item == item then
            ns.char.rewardPick = ns.char.rewardPick or {}
            ns.char.rewardPick[goal.quest] = item
            ns:Fire("SPEC")
            return true
        end
    end
end

ns:On("LOADED", function()
    local function changed() ns:Fire("SPEC") end
    for _, e in ipairs({ "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE", "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" }) do
        pcall(ns.RegisterEvent, ns, e, changed) -- an event the client does not know must not break loading
    end
end)
