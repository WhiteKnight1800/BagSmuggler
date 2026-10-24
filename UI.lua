-- BagSmuggler: shared look (skins, accent colours, panels, widgets)
-- Every widget supports two styles: Blizzard (classic game art) and modern
-- (Sleek / Glass / Onyx). Widgets register a style callback that runs when
-- the skin changes.

local _, ns = ...

local UI = {}
ns.UI = UI

local MEDIA = "Interface\\AddOns\\BagSmuggler\\Media\\"
UI.media = MEDIA
UI.WHITE = "Interface\\Buttons\\WHITE8x8"
UI.FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

UI.textColor = { 0.90, 0.91, 0.94 }
UI.mutedColor = { 0.56, 0.58, 0.64 }
UI.iconColor = { 0.60, 0.62, 0.69 }
UI.GOLD = { 1, 0.82, 0 }

---------------------------------------------------------------------------
-- Skins & accents
---------------------------------------------------------------------------
UI.skins = {
    Bags = {
        blizz = true, bag = true, bg = { 1, 1, 1 }, border = { 1, 1, 1, 1 }, shadow = 0,
        field = { 0, 0, 0, 0.5 }, slot = { 1, 1, 1, 1 }, alphaMul = 1,
    },
    Blizzard = {
        blizz = true, bg = { 1, 1, 1 }, border = { 1, 1, 1, 1 }, shadow = 0,
        field = { 0, 0, 0, 0.5 }, slot = { 1, 1, 1, 1 }, alphaMul = 1,
    },
    Sleek = {
        bg = { 0.075, 0.078, 0.094 }, border = { 1, 1, 1, 0.075 }, shadow = 0.55,
        field = { 1, 1, 1, 0.045 }, slot = { 0.115, 0.12, 0.14, 1 }, alphaMul = 1,
    },
    Glass = {
        bg = { 0.05, 0.065, 0.09 }, border = { 1, 1, 1, 0.11 }, shadow = 0.35,
        field = { 1, 1, 1, 0.06 }, slot = { 0.12, 0.14, 0.18, 0.75 }, alphaMul = 0.72,
    },
    Onyx = {
        bg = { 0.018, 0.018, 0.022 }, border = { 1, 1, 1, 0.05 }, shadow = 0.75,
        field = { 1, 1, 1, 0.035 }, slot = { 0.07, 0.07, 0.08, 1 }, alphaMul = 1,
    },
}
UI.skinOrder = { "Bags", "Blizzard", "Sleek", "Glass", "Onyx" }
UI.skinNames = {
    Bags = "Default Bags", Blizzard = "Blizzard Dialog",
    Sleek = "Sleek", Glass = "Glass", Onyx = "Onyx",
}

UI.accents = {
    { key = "blue",   name = "Ice Blue",    color = { 0.36, 0.64, 1.00 } },
    { key = "fel",    name = "Fel Green",   color = { 0.45, 0.92, 0.32 } },
    { key = "gold",   name = "Gold",        color = { 1.00, 0.77, 0.26 } },
    { key = "purple", name = "Void Purple", color = { 0.68, 0.46, 1.00 } },
    { key = "rose",   name = "Rose",        color = { 1.00, 0.42, 0.55 } },
    { key = "class",  name = "Class Colour" },
}

function UI:Skin()
    return self.skins[ns.db.settings.skin] or self.skins.Bags
end

function UI:IsBag()
    return ns.db ~= nil and self:Skin().bag == true
end

function UI:IsBlizz()
    return ns.db ~= nil and self:Skin().blizz == true
end

function UI:Accent()
    if self:IsBlizz() then return 1, 0.82, 0 end
    local key = ns.db and ns.db.settings.accent or "blue"
    if key == "class" then
        local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[select(2, UnitClass("player"))]
        if c then return c.r, c.g, c.b end
    end
    for _, a in ipairs(self.accents) do
        if a.key == key and a.color then return a.color[1], a.color[2], a.color[3] end
    end
    return 0.36, 0.64, 1.00
end

function UI:AccentHex()
    local r, g, b = self:Accent()
    return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end

function UI:AccentName()
    local key = ns.db.settings.accent
    for _, a in ipairs(self.accents) do
        if a.key == key then return a.name end
    end
    return self.accents[1].name
end

function UI:NextAccent(step)
    local list, key = self.accents, ns.db.settings.accent
    for i, a in ipairs(list) do
        if a.key == key then
            return list[(i - 1 + (step or 1)) % #list + 1].key
        end
    end
    return list[1].key
end

---------------------------------------------------------------------------
-- Style + accent registries
---------------------------------------------------------------------------
local styled = {}

-- fn(isBlizz) runs now and every time the skin changes
function UI:OnStyle(fn)
    styled[#styled + 1] = fn
    fn(self:IsBlizz())
end

function UI:ApplyStyle()
    local b = self:IsBlizz()
    for _, fn in ipairs(styled) do fn(b) end
end

local accented = {}

local function SetGradient(tex, r, g, b, a1, a2)
    if CreateColor and pcall(tex.SetGradient, tex, "HORIZONTAL", CreateColor(r, g, b, a1), CreateColor(r, g, b, a2)) then
        return
    end
    if tex.SetGradientAlpha and pcall(tex.SetGradientAlpha, tex, "HORIZONTAL", r, g, b, a1, r, g, b, a2) then
        return
    end
    tex:SetVertexColor(r, g, b, (a1 + a2) / 2)
end

local function Paint(e)
    local r, g, b = UI:Accent()
    local obj, alpha, kind = e[1], e[2], e[3]
    if kind == "text" then
        obj:SetTextColor(r, g, b, alpha)
    elseif kind == "gradient" then
        obj:SetTexture(UI.WHITE)
        SetGradient(obj, r, g, b, alpha, 0)
    elseif obj.SetColor then
        obj:SetColor(r, g, b, alpha)
    else
        obj:SetVertexColor(r, g, b, alpha)
    end
end

function UI:RegisterAccent(obj, alpha, kind)
    local e = { obj, alpha or 1, kind }
    accented[#accented + 1] = e
    Paint(e)
    return obj
end

function UI:ApplyAccent()
    for _, e in ipairs(accented) do Paint(e) end
end

---------------------------------------------------------------------------
-- Text with roles: title / text / muted / header
---------------------------------------------------------------------------
local ROLES = {
    title  = { modern = { 1, 1, 1 },            blizz = { 1, 0.82, 0 } },
    text   = { modern = UI.textColor,            blizz = { 1, 1, 1 } },
    muted  = { modern = UI.mutedColor,           blizz = { 0.66, 0.66, 0.66 } },
    hint   = { modern = { 0.45, 0.47, 0.53 },    blizz = { 0.5, 0.5, 0.5 } },
    header = { modern = UI.mutedColor,           blizz = { 1, 0.82, 0 } },
}

function UI:RoleColor(role)
    local r = ROLES[role] or ROLES.text
    return self:IsBlizz() and r.blizz or r.modern
end

-- color may be a role name ("muted") or an {r,g,b} table
function UI:Text(parent, size, flags, color, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(self.FONT, size or 12, flags or "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.8)
    fs:SetJustifyH("LEFT")
    if type(color) == "string" then
        fs.role = color
        self:OnStyle(function()
            local c = UI:RoleColor(fs.role)
            fs:SetTextColor(c[1], c[2], c[3])
        end)
    else
        local c = color or self.textColor
        fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    end
    return fs
end

function UI:ResetRoleColor(fs)
    local c = self:RoleColor(fs.role or "text")
    fs:SetTextColor(c[1], c[2], c[3])
end

---------------------------------------------------------------------------
-- Panels
---------------------------------------------------------------------------
local BLIZZ_BACKDROPS = {
    dialog = {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    },
    tooltip = {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    },
}

-- Manual 9-slice so the rounded look works on every client
function UI:NineSlice(frame, file, corner, layer, sub, margin, outset)
    margin, outset = margin or 0.25, outset or 0
    local list = {}
    local function tex()
        local t = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
        t:SetTexture(MEDIA .. file)
        list[#list + 1] = t
        return t
    end
    local a, b = margin, 1 - margin
    local tl, tr, bl, br = tex(), tex(), tex(), tex()
    local top, bottom, left, right, center = tex(), tex(), tex(), tex(), tex()
    for _, c in ipairs({ tl, tr, bl, br }) do c:SetSize(corner, corner) end
    tl:SetPoint("TOPLEFT", -outset, outset);      tl:SetTexCoord(0, a, 0, a)
    tr:SetPoint("TOPRIGHT", outset, outset);      tr:SetTexCoord(b, 1, 0, a)
    bl:SetPoint("BOTTOMLEFT", -outset, -outset);  bl:SetTexCoord(0, a, b, 1)
    br:SetPoint("BOTTOMRIGHT", outset, -outset);  br:SetTexCoord(b, 1, b, 1)
    top:SetPoint("TOPLEFT", tl, "TOPRIGHT");       top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT");    top:SetTexCoord(a, b, 0, a)
    bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT");    bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT"); bottom:SetTexCoord(a, b, b, 1)
    left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT");    left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT");     left:SetTexCoord(0, a, a, b)
    right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT");   right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT");    right:SetTexCoord(b, 1, a, b)
    center:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT"); center:SetPoint("BOTTOMRIGHT", br, "TOPLEFT");    center:SetTexCoord(a, b, a, b)

    local obj = { textures = list }
    function obj:SetColor(r, g, bl2, al)
        for _, t in ipairs(list) do t:SetVertexColor(r, g, bl2, al or 1) end
    end
    function obj:SetShown(v)
        for _, t in ipairs(list) do t:SetShown(v) end
    end
    return obj
end

-- frame must be created with "BackdropTemplate". kind: "dialog" or "tooltip"
function UI:Panel(frame, corner, noShadow, kind, bagAware)
    local p = { kind = kind or "dialog", bagAware = bagAware }
    if not noShadow then
        p.shadow = self:NineSlice(frame, "Shadow", 24, "BACKGROUND", -8, 0.375, 14)
    end
    p.bg = self:NineSlice(frame, "Panel", corner or 10, "BACKGROUND", -7)
    p.border = self:NineSlice(frame, "Border", corner or 10, "BORDER", -7)

    -- darkening layer under the Blizzard dialog art so items read clearly
    local under = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    under:SetTexture(UI.WHITE)
    local inset = p.kind == "dialog" and 11 or 4
    under:SetPoint("TOPLEFT", inset, -inset)
    under:SetPoint("BOTTOMRIGHT", -inset, inset)
    p.under = under

    function p:Apply(alpha)
        local sk = UI:Skin()
        local a = (alpha or ns.db.settings.alpha) * sk.alphaMul
        local blizz = sk.blizz
        if sk.bag and self.bagAware then
            self.bg:SetShown(false)
            self.border:SetShown(false)
            if self.shadow then self.shadow:SetShown(false) end
            self.under:SetShown(false)
            frame:SetBackdrop(nil)
            return
        end
        self.bg:SetShown(not blizz)
        self.border:SetShown(not blizz)
        if self.shadow then self.shadow:SetShown(not blizz) end
        self.under:SetShown(blizz and true or false)
        if blizz then
            frame:SetBackdrop(BLIZZ_BACKDROPS[self.kind])
            if self.kind == "tooltip" then
                frame:SetBackdropColor(0.06, 0.06, 0.08, a)
                frame:SetBackdropBorderColor(0.75, 0.75, 0.75, 1)
                self.under:SetVertexColor(0, 0, 0, 0)
            else
                frame:SetBackdropColor(1, 1, 1, a)
                frame:SetBackdropBorderColor(1, 1, 1, 1)
                self.under:SetVertexColor(0, 0, 0, a * 0.55)
            end
        else
            frame:SetBackdrop(nil)
            self.bg:SetColor(sk.bg[1], sk.bg[2], sk.bg[3], a)
            self.border:SetColor(sk.border[1], sk.border[2], sk.border[3], sk.border[4])
            if self.shadow then self.shadow:SetColor(0, 0, 0, sk.shadow) end
        end
    end
    return p
end

-- Classic dialog title banner, only shown in the Blizzard skin
function UI:Banner(frame, width, hideInBag)
    local h = frame:CreateTexture(nil, "ARTWORK")
    h:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    h:SetSize(width or 256, 64)
    h:SetPoint("TOP", 0, 12)
    local t = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("TOP", h, "TOP", 0, -14)
    local obj = { tex = h, text = t, width = width or 256 }
    function obj:SetText(s)
        t:SetText(s)
        h:SetWidth(math.max(self.width, t:GetStringWidth() + 110))
    end
    self:OnStyle(function(blizz)
        local show = blizz and not (hideInBag and UI:IsBag())
        h:SetShown(show)
        t:SetShown(show)
    end)
    return obj
end

-- Close button: flat glyph (modern) or the red Blizzard X
function UI:CloseButton(frame, onClick, bagAware)
    local modern = self:IconButton(frame, "IconClose", 12, "Close")
    modern:SetPoint("TOPRIGHT", -7, -8)
    modern:SetScript("OnClick", onClick)
    local blizz = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    blizz:SetPoint("TOPRIGHT", -4, -4)
    blizz:SetScript("OnClick", onClick)
    local obj = { modern = modern, blizz = blizz }
    function obj:Current() return UI:IsBlizz() and blizz or modern end
    self:OnStyle(function(isBlizz)
        modern:SetShown(not isBlizz)
        blizz:SetShown(isBlizz)
        blizz:ClearAllPoints()
        if bagAware and UI:IsBag() then
            blizz:SetPoint("TOPRIGHT", 0, -1)   -- sits in the bag art's close box
        else
            blizz:SetPoint("TOPRIGHT", -4, -4)
        end
    end)
    return obj
end

function UI:Divider(parent, alpha)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture(self.WHITE)
    t:SetHeight(1)
    self:OnStyle(function(blizz)
        if blizz then
            t:SetVertexColor(1, 0.82, 0, 0.18)
        else
            t:SetVertexColor(1, 1, 1, alpha or 0.06)
        end
    end)
    return t
end

function UI:AccentLine(parent, alpha)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetHeight(2)
    self:RegisterAccent(t, alpha or 0.9, "gradient")
    self:OnStyle(function(blizz) t:SetShown(not blizz) end)
    return t
end

---------------------------------------------------------------------------
-- Tooltips
---------------------------------------------------------------------------
local function ShowTip(owner, tip, anchor)
    if not tip then return end
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_TOP")
    if type(tip) == "function" then
        tip(GameTooltip)
    else
        GameTooltip:SetText(tip, 1, 1, 1, 1, true)
    end
    GameTooltip:Show()
end
UI.ShowTip = ShowTip

---------------------------------------------------------------------------
-- Glyph icon button (gold glyphs in the Blizzard skin)
---------------------------------------------------------------------------
function UI:IconButton(parent, icon, size, tip)
    size = size or 16
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size + 8, size + 8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(MEDIA .. "Slot")
    bg:SetAllPoints()
    bg:SetVertexColor(1, 1, 1, 0)
    b.bg = bg
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetTexture(MEDIA .. icon)
    t:SetSize(size, size)
    t:SetPoint("CENTER")
    b.icon = t
    b.tip = tip

    function b:PaintIcon(hover)
        if UI:IsBlizz() then
            if hover then t:SetVertexColor(1, 1, 1) else t:SetVertexColor(1, 0.82, 0) end
            bg:SetVertexColor(1, 1, 1, hover and 0.1 or 0)
        else
            if hover then
                t:SetVertexColor(UI:Accent())
            else
                local c = UI.iconColor
                t:SetVertexColor(c[1], c[2], c[3])
            end
            bg:SetVertexColor(1, 1, 1, hover and 0.07 or 0)
        end
    end

    b:SetScript("OnEnter", function(self)
        self:PaintIcon(true)
        ShowTip(self, self.tip)
    end)
    b:SetScript("OnLeave", function(self)
        self:PaintIcon(false)
        GameTooltip_Hide()
    end)
    b:SetScript("OnMouseDown", function(self) self.icon:SetPoint("CENTER", 1, -1) end)
    b:SetScript("OnMouseUp", function(self) self.icon:SetPoint("CENTER", 0, 0) end)
    self:OnStyle(function() b:PaintIcon(false) end)
    return b
end

---------------------------------------------------------------------------
-- 3-slice helper for Blizzard art (left cap / stretch / right cap)
---------------------------------------------------------------------------
local function ThreeSlice(frame, layer, file, capW, l, m, r, top, bottom, blend)
    local L = frame:CreateTexture(nil, layer)
    local M = frame:CreateTexture(nil, layer)
    local R = frame:CreateTexture(nil, layer)
    for _, t in ipairs({ L, M, R }) do
        t:SetTexture(file)
        if blend then t:SetBlendMode(blend) end
    end
    L:SetPoint("TOPLEFT"); L:SetPoint("BOTTOMLEFT"); L:SetWidth(capW)
    R:SetPoint("TOPRIGHT"); R:SetPoint("BOTTOMRIGHT"); R:SetWidth(capW)
    M:SetPoint("TOPLEFT", L, "TOPRIGHT"); M:SetPoint("BOTTOMRIGHT", R, "BOTTOMLEFT")
    L:SetTexCoord(0, l, top, bottom)
    M:SetTexCoord(l, m, top, bottom)
    R:SetTexCoord(m, r, top, bottom)
    local obj = { L, M, R }
    function obj:SetShown(v) for _, t in ipairs(self) do t:SetShown(v) end end
    function obj:SetTexture(f) for _, t in ipairs(self) do t:SetTexture(f) end end
    return obj
end

local function InputBorder(frame)
    return ThreeSlice(frame, "BACKGROUND", "Interface\\Common\\Common-Input-Border", 8, 0.0625, 0.9375, 1, 0, 0.625)
end

---------------------------------------------------------------------------
-- Button: flat (modern) or the red Blizzard panel button
---------------------------------------------------------------------------
local BTN_UP = "Interface\\Buttons\\UI-Panel-Button-Up"
local BTN_DOWN = "Interface\\Buttons\\UI-Panel-Button-Down"
local BTN_HL = "Interface\\Buttons\\UI-Panel-Button-Highlight"

function UI:Button(parent, text, width, height, tip)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height or 22)
    b.fill = self:NineSlice(b, "Panel", 6, "BACKGROUND", 0)
    b.edge = self:NineSlice(b, "Border", 6, "BORDER", 0)
    b.art = ThreeSlice(b, "BACKGROUND", BTN_UP, 12, 0.09375, 0.53125, 0.625, 0, 0.6875)
    b.hl = ThreeSlice(b, "HIGHLIGHT", BTN_HL, 12, 0.09375, 0.53125, 0.625, 0, 0.6875, "ADD")
    b.label = self:Text(b, 11)
    b.label:SetPoint("CENTER")
    b.label:SetJustifyH("CENTER")
    b.label:SetText(text)
    b.tip = tip

    function b:Paint(hover)
        if UI:IsBlizz() then
            if hover then
                self.label:SetTextColor(1, 1, 1)
            else
                self.label:SetTextColor(1, 0.82, 0)
            end
            return
        end
        local c = UI.textColor
        self.label:SetTextColor(c[1], c[2], c[3])
        if hover then
            local r, g, bl = UI:Accent()
            self.fill:SetColor(r, g, bl, 0.22)
            self.edge:SetColor(r, g, bl, 0.65)
        else
            self.fill:SetColor(1, 1, 1, 0.06)
            self.edge:SetColor(1, 1, 1, 0.09)
        end
    end
    function b:SetLabel(t) self.label:SetText(t) end

    b:SetScript("OnEnter", function(self) self:Paint(true); ShowTip(self, self.tip) end)
    b:SetScript("OnLeave", function(self) self:Paint(false); GameTooltip_Hide() end)
    b:SetScript("OnMouseDown", function(self)
        self.label:SetPoint("CENTER", 1, -1)
        if UI:IsBlizz() then self.art:SetTexture(BTN_DOWN) end
    end)
    b:SetScript("OnMouseUp", function(self)
        self.label:SetPoint("CENTER", 0, 0)
        if UI:IsBlizz() then self.art:SetTexture(BTN_UP) end
    end)
    self:OnStyle(function(blizz)
        b.fill:SetShown(not blizz)
        b.edge:SetShown(not blizz)
        b.art:SetShown(blizz)
        b.hl:SetShown(blizz)
        b.art:SetTexture(BTN_UP)
        b:Paint(false)
    end)
    return b
end

---------------------------------------------------------------------------
-- Settings widgets
---------------------------------------------------------------------------
local OFF = { 0.22, 0.23, 0.27 }

-- Toggle switch (modern) / checkbox (Blizzard)
function UI:Toggle(parent, label, width, get, set, tip)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(width, 26)
    f.label = self:Text(f, 12, nil, "text")
    f.label:SetText(label)
    f.label:SetWordWrap(false)

    local track = f:CreateTexture(nil, "ARTWORK")
    track:SetTexture(MEDIA .. "Pill")
    track:SetSize(30, 16)
    track:SetPoint("RIGHT")
    local knob = f:CreateTexture(nil, "OVERLAY")
    knob:SetTexture(MEDIA .. "Circle")
    knob:SetSize(12, 12)

    local box = f:CreateTexture(nil, "ARTWORK")
    box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
    box:SetSize(24, 24)
    box:SetPoint("LEFT", -3, 0)
    local check = f:CreateTexture(nil, "OVERLAY")
    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:SetAllPoints(box)
    local boxHl = f:CreateTexture(nil, "HIGHLIGHT")
    boxHl:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    boxHl:SetBlendMode("ADD")
    boxHl:SetAllPoints(box)

    function f:Refresh()
        local on = get() and true or false
        if UI:IsBlizz() then
            check:SetShown(on)
            return
        end
        knob:ClearAllPoints()
        if on then
            knob:SetPoint("RIGHT", track, "RIGHT", -2, 0)
            track:SetVertexColor(UI:Accent())
            knob:SetVertexColor(1, 1, 1)
        else
            knob:SetPoint("LEFT", track, "LEFT", 2, 0)
            track:SetVertexColor(OFF[1], OFF[2], OFF[3])
            knob:SetVertexColor(0.62, 0.63, 0.68)
        end
    end
    f:SetScript("OnClick", function(self)
        set(not get())
        self:Refresh()
        ns:ApplySettings()
    end)
    f:SetScript("OnEnter", function(self)
        if not UI:IsBlizz() then self.label:SetTextColor(1, 1, 1) end
        ShowTip(self, tip, "ANCHOR_RIGHT")
    end)
    f:SetScript("OnLeave", function(self)
        UI:ResetRoleColor(self.label)
        GameTooltip_Hide()
    end)
    self:OnStyle(function(blizz)
        track:SetShown(not blizz)
        knob:SetShown(not blizz)
        box:SetShown(blizz)
        boxHl:SetShown(blizz)
        check:SetShown(false)
        f.label:ClearAllPoints()
        if blizz then
            f.label:SetPoint("LEFT", box, "RIGHT", 2, 1)
            f.label:SetPoint("RIGHT", 0, 0)
        else
            f.label:SetPoint("LEFT")
            f.label:SetPoint("RIGHT", -40, 0)
        end
        f:Refresh()
    end)
    return f
end

function UI:Slider(parent, label, width, minV, maxV, step, get, set, fmt)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, 38)
    local text = self:Text(f, 12, nil, "text")
    text:SetPoint("TOPLEFT")
    text:SetText(label)
    local value = self:Text(f, 12)
    value:SetPoint("TOPRIGHT")
    value:SetJustifyH("RIGHT")
    self:RegisterAccent(value, 1, "text")

    local s = CreateFrame("Slider", nil, f, "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetHeight(16)
    s:SetPoint("BOTTOMLEFT", 0, 2)
    s:SetPoint("BOTTOMRIGHT", 0, 2)
    s:SetHitRectInsets(0, 0, -4, -4)
    s:SetThumbTexture(MEDIA .. "Circle")
    local thumb = s:GetThumbTexture()

    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(MEDIA .. "Pill")
    track:SetHeight(4)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetVertexColor(OFF[1], OFF[2], OFF[3])
    local fill = s:CreateTexture(nil, "ARTWORK")
    fill:SetTexture(MEDIA .. "Pill")
    fill:SetHeight(4)
    fill:SetPoint("LEFT", track, "LEFT")
    fill:SetPoint("RIGHT", thumb, "CENTER")
    self:RegisterAccent(fill)

    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s:EnableMouseWheel(true)

    local function show(v) value:SetText(fmt and fmt(v) or tostring(v)) end
    s:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / step + 0.5) * step
        v = tonumber(string.format("%.2f", v))
        show(v)
        if self.refreshing then return end
        if get() ~= v then
            set(v)
            ns:ApplySettings()
        end
    end)
    s:SetScript("OnMouseWheel", function(self, delta)
        self:SetValue(math.min(maxV, math.max(minV, self:GetValue() + delta * step)))
    end)

    function f:Refresh()
        s.refreshing = true
        s:SetValue(get())
        show(get())
        s.refreshing = false
    end
    self:OnStyle(function(blizz)
        track:SetShown(not blizz)
        fill:SetShown(not blizz)
        if blizz then
            s:SetBackdrop({
                bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
                edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
                tile = true, tileSize = 8, edgeSize = 8,
                insets = { left = 3, right = 3, top = 6, bottom = 6 },
            })
            s:SetHeight(17)
            s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
            local th = s:GetThumbTexture()
            th:SetSize(32, 32)
            th:SetVertexColor(1, 1, 1)
        else
            s:SetBackdrop(nil)
            s:SetHeight(16)
            s:SetThumbTexture(MEDIA .. "Circle")
            local th = s:GetThumbTexture()
            th:SetSize(13, 13)
            th:SetVertexColor(1, 1, 1)
        end
        fill:ClearAllPoints()
        fill:SetPoint("LEFT", track, "LEFT")
        fill:SetPoint("RIGHT", s:GetThumbTexture(), "CENTER")
    end)
    return f
end

-- "Label        < Value >"
function UI:Selector(parent, label, width, getText, onPrev, onNext)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, 26)
    local text = self:Text(f, 12, nil, "text")
    text:SetPoint("LEFT")
    text:SetText(label)

    local box = CreateFrame("Frame", nil, f)
    box:SetSize(150, 22)
    box:SetPoint("RIGHT")
    local fill = self:NineSlice(box, "Panel", 6, "BACKGROUND", 0)
    fill:SetColor(1, 1, 1, 0.06)
    local edge = self:NineSlice(box, "Border", 6, "BORDER", 0)
    edge:SetColor(1, 1, 1, 0.09)
    local input = InputBorder(box)
    local val = self:Text(box, 11, nil, { 1, 1, 1 })
    val:SetPoint("CENTER")
    val:SetJustifyH("CENTER")

    local arrows = {}
    local function arrow(icon, blizzTex, point, fn)
        local b = CreateFrame("Button", nil, box)
        b:SetSize(22, 22)
        b:SetPoint(point)
        local t = b:CreateTexture(nil, "ARTWORK")
        t:SetPoint("CENTER")
        b.t = t
        b:SetScript("OnEnter", function()
            if UI:IsBlizz() then t:SetVertexColor(1, 1, 1) else t:SetVertexColor(UI:Accent()) end
        end)
        b:SetScript("OnLeave", function() b:Restyle() end)
        b:SetScript("OnClick", function()
            fn()
            ns:ApplySettings()
            f:Refresh()
            if ns.Config and ns.Config.Refresh then ns.Config:Refresh() end
        end)
        function b:Restyle()
            if UI:IsBlizz() then
                t:SetTexture(blizzTex)
                t:SetSize(22, 22)
                t:SetVertexColor(1, 1, 1)
            else
                t:SetTexture(MEDIA .. icon)
                t:SetSize(12, 12)
                t:SetVertexColor(0.6, 0.62, 0.68)
            end
        end
        arrows[#arrows + 1] = b
        return b
    end
    arrow("ChevronLeft", "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up", "LEFT", onPrev)
    arrow("ChevronRight", "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up", "RIGHT", onNext)

    function f:Refresh() val:SetText(getText()) end
    self:OnStyle(function(blizz)
        fill:SetShown(not blizz)
        edge:SetShown(not blizz)
        input:SetShown(blizz)
        if blizz then val:SetTextColor(1, 0.82, 0) else val:SetTextColor(1, 1, 1) end
        for _, a in ipairs(arrows) do a:Restyle() end
    end)
    return f
end

-- Rounded (modern) or Blizzard input-box border for an EditBox
function UI:Field(edit)
    edit.fill = self:NineSlice(edit, "Panel", 6, "BACKGROUND", 0)
    edit.edge = self:NineSlice(edit, "Border", 6, "BORDER", 0)
    edit.input = InputBorder(edit)
    function edit:PaintField()
        local blizz = UI:IsBlizz()
        self.fill:SetShown(not blizz)
        self.edge:SetShown(not blizz)
        self.input:SetShown(blizz)
        if blizz then return end
        local sk = UI:Skin()
        local f = sk.field
        self.fill:SetColor(f[1], f[2], f[3], f[4])
        if self:HasFocus() then
            local r, g, b = UI:Accent()
            self.edge:SetColor(r, g, b, 0.8)
        else
            self.edge:SetColor(1, 1, 1, 0.08)
        end
    end
    self:OnStyle(function() edit:PaintField() end)
end
