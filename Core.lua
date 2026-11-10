-- BagSmuggler by WhiteKnight (Smuggz_)  -  Discord: whiteknight3187
-- Core: API shims, saved variables, events and Blizzard bag hooks.

local ADDON, ns = ...
_G.BagSmuggler = ns

ns.name = "BagSmuggler"
ns.author = "WhiteKnight / Smuggz_"
ns.discord = "whiteknight3187"
local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.version = (GetMeta and GetMeta(ADDON, "Version")) or "1.0.0"

---------------------------------------------------------------------------
-- API shims (TBC Anniversary + WoW Forever)
---------------------------------------------------------------------------
local C = C_Container
if not C then
    C = {
        GetContainerNumSlots = GetContainerNumSlots,
        GetContainerNumFreeSlots = GetContainerNumFreeSlots,
        GetContainerItemLink = GetContainerItemLink,
        GetContainerItemCooldown = GetContainerItemCooldown,
        UseContainerItem = UseContainerItem,
        PickupContainerItem = PickupContainerItem,
        SortBags = SortBags,
    }
    C.GetContainerItemInfo = function(bag, slot)
        local icon, count, locked, quality, readable, lootable, link, filtered, noValue, itemID = GetContainerItemInfo(bag, slot)
        if not icon then return nil end
        return {
            iconFileID = icon, stackCount = count, isLocked = locked, quality = quality,
            isReadable = readable, hasLoot = lootable, hyperlink = link,
            isFiltered = filtered, hasNoValue = noValue, itemID = itemID,
        }
    end
    if GetContainerItemQuestInfo then
        C.GetContainerItemQuestInfo = function(bag, slot)
            local isQuest, questID, isActive = GetContainerItemQuestInfo(bag, slot)
            return { isQuestItem = isQuest, questID = questID, isActive = isActive }
        end
    end
end
ns.C = C

ns.GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
ns.GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
-- Money as gold/silver/copper icons. Modern clients (WoW Forever) only have the
-- C_CurrencyInfo version; the old global is gone there.
local CoinString = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or GetCoinTextureString
function ns.Coins(copper)
    copper = math.floor(tonumber(copper) or 0)
    if CoinString then
        local ok, s = pcall(CoinString, copper)
        if ok and s then return s end
    end
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local out = {}
    if g > 0 then out[#out + 1] = g .. "|cffffd700g|r" end
    if s > 0 then out[#out + 1] = s .. "|cffc7c7cfs|r" end
    if c > 0 or #out == 0 then out[#out + 1] = c .. "|cffeda55fc|r" end
    return table.concat(out, " ")
end

local GetDetailedLevel = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo

function ns.GetItemLevel(link)
    if not link then return 0 end
    local lvl
    if GetDetailedLevel then
        local ok, v = pcall(GetDetailedLevel, link)
        if ok then lvl = v end
    end
    if not lvl then lvl = select(4, ns.GetItemInfo(link)) end
    return tonumber(lvl) or 0
end

function ns.SafeNumSlots(bag)
    local ok, n = pcall(C.GetContainerNumSlots, bag)
    return (ok and tonumber(n)) or 0
end

function ns.Print(...)
    print("|cffffd100BagSmuggler|r:", ...)
end

function ns.ClassHex(class)
    local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    local c = class and colors and colors[class]
    if not c then return "ffffffff" end
    if c.colorStr then return c.colorStr end
    return string.format("ff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
end

---------------------------------------------------------------------------
-- Bag id lists
---------------------------------------------------------------------------
local BagIndex = Enum and Enum.BagIndex
ns.BACKPACK = BACKPACK_CONTAINER or 0
ns.KEYRING = KEYRING_CONTAINER or (BagIndex and BagIndex.Keyring) or -2
ns.BANK = BANK_CONTAINER or (BagIndex and BagIndex.Bank) or -1

function ns:GetBagList()
    local list = {}
    local last = (NUM_BAG_SLOTS or 4) + (NUM_REAGENTBAG_SLOTS or 0)
    for bag = self.BACKPACK, last do
        list[#list + 1] = bag
    end
    if KEYRING_CONTAINER and self.db and self.db.settings.showKeyring and ns.SafeNumSlots(self.KEYRING) > 0 then
        list[#list + 1] = self.KEYRING
    end
    return list
end

function ns:GetBankBagList()
    local list = {}
    if BagIndex and BagIndex.CharacterBankTab_1 and not GetNumBankSlots and ns.SafeNumSlots(self.BANK) == 0 then
        -- Modern tabbed bank
        for i = 1, 6 do
            local id = BagIndex["CharacterBankTab_" .. i]
            if id then list[#list + 1] = id end
        end
    else
        list[1] = self.BANK
        local first = (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) + 1
        for bag = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do
            list[#list + 1] = bag
        end
    end
    return list
end

function ns:IsBankBag(id)
    if id == nil then return false end
    for _, bag in ipairs(self:GetBankBagList()) do
        if bag == id then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------
ns.defaults = {
    settings = {
        skin = "Bags",
        styleVersion = 4,
        accent = "blue",
        sortMode = "quality",
        scale = 1,
        columns = 10,
        bankColumns = 14,
        iconSize = 37,
        spacing = 5,
        alpha = 0.95,
        qualityBorders = true,
        showItemLevel = true,
        showNewGlow = true,
        compactSections = true,
        showKeyring = true,
        locked = false,
        autoSellJunk = true,
        replaceBank = true,
        tooltipCounts = true,
        mergeStacks = false,
        showUpgrades = true,
        showBoE = true,
        disabledCats = {},
    },
    collapsed = {},
    positions = {},
    junk = {},
    notJunk = {},
    realms = {},
}

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function ns:ResetSettings()
    wipe(self.db.settings)
    CopyDefaults(self.defaults.settings, self.db.settings)
    self:ApplySettings()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
    local fn = ns[event]
    if fn then fn(ns, ...) end
end)

function ns:RegisterEvent(event)
    pcall(events.RegisterEvent, events, event)
end

ns:RegisterEvent("ADDON_LOADED")
ns:RegisterEvent("PLAYER_LOGIN")

function ns:ADDON_LOADED(name)
    if name ~= ADDON then return end
    BagSmugglerDB = BagSmugglerDB or {}
    CopyDefaults(self.defaults, BagSmugglerDB)
    self.db = BagSmugglerDB
    local st = self.db.settings
    if (st.styleVersion or 0) < 4 then
        st.skin = "Bags"         -- 1.4.0: Default Bags look becomes the default
        st.styleVersion = 4
    end
    if (st.layoutVersion or 0) < 1 then
        st.mergeStacks = false   -- 1.4.6: show every stack and every empty slot like the default bags
        st.layoutVersion = 1
    end
    if not ns.UI.skins[st.skin] then st.skin = "Bags" end
    events:UnregisterEvent("ADDON_LOADED")
end

function ns:PLAYER_LOGIN()
    self.Data:Init()
    self.bags = self:CreateWindow("bags")
    self.bank = self:CreateWindow("bank")
    self:InstallHooks()
    self:HookBlizzardBank()
    self.Config:Init()
    self:ApplySettings()

    for _, e in ipairs({
        "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN", "PLAYER_MONEY",
        "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED",
        "MERCHANT_SHOW", "MERCHANT_CLOSED", "GET_ITEM_INFO_RECEIVED", "PLAYER_ENTERING_WORLD",
        "BAG_NEW_ITEMS_UPDATED", "QUEST_ACCEPTED", "QUEST_REMOVED",
        "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED",
    }) do
        self:RegisterEvent(e)
    end

    self.Data:SaveBags()
end

function ns:PLAYER_ENTERING_WORLD()
    self.Data:SaveBags()
    self:RefreshAll()
end

function ns:BAG_UPDATE_DELAYED()
    self.Data:SaveBags()
    if self.bankOpen then self.Data:SaveBank() end
    self:RefreshAll()
end

function ns:ITEM_LOCK_CHANGED(bag, slot)
    if bag and slot then self.Item:UpdateLock(bag, slot) end
end

function ns:BAG_UPDATE_COOLDOWN()
    self.Item:UpdateAllCooldowns()
end

function ns:PLAYER_MONEY()
    if self.Data.me then self.Data.me.money = GetMoney() end
    self.bags:UpdateFooter()
end

function ns:BANKFRAME_OPENED()
    self.bankOpen = true
    self.Data:SaveBank()
    self.bank:SetOwner(nil)
    self.bank:Show()
    self.bags:Show()
end

function ns:BANKFRAME_CLOSED()
    self.bankOpen = false
    self.showBlizzBank = false
    self.closingBank = true
    self.bank:Hide()
    self.closingBank = false
end

function ns:PLAYERBANKSLOTS_CHANGED()
    self.Data:SaveBank()
    self.bank:RequestUpdate()
end
ns.PLAYERBANKBAGSLOTS_CHANGED = ns.PLAYERBANKSLOTS_CHANGED

function ns:MERCHANT_SHOW()
    self.atMerchant = true
    if self.db.settings.autoSellJunk then
        C_Timer.After(0.3, function() ns.Junk:Sell() end)
    end
    self:RefreshAll()
end

function ns:MERCHANT_CLOSED()
    self.atMerchant = false
    self:RefreshAll()
end

function ns:GET_ITEM_INFO_RECEIVED()
    if self.infoPending then return end
    self.infoPending = true
    C_Timer.After(0.4, function()
        ns.infoPending = false
        ns:RefreshAll()
    end)
end

function ns:BAG_NEW_ITEMS_UPDATED() self:RefreshAll() end
function ns:QUEST_ACCEPTED() self:RefreshAll() end
function ns:QUEST_REMOVED() self:RefreshAll() end
function ns:PLAYER_EQUIPMENT_CHANGED() self:RefreshAll() end
function ns:PLAYER_LEVEL_UP() self:RefreshAll() end

-- Combat over: redo the full layout that was held back during combat
function ns:PLAYER_REGEN_ENABLED()
    if (self.bags and self.bags.needsLayout) or (self.bank and self.bank.needsLayout) then
        self:RefreshAll()
    end
end

-- Bag ids a window's Restack button tidies
function ns:GetRestackBags(isBank)
    if isBank then
        return self.bankOpen and self:GetBankBagList() or {}
    end
    return self:GetBagList()
end

function ns:RefreshAll()
    if self.bags then self.bags:RequestUpdate() end
    if self.bank then self.bank:RequestUpdate() end
end

function ns:ApplySettings()
    self.skinVersion = (self.skinVersion or 0) + 1
    self.UI:ApplyStyle()
    self.UI:ApplyAccent()
    for _, w in ipairs({ self.bags, self.bank }) do
        if w then
            w:ApplySkin()
            w:RequestUpdate()
        end
    end
end

---------------------------------------------------------------------------
-- Replace Blizzard bag toggles
---------------------------------------------------------------------------
-- Modern clients (WoW Forever): replacing Blizzard's bag functions taints
-- them. The merchant, auction house etc. call OpenAllBags when they open, so the
-- whole vendor window became tainted and right-clicking an item there (sell /
-- use) was blocked. Instead, leave Blizzard's functions alone, hide Blizzard's
-- bag frames, and follow its open/close calls with secure post-hooks.
function ns:InstallModernHooks()
    local bags = self.bags
    local hider = CreateFrame("Frame")
    hider:Hide()
    local function HideBlizzard()
        if ContainerFrameCombinedBags then ContainerFrameCombinedBags:SetParent(hider) end
        for i = 1, (NUM_CONTAINER_FRAMES or 13) do
            local f = _G["ContainerFrame" .. i]
            if f then f:SetParent(hider) end
        end
    end
    HideBlizzard()
    for _, fn in ipairs({ "ContainerFrame_SetFullScreenFrame", "ContainerFrame_ClearFullScreenFrame" }) do
        if _G[fn] then hooksecurefunc(fn, HideBlizzard) end
    end

    -- Blizzard's toggles call its open/close functions internally, so collect
    -- what was asked for this frame and act once on the next frame.
    local want
    local function Resolve()
        local w = want
        want = nil
        if w == "toggle" then bags:Toggle()
        elseif w == "open" then bags:Open()
        elseif w == "close" then bags:Close() end
    end
    local function Ask(kind)
        if not want then C_Timer.After(0, Resolve) end
        if kind == "toggle" or want == "toggle" then want = "toggle"
        elseif kind == "open" or want == "open" then want = "open"
        else want = kind end
    end
    local function Hook(name, kind, bagArg)
        if not _G[name] then return end
        hooksecurefunc(name, function(id)
            if bagArg and id and ns:IsBankBag(id) then return end
            Ask(kind)
        end)
    end
    Hook("ToggleAllBags", "toggle")
    Hook("ToggleBackpack", "toggle")
    Hook("ToggleBag", "toggle", true)
    Hook("ToggleKeyRing", "toggle")
    Hook("OpenAllBags", "open")
    Hook("OpenBackpack", "open")
    Hook("OpenBag", "open", true)
    Hook("CloseAllBags", "close")
    Hook("CloseBackpack", "close")
    Hook("CloseBag", "close", true)
end

function ns:InstallHooks()
    if ContainerFrameCombinedBags and hooksecurefunc then
        return self:InstallModernHooks()
    end
    local bags = self.bags

    local function toggle() bags:Toggle() end
    local function open() bags:Open() end
    local function close()
        local was = bags.frame:IsShown()
        bags:Close()
        return was
    end

    ToggleAllBags = toggle
    OpenAllBags = open
    CloseAllBags = close
    ToggleBackpack = toggle
    OpenBackpack = open
    CloseBackpack = close

    ToggleBag = function(id)
        if ns:IsBankBag(id) then ns.bank:Toggle() else bags:Toggle() end
    end
    OpenBag = function(id)
        if not ns:IsBankBag(id) then bags:Open() end
    end
    CloseBag = function(id)
        if not ns:IsBankBag(id) then bags:Close() end
    end
    if ToggleKeyRing then ToggleKeyRing = toggle end
end

---------------------------------------------------------------------------
-- Blizzard bank frame: kept alive (it owns the bank interaction) but hidden
---------------------------------------------------------------------------
function ns:ShrinkBlizzardBank()
    if not BankFrame then return end
    BankFrame:SetAlpha(0)
    BankFrame:SetScale(0.001)
    BankFrame:EnableMouse(false)
end

function ns:RestoreBlizzardBank()
    if not BankFrame then return end
    BankFrame:SetAlpha(1)
    BankFrame:SetScale(1)
    BankFrame:EnableMouse(true)
end

function ns:HookBlizzardBank()
    if not BankFrame or self.bankHooked then return end
    self.bankHooked = true
    BankFrame:HookScript("OnShow", function()
        if ns.db.settings.replaceBank and not ns.showBlizzBank then
            ns:ShrinkBlizzardBank()
        else
            ns:RestoreBlizzardBank()
        end
    end)
end

function ns:ToggleBlizzardBank()
    self.showBlizzBank = not self.showBlizzBank
    if self.showBlizzBank then self:RestoreBlizzardBank() else self:ShrinkBlizzardBank() end
end

function ns:CloseBankInteraction()
    if BankFrame and BankFrame:IsShown() then
        HideUIPanel(BankFrame)
    elseif CloseBankFrame then
        CloseBankFrame()
    elseif C_Bank and C_Bank.CloseBankFrame then
        C_Bank.CloseBankFrame()
    end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
SLASH_BAGSMUGGLER1 = "/bagsmuggler"
SLASH_BAGSMUGGLER2 = "/bsm"
SlashCmdList.BAGSMUGGLER = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "config" or msg == "options" or msg == "settings" then
        ns.Config:Toggle()
    elseif msg == "bank" then
        ns.bank:SetOwner(ns.bags.owner and ns.bags.owner.realm, ns.bags.owner and ns.bags.owner.name)
        ns.bank:Toggle()
    elseif msg == "reset" then
        wipe(ns.db.positions)
        ns.bags:RestorePosition()
        ns.bank:RestorePosition()
        ns.Print("Window positions reset.")
    elseif msg == "sell" then
        ns.Junk:Sell()
    elseif msg == "restack" then
        ns.Restack:Start(function() return ns:GetRestackBags(false) end)
    elseif msg == "" then
        ns.bags:Toggle()
    else
        ns.Print("/bsm - toggle bags, /bsm bank - view bank, /bsm config - settings, /bsm sell - sell junk, /bsm restack - combine stacks, /bsm reset - reset positions")
    end
end
