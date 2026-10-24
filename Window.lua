-- BagSmuggler: bag and bank windows (frame, header, search, footer, character picker)

local _, ns = ...
local UI = ns.UI
local MEDIA = UI.media

local Window = {}
Window.__index = Window
ns.Window = Window

local M = { PAD = 12, HEADER_H = 78, FOOTER_H = 40, MIN_W = 340 }
local M_BAG = { PAD = 20, HEADER_H = 86, FOOTER_H = 36, MIN_W = 340, ROW = 26 }
Window.metrics = M

-- Spacing depends on the skin: the Default Bags art has its own header and footer
function Window:Metrics()
    return UI:IsBag() and M_BAG or M
end

-- Default Bags skin puts footer buttons on their own row above the money bar
function Window:FooterRowHeight()
    if not UI:IsBag() or not self:IsLive() then return 0 end
    if self.isBank then return M_BAG.ROW end
    if ns.atMerchant and ns.Junk:GetValue() > 0 then return M_BAG.ROW end
    return 0
end

---------------------------------------------------------------------------
-- Deferred updates (coalesced to once per frame)
---------------------------------------------------------------------------
local pending = {}
local updater = CreateFrame("Frame")
updater:Hide()
updater:SetScript("OnUpdate", function(self)
    self:Hide()
    for w in pairs(pending) do
        pending[w] = nil
        -- the bag window keeps its layout current even while closed, so it is
        -- ready (and clickable) if you open it in combat
        if w.frame:IsShown() or w.alwaysLayout then w:Update(true) end
    end
end)

function Window:RequestUpdate()
    pending[self] = true
    updater:Show()
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------
function ns:CreateWindow(kind)
    local w = setmetatable({}, Window)
    w.kind = kind
    w.isBank = (kind == "bank")
    w.alwaysLayout = not w.isBank
    w.headers = {}
    w.offline = {}
    w.shown = {}

    local name = w.isBank and "BagSmugglerBankFrame" or "BagSmugglerBagFrame"
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    w.frame = f
    f.window = w
    f:SetSize(M.MIN_W, 220)
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not ns.db.settings.locked then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        w:SavePosition()
    end)
    f:SetScript("OnShow", function() w:OnShow() end)
    f:SetScript("OnHide", function() w:OnHide() end)
    f:Hide()
    tinsert(UISpecialFrames, name)

    w.panel = UI:Panel(f, 10, nil, "dialog", true)
    w.banner = UI:Banner(f, 200, true)
    w.bagArt = UI:BagFrame(f)
    w.bagArt:SetPortrait(w.isBank and "Interface\\Icons\\INV_Misc_Bag_08" or "Interface\\Buttons\\Button-Backpack-Up")

    -- accent glow line along the top edge
    local line = UI:AccentLine(f, 0.85)
    line:SetPoint("TOPLEFT", 10, -1)
    line:SetPoint("TOPRIGHT", f, "TOP", 30, -1)

    -- quick fade-in when opened
    local fade = f:CreateAnimationGroup()
    local a = fade:CreateAnimation("Alpha")
    a:SetFromAlpha(0)
    a:SetToAlpha(1)
    a:SetDuration(0.12)
    w.fade = fade

    -------------------------------------------------------------------
    -- Title row
    -------------------------------------------------------------------
    local glyph = f:CreateTexture(nil, "ARTWORK")
    glyph:SetTexture(MEDIA .. "LogoPouch")
    glyph:SetSize(22, 22)
    glyph:SetPoint("TOPLEFT", M.PAD - 3, -10)

    local title = UI:Text(f, 15, "", { 1, 1, 1 })
    title:SetPoint("LEFT", glyph, "RIGHT", 7, 0)
    title:SetText("BagSmuggler")
    w.title = title

    local subtitle = UI:Text(f, 11, "", UI.mutedColor)
    subtitle:SetPoint("LEFT", title, "RIGHT", 8, -1)
    w.subtitle = subtitle
    UI:OnStyle(function(blizz)
        glyph:SetShown(not blizz)
        title:SetShown(not blizz)
        subtitle:SetShown(not blizz)
    end)

    -- Header buttons, right to left
    local close = UI:CloseButton(f, function() f:Hide() end, true)
    w.close = close

    local gear = UI:IconButton(f, "IconGear", 15, "Settings")
    w.gearButton = gear
    gear:SetScript("OnClick", function() ns.Config:Toggle() end)

    local restack = UI:IconButton(f, "IconRestack", 15, "Restack\n|cffaaaaaaCombine partial stacks to free up slots|r")
    restack:SetPoint("RIGHT", gear, "LEFT", 0, 0)
    restack:SetScript("OnClick", function()
        if not w:IsLive() then
            ns.Print(w.isBank and "Open your bank to restack it." or "Can't restack another character's bags.")
            return
        end
        ns.Restack:Start(function() return ns:GetRestackBags(w.isBank) end)
    end)

    local sort = UI:IconButton(f, "IconSort", 15, function(tt)
        tt:AddLine("Sort", 1, 1, 1)
        tt:AddLine("By " .. ns.Categories.sortNames[ns.db.settings.sortMode], UI:Accent())
        tt:AddLine("Click to change", 0.6, 0.6, 0.6)
    end)
    sort:SetPoint("RIGHT", restack, "LEFT", 0, 0)
    sort:SetScript("OnClick", function(self)
        local s = ns.db.settings
        s.sortMode = ns.Categories:NextSortMode(s.sortMode)
        ns:RefreshAll()
        self:GetScript("OnEnter")(self)
    end)

    local chars = UI:IconButton(f, "IconChars", 15, "Characters\n|cffaaaaaaView another character's items|r")
    chars:SetPoint("RIGHT", sort, "LEFT", 0, 0)
    chars:SetScript("OnClick", function(self) w:ToggleCharMenu(self) end)
    w.charButton = chars
    w.leftIcon = chars

    if not w.isBank then
        local bank = UI:IconButton(f, "IconBank", 15, "Bank\n|cffaaaaaaView your bank from anywhere|r")
        bank:SetPoint("RIGHT", chars, "LEFT", 0, 0)
        bank:SetScript("OnClick", function()
            local o = w.owner
            ns.bank:SetOwner(o and o.realm, o and o.name)
            ns.bank:Toggle()
        end)
        w.leftIcon = bank
    end

    -------------------------------------------------------------------
    -- Search
    -------------------------------------------------------------------
    local search = CreateFrame("EditBox", nil, f)
    search:SetAutoFocus(false)
    search:SetFont(UI.FONT, 12, "")
    search:SetTextColor(1, 1, 1)
    search:SetHeight(26)
    search:SetTextInsets(28, 10, 0, 0)
    UI:Field(search)

    local mag = search:CreateTexture(nil, "OVERLAY")
    mag:SetTexture(MEDIA .. "IconSearch")
    mag:SetSize(12, 12)
    mag:SetPoint("LEFT", 10, 0)
    mag:SetVertexColor(UI.mutedColor[1], UI.mutedColor[2], UI.mutedColor[3])

    local hint = UI:Text(search, 11, "", "hint")
    hint:SetPoint("LEFT", 28, 0)
    hint:SetText("Search  -  try  boe,  upgrade,  epic,  ilvl>100")

    search:SetScript("OnTextChanged", function(self)
        hint:SetShown(self:GetText() == "" and not self:HasFocus())
        w:ApplySearch()
    end)
    search:SetScript("OnEditFocusGained", function(self)
        hint:Hide()
        self:PaintField()
        mag:SetVertexColor(UI:Accent())
    end)
    search:SetScript("OnEditFocusLost", function(self)
        hint:SetShown(self:GetText() == "")
        self:PaintField()
        mag:SetVertexColor(UI.mutedColor[1], UI.mutedColor[2], UI.mutedColor[3])
    end)
    search:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    search:SetScript("OnEnter", function(self)
        if self:HasFocus() then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Search", 1, 1, 1)
        GameTooltip:AddLine("Names, item types and categories, plus filters:", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("boe  bop  upgrade  new  junk  gear", UI:Accent())
        GameTooltip:AddLine("poor  common  green  blue  epic", UI:Accent())
        GameTooltip:AddLine("ilvl>100   ilvl<=60   i=115", UI:Accent())
        GameTooltip:AddLine("Combine words: epic boe. Use \"quotes\" for exact phrases.", 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    search:SetScript("OnLeave", GameTooltip_Hide)
    w.search = search

    -- Blizzard skin: title lives in the banner, so the icons sit beside the search box
    UI:OnStyle(function(blizz)
        gear:ClearAllPoints()
        search:ClearAllPoints()
        w.bagArt:SetShown(UI:IsBag())
        if UI:IsBag() then
            search:SetPoint("TOPLEFT", 26, -55)
            gear:SetPoint("RIGHT", f, "TOPRIGHT", -16, -65)
            search:SetPoint("RIGHT", w.leftIcon, "LEFT", -6, 0)
            search:SetHeight(20)
            return
        end
        search:SetPoint("TOPLEFT", M.PAD + (blizz and 4 or 0), -42)
        if blizz then
            gear:SetPoint("RIGHT", f, "TOPRIGHT", -M.PAD, -55)
            search:SetPoint("RIGHT", w.leftIcon, "LEFT", -6, 0)
            search:SetHeight(22)
        else
            gear:SetPoint("RIGHT", close.modern, "LEFT", 0, 0)
            search:SetPoint("TOPRIGHT", -M.PAD, -42)
            search:SetHeight(26)
        end
    end)

    -------------------------------------------------------------------
    -- Content
    -------------------------------------------------------------------
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", M.PAD, -M.HEADER_H)
    content:SetSize(1, 1)
    w.content = content

    local empty = UI:Text(content, 12, "", "muted")
    empty:SetPoint("TOPLEFT", 2, -2)
    empty:Hide()
    w.emptyText = empty

    -------------------------------------------------------------------
    -- Footer
    -------------------------------------------------------------------
    local divider = UI:Divider(f, 0.06)
    divider:SetPoint("BOTTOMLEFT", M.PAD, M.FOOTER_H - 4)
    divider:SetPoint("BOTTOMRIGHT", -M.PAD, M.FOOTER_H - 4)

    local freeText = UI:Text(f, 12, "", "text")
    freeText:SetPoint("BOTTOMLEFT", M.PAD + 1, 14)
    w.freeText = freeText

    local track = f:CreateTexture(nil, "ARTWORK")
    track:SetTexture(MEDIA .. "Pill")
    track:SetSize(64, 4)
    track:SetPoint("LEFT", freeText, "RIGHT", 9, 0)
    track:SetVertexColor(1, 1, 1, 0.08)
    local fill = f:CreateTexture(nil, "OVERLAY")
    fill:SetTexture(MEDIA .. "Pill")
    fill:SetHeight(4)
    fill:SetPoint("LEFT", track, "LEFT")
    w.capTrack, w.capFill = track, fill

    local money = CreateFrame("Button", nil, f)
    money:SetSize(160, 18)
    money:SetPoint("BOTTOMRIGHT", -M.PAD, 11)
    local moneyText = UI:Text(money, 12, "", "text")
    moneyText:SetPoint("RIGHT")
    moneyText:SetJustifyH("RIGHT")
    money.text = moneyText
    money:SetScript("OnEnter", function(self)
        local total, list = ns.Data:RealmMoney()
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        GameTooltip:AddLine(ns.realm, 1, 1, 1)
        for _, c in ipairs(list) do
            GameTooltip:AddDoubleLine("|c" .. ns.ClassHex(c.class) .. c.name .. "|r", GetCoinTextureString(c.money), 1, 1, 1, 1, 1, 1)
        end
        GameTooltip:AddLine(" ")
        local r, g, b = UI:Accent()
        GameTooltip:AddDoubleLine("Total", GetCoinTextureString(total), r, g, b, 1, 1, 1)
        GameTooltip:Show()
    end)
    money:SetScript("OnLeave", GameTooltip_Hide)
    w.money = money

    if w.isBank then
        local blizz = UI:Button(f, "Blizzard Bank", 96, 20, "Show the default bank window\n|cffaaaaaa(for swapping bank bags)|r")
        blizz:SetPoint("BOTTOMRIGHT", -M.PAD, 9)
        blizz:SetScript("OnClick", function() ns:ToggleBlizzardBank() end)
        w.blizzButton = blizz

        local buy = UI:Button(f, "Buy Slot", 70, 20, "Buy another bank bag slot")
        buy:SetPoint("RIGHT", blizz, "LEFT", -6, 0)
        buy:SetScript("OnClick", function()
            if StaticPopupDialogs and StaticPopupDialogs.CONFIRM_BUY_BANK_SLOT then
                StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
            elseif PurchaseSlot then
                PurchaseSlot()
            end
        end)
        w.buyButton = buy
    else
        local sell = UI:Button(f, "Sell Junk", 78, 20, function(tt)
            tt:AddLine("Sell junk", 1, 1, 1)
            tt:AddLine("Worth " .. GetCoinTextureString(ns.Junk:GetValue()), 0.85, 0.85, 0.85)
            tt:AddLine("Alt + Right-click an item to mark or unmark junk", 0.6, 0.6, 0.6, true)
        end)
        sell:SetPoint("LEFT", track, "RIGHT", 12, 0)
        sell:SetScript("OnClick", function() ns.Junk:Sell() end)
        w.sellButton = sell
    end

    UI:OnStyle(function()
        local bag = UI:IsBag()
        divider:SetShown(not bag)
        freeText:ClearAllPoints()
        money:ClearAllPoints()
        if bag then
            freeText:SetPoint("BOTTOMLEFT", 26, 13)
            money:SetPoint("BOTTOMRIGHT", -18, 10)
        else
            freeText:SetPoint("BOTTOMLEFT", M.PAD + 1, 14)
            money:SetPoint("BOTTOMRIGHT", -M.PAD, 11)
        end
        if w.blizzButton then
            w.blizzButton:ClearAllPoints()
            if bag then
                w.blizzButton:SetPoint("BOTTOMRIGHT", -18, 36)
            else
                w.blizzButton:SetPoint("BOTTOMRIGHT", -M.PAD, 9)
            end
        end
    end)

    w:RestorePosition()
    w:ApplySkin()
    return w
end

---------------------------------------------------------------------------
-- Show / hide
---------------------------------------------------------------------------
function Window:Toggle()
    if self.frame:IsShown() then self.frame:Hide() else self.frame:Show() end
end

function Window:Open() self.frame:Show() end
function Window:Close() self.frame:Hide() end
function Window:Show() self.frame:Show(); self:RequestUpdate() end
function Window:Hide() self.frame:Hide() end

function Window:OnShow()
    if SOUNDKIT then PlaySound(self.isBank and SOUNDKIT.IG_MAINMENU_OPEN or SOUNDKIT.IG_BACKPACK_OPEN) end
    self.fade:Play()
    self:Update()
end

function Window:OnHide()
    if SOUNDKIT then PlaySound(self.isBank and SOUNDKIT.IG_MAINMENU_CLOSE or SOUNDKIT.IG_BACKPACK_CLOSE) end
    if self.menu then self.menu:Hide() end
    self.search:ClearFocus()
    if self.isBank then
        if ns.bankOpen and not ns.closingBank and not ns.showBlizzBank then
            ns:CloseBankInteraction()
        end
    else
        if C_NewItems and C_NewItems.ClearAll then pcall(C_NewItems.ClearAll) end
    end
end

---------------------------------------------------------------------------
-- Owner (which character we're looking at)
---------------------------------------------------------------------------
function Window:SetOwner(realm, name)
    if not realm or not name or (realm == ns.realm and name == ns.player) then
        self.owner = nil
    else
        self.owner = { realm = realm, name = name }
    end
    self:RequestUpdate()
end

function Window:IsLive()
    if self.owner then return false end
    if self.isBank then return ns.bankOpen and true or false end
    return true
end

function Window:GetOwnerData()
    local o = self.owner
    return ns.Data:Get(o and o.realm, o and o.name)
end

---------------------------------------------------------------------------
-- Position & skin
---------------------------------------------------------------------------
function Window:RestorePosition()
    local f = self.frame
    f:ClearAllPoints()
    local p = ns.db.positions[self.kind]
    if p then
        f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    elseif self.isBank then
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -110)
    else
        f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -60, 110)
    end
end

function Window:SavePosition()
    local f = self.frame
    local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if self.isBank then
        local x = f:GetLeft()
        local y = f:GetTop() - UIParent:GetTop() / s
        ns.db.positions[self.kind] = { "TOPLEFT", "TOPLEFT", x, y }
    else
        local x = f:GetRight() - UIParent:GetRight() / s
        local y = f:GetBottom()
        ns.db.positions[self.kind] = { "BOTTOMRIGHT", "BOTTOMRIGHT", x, y }
    end
    self:RestorePosition()
end

function Window:ApplySkin()
    self.frame:SetScale(ns.db.settings.scale)
    self.panel:Apply()
    self.search:PaintField()
    if self.menu then self.menu.panel:Apply(0.98) end
end

---------------------------------------------------------------------------
-- Title / footer
---------------------------------------------------------------------------
function Window:UpdateTitle()
    local data = self:GetOwnerData()
    local o = self.owner
    local what = self.isBank and "Bank" or "Bags"
    local text
    if o then
        text = "|c" .. ns.ClassHex(data and data.class) .. o.name .. "|r  " .. what
    elseif self.isBank and not self:IsLive() then
        text = what .. "  |cff666a75offline|r"
    else
        text = what
    end
    self.subtitle:SetText(text)
    if UI:IsBag() then
        local t
        if o then
            t = "|c" .. ns.ClassHex(data and data.class) .. o.name .. "|r - " .. what
        elseif self.isBank then
            t = self:IsLive() and "BagSmuggler Bank" or "BagSmuggler Bank |cff999999(offline)|r"
        else
            t = "BagSmuggler"
        end
        self.bagArt.title:SetText(t)
    elseif UI:IsBlizz() then
        local banner
        if o then
            banner = o.name .. " - " .. what
        elseif self.isBank then
            banner = self:IsLive() and "BagSmuggler Bank" or "BagSmuggler Bank (offline)"
        else
            banner = "BagSmuggler"
        end
        self.banner:SetText(banner)
    end
end

function Window:UpdateFooter()
    if not self.frame:IsShown() then return end
    local stats = self.stats or {}
    local live = self:IsLive()

    local blizz = UI:IsBlizz()
    local used
    if stats.offline then
        self.freeText:SetText(("%d |cff8f939eitems|r"):format(stats.count or 0))
    else
        local total, free = stats.total or 0, stats.free or 0
        local text
        if blizz then
            text = ("%d/%d |cffaaaaaafree|r"):format(free, total)
        else
            text = ("%d |cff8f939efree|r"):format(free)
        end
        if (stats.special or 0) > 0 then
            text = text .. (" |cff777777+%d|r"):format(stats.special)
        end
        self.freeText:SetText(text)
        if not blizz then used = total > 0 and (total - free) / total or 0 end
    end

    self.capTrack:SetShown(used ~= nil)
    self.capFill:SetShown(used ~= nil and used > 0)
    if used then
        self.capFill:SetWidth(math.max(4, 64 * used))
        if used < 0.75 then
            self.capFill:SetVertexColor(0.36, 0.85, 0.48)
        elseif used < 0.9 then
            self.capFill:SetVertexColor(1, 0.72, 0.26)
        else
            self.capFill:SetVertexColor(1, 0.36, 0.36)
        end
    end
    -- Sell Junk sits after the capacity bar, or straight after the text
    if self.sellButton then
        self.sellButton:ClearAllPoints()
        if UI:IsBag() then
            self.sellButton:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 24, 36)
        elseif used then
            self.sellButton:SetPoint("LEFT", self.capTrack, "RIGHT", 12, 0)
        else
            self.sellButton:SetPoint("LEFT", self.freeText, "RIGHT", 12, 0)
        end
    end

    local data = self:GetOwnerData()
    local money = (self.owner and data and data.money) or GetMoney()
    self.money.text:SetText(GetCoinTextureString(money or 0))
    self.money:SetShown(not self.isBank)

    if self.sellButton then
        self.sellButton:SetShown(live and ns.atMerchant and ns.Junk:GetValue() > 0)
    end
    if self.blizzButton then
        self.blizzButton:SetShown(live)
    end
    if self.buyButton then
        local show = false
        if live and GetNumBankSlots then
            local _, full = GetNumBankSlots()
            show = not full
        end
        self.buyButton:SetShown(show)
    end
end

---------------------------------------------------------------------------
-- Character picker
---------------------------------------------------------------------------
function Window:ToggleCharMenu(anchor)
    local m = self.menu
    if not m then
        m = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
        m:SetFrameStrata("DIALOG")
        m:EnableMouse(true)
        m.panel = UI:Panel(m, 8, nil, "tooltip")
        m.panel:Apply(0.98)
        m.rows = {}
        local hint = UI:Text(m, 10, "", "hint")
        hint:SetPoint("BOTTOMLEFT", 10, 8)
        hint:SetText("Right-click to forget a character")
        m.hint = hint
        m:Hide()
        self.menu = m
    end
    if m:IsShown() then m:Hide() return end

    local chars = ns.Data:GetCharacters()
    local width = 210
    for i, c in ipairs(chars) do
        local r = m.rows[i]
        if not r then
            r = CreateFrame("Button", nil, m)
            r:SetHeight(22)
            r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            local hl = r:CreateTexture(nil, "BACKGROUND")
            hl:SetTexture(MEDIA .. "Slot")
            hl:SetAllPoints()
            hl:SetVertexColor(1, 1, 1, 0.06)
            hl:Hide()
            r.hl = hl
            local dot = r:CreateTexture(nil, "ARTWORK")
            dot:SetTexture(MEDIA .. "Circle")
            dot:SetSize(6, 6)
            dot:SetPoint("LEFT", 8, 0)
            r.dot = dot
            r.text = UI:Text(r, 12)
            r.text:SetPoint("LEFT", 20, 0)
            r.realm = UI:Text(r, 10, "", "hint")
            r.realm:SetPoint("RIGHT", -8, 0)
            r:SetScript("OnEnter", function(self) self.hl:Show() end)
            r:SetScript("OnLeave", function(self) self.hl:Hide() end)
            m.rows[i] = r
        end
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 22)
        r:SetPoint("RIGHT", -6, 0)
        local isOwner = (self.owner == nil and c.current) or (self.owner and self.owner.realm == c.realm and self.owner.name == c.name)
        r.text:SetText("|c" .. ns.ClassHex(c.data.class) .. c.name .. "|r")
        r.realm:SetText(c.realm)
        if isOwner then
            r.dot:SetVertexColor(UI:Accent())
        else
            r.dot:SetVertexColor(1, 1, 1, 0.15)
        end
        width = math.max(width, r.text:GetStringWidth() + r.realm:GetStringWidth() + 56)
        r:SetScript("OnClick", function(_, button)
            m:Hide()
            if button == "RightButton" then
                if not c.current then
                    ns.Data:Delete(c.realm, c.name)
                    if self.owner and self.owner.realm == c.realm and self.owner.name == c.name then self:SetOwner(nil) end
                end
            else
                self:SetOwner(c.realm, c.name)
            end
        end)
        r:Show()
    end
    for i = #chars + 1, #m.rows do m.rows[i]:Hide() end

    m:SetSize(width, 12 + #chars * 22 + 22)
    m:ClearAllPoints()
    m:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -6)
    m:Show()
end
