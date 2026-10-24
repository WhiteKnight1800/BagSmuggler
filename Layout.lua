-- BagSmuggler: gathering items, category layout and smart search

local _, ns = ...
local C = ns.C
local UI = ns.UI
local Window = ns.Window
local MEDIA = UI.media

local SECTION_GAP = 14
local ROW_GAP = 10
local TITLE_H = 20
---------------------------------------------------------------------------
-- Gathering entries
---------------------------------------------------------------------------
function Window:CollectLive()
    local entries = {}
    local free, special, total = 0, 0, 0
    local firstFree
    local list = self.isBank and ns:GetBankBagList() or ns:GetBagList()
    for _, bag in ipairs(list) do
        local num = ns.SafeNumSlots(bag)
        if num > 0 then
            local nfree, family = C.GetContainerNumFreeSlots(bag)
            nfree, family = nfree or 0, family or 0
            if bag == ns.KEYRING then family = -1 end
            if family == 0 then
                free = free + nfree
                total = total + num
            elseif bag ~= ns.KEYRING then
                special = special + nfree
            end
            for slot = 1, num do
                local info = C.GetContainerItemInfo(bag, slot)
                if info and info.iconFileID then
                    entries[#entries + 1] = ns.Categories:MakeLiveEntry(bag, slot, info)
                elseif family == 0 and not firstFree then
                    firstFree = { bag = bag, slot = slot, isFree = true }
                end
            end
        end
    end
    if firstFree then firstFree.freeCount = free end
    return entries, { free = free, special = special, total = total, first = firstFree }
end

function Window:CollectOffline()
    local entries = {}
    local data = self:GetOwnerData()
    local items = data and (self.isBank and data.bank or data.bags) or {}
    for i, stored in ipairs(items) do
        if stored[1] then
            entries[#entries + 1] = ns.Categories:MakeOfflineEntry(stored, i)
        end
    end
    return entries, { offline = true, count = #entries, noBank = self.isBank and data and not data.hasBank }
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------
local function HeaderEnter(self)
    if not self.catKey or self.catKey == "empty" then return end
    self.name:SetTextColor(1, 1, 1)
    if UI:IsBlizz() then self.chev:SetAlpha(1) end
    if not self.collapsed then self.chev:SetAlpha(0.8) end
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetText(self.collapsed and "Click to expand" or "Click to collapse", 1, 1, 1)
    GameTooltip:Show()
end

local function HeaderLeave(self)
    self:PaintName()
    if not self.collapsed and not UI:IsBlizz() then self.chev:SetAlpha(0) end
    if UI:IsBlizz() then self.chev:SetAlpha(0.8) end
    GameTooltip_Hide()
end

local function HeaderClick(self)
    local key = self.catKey
    if not key or key == "empty" then return end
    ns.db.collapsed[key] = (not ns.db.collapsed[key]) or nil
    ns:RefreshAll()
end

-- Section header: [bar] NAME  12  value  >  --------
local HeaderMixin = {}

function HeaderMixin:PaintName()
    if UI:IsBlizz() then
        self.name:SetTextColor(1, 0.82, 0)
    else
        local c = UI.textColor
        self.name:SetTextColor(c[1], c[2], c[3])
    end
end

function HeaderMixin:SetData(cat, count, extra, collapsed, isFree)
    self.catKey = cat.key
    self.collapsed = collapsed
    local c = cat.color
    local blizz = UI:IsBlizz()
    self.bar:SetVertexColor(c[1], c[2], c[3], 1)
    self.bar:SetShown(not blizz)
    if blizz then
        self.name:SetFont(UI.FONT, 12, "")
        self.count:SetFont(UI.FONT, 11, "")
        self.extra:SetFont(UI.FONT, 11, "")
        self.name:SetText(cat.name)
        self.count:SetTextColor(0.8, 0.8, 0.8)
        self.extra:SetTextColor(0.8, 0.8, 0.8)
        self.name:ClearAllPoints()
        self.name:SetPoint("LEFT", 0, 0)
        self.chev:SetVertexColor(1, 0.82, 0)
    else
        self.name:SetFont(UI.FONT, 10, "")
        self.count:SetFont(UI.FONT, 10, "")
        self.extra:SetFont(UI.FONT, 10, "")
        self.name:SetText(cat.name:upper())
        local m = UI.mutedColor
        self.count:SetTextColor(m[1], m[2], m[3])
        self.extra:SetTextColor(m[1], m[2], m[3])
        self.name:ClearAllPoints()
        self.name:SetPoint("LEFT", self.bar, "RIGHT", 6, 0)
        self.chev:SetVertexColor(0.7, 0.72, 0.78)
    end
    self:PaintName()
    self.count:SetText(isFree and "" or count)
    self.extra:SetText(extra or "")
    self.chev:SetTexture(MEDIA .. (collapsed and "ChevronRight" or "ChevronDown"))
    self.chev:SetAlpha((collapsed or blizz) and 0.8 or 0)
    self.chev:SetShown(not isFree)
end

function HeaderMixin:ContentWidth()
    local w = (UI:IsBlizz() and 0 or 9) + self.name:GetStringWidth() + 5 + self.count:GetStringWidth()
    if (self.extra:GetText() or "") ~= "" then w = w + 6 + self.extra:GetStringWidth() end
    return w + 16
end

function Window:GetHeader(i)
    local h = self.headers[i]
    if not h then
        h = CreateFrame("Button", nil, self.content)
        for k, v in pairs(HeaderMixin) do h[k] = v end
        h:SetHeight(TITLE_H - 6)

        local bar = h:CreateTexture(nil, "ARTWORK")
        bar:SetTexture(MEDIA .. "Pill")
        bar:SetSize(3, 10)
        bar:SetPoint("LEFT", 0, 0)
        h.bar = bar

        h.name = UI:Text(h, 10, "")
        h.name:SetPoint("LEFT", bar, "RIGHT", 6, 0)
        h.count = UI:Text(h, 10, "", UI.mutedColor)
        h.count:SetPoint("LEFT", h.name, "RIGHT", 5, 0)
        h.extra = UI:Text(h, 10, "", UI.mutedColor)
        h.extra:SetPoint("LEFT", h.count, "RIGHT", 6, 0)

        local chev = h:CreateTexture(nil, "ARTWORK")
        chev:SetSize(10, 10)
        chev:SetVertexColor(0.7, 0.72, 0.78)
        h.chev = chev

        local line = UI:Divider(h, 0.06)
        line:SetPoint("RIGHT", h, "RIGHT", 0, 0)
        h.line = line

        h:SetScript("OnEnter", HeaderEnter)
        h:SetScript("OnLeave", HeaderLeave)
        h:SetScript("OnClick", HeaderClick)
        self.headers[i] = h
    end
    return h
end

-- Places the chevron and divider once the header's width is known
function HeaderMixin:Arrange()
    local anchor = (self.extra:GetText() or "") ~= "" and self.extra or self.count
    self.chev:ClearAllPoints()
    self.chev:SetPoint("LEFT", anchor, "RIGHT", 4, 0)
    self.line:ClearAllPoints()
    self.line:SetPoint("LEFT", self.chev, "RIGHT", 6, 0)
    self.line:SetPoint("RIGHT", self, "RIGHT", 0, 0)
    self.line:SetShown(self:GetWidth() - self:ContentWidth() > 12)
end

-- Combine identical items into one tile showing the total.
-- The clickable stack is the smallest unlocked one, so using it eats partial stacks first.
local function Better(a, b)
    if (a.selfLocked and true or false) ~= (b.selfLocked and true or false) then
        return not a.selfLocked
    end
    return a.count < b.count
end

local function MergeStacks(list)
    local out, byKey = {}, {}
    for _, e in ipairs(list) do
        e.selfLocked = e.locked
        local key = e.isGear and e.link or e.id
        local m = key and byKey[key]
        if m then
            local total, stacks = m.displayCount + e.count, m.stacks + 1
            local isNew = m.isNew or e.isNew
            local rep = Better(e, m) and e or m
            rep.displayCount, rep.stacks, rep.isNew = total, stacks, isNew
            rep.locked = rep.selfLocked
            if rep ~= m then
                out[m.index] = rep
                rep.index = m.index
                byKey[key] = rep
            end
        else
            e.displayCount = e.count
            e.stacks = 1
            out[#out + 1] = e
            e.index = #out
            if key then byKey[key] = e end
        end
    end
    return out
end

local function SellValue(items)
    local total = 0
    for _, e in ipairs(items) do
        if e.link and not e.noValue then
            local price = select(11, ns.GetItemInfo(e.link))
            if price then total = total + price * (e.displayCount or e.count or 1) end
        end
    end
    return total
end

-- Item buttons may not be moved, shown or hidden during combat. While in
-- combat we only repaint the buttons already on screen (from their own slot)
-- and do the full layout as soon as combat ends.
local function Refill(window, dstBag, dstSlot, itemID)
    if CursorHasItem() then return end
    local list = window.isBank and ns:GetBankBagList() or ns:GetBagList()
    for _, bag in ipairs(list) do
        for slot = 1, ns.SafeNumSlots(bag) do
            if not (bag == dstBag and slot == dstSlot) then
                local info = C.GetContainerItemInfo(bag, slot)
                if info and info.itemID == itemID and not info.isLocked then
                    C.PickupContainerItem(bag, slot)
                    C.PickupContainerItem(dstBag, dstSlot)
                    if CursorHasItem() then ClearCursor() end
                    return
                end
            end
        end
    end
end

function Window:CombatRefresh()
    self.needsLayout = true
    if not self.frame:IsShown() then return end
    local s = ns.db.settings
    local totals = {}
    if s.mergeStacks then
        local list = self.isBank and ns:GetBankBagList() or ns:GetBagList()
        for _, bag in ipairs(list) do
            for slot = 1, ns.SafeNumSlots(bag) do
                local info = C.GetContainerItemInfo(bag, slot)
                if info and info.itemID then
                    totals[info.itemID] = (totals[info.itemID] or 0) + (info.stackCount or 1)
                end
            end
        end
    end
    for b in pairs(self.shown) do
        local old = b.wkEntry
        if b.wkLive and not (old and old.isFree and not old.isEmpty) then
            local info = C.GetContainerItemInfo(b.wkBag, b.wkSlot)
            if info and info.iconFileID then
                local e = ns.Categories:MakeLiveEntry(b.wkBag, b.wkSlot, info)
                if old and old.id == e.id then
                    e.isUpgrade, e.isBoE = old.isUpgrade, old.isBoE
                end
                if s.mergeStacks and e.id and not e.isGear then
                    e.displayCount = totals[e.id] or e.count
                end
                ns.Item:UpdateLive(b, e)
            else
                ns.Item:UpdateLive(b, { bag = b.wkBag, slot = b.wkSlot, isFree = true, isEmpty = true })
                -- a merged tile ran dry: pull another stack of the same item into its slot
                if old and old.id and (totals[old.id] or 0) > 0 then
                    local bag, slot, id = b.wkBag, b.wkSlot, old.id
                    C_Timer.After(0.1, function() Refill(self, bag, slot, id) end)
                end
            end
        end
    end
    self:UpdateFooter()
    self:ApplySearch()
end

function Window:Update(force)
    if not self.frame:IsShown() and not (force and self:IsLive()) then return end
    if self:IsLive() and InCombatLockdown() then
        return self:CombatRefresh()
    end
    self.needsLayout = nil
    local s = ns.db.settings
    local collapsed = ns.db.collapsed
    local size, gap = s.iconSize, s.spacing
    local cols = self.isBank and s.bankColumns or s.columns
    local step = size + gap
    local isLive = self:IsLive()
    local isMine = self.owner == nil

    local entries, stats
    if isLive then entries, stats = self:CollectLive() else entries, stats = self:CollectOffline() end
    self.stats = stats

    -- Gear flags (upgrades only make sense for the character you're playing)
    if isMine then ns.Gear:Refresh() end
    for _, e in ipairs(entries) do
        if e.isGear then
            e.isUpgrade = isMine and ns.Gear:IsUpgrade(e) or false
            e.isBoE = ns.Gear:IsBoE(e)
        end
    end

    -- Group by category
    local groups = {}
    for _, e in ipairs(entries) do
        local g = groups[e.cat]
        if not g then g = {}; groups[e.cat] = g end
        g[#g + 1] = e
    end
    local sorter = ns.Categories:GetSorter(s.sortMode)
    local sections = {}
    for _, c in ipairs(ns.Categories.list) do
        local g = groups[c.key]
        if g and #g > 0 then
            local itemCount = #g
            if s.mergeStacks then g = MergeStacks(g) end
            table.sort(g, sorter)
            sections[#sections + 1] = {
                cat = c, items = g, count = itemCount,
                collapsed = collapsed[c.key] and true or false,
                value = (c.key == "junk") and SellValue(g) or nil,
            }
        end
    end
    if stats.first then
        sections[#sections + 1] = { cat = ns.Categories.byKey.empty, items = { stats.first }, isFree = true, count = 1 }
    end

    -- Place sections (packed left to right, wrapping into rows)
    local maxW = cols * step - gap
    local x, y, rowH = 0, 0, 0
    local nowShown = {}
    local offlineIndex = 0

    for i, sec in ipairs(sections) do
        local c = sec.cat
        local h = self:GetHeader(i)
        local extra = (sec.value and sec.value > 0) and GetCoinTextureString(sec.value) or nil
        h:SetData(c, sec.count, extra, sec.collapsed, sec.isFree)
        local headerW = h:ContentWidth()

        local n = sec.collapsed and 0 or #sec.items
        local secW, secH
        if n == 0 then
            local slots = math.max(1, math.ceil((headerW + 4) / step))
            secW = math.min(maxW, slots * step - gap)
            secH = TITLE_H
        else
            local secCols = math.min(n, cols)
            local secRows = math.ceil(n / cols)
            secW = secCols * step - gap
            secH = TITLE_H + secRows * step - gap
            -- give the header room when the section is narrower than its text
            local need = headerW
            if need > secW + SECTION_GAP and secCols < cols then
                local extra = math.min(cols, math.ceil((need + gap) / step)) * step - gap
                secW = math.min(maxW, math.max(secW, extra))
            end
        end

        if x > 0 and (not s.compactSections or x + SECTION_GAP + secW > maxW) then
            y = y + rowH + ROW_GAP
            x, rowH = 0, 0
        end
        local sx = x > 0 and (x + SECTION_GAP) or 0

        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", self.content, "TOPLEFT", sx, -y)
        h:SetWidth(secW)
        h:Show()
        h:Arrange()

        for j = 1, n do
            local e = sec.items[j]
            local col = (j - 1) % cols
            local row = math.floor((j - 1) / cols)
            local b
            if e.bag then
                b = ns.Item:GetLive(e.bag, e.slot, self)
                ns.Item:UpdateLive(b, e)
            else
                offlineIndex = offlineIndex + 1
                b = ns.Item:GetOffline(self, offlineIndex)
                ns.Item:UpdateOffline(b, e)
            end
            b:SetSize(size, size)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self.content, "TOPLEFT", sx + col * step, -(y + TITLE_H + row * step))
            b:Show()
            nowShown[b] = true
        end

        x = sx + secW
        rowH = math.max(rowH, secH)
    end

    -- Hide anything not placed this pass
    for b in pairs(self.shown) do
        if not nowShown[b] then
            b:Hide()
            b.wkEntry = nil
        end
    end
    self.shown = nowShown
    for i = #sections + 1, #self.headers do self.headers[i]:Hide() end

    local contentH = y + rowH
    self.emptyText:SetShown(#sections == 0)
    if #sections == 0 then
        self.emptyText:SetText(stats.noBank and "Visit a banker once on this character to record the bank." or "Nothing here.")
        contentH = 20
    end

    local W = self:Metrics()
    local width = math.max(maxW, W.MIN_W - W.PAD * 2)
    self.content:ClearAllPoints()
    self.content:SetPoint("TOPLEFT", W.PAD, -W.HEADER_H)
    self.content:SetSize(width, contentH)
    self.frame:SetSize(width + W.PAD * 2, W.HEADER_H + contentH + W.FOOTER_H + self:FooterRowHeight())

    self:UpdateTitle()
    self:UpdateFooter()
    self:ApplySearch()
end


---------------------------------------------------------------------------
-- Search
---------------------------------------------------------------------------
-- Smart filters: every word must match. Examples:
--   boe  bop  upgrade  new  junk  gear  epic  blue  ilvl>100  i<60  "mana potion"
local QUALITY_WORDS = {
    poor = 0, grey = 0, gray = 0, common = 1, white = 1, uncommon = 2, green = 2,
    rare = 3, blue = 3, epic = 4, purple = 4, legendary = 5, orange = 5,
}

local FLAGS = {
    boe = function(e) return e.isBoE end,
    bop = function(e) return e.bound == true end,
    bound = function(e) return e.bound == true end,
    soulbound = function(e) return e.bound == true end,
    upgrade = function(e) return e.isUpgrade end,
    upgrades = function(e) return e.isUpgrade end,
    new = function(e) return e.isNew end,
    junk = function(e) return e.cat == "junk" end,
    gear = function(e) return e.isGear end,
}

local function Compare(value, op, n)
    if op == ">" then return value > n
    elseif op == ">=" then return value >= n
    elseif op == "<" then return value < n
    elseif op == "<=" then return value <= n
    end
    return value == n
end

local function TextMatch(e, text)
    if e.lname:find(text, 1, true) then return true end
    if e.itemType:lower():find(text, 1, true) then return true end
    if e.subType:lower():find(text, 1, true) then return true end
    local c = ns.Categories.byKey[e.cat]
    return c and c.name:lower():find(text, 1, true) and true or false
end

local function TokenMatch(e, tok)
    local flag = FLAGS[tok]
    if flag then return flag(e) and true or false end
    local q = QUALITY_WORDS[tok]
    if q then return e.quality == q end
    local op, num = tok:match("^ilvl([<>=]=?)(%d+)$")
    if not op then op, num = tok:match("^i([<>=]=?)(%d+)$") end
    if op then return e.isGear and Compare(e.ilvl or 0, op, tonumber(num)) or false end
    return TextMatch(e, tok)
end

local function Tokenize(text)
    local toks = {}
    for quoted in text:gmatch('"([^"]+)"') do toks[#toks + 1] = quoted end
    text = text:gsub('"[^"]*"', " ")
    for word in text:gmatch("%S+") do toks[#toks + 1] = word end
    return toks
end

local function Matches(e, toks)
    if e.isFree then return false end
    for _, tok in ipairs(toks) do
        if not TokenMatch(e, tok) then return false end
    end
    return true
end

function Window:ApplySearch()
    local text = (self.search:GetText() or ""):lower():match("^%s*(.-)%s*$")
    local toks = text ~= "" and Tokenize(text) or nil
    for b in pairs(self.shown) do
        local e = b.wkEntry
        if not toks or #toks == 0 or not e then
            b:SetAlpha(1)
        else
            b:SetAlpha(Matches(e, toks) and 1 or 0.18)
        end
    end
end

