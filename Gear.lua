-- BagSmuggler: gear helpers (upgrade detection, bind-on-equip detection)

local _, ns = ...
local C = ns.C

local Gear = {}
ns.Gear = Gear

-- equipLoc -> inventory slot ids it can go into
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 },
    INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}

-- Armour subclasses: 0 misc, 1 cloth, 2 leather, 3 mail, 4 plate, 6 shield, 7 libram, 8 idol, 9 totem
local ARMOR = {
    WARRIOR = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [6] = true },
    PALADIN = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [6] = true, [7] = true },
    HUNTER  = { [0] = true, [1] = true, [2] = true, [3] = true },
    SHAMAN  = { [0] = true, [1] = true, [2] = true, [3] = true, [6] = true, [9] = true },
    ROGUE   = { [0] = true, [1] = true, [2] = true },
    DRUID   = { [0] = true, [1] = true, [2] = true, [8] = true },
    PRIEST  = { [0] = true, [1] = true },
    MAGE    = { [0] = true, [1] = true },
    WARLOCK = { [0] = true, [1] = true },
}

-- Weapon subclasses: 0 1h axe, 1 2h axe, 2 bow, 3 gun, 4 1h mace, 5 2h mace, 6 polearm,
-- 7 1h sword, 8 2h sword, 10 staff, 13 fist, 15 dagger, 16 thrown, 18 crossbow, 19 wand
local function set(...)
    local t = {}
    for i = 1, select("#", ...) do t[select(i, ...)] = true end
    return t
end
local WEAPON = {
    WARRIOR = set(0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18),
    PALADIN = set(0, 1, 4, 5, 6, 7, 8),
    HUNTER  = set(0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18),
    ROGUE   = set(2, 3, 4, 7, 13, 15, 16, 18),
    PRIEST  = set(4, 10, 15, 19),
    SHAMAN  = set(0, 1, 4, 5, 10, 13, 15),
    MAGE    = set(7, 10, 15, 19),
    WARLOCK = set(7, 10, 15, 19),
    DRUID   = set(4, 5, 10, 13, 15),
}

local equipped = {}

-- Called once per window update
function Gear:Refresh()
    for slot = 1, 18 do
        local link = GetInventoryItemLink("player", slot)
        equipped[slot] = link and ns.GetItemLevel(link) or 0
    end
    self.class = self.class or select(2, UnitClass("player"))
    self.level = UnitLevel("player")
end

local function CanUse(e)
    local class = Gear.class
    if e.classID == 4 then
        local allowed = ARMOR[class]
        return not allowed or allowed[e.subClassID] or false
    elseif e.classID == 2 then
        local allowed = WEAPON[class]
        return not allowed or allowed[e.subClassID] or false
    end
    return false
end

function Gear:IsUpgrade(e)
    if not e.isGear or not e.link then return false end
    local slots = SLOTS[e.equipLoc]
    if not slots or not CanUse(e) then return false end
    local minLevel = select(5, ns.GetItemInfo(e.link))
    if minLevel and self.level and minLevel > self.level then return false end
    local lowest
    for _, slot in ipairs(slots) do
        local lvl = equipped[slot] or 0
        if not lowest or lvl < lowest then lowest = lvl end
    end
    return lowest ~= nil and e.ilvl > lowest
end

-- Bind-on-equip and not yet bound
function Gear:IsBoE(e)
    if not e.isGear or not e.link then return false end
    local bindType = select(14, ns.GetItemInfo(e.link))
    if bindType ~= 2 then return false end
    if e.bound ~= nil then return not e.bound end
    if e.bag and C_Item and C_Item.IsBound and ItemLocation and ItemLocation.CreateFromBagAndSlot then
        local ok, bound = pcall(function()
            return C_Item.IsBound(ItemLocation:CreateFromBagAndSlot(e.bag, e.slot))
        end)
        if ok then return not bound end
    end
    return false
end
