-- BagSmuggler: "Default Bags" skin.
-- Rebuilds the classic Blizzard bag frame from pieces of the game's own bag art
-- (Interface\ContainerFrame) so it can stretch to any size: portrait ring and
-- title bar on top, stone edges down the sides, the gold money bar at the
-- bottom, plain bag backing inside, and a real slot cell behind every item.

local _, ns = ...
local UI = ns.UI

local COMP = "Interface\\ContainerFrame\\UI-Bag-Components"       -- 256 x 512
local PACK = "Interface\\ContainerFrame\\UI-BackpackBackground"    -- 256 x 256

-- Pixel rects measured from the art: { left, top, right, bottom }
local HEAD_Y = { 0, 50 }
local HEAD_L, HEAD_M, HEAD_R = { 64, 140 }, { 140, 175 }, { 175, 256 }
local EDGE_Y = { 224, 248 }
local EDGE_L, EDGE_R = { 64, 82 }, { 244, 256 }
local FOOT_Y = { 212, 240 }
local FOOT_L, FOOT_M, FOOT_R = { 64, 110 }, { 110, 200 }, { 200, 256 }
local PATCH = { 112, 127, 158, 160 }
local CELL = { 120, 87, 162, 128 }          -- slot cell around a 37px button

local HEAD_H = HEAD_Y[2] - HEAD_Y[1]        -- 50
local FOOT_H = FOOT_Y[2] - FOOT_Y[1]        -- 28
local EDGE_LW = EDGE_L[2] - EDGE_L[1]       -- 18
local EDGE_RW = EDGE_R[2] - EDGE_R[1]       -- 12

UI.bag = {
    HEAD_H = HEAD_H, FOOT_H = FOOT_H, EDGE_LW = EDGE_LW, EDGE_RW = EDGE_RW,
    CELL = CELL, PACK = PACK,
}


local function Coords(tex, x0, y0, x1, y1, w, h)
    tex:SetTexCoord(x0 / w, x1 / w, y0 / h, y1 / h)
end

-- Builds the bag art on `frame`; returns an object with SetShown / SetPortrait / title
function UI:BagFrame(frame)
    local o = { textures = {} }
    local function tex(file, layer, sub)
        local t = frame:CreateTexture(nil, layer or "BORDER", nil, sub or 0)
        t:SetTexture(file)
        o.textures[#o.textures + 1] = t
        return t
    end

    -- Portrait (sits under the hollow ring of the header art)
    local portrait = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    portrait:SetSize(40, 40)
    portrait:SetPoint("TOPLEFT", 4, -4)
    o.portrait = portrait
    o.textures[#o.textures + 1] = portrait
    if frame.CreateMaskTexture and portrait.AddMaskTexture then
        pcall(function()
            local mask = frame:CreateMaskTexture()
            mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(portrait)
            portrait:AddMaskTexture(mask)
        end)
    end

    -- Header: left cap (ring + bar start), stretched middle, right cap (bar end + close box)
    local hl = tex(COMP, "BORDER", 1)
    hl:SetSize(HEAD_L[2] - HEAD_L[1], HEAD_H)
    hl:SetPoint("TOPLEFT")
    Coords(hl, HEAD_L[1], HEAD_Y[1], HEAD_L[2], HEAD_Y[2], 256, 512)
    local hr = tex(COMP, "BORDER", 1)
    hr:SetSize(HEAD_R[2] - HEAD_R[1], HEAD_H)
    hr:SetPoint("TOPRIGHT")
    Coords(hr, HEAD_R[1], HEAD_Y[1], HEAD_R[2], HEAD_Y[2], 256, 512)
    local hm = tex(COMP, "BORDER", 1)
    hm:SetPoint("TOPLEFT", hl, "TOPRIGHT")
    hm:SetPoint("BOTTOMRIGHT", hr, "BOTTOMLEFT")
    Coords(hm, HEAD_M[1], HEAD_Y[1], HEAD_M[2], HEAD_Y[2], 256, 512)

    -- Footer with the gold money bar (from the backpack art)
    local fl = tex(PACK, "BORDER", 1)
    fl:SetSize(FOOT_L[2] - FOOT_L[1], FOOT_H)
    fl:SetPoint("BOTTOMLEFT")
    Coords(fl, FOOT_L[1], FOOT_Y[1], FOOT_L[2], FOOT_Y[2], 256, 256)
    local fr = tex(PACK, "BORDER", 1)
    fr:SetSize(FOOT_R[2] - FOOT_R[1], FOOT_H)
    fr:SetPoint("BOTTOMRIGHT")
    Coords(fr, FOOT_R[1], FOOT_Y[1], FOOT_R[2], FOOT_Y[2], 256, 256)
    local fm = tex(PACK, "BORDER", 1)
    fm:SetPoint("TOPLEFT", fl, "TOPRIGHT")
    fm:SetPoint("BOTTOMRIGHT", fr, "BOTTOMLEFT")
    Coords(fm, FOOT_M[1], FOOT_Y[1], FOOT_M[2], FOOT_Y[2], 256, 256)

    -- Stone edges, stretched between header and footer
    local el = tex(COMP, "BORDER", 0)
    el:SetWidth(EDGE_LW)
    el:SetPoint("TOPLEFT", 0, -HEAD_H)
    el:SetPoint("BOTTOMLEFT", 0, FOOT_H)
    Coords(el, EDGE_L[1], EDGE_Y[1], EDGE_L[2], EDGE_Y[2], 256, 512)
    local er = tex(COMP, "BORDER", 0)
    er:SetWidth(EDGE_RW)
    er:SetPoint("TOPRIGHT", 0, -HEAD_H)
    er:SetPoint("BOTTOMRIGHT", 0, FOOT_H)
    Coords(er, EDGE_R[1], EDGE_Y[1], EDGE_R[2], EDGE_Y[2], 256, 512)

    -- Plain backing: mirrored tiles of a clean patch (mirroring hides the seams)
    local tiles = {}
    local PW, PH = PATCH[3] - PATCH[1], PATCH[4] - PATCH[2]
    local function Retile()
        if not o.shown then return end
        local w, h = frame:GetWidth(), frame:GetHeight()
        if not w or w <= 0 then return end
        local x0, y0 = EDGE_LW, HEAD_H - 2
        local x1, y1 = w - EDGE_RW, h - FOOT_H + 2
        local n = 0
        local row, y = 0, y0
        while y < y1 do
            local th = math.min(PH, y1 - y)
            local col, x = 0, x0
            while x < x1 do
                local tw = math.min(PW, x1 - x)
                n = n + 1
                local t = tiles[n]
                if not t then
                    t = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
                    t:SetTexture(COMP)
                    tiles[n] = t
                end
                local fx, fy = (col % 2 == 1), (row % 2 == 1)
                local l, r = PATCH[1], PATCH[1] + tw
                local tp, bt = PATCH[2], PATCH[2] + th
                if fx then l, r = PATCH[3], PATCH[3] - tw end
                if fy then tp, bt = PATCH[4], PATCH[4] - th end
                t:SetTexCoord(l / 256, r / 256, tp / 512, bt / 512)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", x, -y)
                t:SetSize(tw, th)
                t:Show()
                x = x + PW
                col = col + 1
            end
            y = y + PH
            row = row + 1
        end
        for i = n + 1, #tiles do tiles[i]:Hide() end
    end
    frame:HookScript("OnSizeChanged", Retile)

    -- Title in the bar
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", 50, -11)
    title:SetPoint("RIGHT", -36, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    o.title = title
    o.textures[#o.textures + 1] = title

    function o:SetShown(v)
        self.shown = v and true or false
        for _, t in ipairs(self.textures) do t:SetShown(v) end
        if v then Retile() else for _, t in ipairs(tiles) do t:Hide() end end
    end

    function o:SetPortrait(file)
        if SetPortraitToTexture and not portrait.AddMaskTexture then
            SetPortraitToTexture(portrait, file)
        else
            portrait:SetTexture(file)
        end
    end

    o:SetShown(false)
    return o
end
