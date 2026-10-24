-- BagSmuggler: combine partial stacks of the same item

local _, ns = ...
local C = ns.C

local Restack = {}
ns.Restack = Restack

local MAX_MOVES = 250
local MAX_WAITS = 60

function Restack:IsRunning()
    return self.ticker ~= nil
end

function Restack:Stop(moves)
    if self.ticker then self.ticker:Cancel() end
    self.ticker = nil
    if moves and moves > 0 then
        ns.Print(("Restacked (%d move%s)."):format(moves, moves == 1 and "" or "s"))
    elseif moves == 0 then
        ns.Print("Nothing to restack.")
    end
    ns:RefreshAll()
end

-- bagList: function returning the bag ids to tidy
function Restack:Start(bagList)
    if self.ticker then return end
    if InCombatLockdown() then
        ns.Print("Can't restack in combat.")
        return
    end
    local moves, waits = 0, 0

    self.ticker = C_Timer.NewTicker(0.12, function()
        if InCombatLockdown() then return self:Stop(moves) end
        if CursorHasItem() then
            waits = waits + 1
            if waits > MAX_WAITS then return self:Stop(moves) end
            return
        end

        local partial = {}
        for _, bag in ipairs(bagList()) do
            if bag ~= ns.KEYRING then
                for slot = 1, ns.SafeNumSlots(bag) do
                    local info = C.GetContainerItemInfo(bag, slot)
                    if info and info.itemID then
                        if info.isLocked then
                            waits = waits + 1
                            if waits > MAX_WAITS then return self:Stop(moves) end
                            return
                        end
                        local max = select(8, ns.GetItemInfo(info.itemID))
                        if max and max > 1 and (info.stackCount or 1) < max then
                            local list = partial[info.itemID]
                            if not list then
                                list = {}
                                partial[info.itemID] = list
                            end
                            list[#list + 1] = { bag = bag, slot = slot }
                        end
                    end
                end
            end
        end
        waits = 0

        for _, list in pairs(partial) do
            if #list > 1 then
                local dst, src = list[1], list[#list]
                C.PickupContainerItem(src.bag, src.slot)
                C.PickupContainerItem(dst.bag, dst.slot)
                if CursorHasItem() then ClearCursor() end
                moves = moves + 1
                if moves >= MAX_MOVES then return self:Stop(moves) end
                return
            end
        end
        self:Stop(moves)
    end)
end
