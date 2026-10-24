-- BagSmuggler: per-character inventory snapshots (offline viewing + tooltip counts)

local _, ns = ...
local C = ns.C

local Data = {}
ns.Data = Data

function Data:Init()
    ns.realm = GetRealmName()
    ns.player = UnitName("player")
    local realms = ns.db.realms
    realms[ns.realm] = realms[ns.realm] or {}
    local me = realms[ns.realm][ns.player] or {}
    realms[ns.realm][ns.player] = me

    me.class = select(2, UnitClass("player"))
    me.faction = UnitFactionGroup("player")
    me.bags = me.bags or {}
    me.bank = me.bank or {}
    me.bagCounts = me.bagCounts or {}
    me.bankCounts = me.bankCounts or {}
    me.money = GetMoney()
    self.me = me

    self:HookTooltips()
end

function Data:Get(realm, name)
    if not realm then return self.me end
    local r = ns.db.realms[realm]
    return r and r[name]
end

local function Snapshot(bagList)
    local items, counts = {}, {}
    for _, bag in ipairs(bagList) do
        for slot = 1, ns.SafeNumSlots(bag) do
            local info = C.GetContainerItemInfo(bag, slot)
            if info and info.hyperlink then
                local n = info.stackCount or 1
                items[#items + 1] = { info.hyperlink, n, info.quality, info.isBound }
                local id = info.itemID or tonumber(info.hyperlink:match("item:(%d+)"))
                if id then counts[id] = (counts[id] or 0) + n end
            end
        end
    end
    return items, counts
end

function Data:SaveBags()
    local me = self.me
    if not me then return end
    me.bags, me.bagCounts = Snapshot(ns:GetBagList())
    me.money = GetMoney()
    me.lastSeen = time()
end

function Data:SaveBank()
    local me = self.me
    if not me or not ns.bankOpen then return end
    me.bank, me.bankCounts = Snapshot(ns:GetBankBagList())
    me.hasBank = true
end

-- Sorted list of all known characters, current realm first
function Data:GetCharacters()
    local list = {}
    for realm, chars in pairs(ns.db.realms) do
        for name, c in pairs(chars) do
            list[#list + 1] = { realm = realm, name = name, data = c, current = (realm == ns.realm and name == ns.player) }
        end
    end
    table.sort(list, function(a, b)
        local ar, br = a.realm == ns.realm, b.realm == ns.realm
        if ar ~= br then return ar end
        if a.realm ~= b.realm then return a.realm < b.realm end
        return a.name < b.name
    end)
    return list
end

function Data:Delete(realm, name)
    if realm == ns.realm and name == ns.player then return end
    local r = ns.db.realms[realm]
    if r then r[name] = nil end
    if next(r or {}) == nil then ns.db.realms[realm] = nil end
    ns.Print(("Removed saved data for %s - %s."):format(name, realm))
end

function Data:RealmMoney()
    local total, list = 0, {}
    for name, c in pairs(ns.db.realms[ns.realm] or {}) do
        local m = c.money or 0
        total = total + m
        list[#list + 1] = { name = name, class = c.class, money = m }
    end
    table.sort(list, function(a, b) return a.money > b.money end)
    return total, list
end

---------------------------------------------------------------------------
-- Tooltip: "Smuggz: Bags 5, Bank 20"
---------------------------------------------------------------------------
function Data:AddTooltipCounts(tt, link)
    if not ns.db.settings.tooltipCounts or type(link) ~= "string" then return end
    local id = tonumber(link:match("item:(%d+)"))
    if not id then return end
    local realm = ns.db.realms[ns.realm]
    if not realm then return end

    local rows, total = {}, 0
    for name, c in pairs(realm) do
        local b = c.bagCounts and c.bagCounts[id] or 0
        local k = c.bankCounts and c.bankCounts[id] or 0
        if b + k > 0 then
            rows[#rows + 1] = { name = name, class = c.class, bags = b, bank = k }
            total = total + b + k
        end
    end
    if #rows == 0 then return end
    table.sort(rows, function(a, b) return a.name < b.name end)

    tt:AddLine(" ")
    for _, r in ipairs(rows) do
        local parts = {}
        if r.bags > 0 then parts[#parts + 1] = "Bags " .. r.bags end
        if r.bank > 0 then parts[#parts + 1] = "Bank " .. r.bank end
        tt:AddDoubleLine("|c" .. ns.ClassHex(r.class) .. r.name .. "|r", table.concat(parts, ", "), 1, 1, 1, 0.8, 0.8, 0.8)
    end
    if #rows > 1 then
        tt:AddDoubleLine("|cff7fbfffTotal|r", total, 1, 1, 1, 1, 1, 1)
    end
    tt:Show()
end

function Data:HookTooltips()
    local function handler(tt)
        if tt.wkDone then return end
        local ok, _, link = pcall(tt.GetItem, tt)
        if ok and link then
            tt.wkDone = true
            pcall(Data.AddTooltipCounts, Data, tt, link)
        end
    end

    local tips = { GameTooltip, ItemRefTooltip }
    for _, tt in ipairs(tips) do
        pcall(tt.HookScript, tt, "OnTooltipCleared", function(self) self.wkDone = nil end)
    end

    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt)
            if tt == GameTooltip or tt == ItemRefTooltip then handler(tt) end
        end)
    else
        for _, tt in ipairs(tips) do
            pcall(tt.HookScript, tt, "OnTooltipSetItem", handler)
        end
    end
end
