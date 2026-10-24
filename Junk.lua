-- BagSmuggler: junk detection, marking and selling

local _, ns = ...
local C = ns.C

local Junk = {}
ns.Junk = Junk

function Junk:IsJunk(id, quality)
    if not id then return false end
    local db = ns.db
    if db.notJunk[id] then return false end
    if db.junk[id] then return true end
    return quality == 0
end

-- Alt + Right-click on an item
function Junk:Toggle(id, quality, link)
    if not id then return end
    local db = ns.db
    local label = link or ("item " .. id)
    if self:IsJunk(id, quality) then
        db.junk[id] = nil
        if quality == 0 then db.notJunk[id] = true end
        ns.Print(label .. " is no longer junk.")
    else
        db.notJunk[id] = nil
        if quality ~= 0 then db.junk[id] = true end
        ns.Print(label .. " marked as junk.")
    end
    ns:RefreshAll()
end

function Junk:ClearMarks()
    wipe(ns.db.junk)
    wipe(ns.db.notJunk)
    ns:RefreshAll()
end

-- Returns list of sellable junk and total value in copper
function Junk:Collect()
    local list, total = {}, 0
    for _, bag in ipairs(ns:GetBagList()) do
        if bag ~= ns.KEYRING then
            for slot = 1, ns.SafeNumSlots(bag) do
                local info = C.GetContainerItemInfo(bag, slot)
                if info and info.hyperlink and not info.hasNoValue and not info.isLocked
                    and self:IsJunk(info.itemID, info.quality) then
                    local price = select(11, ns.GetItemInfo(info.hyperlink))
                    if price and price > 0 then
                        local value = price * (info.stackCount or 1)
                        list[#list + 1] = { bag = bag, slot = slot, link = info.hyperlink, value = value }
                        total = total + value
                    end
                end
            end
        end
    end
    return list, total
end

function Junk:GetValue()
    local _, total = self:Collect()
    return total
end

local function MerchantOpen()
    return MerchantFrame and MerchantFrame:IsShown()
end

function Junk:Sell()
    if self.selling or not MerchantOpen() then return end
    local list = self:Collect()
    if #list == 0 then return end

    self.selling = true
    local i, sold, earned = 0, 0, 0
    local ticker
    local function finish()
        if ticker then ticker:Cancel() end
        self.selling = false
        if sold > 0 then
            ns.Print(("Sold %d junk item%s for %s"):format(sold, sold == 1 and "" or "s", GetCoinTextureString(earned)))
        end
        ns.bags:UpdateFooter()
    end

    ticker = C_Timer.NewTicker(0.15, function()
        if not MerchantOpen() then return finish() end
        for _ = 1, 4 do
            i = i + 1
            local item = list[i]
            if not item then return finish() end
            local info = C.GetContainerItemInfo(item.bag, item.slot)
            if info and info.hyperlink == item.link and not info.isLocked then
                C.UseContainerItem(item.bag, item.slot)
                sold = sold + 1
                earned = earned + item.value
            end
        end
    end)
end
