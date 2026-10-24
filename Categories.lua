-- BagSmuggler: item categorisation and sorting

local _, ns = ...
local C = ns.C

local Cat = {}
ns.Categories = Cat

-- r, g, b used for the section heading
Cat.list = {
    { key = "new",        name = "New",           order = 1,   color = { 1.00, 0.82, 0.20 } },
    { key = "equipment",  name = "Equipment",     order = 10,  color = { 0.55, 0.75, 1.00 } },
    { key = "consumable", name = "Consumables",   order = 20,  color = { 0.45, 0.90, 0.45 } },
    { key = "quest",      name = "Quest",         order = 30,  color = { 1.00, 0.85, 0.00 } },
    { key = "tradegoods", name = "Trade Goods",   order = 40,  color = { 0.90, 0.70, 0.45 } },
    { key = "recipe",     name = "Recipes",       order = 50,  color = { 0.80, 0.80, 0.95 } },
    { key = "shards",     name = "Soul Shards",   order = 55,  color = { 0.75, 0.45, 1.00 } },
    { key = "ammo",       name = "Ammo",          order = 60,  color = { 0.85, 0.85, 0.85 } },
    { key = "keys",       name = "Keys",          order = 65,  color = { 0.95, 0.90, 0.60 } },
    { key = "container",  name = "Bags",          order = 70,  color = { 0.70, 0.55, 0.40 } },
    { key = "misc",       name = "Miscellaneous", order = 80,  color = { 0.75, 0.75, 0.75 } },
    { key = "junk",       name = "Junk",          order = 90,  color = { 0.60, 0.60, 0.60 } },
    { key = "empty",      name = "Free",          order = 100, color = { 0.50, 0.50, 0.50 } },
}

Cat.byKey = {}
for _, c in ipairs(Cat.list) do Cat.byKey[c.key] = c end

-- Categories the player can switch off (items fall back to Miscellaneous)
Cat.optional = { "new", "equipment", "consumable", "quest", "tradegoods", "recipe", "shards", "ammo", "keys", "container", "junk" }

local SOUL_SHARD = 6265

local function Enabled(key)
    return not ns.db.settings.disabledCats[key]
end

function Cat:Classify(e)
    if ns.Junk:IsJunk(e.id, e.quality) and Enabled("junk") then return "junk" end
    if e.isNew and Enabled("new") then return "new" end
    if e.id == SOUL_SHARD and Enabled("shards") then return "shards" end
    if e.bag and e.bag == ns.KEYRING and Enabled("keys") then return "keys" end
    if e.isQuest and Enabled("quest") then return "quest" end

    local c = e.classID
    if e.isGear and Enabled("equipment") then return "equipment" end
    if c == 0 and Enabled("consumable") then return "consumable" end
    if c == 12 and Enabled("quest") then return "quest" end
    if (c == 7 or c == 3 or c == 5 or c == 8) and Enabled("tradegoods") then return "tradegoods" end
    if c == 9 and Enabled("recipe") then return "recipe" end
    if c == 6 and Enabled("ammo") then return "ammo" end
    if c == 13 and Enabled("keys") then return "keys" end
    if (c == 1 or c == 11) and Enabled("container") then return "container" end
    return "misc"
end

-- Fills derived fields on an entry ({ link, id, count, quality, bag?, slot? })
function Cat:Fill(e)
    if not e.id and e.link then
        e.id = tonumber(e.link:match("item:(%-?%d+)"))
    end
    local itemType, subType, equipLoc, icon, classID, subClassID
    if e.id then
        local _
        _, itemType, subType, equipLoc, icon, classID, subClassID = ns.GetItemInfoInstant(e.id)
    end
    e.icon = e.icon or icon or 134400
    e.itemType = itemType or ""
    e.subType = subType or ""
    e.equipLoc = equipLoc or ""
    e.classID = classID or 99
    e.subClassID = subClassID or 0
    e.quality = e.quality or 1
    e.count = e.count or 1
    e.name = (e.link and e.link:match("%[(.-)%]")) or ""
    e.lname = e.name:lower()

    e.isGear = (e.classID == 2 or e.classID == 4) and e.equipLoc ~= ""
        and not e.equipLoc:find("NON_EQUIP")
    e.ilvl = e.isGear and ns.GetItemLevel(e.link) or 0
    e.cat = self:Classify(e)
    return e
end

function Cat:MakeLiveEntry(bag, slot, info)
    local e = {
        bag = bag, slot = slot,
        link = info.hyperlink, id = info.itemID,
        count = info.stackCount, quality = info.quality,
        icon = info.iconFileID, locked = info.isLocked,
        noValue = info.hasNoValue, bound = info.isBound,
        sortKey = bag * 1000 + slot,
    }
    if C.GetContainerItemQuestInfo then
        local ok, q = pcall(C.GetContainerItemQuestInfo, bag, slot)
        if ok and type(q) == "table" then
            e.isQuest = q.isQuestItem or (q.questID ~= nil)
        end
    end
    if C_NewItems and C_NewItems.IsNewItem then
        local ok, isNew = pcall(C_NewItems.IsNewItem, bag, slot)
        e.isNew = ok and isNew or false
    end
    return self:Fill(e)
end

function Cat:MakeOfflineEntry(stored, index)
    local e = {
        link = stored[1], count = stored[2], quality = stored[3], bound = stored[4],
        sortKey = index,
    }
    return self:Fill(e)
end

---------------------------------------------------------------------------
-- Sorting
---------------------------------------------------------------------------
local function tie(a, b)
    if a.name ~= b.name then return a.name < b.name end
    if a.count ~= b.count then return a.count > b.count end
    return a.sortKey < b.sortKey
end

Cat.sorters = {
    quality = function(a, b)
        if a.quality ~= b.quality then return a.quality > b.quality end
        if a.ilvl ~= b.ilvl then return a.ilvl > b.ilvl end
        return tie(a, b)
    end,
    ilvl = function(a, b)
        if a.ilvl ~= b.ilvl then return a.ilvl > b.ilvl end
        if a.quality ~= b.quality then return a.quality > b.quality end
        return tie(a, b)
    end,
    name = function(a, b)
        return tie(a, b)
    end,
    type = function(a, b)
        if a.classID ~= b.classID then return a.classID < b.classID end
        if a.subClassID ~= b.subClassID then return a.subClassID < b.subClassID end
        if a.quality ~= b.quality then return a.quality > b.quality end
        return tie(a, b)
    end,
}

Cat.sortOrder = { "quality", "ilvl", "name", "type" }
Cat.sortNames = { quality = "Quality", ilvl = "Item Level", name = "Name", type = "Type" }

function Cat:GetSorter(mode)
    return self.sorters[mode] or self.sorters.quality
end

function Cat:NextSortMode(mode)
    for i, m in ipairs(self.sortOrder) do
        if m == mode then return self.sortOrder[i % #self.sortOrder + 1] end
    end
    return "quality"
end
