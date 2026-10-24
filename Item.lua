-- BagSmuggler: item buttons (live secure container buttons + offline display buttons)

local _, ns = ...
local C = ns.C
local UI = ns.UI
local MEDIA = UI.media

local Item = {}
ns.Item = Item

local live = {}      -- [bag*1000+slot] = button
local parents = {}   -- [bag] = frame carrying the bag id
local liveCount, offlineCount = 0, 0
local INSET = 3

local buttonType
local function ButtonType()
    if buttonType == nil then
        local ok, f = pcall(CreateFrame, "ItemButton", nil, UIParent)
        if ok and f then f:Hide() end
        buttonType = ok and "ItemButton" or "Button"
    end
    return buttonType
end

---------------------------------------------------------------------------
-- Look
---------------------------------------------------------------------------
local function Font(fs, size, flags)
    if fs then fs:SetFont(UI.FONT, size, flags or "OUTLINE") end
end

function Item:Decorate(b)
    local name = b:GetName()
    b.wkIcon = b.icon or _G[name .. "IconTexture"]
    b.wkCount = b.Count or _G[name .. "Count"]
    b.wkCooldown = b.Cooldown or _G[name .. "Cooldown"]

    local bg = b:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetAllPoints()
    b.wkBg = bg

    -- slot cell from the default bag art (Default Bags skin); drawn a little
    -- larger than the button so neighbouring cells join up like the real bag
    local cell = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    local CELL = UI.bag.CELL
    cell:SetTexture(UI.bag.PACK)
    cell:SetTexCoord(CELL[1] / 256, CELL[3] / 256, CELL[2] / 256, CELL[4] / 256)
    cell:SetPoint("CENTER")
    cell:Hide()
    b.wkCell = cell

    local tint = b:CreateTexture(nil, "BACKGROUND", nil, -6)
    tint:SetTexture(MEDIA .. "Slot")
    tint:SetAllPoints()
    tint:Hide()
    b.wkTint = tint

    if b.wkIcon then
        b.wkIcon:ClearAllPoints()
        b.wkIcon:SetPoint("TOPLEFT", INSET, -INSET)
        b.wkIcon:SetPoint("BOTTOMRIGHT", -INSET, INSET)
        b.wkIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        if b.CreateMaskTexture and b.wkIcon.AddMaskTexture then
            pcall(function()
                local mask = b:CreateMaskTexture()
                mask:SetTexture(MEDIA .. "SlotMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                mask:SetPoint("TOPLEFT", b.wkIcon, "TOPLEFT")
                mask:SetPoint("BOTTOMRIGHT", b.wkIcon, "BOTTOMRIGHT")
                b.wkIcon:AddMaskTexture(mask)
                b.wkMask = mask
                b.wkMasked = true
            end)
        end
    end

    local border = b:CreateTexture(nil, "OVERLAY", nil, 6)
    border:SetTexture(MEDIA .. "SlotBorder")
    border:SetAllPoints()
    b.wkBorder = border

    if b.wkCount then
        Font(b.wkCount, 12)
        b.wkCount:ClearAllPoints()
        b.wkCount:SetPoint("BOTTOMRIGHT", -4, 4)
    end

    local lvl = b:CreateFontString(nil, "OVERLAY")
    Font(lvl, 10)
    lvl:SetPoint("TOPLEFT", 4, -4)
    b.wkLevel = lvl

    local junk = b:CreateTexture(nil, "OVERLAY", nil, 7)
    junk:SetTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up")
    junk:SetPoint("TOPLEFT", 2, -2)
    b.wkJunk = junk

    local glow = b:CreateTexture(nil, "OVERLAY", nil, 5)
    glow:SetTexture(MEDIA .. "Glow")
    glow:SetPoint("TOPLEFT", -2, 2)
    glow:SetPoint("BOTTOMRIGHT", 2, -2)
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 0.82, 0.3)
    local ag = glow:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(1)
    a:SetToAlpha(0.2)
    a:SetDuration(0.9)
    b.wkNew, b.wkNewAnim = glow, ag

    local free = b:CreateFontString(nil, "OVERLAY")
    Font(free, 14, "")
    free:SetTextColor(0.5, 0.52, 0.58)
    free:SetPoint("CENTER", 0, 3)
    b.wkFree = free
    local freeLabel = b:CreateFontString(nil, "OVERLAY")
    Font(freeLabel, 8, "")
    freeLabel:SetTextColor(0.42, 0.44, 0.5)
    freeLabel:SetPoint("TOP", free, "BOTTOM", 0, -1)
    freeLabel:SetText("FREE")
    b.wkFreeLabel = freeLabel

    local up = b:CreateTexture(nil, "OVERLAY", nil, 7)
    up:SetTexture(MEDIA .. "Upgrade")
    up:SetPoint("TOPRIGHT", -2, -2)
    up:Hide()
    b.wkUp = up

    local boe = b:CreateFontString(nil, "OVERLAY")
    Font(boe, 9)
    boe:SetPoint("BOTTOMLEFT", 4, 4)
    boe:SetText("BoE")
    boe:SetTextColor(0.45, 0.85, 1)
    boe:Hide()
    b.wkBoE = boe

    local cd = b.wkCooldown
    if cd then
        cd:ClearAllPoints()
        cd:SetPoint("TOPLEFT", INSET, -INSET)
        cd:SetPoint("BOTTOMRIGHT", -INSET, INSET)
        if cd.SetSwipeTexture then pcall(cd.SetSwipeTexture, cd, MEDIA .. "SlotMask") end
        if cd.SetCountdownFont then
            pcall(cd.SetCountdownFont, cd, "NumberFontNormalSmall")
        else
            for _, r in ipairs({ cd:GetRegions() }) do
                if r.GetObjectType and r:GetObjectType() == "FontString" then
                    pcall(r.SetFont, r, UI.FONT, 11, "OUTLINE")
                end
            end
        end
    end
end

local function StyleModern(b, size, sk)
    local normal = b:GetNormalTexture()
    if normal then normal:SetAlpha(0) end
    local pushed = b:GetPushedTexture()
    if pushed then
        pushed:SetTexture(MEDIA .. "Slot")
        pushed:SetVertexColor(0, 0, 0, 0.35)
        pushed:ClearAllPoints()
        pushed:SetAllPoints()
    end
    local hl = b:GetHighlightTexture()
    if hl then
        hl:SetTexture(MEDIA .. "Slot")
        hl:SetVertexColor(1, 1, 1, 0.12)
        hl:SetBlendMode("ADD")
        hl:ClearAllPoints()
        hl:SetAllPoints()
    end
    b.wkBg:SetTexture(MEDIA .. "Slot")
    b.wkBg:SetVertexColor(sk.slot[1], sk.slot[2], sk.slot[3], sk.slot[4])
    if b.wkIcon then
        b.wkIcon:ClearAllPoints()
        b.wkIcon:SetPoint("TOPLEFT", INSET, -INSET)
        b.wkIcon:SetPoint("BOTTOMRIGHT", -INSET, INSET)
        b.wkIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        if b.wkMask and not b.wkMasked then
            pcall(b.wkIcon.AddMaskTexture, b.wkIcon, b.wkMask)
            b.wkMasked = true
        end
    end
    b.wkBorder:SetTexture(MEDIA .. "SlotBorder")
    b.wkBorder:SetBlendMode("BLEND")
    b.wkBorder:ClearAllPoints()
    b.wkBorder:SetAllPoints()
    b.wkNew:SetTexture(MEDIA .. "Glow")
    b.wkNew:ClearAllPoints()
    b.wkNew:SetPoint("TOPLEFT", -2, 2)
    b.wkNew:SetPoint("BOTTOMRIGHT", 2, -2)
    if b.wkCount then
        Font(b.wkCount, 12)
        b.wkCount:ClearAllPoints()
        b.wkCount:SetPoint("BOTTOMRIGHT", -4, 4)
    end
    b.wkFree:SetTextColor(0.5, 0.52, 0.58)
    b.wkFree:ClearAllPoints()
    b.wkFree:SetPoint("CENTER", 0, 3)
    local cd = b.wkCooldown
    if cd then
        cd:ClearAllPoints()
        cd:SetPoint("TOPLEFT", INSET, -INSET)
        cd:SetPoint("BOTTOMRIGHT", -INSET, INSET)
        if cd.SetSwipeTexture then pcall(cd.SetSwipeTexture, cd, MEDIA .. "SlotMask") end
    end
end

local function StyleBlizzard(b, size)
    local ratio = size / 37
    local normal = b:GetNormalTexture()
    if normal then
        normal:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        normal:ClearAllPoints()
        normal:SetPoint("CENTER", 0, -1 * ratio)
        normal:SetSize(64 * ratio, 64 * ratio)
        normal:SetVertexColor(1, 1, 1, 1)
        normal:SetAlpha(1)
    end
    local pushed = b:GetPushedTexture()
    if pushed then
        pushed:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
        pushed:SetVertexColor(1, 1, 1, 1)
        pushed:ClearAllPoints()
        pushed:SetAllPoints()
    end
    local hl = b:GetHighlightTexture()
    if hl then
        hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        hl:SetVertexColor(1, 1, 1, 1)
        hl:SetBlendMode("ADD")
        hl:ClearAllPoints()
        hl:SetAllPoints()
    end
    b.wkBg:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
    b.wkBg:SetVertexColor(1, 1, 1, 1)
    if b.wkIcon then
        if b.wkMask and b.wkMasked then
            pcall(b.wkIcon.RemoveMaskTexture, b.wkIcon, b.wkMask)
            b.wkMasked = false
        end
        b.wkIcon:ClearAllPoints()
        b.wkIcon:SetAllPoints()
        b.wkIcon:SetTexCoord(0, 1, 0, 1)
    end
    -- classic quality glow
    b.wkBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    b.wkBorder:SetBlendMode("ADD")
    b.wkBorder:ClearAllPoints()
    b.wkBorder:SetPoint("CENTER")
    b.wkBorder:SetSize(size * 1.8, size * 1.8)
    b.wkNew:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    b.wkNew:ClearAllPoints()
    b.wkNew:SetPoint("CENTER")
    b.wkNew:SetSize(size * 1.8, size * 1.8)
    if b.wkCount then
        b.wkCount:SetFontObject(NumberFontNormal)
        b.wkCount:ClearAllPoints()
        b.wkCount:SetPoint("BOTTOMRIGHT", -5, 2)
    end
    b.wkFree:SetTextColor(0.85, 0.85, 0.85)
    b.wkFree:ClearAllPoints()
    b.wkFree:SetPoint("CENTER", 0, 0)
    local cd = b.wkCooldown
    if cd then
        cd:ClearAllPoints()
        cd:SetAllPoints()
        if cd.SetSwipeTexture then pcall(cd.SetSwipeTexture, cd, "Interface\\Buttons\\WHITE8x8") end
        if cd.SetSwipeColor then pcall(cd.SetSwipeColor, cd, 0, 0, 0, 0.8) end
    end
end

function Item:Skin(b)
    if b.wkSkinVersion == ns.skinVersion then return end
    b.wkSkinVersion = ns.skinVersion
    local size = ns.db.settings.iconSize
    local sk = UI:Skin()
    b.wkBlizz = sk.blizz and true or false
    if b.wkBlizz then StyleBlizzard(b, size) else StyleModern(b, size, sk) end
    if sk.bag then
        -- one cell per grid step so neighbouring cells join up seamlessly
        local step = size + ns.db.settings.spacing
        b.wkCell:SetSize(step, step)
        b.wkCell:Show()
        b.wkBg:Hide()
    else
        b.wkCell:Hide()
        b.wkBg:Show()
    end
    local small = math.max(10, size * 0.36)
    b.wkJunk:SetSize(small, small)
    b.wkUp:SetSize(math.max(10, size * 0.38), math.max(10, size * 0.38))
end

local NEUTRAL = { 1, 1, 1, 0.07 }

local function SetBorder(b, r, g, bl, a)
    b.wkBorder:SetVertexColor(r, g, bl, a or 1)
end

local function HideBlizzardExtras(b)
    if b.IconBorder then b.IconBorder:Hide() end
    if b.IconOverlay then b.IconOverlay:Hide() end
    if b.JunkIcon then b.JunkIcon:Hide() end
    if b.NewItemTexture then b.NewItemTexture:Hide() end
    if b.BattlepayItemTexture then b.BattlepayItemTexture:Hide() end
    if b.flash then b.flash:Hide() end
end

-- Applies everything common to live and offline buttons
function Item:Paint(b, e)
    local s = ns.db.settings
    self:Skin(b)
    b.wkEntry = e
    HideBlizzardExtras(b)
    b.wkFree:Hide()
    b.wkFreeLabel:Hide()

    SetItemButtonTexture(b, e.icon)
    SetItemButtonCount(b, e.displayCount or e.count)
    SetItemButtonDesaturated(b, e.locked)

    local q = e.quality
    local qc = q and ITEM_QUALITY_COLORS[q]
    local r, g, bl
    if e.cat == "quest" and s.qualityBorders then
        r, g, bl = 1, 0.82, 0
    elseif s.qualityBorders and q and q >= 2 and qc then
        r, g, bl = qc.r, qc.g, qc.b
    end
    if b.wkBlizz then
        b.wkTint:Hide()
        if r then
            SetBorder(b, r, g, bl, 0.85)
            b.wkBorder:Show()
        else
            b.wkBorder:Hide()
        end
    elseif r then
        b.wkBorder:Show()
        SetBorder(b, r, g, bl, 0.95)
        b.wkTint:SetVertexColor(r, g, bl, 0.10)
        b.wkTint:Show()
    else
        b.wkBorder:Show()
        SetBorder(b, NEUTRAL[1], NEUTRAL[2], NEUTRAL[3], NEUTRAL[4])
        b.wkTint:Hide()
    end

    if s.showItemLevel and e.isGear and e.ilvl and e.ilvl > 1 and e.cat ~= "junk" then
        local c = qc or ITEM_QUALITY_COLORS[1]
        b.wkLevel:SetText(e.ilvl)
        b.wkLevel:SetTextColor(c.r, c.g, c.b)
        b.wkLevel:Show()
    else
        b.wkLevel:Hide()
    end

    b.wkJunk:SetShown(e.cat == "junk")
    b.wkUp:SetShown(s.showUpgrades and e.isUpgrade and true or false)
    b.wkBoE:SetShown(s.showBoE and e.isBoE and true or false)

    if e.isNew and s.showNewGlow then
        b.wkNew:Show()
        if not b.wkNewAnim:IsPlaying() then b.wkNewAnim:Play() end
    else
        b.wkNewAnim:Stop()
        b.wkNew:Hide()
    end
end

---------------------------------------------------------------------------
-- Live buttons
---------------------------------------------------------------------------
function Item:GetBagParent(bag, window)
    local p = parents[bag]
    if not p then
        p = CreateFrame("Frame", nil, window.content)
        p:SetAllPoints(window.content)
        p:SetID(bag)
        parents[bag] = p
    end
    return p
end

function Item:GetLive(bag, slot, window)
    local key = bag * 1000 + slot
    local b = live[key]
    if not b then
        liveCount = liveCount + 1
        b = CreateFrame(ButtonType(), "BagSmugglerItem" .. liveCount, self:GetBagParent(bag, window), "ContainerFrameItemButtonTemplate")
        b:SetID(slot)
        if b.SetBagID then b:SetBagID(bag) end
        b.bagID = bag
        b.wkBag, b.wkSlot, b.wkLive = bag, slot, true
        self:Decorate(b)
        b:HookScript("OnClick", Item.OnClick)
        live[key] = b
    end
    return b
end

function Item.OnClick(b, button)
    if button == "RightButton" and IsAltKeyDown() then
        local e = b.wkEntry
        if e and e.id then ns.Junk:Toggle(e.id, e.quality, e.link) end
    end
end

function Item:UpdateLive(b, e)
    if e.isFree then
        self:Skin(b)
        b.wkEntry = e
        HideBlizzardExtras(b)
        SetItemButtonTexture(b, nil)
        SetItemButtonCount(b, 0)
        SetItemButtonDesaturated(b, false)
        SetBorder(b, 1, 1, 1, 0.05)
        b.wkBorder:SetShown(not b.wkBlizz)
        b.wkTint:Hide()
        b.wkLevel:Hide()
        b.wkJunk:Hide()
        b.wkUp:Hide()
        b.wkBoE:Hide()
        b.wkNewAnim:Stop()
        b.wkNew:Hide()
        b.wkFree:SetText(e.freeCount or "")
        b.wkFree:SetShown(not e.isEmpty)
        b.wkFreeLabel:SetShown(not e.isEmpty and not b.wkBlizz and ns.db.settings.iconSize >= 32)
        if b.wkCooldown then CooldownFrame_Set(b.wkCooldown, 0, 0, 0) end
        return
    end
    self:Paint(b, e)
    self:UpdateCooldown(b)
end

function Item:UpdateCooldown(b)
    local cd = b.wkCooldown
    if not cd or not b.wkLive then return end
    local e = b.wkEntry
    if not e or e.isFree then
        CooldownFrame_Set(cd, 0, 0, 0)
        return
    end
    local start, duration, enable = C.GetContainerItemCooldown(b.wkBag, b.wkSlot)
    CooldownFrame_Set(cd, start or 0, duration or 0, enable or 0)
end

function Item:UpdateAllCooldowns()
    for _, b in pairs(live) do
        if b:IsVisible() then self:UpdateCooldown(b) end
    end
end

function Item:UpdateLock(bag, slot)
    local b = live[bag * 1000 + slot]
    if b and b:IsVisible() and b.wkEntry and not b.wkEntry.isFree then
        local info = C.GetContainerItemInfo(bag, slot)
        SetItemButtonDesaturated(b, info and info.isLocked)
    end
end

---------------------------------------------------------------------------
-- Offline buttons (other characters / bank away from banker)
---------------------------------------------------------------------------
local function OfflineEnter(b)
    local e = b.wkEntry
    if not e or not e.link then return end
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    pcall(GameTooltip.SetHyperlink, GameTooltip, e.link)
    GameTooltip:Show()
end

local function OfflineClick(b)
    local e = b.wkEntry
    if e and e.link and IsModifiedClick() then
        HandleModifiedItemClick(e.link)
    end
end

function Item:GetOffline(window, index)
    local pool = window.offline
    local b = pool[index]
    if not b then
        offlineCount = offlineCount + 1
        b = CreateFrame(ButtonType(), "BagSmugglerOffline" .. offlineCount, window.content, "ItemButtonTemplate")
        b:RegisterForClicks("AnyUp")
        self:Decorate(b)
        b:SetScript("OnEnter", OfflineEnter)
        b:SetScript("OnLeave", GameTooltip_Hide)
        b:SetScript("OnClick", OfflineClick)
        pool[index] = b
    end
    return b
end

function Item:UpdateOffline(b, e)
    e.locked = false
    self:Paint(b, e)
    if b.wkCooldown then b.wkCooldown:Hide() end
end
