-- BagSmuggler: settings window (sidebar tabs: General, Look, Categories, About)

local _, ns = ...
local UI = ns.UI
local MEDIA = UI.media

local Config = {}
ns.Config = Config

local W, H = 620, 480
local SIDEBAR = 160
local PAGE_X = SIDEBAR + 20
local PAGE_W = W - PAGE_X - 22
local COL_W = math.floor((PAGE_W - 24) / 2)

local widgets = {}
local function track(w) widgets[#widgets + 1] = w; return w end
local function S() return ns.db.settings end

local function NextIn(list, current, step)
    for i, v in ipairs(list) do
        if v == current then return list[(i - 1 + step) % #list + 1] end
    end
    return list[1]
end

---------------------------------------------------------------------------
-- Page helpers
---------------------------------------------------------------------------
local function PageTitle(page, title, desc)
    local t = UI:Text(page, 16, "", "title")
    t:SetPoint("TOPLEFT", 0, -18)
    t:SetText(title)
    if desc then
        local d = UI:Text(page, 11, "", "muted")
        d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -5)
        d:SetWidth(PAGE_W)
        d:SetText(desc)
    end
end

local function Section(page, text, y, x)
    local t = UI:Text(page, 10, "", "header")
    t:SetPoint("TOPLEFT", x or 0, y)
    UI:OnStyle(function(blizz)
        t:SetFont(UI.FONT, blizz and 12 or 10, "")
        t:SetText(blizz and text or text:upper())
    end)
    local line = UI:Divider(page, 0.06)
    line:SetPoint("LEFT", t, "RIGHT", 8, 0)
    UI:OnStyle(function()
        line:SetWidth(math.max(10, PAGE_W - (x or 0) - t:GetStringWidth() - 8))
    end)
    return t
end

local function Toggle(page, label, key, x, y, width, tip)
    local t = UI:Toggle(page, label, width or COL_W,
        function() return S()[key] end,
        function(v) S()[key] = v end, tip)
    t:SetPoint("TOPLEFT", x, y)
    return track(t)
end

local function Slider(page, label, key, minV, maxV, step, x, y, fmt)
    local s = UI:Slider(page, label, COL_W, minV, maxV, step,
        function() return S()[key] end,
        function(v) S()[key] = v end, fmt)
    s:SetPoint("TOPLEFT", x, y)
    return track(s)
end

local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------
local function BuildGeneral(page)
    PageTitle(page, "General", "How BagSmuggler behaves around vendors, the bank and your tooltips.")
    Section(page, "Behaviour", -70)
    local y = -88
    Toggle(page, "Auto-sell junk at vendors", "autoSellJunk", 0, y, PAGE_W,
        "Sells grey items and anything you've marked as junk.\nAlt + Right-click an item to mark or unmark it.")
    Toggle(page, "Replace the Blizzard bank", "replaceBank", 0, y - 30, PAGE_W)
    Toggle(page, "Show alt counts on item tooltips", "tooltipCounts", 0, y - 60, PAGE_W,
        "Adds lines like \"Smuggz: Bags 5, Bank 20\" to item tooltips.")
    Toggle(page, "Merge identical stacks into one tile", "mergeStacks", 0, y - 90, PAGE_W,
        "27 Soul Shards become one tile showing 27.\nClicking uses the smallest stack first.")
    Toggle(page, "Lock window positions", "locked", 0, y - 120, PAGE_W)
    Toggle(page, "Show keyring items", "showKeyring", 0, y - 150, PAGE_W, "TBC only.")

    Section(page, "Sorting", y - 196)
    local sel = UI:Selector(page, "Sort items within categories by", PAGE_W,
        function() return ns.Categories.sortNames[S().sortMode] end,
        function()
            local order = ns.Categories.sortOrder
            S().sortMode = NextIn(order, S().sortMode, -1)
        end,
        function() S().sortMode = ns.Categories:NextSortMode(S().sortMode) end)
    sel:SetPoint("TOPLEFT", 0, y - 216)
    track(sel)
end

local function BuildLook(page)
    PageTitle(page, "Look", "Skins, accent colour, sizes and what's drawn on each item.")
    Section(page, "Style", -70)
    local skin = UI:Selector(page, "Skin", PAGE_W,
        function() return UI.skinNames[S().skin] or S().skin end,
        function() S().skin = NextIn(UI.skinOrder, S().skin, -1) end,
        function() S().skin = NextIn(UI.skinOrder, S().skin, 1) end)
    skin:SetPoint("TOPLEFT", 0, -88)
    track(skin)
    local accent = UI:Selector(page, "Accent (modern skins)", PAGE_W,
        function() return UI:AccentName() end,
        function() S().accent = UI:NextAccent(-1) end,
        function() S().accent = UI:NextAccent(1) end)
    accent:SetPoint("TOPLEFT", 0, -118)
    track(accent)

    Section(page, "Size", -160)
    local R = COL_W + 24
    Slider(page, "Scale", "scale", 0.5, 1.5, 0.05, 0, -178, pct)
    Slider(page, "Icon size", "iconSize", 26, 48, 1, R, -178)
    Slider(page, "Bag columns", "columns", 6, 20, 1, 0, -222)
    Slider(page, "Icon spacing", "spacing", 0, 10, 1, R, -222)
    Slider(page, "Bank columns", "bankColumns", 6, 24, 1, 0, -266)
    Slider(page, "Background opacity", "alpha", 0.2, 1, 0.05, R, -266, pct)

    Section(page, "On items", -318)
    Toggle(page, "Quality borders", "qualityBorders", 0, -336)
    Toggle(page, "Item level on gear", "showItemLevel", R, -336)
    Toggle(page, "Upgrade arrows", "showUpgrades", 0, -364, nil,
        "Green arrow when an item's level beats what you have equipped in that slot (and your class can use it).")
    Toggle(page, "BoE tag", "showBoE", R, -364, nil, "Marks unbound bind-on-equip gear.")
    Toggle(page, "Glow on new items", "showNewGlow", 0, -392)
    Toggle(page, "Categories side by side", "compactSections", R, -392, nil, "Off = every category gets its own row.")
end

local function BuildCategories(page)
    PageTitle(page, "Categories",
        "Switch a category off to fold its items into Miscellaneous. Click any header in your bags to collapse it.")
    Section(page, "Shown categories", -78)
    local R = COL_W + 24
    for i, key in ipairs(ns.Categories.optional) do
        local c = ns.Categories.byKey[key]
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local t = UI:Toggle(page, c.name, COL_W,
            function() return not S().disabledCats[key] end,
            function(v) S().disabledCats[key] = (not v) or nil end)
        t:SetPoint("TOPLEFT", col == 0 and 0 or R, -96 - row * 30)
        -- coloured dot matching the category header bar
        local dot = t:CreateTexture(nil, "ARTWORK")
        dot:SetTexture(MEDIA .. "Pill")
        dot:SetSize(3, 10)
        dot:SetPoint("LEFT", -9, 0)
        dot:SetVertexColor(c.color[1], c.color[2], c.color[3])
        track(t)
    end
    local expand = UI:Button(page, "Expand all collapsed", 160, 24)
    expand:SetPoint("TOPLEFT", 0, -96 - 6 * 30 - 10)
    expand:SetScript("OnClick", function()
        wipe(ns.db.collapsed)
        ns:RefreshAll()
    end)
end

local function BuildAbout(page)
    local glyph = page:CreateTexture(nil, "ARTWORK")
    glyph:SetTexture(MEDIA .. "Logo")
    glyph:SetSize(56, 56)
    glyph:SetPoint("TOPLEFT", -4, -12)

    local title = UI:Text(page, 24, "", "title")
    title:SetPoint("TOPLEFT", glyph, "TOPRIGHT", 12, 2)
    title:SetText("BagSmuggler")
    local ver = UI:Text(page, 11, "", "muted")
    ver:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 1, -3)
    ver:SetText("Version " .. ns.version .. "  -  TBC Anniversary & WoW Forever")

    Section(page, "Created by", -84)
    local author = UI:Text(page, 15, "", "text")
    author:SetPoint("TOPLEFT", 0, -104)
    author:SetText("WhiteKnight  |cff666a75/|r  Smuggz_")

    local discordLabel = UI:Text(page, 11, "", "muted")
    discordLabel:SetPoint("TOPLEFT", 0, -134)
    discordLabel:SetText("Discord")

    -- read-only box so the name can be copied with Ctrl+C
    local box = CreateFrame("EditBox", nil, page)
    box:SetSize(190, 26)
    box:SetPoint("LEFT", discordLabel, "RIGHT", 12, 0)
    box:SetAutoFocus(false)
    box:SetFont(UI.FONT, 13, "")
    box:SetHeight(24)
    box:SetTextColor(1, 1, 1)
    box:SetTextInsets(10, 10, 0, 0)
    UI:Field(box)
    box:SetText(ns.discord)
    box:SetCursorPosition(0)
    box:SetScript("OnTextChanged", function(self, user)
        if user then self:SetText(ns.discord); self:HighlightText() end
    end)
    box:SetScript("OnEditFocusGained", function(self) self:HighlightText(); self:PaintField() end)
    box:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0); self:PaintField() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    track({ Refresh = function() box:PaintField() end })
    local copy = UI:Text(page, 10, "", "hint")
    copy:SetPoint("LEFT", box, "RIGHT", 8, 0)
    copy:SetText("click, then Ctrl+C")

    local thanks = UI:Text(page, 11, "", "muted")
    thanks:SetPoint("TOPLEFT", 0, -164)
    thanks:SetWidth(PAGE_W)
    thanks:SetText("Found a bug or got an idea? Message me on Discord. Thanks for using BagSmuggler!")

    Section(page, "Commands", -198)
    local cmds = UI:Text(page, 11, "", "text")
    cmds:SetPoint("TOPLEFT", 0, -216)
    cmds:SetSpacing(4)
    local function fill()
    local hex = UI:AccentHex()
    cmds:SetText(
        hex .. "/bsm|r  toggle bags\n" ..
        hex .. "/bsm bank|r  view your bank anywhere\n" ..
        hex .. "/bsm config|r  this window\n" ..
        hex .. "/bsm restack|r  combine partial stacks\n" ..
        hex .. "/bsm sell|r  sell junk at a vendor\n" ..
        hex .. "/bsm reset|r  reset window positions\n" ..
        "|cff8f939eAlt + Right-click|r an item to mark it as junk")
    end
    UI:OnStyle(fill)
    track({ Refresh = fill })

    Section(page, "Reset", -350)
    local b1 = UI:Button(page, "Reset Positions", 130, 24)
    b1:SetPoint("TOPLEFT", 0, -368)
    b1:SetScript("OnClick", function()
        wipe(ns.db.positions)
        ns.bags:RestorePosition()
        ns.bank:RestorePosition()
    end)
    local b2 = UI:Button(page, "Clear Junk Marks", 130, 24)
    b2:SetPoint("LEFT", b1, "RIGHT", 8, 0)
    b2:SetScript("OnClick", function()
        ns.Junk:ClearMarks()
        ns.Print("Junk marks cleared.")
    end)
    local b3 = UI:Button(page, "Reset Settings", 130, 24)
    b3:SetPoint("LEFT", b2, "RIGHT", 8, 0)
    b3:SetScript("OnClick", function()
        ns:ResetSettings()
        Config:Refresh()
    end)
end

---------------------------------------------------------------------------
-- Frame + sidebar
---------------------------------------------------------------------------
local PAGES = {
    { key = "general",    name = "General",    build = BuildGeneral },
    { key = "look",       name = "Look",       build = BuildLook },
    { key = "categories", name = "Categories", build = BuildCategories },
    { key = "about",      name = "About",      build = BuildAbout },
}

function Config:Build()
    local f = CreateFrame("Frame", "BagSmugglerConfigFrame", UIParent, "BackdropTemplate")
    f:SetSize(W, H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnShow", function() Config:Refresh() end)
    f:Hide()
    tinsert(UISpecialFrames, "BagSmugglerConfigFrame")
    self.frame = f

    self.panel = UI:Panel(f, 12, nil, "dialog")
    local banner = UI:Banner(f, 220)
    banner:SetText("BagSmuggler")
    local line = UI:AccentLine(f, 0.85)
    line:SetPoint("TOPLEFT", 12, -1)
    line:SetPoint("TOPRIGHT", f, "TOP", 0, -1)

    -- Sidebar
    local side = f:CreateTexture(nil, "BACKGROUND", nil, -6)
    side:SetTexture(UI.WHITE)
    side:SetVertexColor(1, 1, 1, 0.025)
    side:SetWidth(SIDEBAR)
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetTexture(UI.WHITE)
    sep:SetVertexColor(1, 1, 1, 0.06)
    sep:SetWidth(1)
    UI:OnStyle(function(blizz)
        local i = blizz and 11 or 1
        side:ClearAllPoints()
        side:SetPoint("TOPLEFT", i, -i)
        side:SetPoint("BOTTOMLEFT", i, i)
        side:SetVertexColor(blizz and 0 or 1, blizz and 0 or 1, blizz and 0 or 1, blizz and 0.25 or 0.025)
        sep:ClearAllPoints()
        sep:SetPoint("TOPLEFT", SIDEBAR, -i)
        sep:SetPoint("BOTTOMLEFT", SIDEBAR, i)
    end)

    local glyph = f:CreateTexture(nil, "ARTWORK")
    glyph:SetTexture(MEDIA .. "LogoPouch")
    glyph:SetSize(26, 26)
    glyph:SetPoint("TOPLEFT", 12, -14)
    local name = UI:Text(f, 17, "", "title")
    name:SetPoint("LEFT", glyph, "RIGHT", 8, 0)
    name:SetText("BagSmuggler")
    local ver = UI:Text(f, 10, "", "muted")
    ver:SetText("v" .. ns.version)
    UI:OnStyle(function(blizz)
        glyph:SetShown(true)
        name:SetShown(not blizz)
        ver:ClearAllPoints()
        if blizz then
            ver:SetPoint("LEFT", glyph, "RIGHT", 6, 0)
        else
            ver:SetPoint("TOPLEFT", glyph, "BOTTOMLEFT", 0, -6)
        end
    end)

    self.tabs = {}
    self.pages = {}
    for i, p in ipairs(PAGES) do
        local tab = CreateFrame("Button", nil, f)
        tab:SetSize(SIDEBAR - 20, 30)
        tab:SetPoint("TOPLEFT", 10, -70 - (i - 1) * 34)
        local bg = tab:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(MEDIA .. "Slot")
        bg:SetAllPoints()
        bg:SetVertexColor(1, 1, 1, 0)
        tab.bg = bg
        local ind = tab:CreateTexture(nil, "ARTWORK")
        ind:SetTexture(MEDIA .. "Pill")
        ind:SetSize(3, 14)
        ind:SetPoint("LEFT", 6, 0)
        UI:RegisterAccent(ind)
        tab.ind = ind
        tab.label = UI:Text(tab, 12)
        local qhl = tab:CreateTexture(nil, "BACKGROUND")
        qhl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        qhl:SetBlendMode("ADD")
        qhl:SetAllPoints()
        qhl:Hide()
        tab.qhl = qhl
        tab.label:SetPoint("LEFT", 16, 0)
        tab.label:SetText(p.name)
        tab.key = p.key
        tab:SetScript("OnClick", function() Config:ShowPage(p.key) end)
        tab:SetScript("OnEnter", function(self) if Config.current ~= self.key then self.bg:SetVertexColor(1, 1, 1, UI:IsBlizz() and 0.08 or 0.04) end end)
        tab:SetScript("OnLeave", function(self) if Config.current ~= self.key then self.bg:SetVertexColor(1, 1, 1, 0) end end)
        self.tabs[p.key] = tab

        local page = CreateFrame("Frame", nil, f)
        UI:OnStyle(function(blizz)
            page:ClearAllPoints()
            page:SetPoint("TOPLEFT", PAGE_X, blizz and -24 or 0)
            page:SetPoint("BOTTOMRIGHT", -22, 14)
        end)
        page:Hide()
        p.build(page)
        self.pages[p.key] = page
    end

    -- Credits at the foot of the sidebar
    local by = UI:Text(f, 10, "", "muted")
    by:SetPoint("BOTTOMLEFT", 18, 50)
    by:SetText("Made by")
    local who = UI:Text(f, 12, "", "title")
    who:SetPoint("TOPLEFT", by, "BOTTOMLEFT", 0, -3)
    who:SetText("WhiteKnight")
    local alias = UI:Text(f, 10, "", "muted")
    alias:SetPoint("TOPLEFT", who, "BOTTOMLEFT", 0, -2)
    alias:SetText("Smuggz_  -  " .. ns.discord)

    UI:CloseButton(f, function() f:Hide() end)

    self:ShowPage("general")
end

function Config:ShowPage(key)
    self.current = key
    for k, page in pairs(self.pages) do page:SetShown(k == key) end
    self:PaintTabs()
end

function Config:PaintTabs()
    if not self.tabs then return end
    local blizz = UI:IsBlizz()
    for k, tab in pairs(self.tabs) do
        local on = (k == self.current)
        tab.ind:SetShown(on and not blizz)
        tab.qhl:SetShown(on and blizz)
        tab.bg:SetVertexColor(1, 1, 1, (on and not blizz) and 0.07 or 0)
        local c
        if blizz then
            c = on and { 1, 1, 1 } or UI.GOLD
        else
            c = on and { 1, 1, 1 } or UI.mutedColor
        end
        tab.label:SetTextColor(c[1], c[2], c[3])
    end
end

function Config:Refresh()
    if not self.frame then return end
    self.panel:Apply(0.98)
    self:PaintTabs()
    for _, w in ipairs(widgets) do
        if w.Refresh then w:Refresh() end
    end
end

function Config:Toggle()
    if not self.frame then self:Build() end
    self.frame:SetShown(not self.frame:IsShown())
end

-- Entry in the Blizzard options / AddOns list
function Config:Init()
    local panel = CreateFrame("Frame")
    panel.name = "BagSmuggler"
    local t = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16)
    t:SetText("BagSmuggler")
    local sub = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -4)
    sub:SetText("by WhiteKnight / Smuggz_  -  Discord: " .. ns.discord)
    local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    b:SetSize(180, 24)
    b:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -14)
    b:SetText("Open BagSmuggler Settings")
    b:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then HideUIPanel(InterfaceOptionsFrame) end
        Config:Toggle()
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "BagSmuggler")
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end
