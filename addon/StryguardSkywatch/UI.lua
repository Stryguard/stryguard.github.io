local _, ns = ...

-- The window: the board on the left, towers and the next wave on the right, and the
-- level select, shop, blessing, victory and game-over screens laid over the top.

local G = ns.Game
local Meta = ns.Meta
local UI = {}
ns.UI = UI

local floor, min, max = math.floor, math.min, math.max
local CELL, COLS, ROWS = ns.CELL, ns.COLS, ns.ROWS
local BW, BH = COLS * CELL, ROWS * CELL
local PAD, TOP, SIDE, FOOT = 8, 28, 196, 22
local W, H = PAD + BW + PAD + SIDE + PAD, TOP + BH + FOOT + PAD
local STEP = 1 / 30
local SIZE = CELL / 30    -- foe sizes in Data.lua are for 30-pixel squares
local FLAT = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local MEDIA = "Interface\\AddOns\\StryguardSkywatch\\media\\"
local ART_W, ART_H = 1024, 512   -- each map picture fills the top-left of a 1024x512 texture
local SLOT_W, SLOT_H, ATLAS_CELL = 512, 256, 18   -- atlases hold four smaller maps, 18 pixels a square
local ICON = "Interface\\Icons\\"
local STAR = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"
local SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
local SHEEP = ICON .. "Spell_Nature_Polymorph"

local INK = { 0.92, 0.86, 0.72 }
local GOLD = { 1, 0.82, 0.25 }
local EDGE = { 0.42, 0.33, 0.2 }
local BAD = { 1, 0.4, 0.3 }
local NEWS = { 0.5, 0.82, 1 }
local FX_COLOR = {
    archer = { 1, 0.9, 0.6 }, frost = { 0.55, 0.8, 1 }, fire = { 1, 0.5, 0.15 }, storm = { 0.75, 0.8, 1 },
    holy = { 1, 0.95, 0.55 }, heal = { 0.35, 1, 0.45 }, poof = { 0.85, 0.85, 0.85 }, build = { 1, 0.82, 0.25 },
    venom = { 0.5, 1, 0.35 }, arcane = { 0.85, 0.55, 1 }, trap = { 0.8, 0.8, 0.8 }, ward = { 0.5, 0.6, 1 },
    revive = { 0.6, 0.9, 0.5 }, cannon = { 1, 0.7, 0.35 }, ballista = { 0.9, 0.8, 0.6 }, shadow = { 0.65, 0.35, 0.85 },
    mage = { 0.5, 0.8, 1 }, harbor = { 1, 0.75, 0.4 }, rifle = { 1, 0.95, 0.75 }, rocket = { 1, 0.5, 0.3 },
    tesla = { 0.55, 0.9, 1 }, gryphon = { 1, 0.85, 0.45 }, quake = { 0.75, 0.6, 0.4 }, roots = { 0.4, 0.75, 0.3 },
    earthbind = { 0.7, 0.55, 0.35 }, camp = { 1, 0.6, 0.2 }, silence = { 0.6, 0.3, 0.9 }, shield = { 0.4, 0.7, 1 },
    blink = { 0.8, 0.6, 1 }, burrow = { 0.6, 0.45, 0.3 }, sheep = { 1, 1, 1 },
}
local GROUND = {
    ["."] = { 0.2, 0.27, 0.14 }, ["T"] = { 0.2, 0.27, 0.14 }, ["#"] = { 0.47, 0.38, 0.25 },
    ["~"] = { 0.16, 0.3, 0.45 }, ["S"] = { 0.3, 0.14, 0.34 }, ["E"] = { 0.45, 0.12, 0.12 },
    ["G"] = { 0.35, 0.36, 0.4 }, ["R"] = { 0.4, 0.38, 0.36 },
}
local MODE_NAME = { first = "First", strong = "Strongest", close = "Closest" }

local f, board, side, rangeLayer, towerLayer, enemyLayer, fxLayer
local cells, decos, towerViews, enemyViews, lines, rings = {}, {}, {}, {}, {}, {}
local towerButtons, info, waveBox = {}, {}, {}
local menu, shop, draft, victory, over, pauseBox, armoury, deeds
local stats, toastText, footLeft, footRight, flash, ghost, rangeTex, selTex, lairIcon, keepIcon, mapArt
local speedB, pauseB
local selected, building
local speed, acc, toastT, flashT, refreshT = 1, 0, 0, 0, 0
local pauseReason
local towersDirty = true
local menuChapter, heroicMode = nil, false
local shopPage, deedPage = 1, 1

-- Small builders ---------------------------------------------------------------

local function Tex(parent, layer, r, g, b, a, sub)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
    if r then t:SetColorTexture(r, g, b, a or 1) end
    return t
end

local function Round(parent, layer, sub)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
    local m = parent:CreateMaskTexture()
    m:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetAllPoints(t)
    t:AddMaskTexture(m)
    return t
end

local function Text(parent, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    return fs
end

local function Num(n)
    local s = tostring(floor(n + 0.5))
    local k
    repeat s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
    return s
end

local function Flat(frame, r, g, b, a)
    frame:SetBackdrop(FLAT)
    frame:SetBackdropColor(r or 0.1, g or 0.085, b or 0.07, a or 1)
    frame:SetBackdropBorderColor(EDGE[1], EDGE[2], EDGE[3], 1)
end

local function Light(b, on)
    b.lit = on
    local c = (on or (b:IsMouseOver() and b:IsEnabled())) and GOLD or EDGE
    b:SetBackdropBorderColor(c[1], c[2], c[3], 1)
end

local function Button(parent, w, h, label, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h)
    Flat(b, 0.2, 0.15, 0.1)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.label:SetPoint("CENTER")
    b.label:SetText(label or "")
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self)
        if self:IsEnabled() then self:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1) end
        if self.tip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            self.tip(GameTooltip)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        Light(self, self.lit)
        GameTooltip:Hide()
    end)
    return b
end

-- Only touch a button when its state changes: hiding or re-enabling it between mouse
-- down and up cancels the click, and the panel refreshes several times a second.
local function Shown(b, on)
    if b:IsShown() ~= on then b:SetShown(on) end
end

local function SetOn(b, on)
    if b:IsEnabled() ~= on then b:SetEnabled(on) end
    if on then b.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) else b.label:SetTextColor(0.5, 0.47, 0.42) end
    if b.icon then b.icon:SetDesaturated(not on) end
end

local function Overlay(cover, level)
    local o = CreateFrame("Frame", nil, f, "BackdropTemplate")
    if cover == "all" then
        o:SetPoint("TOPLEFT", PAD, -TOP)
        o:SetPoint("BOTTOMRIGHT", -PAD, PAD)
        o.w = W - 2 * PAD
    else
        o:SetAllPoints(board)
        o.w = BW
    end
    o:SetFrameLevel(f:GetFrameLevel() + (level or 20))
    Flat(o, 0.05, 0.04, 0.03, 0.94)
    o:EnableMouse(true)
    o:Hide()
    return o
end

local function Centered(parent, template, y, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", template)
    fs:SetPoint("TOP", 0, y)
    fs:SetWidth((parent.w or BW) - 30)
    fs:SetJustifyH("CENTER")
    if text then fs:SetText(text) end
    return fs
end

local function Stars(parent, size)
    local list = {}
    for k = 1, 3 do
        local t = parent:CreateTexture(nil, "ARTWORK")
        t:SetSize(size, size)
        t:SetTexture(STAR)
        list[k] = t
    end
    return list
end

local function SetStars(list, n)
    for k, t in ipairs(list) do
        local on = k <= n
        t:SetDesaturated(not on)
        t:SetAlpha(on and 1 or 0.3)
    end
end

local function Toast(msg, c)
    c = c or GOLD
    toastText:SetText(msg)
    toastText:SetTextColor(c[1], c[2], c[3])
    toastT = 3.5
end
UI.Toast = Toast

local function Save()
    if ns.Core then ns.Core.SaveRun() end
end

-- A run that can still be played (not lost, and not sitting on its victory screen).
local function Live(s)
    return s ~= nil and not s.over and not (s.won and not s.endless)
end

-- Effects ----------------------------------------------------------------------

local function Beam(x1, y1, x2, y2, kind)
    local l
    for _, o in ipairs(lines) do if o.ttl <= 0 then l = o break end end
    if not l then
        l = { line = fxLayer:CreateLine(nil, "OVERLAY") }
        lines[#lines + 1] = l
    end
    local c = FX_COLOR[kind] or INK
    l.line:SetColorTexture(c[1], c[2], c[3], 1)
    l.line:SetThickness(kind == "storm" and 2.5 or ((kind == "fire" or kind == "arcane") and 3 or 1.5))
    l.line:SetStartPoint("TOPLEFT", board, x1 * CELL, -y1 * CELL)
    l.line:SetEndPoint("TOPLEFT", board, x2 * CELL, -y2 * CELL)
    l.line:SetAlpha(1)
    l.line:Show()
    l.ttl, l.max = 0.14, 0.14
end

local function Ring(x, y, radius, kind, ttl)
    local o
    for _, r in ipairs(rings) do if r.ttl <= 0 then o = r break end end
    if not o then
        o = { tex = Round(fxLayer, "OVERLAY") }
        rings[#rings + 1] = o
    end
    local c = FX_COLOR[kind] or INK
    o.tex:SetColorTexture(c[1], c[2], c[3], 1)
    o.tex:ClearAllPoints()
    o.tex:SetPoint("CENTER", board, "TOPLEFT", x * CELL, -y * CELL)
    o.size = radius * 2 * CELL
    o.ttl = ttl or 0.35
    o.max = o.ttl
    o.tex:Show()
end

local function DrawEffects(el)
    for _, l in ipairs(lines) do
        if l.ttl > 0 then
            l.ttl = l.ttl - el
            if l.ttl <= 0 then l.line:Hide() else l.line:SetAlpha(l.ttl / l.max) end
        end
    end
    for _, o in ipairs(rings) do
        if o.ttl > 0 then
            o.ttl = o.ttl - el
            if o.ttl <= 0 then
                o.tex:Hide()
            else
                local frac = o.ttl / o.max
                local size = o.size * (0.6 + 0.4 * (1 - frac))
                o.tex:SetSize(size, size)
                o.tex:SetAlpha(0.45 * frac)
            end
        end
    end
end

-- The board ----------------------------------------------------------------------

-- Each map has a painted picture (made by tools/make_maps.py). The coloured squares
-- underneath are only a fallback for a map without one.
local function DrawMap()
    local s = G.s
    for _, d in ipairs(decos) do d:Hide() end
    local info = s.map.map
    local painted = mapArt:SetTexture(MEDIA .. (info.art or s.mapKey))
    if info.slot then
        local u0, v0 = (info.slot % 2) * SLOT_W / ART_W, floor(info.slot / 2) * SLOT_H / ART_H
        mapArt:SetTexCoord(u0, u0 + COLS * ATLAS_CELL / ART_W, v0, v0 + ROWS * ATLAS_CELL / ART_H)
    else
        mapArt:SetTexCoord(0, BW / ART_W, 0, BH / ART_H)
    end
    mapArt:SetShown(painted ~= false)
    lairIcon:SetShown(painted == false)
    keepIcon:SetShown(painted == false)
    if painted ~= false then return end
    local n = 0
    for r = 0, ROWS - 1 do
        for c = 0, COLS - 1 do
            local ch = s.grid[r][c]
            local col = GROUND[ch] or GROUND["."]
            local shade = (ch == "." or ch == "T") and ((r + c) % 2 == 0 and 1 or 0.9) or 1
            cells[r * 100 + c]:SetColorTexture(col[1] * shade, col[2] * shade, col[3] * shade, 1)
            local x, y = (c + 0.5) * CELL, -(r + 0.5) * CELL
            if ch == "T" then
                n = n + 1
                local t = decos[n] or Round(board, "BORDER")
                decos[n] = t
                t:SetColorTexture(0.09, 0.16, 0.07, 1)
                t:SetSize(CELL - 6, CELL - 6)
                t:ClearAllPoints()
                t:SetPoint("CENTER", board, "TOPLEFT", x, y)
                t:Show()
            elseif ch == "S" then
                lairIcon:SetPoint("CENTER", board, "TOPLEFT", x, y)
            elseif ch == "E" then
                keepIcon:SetPoint("CENTER", board, "TOPLEFT", x, y)
            end
        end
    end
end

-- A tower: a round stone base with a shadow, a ring in the tower's colour and its icon.
local function NewTowerView()
    local v = CreateFrame("Frame", nil, towerLayer)
    v:SetSize(CELL, CELL)
    v.shadow = Round(v, "BACKGROUND", -2)
    v.shadow:SetColorTexture(0, 0, 0, 0.45)
    v.shadow:SetPoint("TOPLEFT", 3, -5)
    v.shadow:SetPoint("BOTTOMRIGHT", 3, -1)
    v.base = Round(v, "BACKGROUND", -1)
    v.base:SetColorTexture(0.2, 0.18, 0.16, 1)
    v.base:SetPoint("TOPLEFT", 1, -1)
    v.base:SetPoint("BOTTOMRIGHT", -1, 1)
    v.edge = Round(v, "BACKGROUND")
    v.edge:SetPoint("TOPLEFT", 2, -2)
    v.edge:SetPoint("BOTTOMRIGHT", -2, 2)
    v.icon = Round(v, "ARTWORK")
    v.icon:SetPoint("TOPLEFT", 4, -4)
    v.icon:SetPoint("BOTTOMRIGHT", -4, 4)
    v.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    v.pips = {}
    for i = 1, 3 do
        local p = Tex(v, "OVERLAY", GOLD[1], GOLD[2], GOLD[3], 1)
        p:SetSize(4, 4)
        p:SetPoint("BOTTOM", (i - 2) * 5, 0)
        v.pips[i] = p
    end
    v.badge = Tex(v, "OVERLAY", nil, nil, nil, nil, 1)
    v.badge:SetSize(11, 11)
    v.badge:SetPoint("TOPRIGHT", -1, -1)
    return v
end

local function DrawTowers()
    towersDirty = false
    local list = G.s.towers
    for i, t in ipairs(list) do
        local v = towerViews[i]
        if not v then v = NewTowerView() towerViews[i] = v end
        v:SetPoint("TOPLEFT", board, "TOPLEFT", t.c * CELL, -t.r * CELL)
        v.icon:SetTexture(t.def.icon)
        local c = t.def.color
        v.edge:SetColorTexture(c[1], c[2], c[3], 1)
        -- Traps lie flat on the road, so they cast no shadow.
        v.shadow:SetShown(not t.def.road)
        for p = 1, 3 do v.pips[p]:SetShown(p <= t.level - 1 or t.level == 4) end
        if t.spec then
            for _, sp in ipairs(t.def.specs) do if sp.key == t.spec then v.badge:SetTexture(sp.icon) end end
            v.badge:Show()
        else
            v.badge:Hide()
        end
        v:Show()
    end
    for i = #list + 1, #towerViews do towerViews[i]:Hide() end
end

-- Silenced towers turn purple and grey until they come back.
local function TintTowers()
    for i, t in ipairs(G.s.towers) do
        local v = towerViews[i]
        if v then
            local quiet = (t.silenceT or 0) > 0
            if v.quiet ~= quiet then
                v.quiet = quiet
                v.icon:SetDesaturated(quiet)
                if quiet then v.icon:SetVertexColor(0.75, 0.5, 1) else v.icon:SetVertexColor(1, 1, 1) end
            end
        end
    end
end

local function NewEnemyView()
    local v = CreateFrame("Frame", nil, enemyLayer)
    v:SetSize(19, 19)
    v.shadow = Round(v, "BACKGROUND", -1)
    v.shadow:SetColorTexture(0, 0, 0, 0.4)
    v.ring = Round(v, "BACKGROUND")
    v.ring:SetAllPoints()
    v.icon = Round(v, "ARTWORK")
    v.icon:SetPoint("TOPLEFT", 2, -2)
    v.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    v.hpBg = Tex(v, "OVERLAY", 0, 0, 0, 0.85)
    v.hpBg:SetHeight(3)
    v.hpBg:SetPoint("BOTTOMLEFT", v, "TOPLEFT", 0, 1)
    v.hpBg:SetPoint("BOTTOMRIGHT", v, "TOPRIGHT", 0, 1)
    v.hp = Tex(v, "OVERLAY", 0.3, 0.9, 0.3, 1, 1)
    v.hp:SetHeight(3)
    v.hp:SetPoint("LEFT", v.hpBg, "LEFT")
    v.sh = Tex(v, "OVERLAY", 0.45, 0.75, 1, 1, 2)
    v.sh:SetHeight(2)
    v.sh:SetPoint("BOTTOMLEFT", v.hpBg, "TOPLEFT", 0, 0)
    return v
end

local function DrawEnemies()
    local list = G.s.enemies
    for i, e in ipairs(list) do
        local v = enemyViews[i]
        if not v then v = NewEnemyView() enemyViews[i] = v end
        local look = e.kind .. (e.elite and "+" or "") .. (e.giant and "^" or "") .. (e.sheepT > 0 and "~" or "")
        if v.look ~= look then
            v.look = look
            local d = e.def
            v.size = floor(((d.size or 19) + (e.elite and 6 or 0) + (e.giant and 8 or 0)) * SIZE + 0.5)
            v:SetSize(v.size, v.size)
            v.icon:SetTexture(e.sheepT > 0 and SHEEP or d.icon)
            v.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            local c = (d.boss or e.elite) and GOLD or d.color or INK
            v.ring:SetColorTexture(c[1], c[2], c[3], 1)
            v:SetFrameLevel(enemyLayer:GetFrameLevel() + (d.flying and 2 or 1))
            -- Flyers cast their shadow further away, so they read as up in the air.
            local off = d.flying and 6 or 2
            v.shadow:ClearAllPoints()
            v.shadow:SetPoint("TOPLEFT", off, -off - 1)
            v.shadow:SetPoint("BOTTOMRIGHT", off, -off + 2)
            v.shadow:SetAlpha(d.flying and 0.6 or 1)
            v.kind = e.kind
        end
        v:SetPoint("CENTER", board, "TOPLEFT", e.x * CELL, -e.y * CELL)
        local frac = max(0, e.hp / e.max)
        v.hp:SetWidth(max(1, v.size * frac))
        if frac > 0.5 then v.hp:SetColorTexture(0.3, 0.9, 0.3, 1)
        elseif frac > 0.25 then v.hp:SetColorTexture(0.95, 0.8, 0.2, 1)
        else v.hp:SetColorTexture(0.95, 0.3, 0.2, 1) end
        if e.shield > 0 then
            v.sh:SetWidth(max(1, v.size * min(1, e.shield / e.max)))
            v.sh:Show()
        else
            v.sh:Hide()
        end
        local alpha = e.seen and 1 or 0.3
        if not G.Touchable(e) then alpha = e.submergeT > 0 and 0.12 or 0.25 end
        v:SetAlpha(alpha)
        if e.stunT > 0 then v.icon:SetVertexColor(1, 1, 0.4)
        elseif e.slowT > 0 then v.icon:SetVertexColor(0.55, 0.75, 1)
        elseif e.burnT > 0 then v.icon:SetVertexColor(1, 0.6, 0.35)
        elseif e.poisonT > 0 then v.icon:SetVertexColor(0.6, 1, 0.45)
        else v.icon:SetVertexColor(1, 1, 1) end
        v:Show()
    end
    for i = #list + 1, #enemyViews do enemyViews[i]:Hide() end
end

local function CursorCell()
    if not board:IsMouseOver() then return end
    local x, y = GetCursorPosition()
    local sc = board:GetEffectiveScale()
    local left, top = board:GetLeft(), board:GetTop()
    if not left then return end
    local cx, cy = (x / sc - left) / CELL, (top - y / sc) / CELL
    if cx < 0 or cy < 0 or cx >= COLS or cy >= ROWS then return end
    return floor(cx), floor(cy)
end

local function ShowRange(x, y, radius, ok)
    rangeTex:ClearAllPoints()
    rangeTex:SetPoint("CENTER", board, "TOPLEFT", x * CELL, -y * CELL)
    rangeTex:SetSize(radius * 2 * CELL, radius * 2 * CELL)
    local c = ok == false and BAD or INK
    rangeTex:SetColorTexture(c[1], c[2], c[3], 0.13)
    rangeTex:Show()
end

local function DrawHover()
    local s = G.s
    local c, r = CursorCell()
    ghost:Hide()
    rangeTex:Hide()
    selTex:Hide()
    if selected and selected.removed then selected = nil end
    if building and c then
        local ok = G.CanBuild(c, r, building) and s.gold >= G.Price(building)
        ghost:SetPoint("TOPLEFT", board, "TOPLEFT", c * CELL, -r * CELL)
        ghost.icon:SetTexture(ns.TOWER[building].icon)
        local col = ok and { 0.3, 1, 0.3 } or BAD
        ghost.cell:SetColorTexture(col[1], col[2], col[3], 0.3)
        ghost:Show()
        ShowRange(c + 0.5, r + 0.5, G.BaseRange(building), ok)
    elseif selected then
        selTex:SetPoint("TOPLEFT", board, "TOPLEFT", selected.c * CELL, -selected.r * CELL)
        selTex:Show()
        if selected.st then ShowRange(selected.x, selected.y, selected.st.range) end
    elseif c then
        local t = s.at[r * 100 + c]
        if t and t.st then ShowRange(t.x, t.y, t.st.range) end
    end
end

local function OnBoardClick(_, button)
    local s = G.s
    if not s or s.over then return end
    if button == "RightButton" then
        building, selected = nil, nil
        UI.Refresh()
        return
    end
    local c, r = CursorCell()
    if not c then return end
    if building then
        local t = G.Build(building, c, r)
        if t then
            Ring(t.x, t.y, 0.7, "build", 0.3)
            if not IsShiftKeyDown() then building, selected = nil, t end
            Save()
        elseif s.gold < G.Price(building) then
            Toast("Not enough gold", BAD)
        elseif ns.TOWER[building].on == "#" then
            Toast(ns.TOWER[building].short .. " goes on the road", BAD)
        elseif ns.TOWER[building].on == "R" then
            Toast("Mining Camps go on rocks", BAD)
        elseif ns.TOWER[building].on == "~" then
            Toast("Harbor Batteries go on water or lava", BAD)
        else
            Toast("Can't build there", BAD)
        end
    else
        selected = s.at[r * 100 + c]
    end
    UI.Refresh()
end

-- The side panel -------------------------------------------------------------------

-- One line of numbers for a tower, from its stats (a def when first built, or t.st).
local function StatLine(d, live)
    local st = live or d
    local range = st.range or d.range
    if d.income then
        return ("+%d gold every wave"):format(floor((live and live.income or d.income[1]) * (G.s and G.s.level.ramp or 1) + 0.5))
    elseif d.mend then
        return ("Mends %.2f lives a wave"):format(live and live.mend or d.mend[1])
    elseif d.hasteAura then
        return ("Towers touching it attack %d%% faster"):format((d.hasteAura[1]) * 100 + 0.5)
    elseif st.mine then
        return ("Blast %d every %.1fs · Range %.1f"):format(st.damage, 1 / st.rate, range)
    end
    local how = st.attack or d.attack
    local dmg, rate = st.damage or d.damage, st.rate or d.rate
    if how == "pulse" then
        if dmg <= 0 then return ("Slows by %d%% · Range %.1f"):format((st.slow or 0) * 100 + 0.5, range) end
        return ("Hits all in reach for %d, every %.1fs · Range %.1f"):format(dmg, 1 / rate, range)
    elseif how == "venom" then
        return ("Hit %d · Poison %.1f/s per stack, up to %d · Range %.1f"):format(dmg, st.poison or d.poison, st.stacks or 5, range)
    elseif how == "beam" then
        return ("Beam %d-%d a second · Range %.1f"):format(dmg * rate, dmg * rate * (1 + (st.cap or d.cap)), range)
    elseif how == "missile" then
        return ("%d missiles of %d · %.1f casts a second · Range %.1f"):format(st.missiles or d.missiles, dmg, rate, range)
    elseif how == "curse" then
        return ("Damage %d · Curse +%d%% · Range %.1f"):format(dmg, (st.weaken or d.weaken) * 100 + 0.5, range)
    end
    return ("Damage %d · Range %.1f · %.1f a second"):format(dmg, range, rate)
end

local GROUND_NAME = { ["#"] = "Built on the road.", R = "Built on rocks.", ["~"] = "Built on water or lava." }

local function TowerTip(def)
    return function(tt)
        tt:AddLine(def.name)
        tt:AddLine(def.blurb, 1, 1, 1, true)
        tt:AddLine(StatLine(def), 0.8, 0.8, 0.8, true)
        local traits = {}
        if def.on then traits[#traits + 1] = GROUND_NAME[def.on] end
        if def.school == "magic" then traits[#traits + 1] = "Magic." else traits[#traits + 1] = "Physical." end
        if def.airOnly then traits[#traits + 1] = "Flyers only."
        elseif def.air then traits[#traits + 1] = "Hits flyers."
        elseif (def.damage or 0) > 0 then traits[#traits + 1] = "Ground only." end
        tt:AddLine(table.concat(traits, " "), 0.7, 0.7, 0.6, true)
        for _, sp in ipairs(def.specs) do tt:AddLine("At level 4: " .. sp.name .. ". " .. sp.desc, 0.6, 0.8, 1, true) end
        if not G.Unlocked(def.key) then
            tt:AddLine("Locked: win " .. ns.LEVEL[def.unlock].name .. " to unlock it.", 1, 0.45, 0.35, true)
        end
    end
end

local function BuildSide()
    side = CreateFrame("Frame", nil, f)
    side:SetSize(SIDE, BH + FOOT)
    side:SetPoint("TOPLEFT", board, "TOPRIGHT", PAD, 0)

    -- Nine slots, filled from the run's loadout (see UI.SetTowerButtons).
    for i = 1, ns.LOADOUT_SIZE do
        local b
        b = Button(side, 62, 44, "", function()
            local def = b.def
            if not def or not G.s or G.s.over then return end
            if not G.Unlocked(def.key) then
                Toast("Win " .. ns.LEVEL[def.unlock].name .. " to unlock the " .. def.name .. ".", BAD)
                return
            end
            selected = nil
            building = building ~= def.key and def.key or nil
            UI.Refresh()
        end)
        b:SetPoint("TOPLEFT", ((i - 1) % 3) * 67, -floor((i - 1) / 3) * 48)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(26, 26)
        b.icon:SetPoint("TOP", 0, -4)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.cost = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.cost:SetPoint("BOTTOM", 0, 3)
        b.tip = function(tt) if b.def then TowerTip(b.def)(tt) end end
        b:Hide()
        towerButtons[i] = b
    end

    -- What's selected.
    local p = CreateFrame("Frame", nil, side, "BackdropTemplate")
    p:SetSize(SIDE, 112)
    p:SetPoint("TOPLEFT", 0, -150)
    Flat(p)
    info.frame = p
    info.title = Text(p, "GameFontNormal")
    info.title:SetPoint("TOPLEFT", 6, -6)
    info.title:SetPoint("RIGHT", -6, 0)
    info.stats = Text(p)
    info.stats:SetPoint("TOPLEFT", info.title, "BOTTOMLEFT", 0, -3)
    info.stats:SetPoint("RIGHT", -6, 0)
    info.note = Text(p, "GameFontDisableSmall")
    info.note:SetPoint("TOPLEFT", info.stats, "BOTTOMLEFT", 0, -3)
    info.note:SetPoint("RIGHT", -6, 0)

    info.up = Button(p, SIDE - 12, 20, "Upgrade", function()
        if selected and G.Upgrade(selected) then Save() UI.Refresh() end
    end)
    info.up:SetPoint("BOTTOMLEFT", 6, 30)
    info.specs = {}
    for i = 1, 2 do
        local b = Button(p, 89, 28, "", function(self)
            if selected and self.spec and G.Upgrade(selected, self.spec.key) then Save() UI.Refresh() end
        end)
        b:SetPoint("BOTTOMLEFT", 6 + (i - 1) * 95, 28)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(20, 20)
        b.icon:SetPoint("LEFT", 4, 0)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.label:ClearAllPoints()
        b.label:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
        b.label:SetPoint("RIGHT", -3, 0)
        b.label:SetJustifyH("LEFT")
        b.tip = function(tt)
            if not (selected and b.spec) then return end
            tt:AddLine(b.spec.name)
            tt:AddLine(b.spec.desc, 1, 1, 1, true)
            tt:AddLine(("Costs %d gold. You can only pick one."):format(G.UpgradePrice(selected) or 0), 0.8, 0.8, 0.8, true)
        end
        info.specs[i] = b
    end
    info.mode = Button(p, 89, 18, "", function()
        if selected then G.CycleMode(selected) Save() UI.Refresh() end
    end)
    info.mode:SetPoint("BOTTOMLEFT", 6, 6)
    info.mode.tip = function(tt)
        tt:AddLine("Targeting")
        tt:AddLine("First: whoever is closest to the keep. Strongest: the most health. Closest: nearest to the tower.", 1, 1, 1, true)
    end
    info.sell = Button(p, 89, 18, "Sell", function()
        if selected then G.Sell(selected) selected = nil Save() UI.Refresh() end
    end)
    info.sell:SetPoint("BOTTOMLEFT", 101, 6)

    -- The next wave.
    local wb = CreateFrame("Frame", nil, side, "BackdropTemplate")
    wb:SetSize(SIDE, 70)
    wb:SetPoint("TOPLEFT", 0, -268)
    Flat(wb)
    waveBox.frame = wb
    waveBox.title = Text(wb, "GameFontNormalSmall")
    waveBox.title:SetPoint("TOPLEFT", 6, -6)
    waveBox.tag = Text(wb, "GameFontHighlightSmall")
    waveBox.tag:SetPoint("TOPRIGHT", -6, -6)
    waveBox.tag:SetJustifyH("RIGHT")
    waveBox.icons = {}
    for i = 1, 4 do
        local e = CreateFrame("Frame", nil, wb)
        e:SetSize(44, 18)
        e:SetPoint("TOPLEFT", 6 + (i - 1) * 46, -21)
        e.icon = Round(e, "ARTWORK")
        e.icon:SetSize(16, 16)
        e.icon:SetPoint("LEFT")
        e.count = Text(e)
        e.count:SetPoint("LEFT", e.icon, "RIGHT", 3, 0)
        e:EnableMouse(true)
        e:SetScript("OnEnter", function(self)
            if not self.kind then return end
            local d = ns.ENEMIES[self.kind]
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(d.name)
            if ns.INTRO[self.kind] then GameTooltip:AddLine(ns.INTRO[self.kind], 1, 1, 1, true) end
            if d.boss then GameTooltip:AddLine(("Costs %d lives if it reaches the keep."):format(d.lives or 1), 1, 0.5, 0.4) end
            GameTooltip:Show()
        end)
        e:SetScript("OnLeave", function() GameTooltip:Hide() end)
        waveBox.icons[i] = e
    end
    waveBox.go = Button(wb, 132, 20, "", function()
        if G.s and not G.s.over then G.NextWave() UI.Refresh() end
    end)
    waveBox.go:SetPoint("BOTTOMLEFT", 6, 6)
    waveBox.auto = Button(wb, 48, 20, "", function()
        G.auto = not G.auto
        ns.db.opts.auto = G.auto
        UI.Refresh()
    end)
    waveBox.auto:SetPoint("BOTTOMRIGHT", -6, 6)
    waveBox.auto.tip = function(tt)
        tt:AddLine("Auto waves")
        tt:AddLine("When on, the next wave starts by itself a few seconds after the last one is cleared.", 1, 1, 1, true)
    end
end

-- The numbers line for a built tower.
local function TowerStats(t)
    local st = t.st
    if t.kind == "drums" then
        return ("Towers touching it attack faster")
    end
    return StatLine(t.def, st)
end

local function RefreshInfo()
    local s = G.s
    local show = {}
    info.note:SetText("")
    local t = selected
    if t and t.st then
        local d, st = t.def, t.st
        local name = d.name
        if t.spec then
            for _, sp in ipairs(d.specs) do if sp.key == t.spec then name = d.name .. ": " .. sp.name end end
        else
            name = name .. "  |cffbbbbbb(level " .. t.level .. ")|r"
        end
        info.title:SetText(name)
        info.stats:SetText(TowerStats(t))
        local notes = {}
        if t.dealt >= 1 then notes[#notes + 1] = "Dealt " .. Num(t.dealt) .. " damage" end
        if st.aura > 0 then notes[#notes + 1] = ("+%d%% from a beacon"):format(st.aura * 100 + 0.5) end
        if t.kind == "holy" then notes[#notes + 1] = ("Lifts towers around it by %d%%"):format((t.spec == "crusader" and 0.5 or d.aura[t.level]) * 100 + 0.5) end
        if t.kind == "arcane" and t.ramp > 0 then notes[#notes + 1] = ("Power x%.1f"):format(1 + t.ramp) end
        if (t.silenceT or 0) > 0 then notes[#notes + 1] = "|cffb080ffSilenced!|r" end
        info.note:SetText(table.concat(notes, ". "))

        local price = G.UpgradePrice(t)
        if t.level < 3 then
            info.up.label:SetText(("Upgrade to level %d (%dg)"):format(t.level + 1, price))
            SetOn(info.up, s.gold >= price and not s.over)
            show[info.up] = true
        elseif t.level == 3 then
            for i, sp in ipairs(d.specs) do
                local b = info.specs[i]
                b.spec = sp
                b.icon:SetTexture(sp.icon)
                b.label:SetText(sp.name .. "\n|cffffffff" .. price .. "g|r")
                SetOn(b, s.gold >= price and not s.over)
                show[b] = true
            end
        end
        if (st.rate or 0) > 0 and not st.pulse then
            info.mode.label:SetText("Target: " .. MODE_NAME[t.mode])
            SetOn(info.mode, true)
            show[info.mode] = true
        end
        info.sell.label:SetText(("Sell (%dg)"):format(G.SellValue(t)))
        SetOn(info.sell, not s.over)
        show[info.sell] = true
    elseif building then
        local d = ns.TOWER[building]
        info.title:SetText(d.name .. "  |cffffd100" .. G.Price(building) .. "g|r")
        info.stats:SetText(d.blurb)
        local where = ({ ["#"] = "Click a road square to build. ", R = "Click a rock to build. ", ["~"] = "Click water or lava to build. " })[d.on or ""]
        info.note:SetText((where or "Click an empty square to build. ") .. "Shift-click to keep building. Right-click to stop.")
    else
        info.title:SetText("Hold the road")
        info.stats:SetText(("Hold all %d waves to win %s. Pick a tower, then click an empty square."):format(s.level.waves, s.map.name))
        info.note:SetText("Every fourth wave you choose a blessing. Click a tower to upgrade or sell it.")
    end
    for _, b in ipairs({ info.up, info.specs[1], info.specs[2], info.mode, info.sell }) do
        Shown(b, show[b] == true)
    end
end

-- Fill the nine tower buttons from the run's loadout.
function UI.SetTowerButtons()
    local list = G.s and G.s.loadout or Meta.Loadout()
    for i, b in ipairs(towerButtons) do
        local def = list[i] and ns.TOWER[list[i]]
        b.def = def
        if def then
            b.icon:SetTexture(def.icon)
            b:Show()
        else
            b:Hide()
        end
    end
end

local function RefreshWave()
    local s = G.s
    local w = G.Preview()
    if w.n > s.level.waves then
        waveBox.title:SetText(("Next: wave %d (endless)"):format(w.n))
    else
        waveBox.title:SetText(("Next: wave %d of %d"):format(w.n, s.level.waves))
    end
    if w.boss then
        waveBox.tag:SetText(w.final and "|cffff6040Final boss!|r" or "|cffff6040Boss!|r")
    elseif w.affix then
        waveBox.tag:SetText("|cffff9040" .. ns.AFFIXES[w.affix].name .. "|r")
    elseif w.new then
        waveBox.tag:SetText("|cff80d0ffNew foe|r")
    else
        waveBox.tag:SetText("")
    end
    for i, e in ipairs(waveBox.icons) do
        local g = w.groups[i]
        if g then
            local d = ns.ENEMIES[g.kind]
            e.kind = g.kind
            e.icon:SetTexture(d.icon)
            e.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            e.count:SetText(d.boss and "Boss" or ("x" .. g.count))
            e:Show()
        else
            e.kind = nil
            e:Hide()
        end
    end
    local label
    if s.won and not s.endless then
        label = "Level won!"
    elseif s.wave == 0 then
        label = "Start wave 1"
    elseif not s.idle then
        label = ("Send early (+%dg)"):format(G.EarlyBonus())
    elseif G.auto and s.autoT then
        label = ("Next wave (%d)"):format(max(0, math.ceil(s.autoT)))
    else
        label = "Next wave"
    end
    waveBox.go.label:SetText(label)
    SetOn(waveBox.go, Live(s) and not s.draft)
    waveBox.auto.label:SetText(G.auto and "Auto" or "|cff888888Auto|r")
    Light(waveBox.auto, G.auto)
end

-- Overlays -----------------------------------------------------------------------

local function HideOverlays()
    menu:Hide()
    shop:Hide()
    armoury:Hide()
    deeds:Hide()
    draft:Hide()
    victory:Hide()
    over:Hide()
end

local function AfterLoad()
    selected, building = nil, nil
    acc = 0
    HideOverlays()
    DrawMap()
    UI.SetTowerButtons()
    towersDirty = true
    pauseReason = nil
    if G.s.draft then UI.ShowDraft() end
    UI.Refresh()
end

local function StartMap(levelKey, heroic)
    if not Meta.LevelOpen(levelKey) then return end
    if heroic and not Meta.Cleared(levelKey) then heroic = false end
    G.New(levelKey, nil, false, heroic)
    AfterLoad()
    Save()
    Toast(("%s%s: hold %d waves. Build some towers, then start the first wave."):format(heroic and "Heroic " or "", G.s.map.name, G.s.level.waves))
end

-- The chapter the menu shows by default: the one being played, or the furthest open.
local function CurrentChapter()
    if G.s then return G.s.level.chapter end
    local best = 1
    for c = 1, #ns.CHAPTERS do if Meta.ChapterOpen(c) then best = c end end
    return best
end

local function BuildMenu()
    menu = Overlay("all")
    Centered(menu, "GameFontNormalHuge", -10, "Skywatch")
    menu.sub = Centered(menu, "GameFontHighlight", -36, "Hold the road to Stryguard keep. Win a level to open the next road.")
    menu.cont = Button(menu, 250, 24, "", function()
        if Live(G.s) then
            menu:Hide()
            G.paused, pauseReason = false, nil
        elseif G.Restore(ns.db.run) then
            AfterLoad()
            Toast("Welcome back. Wave " .. G.s.wave .. " held on " .. G.s.map.name .. ".")
        end
        UI.Refresh()
    end)
    menu.cont:SetPoint("TOPLEFT", 8, -58)
    menu.shopB = Button(menu, 160, 24, "", function() UI.ShowShop() end)
    menu.shopB:SetPoint("LEFT", menu.cont, "RIGHT", 8, 0)
    menu.shopB.tip = function(tt)
        tt:AddLine("The Quartermaster")
        tt:AddLine("Spend marks on upgrades that last for every run. You earn marks by holding waves, slaying bosses, winning levels and doing deeds.", 1, 1, 1, true)
    end
    menu.armB = Button(menu, 160, 24, "Armoury", function() UI.ShowArmoury() end)
    menu.armB:SetPoint("LEFT", menu.shopB, "RIGHT", 8, 0)
    menu.armB.tip = function(tt)
        tt:AddLine("The Armoury")
        tt:AddLine("Choose the nine towers you bring on a run.", 1, 1, 1, true)
    end
    menu.deedB = Button(menu, 160, 24, "", function() UI.ShowDeeds() end)
    menu.deedB:SetPoint("LEFT", menu.armB, "RIGHT", 8, 0)
    menu.deedB.tip = function(tt)
        tt:AddLine("Deeds")
        tt:AddLine("Feats that pay marks once.", 1, 1, 1, true)
    end

    -- Chapter picker and Heroic switch.
    menu.prev = Button(menu, 26, 22, "<", function()
        menuChapter = max(1, (menuChapter or 1) - 1)
        menu.armed = nil
        UI.RefreshMenu()
    end)
    menu.prev:SetPoint("TOPLEFT", 8, -90)
    menu.next = Button(menu, 26, 22, ">", function()
        menuChapter = min(#ns.CHAPTERS, (menuChapter or 1) + 1)
        menu.armed = nil
        UI.RefreshMenu()
    end)
    menu.next:SetPoint("LEFT", menu.prev, "RIGHT", 4, 0)
    menu.chTitle = Text(menu, "GameFontNormalLarge")
    menu.chTitle:SetPoint("LEFT", menu.next, "RIGHT", 10, 1)
    menu.chBlurb = Text(menu, "GameFontDisableSmall")
    menu.chBlurb:SetPoint("LEFT", menu.chTitle, "RIGHT", 10, -1)
    menu.chBlurb:SetPoint("RIGHT", menu, "TOPRIGHT", -166, -101)
    menu.chBlurb:SetWordWrap(false)
    menu.heroic = Button(menu, 150, 22, "", function()
        heroicMode = not heroicMode
        menu.armed = nil
        UI.RefreshMenu()
    end)
    menu.heroic:SetPoint("TOPRIGHT", -8, -90)
    menu.heroic.tip = function(tt)
        tt:AddLine("Heroic")
        tt:AddLine("For levels you've won: tougher foes, an affix on every other wave and half the lives. Pays half as much again, and earns skulls instead of stars.", 1, 1, 1, true)
    end

    menu.cards = {}
    for i = 1, 6 do
        local b
        b = Button(menu, 248, 86, "", function()
            local def = b.def
            if not def or not Meta.LevelOpen(def.key) then return end
            if heroicMode and not Meta.Cleared(def.key) then
                Toast("Win " .. def.name .. " first to play it on Heroic.", BAD)
                return
            end
            local running = Live(G.s) or ns.db.run
            if running and menu.armed ~= def.key then
                menu.armed = def.key
                UI.RefreshMenu()
                return
            end
            menu.armed = nil
            StartMap(def.key, heroicMode)
        end)
        local col, row = (i - 1) % 3, floor((i - 1) / 3)
        b:SetPoint("TOP", (col - 1) * 256, -118 - row * 92)
        b.label:ClearAllPoints()
        b.label:SetPoint("TOP", 0, -7)
        b.label:SetFontObject("GameFontNormalLarge")
        b.blurb = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.blurb:SetPoint("TOP", 0, -28)
        b.blurb:SetWidth(228)
        b.info = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        b.info:SetPoint("BOTTOMLEFT", 8, 7)
        b.info:SetJustifyH("LEFT")
        b.stars = Stars(b, 14)
        for k, t in ipairs(b.stars) do t:SetPoint("BOTTOMRIGHT", -8 - (3 - k) * 16, 5) end
        b.skulls = {}
        for k = 1, 3 do
            local t = b:CreateTexture(nil, "ARTWORK")
            t:SetSize(12, 12)
            t:SetTexture(SKULL)
            t:SetPoint("BOTTOMRIGHT", -8 - (3 - k) * 14 - 52, 6)
            b.skulls[k] = t
        end
        menu.cards[i] = b
    end
    menu.flights = Button(menu, 230, 20, "", function()
        ns.db.opts.autoOpen = not ns.db.opts.autoOpen
        UI.RefreshMenu()
    end)
    menu.flights:SetPoint("TOPRIGHT", menu, "TOP", -4, -306)
    menu.land = Button(menu, 230, 20, "", function()
        ns.db.opts.autoPause = not ns.db.opts.autoPause
        UI.RefreshMenu()
    end)
    menu.land:SetPoint("TOPLEFT", menu, "TOP", 4, -306)
    Centered(menu, "GameFontDisableSmall", -332,
        "/skywatch opens and closes this window. Your run is saved between waves, so it carries over to your next flight.")
end

function UI.RefreshMenu()
    local s = G.s
    local saved = type(ns.db.run) == "table" and (ns.db.run.v == 2 or ns.db.run.v == 3) and ns.LEVEL[ns.db.run.map] and ns.db.run or nil
    if Live(s) then
        menu.cont.label:SetText(("Back to %s (wave %d)"):format(s.map.name, s.wave))
        menu.cont:Show()
    elseif saved then
        menu.cont.label:SetText(("Continue: %s (wave %d)"):format(ns.LEVEL[saved.map].name, saved.wave or 0))
        menu.cont:Show()
    else
        menu.cont:Hide()
    end
    menu.shopB.label:SetText(("Shop  ·  %d marks"):format(Meta.Marks()))
    menu.deedB.label:SetText(("Deeds  ·  %d/%d"):format(Meta.DeedCount(), #ns.DEEDS))
    menuChapter = menuChapter or CurrentChapter()
    local ch = ns.CHAPTERS[menuChapter]
    menu.chTitle:SetText(("%d. %s"):format(menuChapter, ch.name))
    menu.chBlurb:SetText(ch.blurb)
    SetOn(menu.prev, menuChapter > 1)
    SetOn(menu.next, menuChapter < #ns.CHAPTERS)
    menu.heroic.label:SetText(heroicMode and "|cffff6040Heroic: on|r" or "Heroic: off")
    Light(menu.heroic, heroicMode)
    for i, b in ipairs(menu.cards) do
        local def = ch.levels[i]
        b.def = def
        local open = Meta.LevelOpen(def.key)
        local p = Meta.Progress(def.key)
        local playable = open and (not heroicMode or Meta.Cleared(def.key))
        SetOn(b, playable)
        b.label:SetText(((menuChapter - 1) * 6 + i) .. ". " .. def.name)
        if open then
            b.blurb:SetText(def.blurb)
        else
            b.blurb:SetText("Win " .. ns.LEVELS[def.index - 1].name .. " to open this road.")
        end
        if menu.armed == def.key then
            b.info:SetText("|cffff6050Click again to give up your current run|r")
        elseif open then
            local text = def.waves .. " waves"
            local tower = Meta.TowerFrom(def.key)
            if tower and not Meta.Cleared(def.key) then text = text .. "  ·  |cff80d0ffunlocks " .. tower.short .. "|r" end
            if p and p.endless then text = text .. ("  ·  endless %d"):format(p.endless) end
            b.info:SetText(text)
        else
            b.info:SetText("Locked")
        end
        SetStars(b.stars, p and p.stars or 0)
        for _, t in ipairs(b.stars) do t:SetShown(open) end
        local sk = p and p.heroic or 0
        for k, t in ipairs(b.skulls) do
            t:SetShown(open and (Meta.Cleared(def.key)))
            t:SetDesaturated(k > sk)
            t:SetAlpha(k <= sk and 1 or 0.25)
        end
    end
    menu.flights.label:SetText("Open when a flight starts: " .. (ns.db.opts.autoOpen and "on" or "off"))
    menu.land.label:SetText("Pause when I land: " .. (ns.db.opts.autoPause and "on" or "off"))
end

function UI.ShowMenu()
    if G.s and not G.s.over then G.paused = true end
    menu.armed = nil
    menuChapter = CurrentChapter()
    UI.RefreshMenu()
    menu:Show()
end

-- A row of page buttons for a paged overlay.
local function Pager(parent, onTurn)
    local p = {}
    p.prev = Button(parent, 26, 20, "<", function() onTurn(-1) end)
    p.prev:SetPoint("TOPRIGHT", -150, -8)
    p.label = Text(parent, "GameFontHighlightSmall")
    p.label:SetPoint("LEFT", p.prev, "RIGHT", 6, 0)
    p.label:SetWidth(36)
    p.label:SetJustifyH("CENTER")
    p.next = Button(parent, 26, 20, ">", function() onTurn(1) end)
    p.next:SetPoint("LEFT", p.label, "RIGHT", 6, 0)
    function p.Set(page, pages)
        p.label:SetText(page .. "/" .. pages)
        SetOn(p.prev, page > 1)
        SetOn(p.next, page < pages)
    end
    return p
end

local SHOP_PER_PAGE = 12

local function BuildShop()
    shop = Overlay("all", 30)
    Centered(shop, "GameFontNormalHuge", -12, "The Quartermaster")
    shop.marks = Centered(shop, "GameFontHighlight", -40)
    local back = Button(shop, 70, 20, "Back", function()
        shop:Hide()
        UI.RefreshMenu()
    end)
    back:SetPoint("TOPRIGHT", -8, -8)
    shop.pager = Pager(shop, function(d)
        shopPage = max(1, min(math.ceil(#ns.SHOP / SHOP_PER_PAGE), shopPage + d))
        UI.RefreshShop()
    end)
    shop.cards = {}
    for i = 1, SHOP_PER_PAGE do
        local b
        b = Button(shop, 186, 92, "", function()
            if b.item and Meta.Buy(b.item.key) then
                G.Refresh()
                UI.RefreshShop()
            end
        end)
        local col, row = (i - 1) % 4, floor((i - 1) / 4)
        b:SetPoint("TOPLEFT", 4 + col * 192, -60 - row * 98)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(28, 28)
        b.icon:SetPoint("TOPLEFT", 6, -6)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.label:ClearAllPoints()
        b.label:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 6, 0)
        b.label:SetPoint("RIGHT", -6, 0)
        b.label:SetJustifyH("LEFT")
        b.label:SetFontObject("GameFontNormal")
        b.rank = Text(b, "GameFontDisableSmall")
        b.rank:SetPoint("TOPLEFT", b.label, "BOTTOMLEFT", 0, -3)
        b.desc = Text(b, "GameFontHighlightSmall")
        b.desc:SetPoint("TOPLEFT", 6, -40)
        b.desc:SetWidth(174)
        b.cost = Text(b, "GameFontNormalSmall")
        b.cost:SetPoint("BOTTOMRIGHT", -6, 6)
        b.cost:SetJustifyH("RIGHT")
        shop.cards[i] = b
    end
end

function UI.RefreshShop()
    local marks = Meta.Marks()
    local pages = math.ceil(#ns.SHOP / SHOP_PER_PAGE)
    shopPage = min(shopPage, pages)
    shop.pager.Set(shopPage, pages)
    shop.marks:SetText(("You have |cffffd100%d|r marks. Upgrades last for every run. Click one to buy it."):format(marks))
    for i, b in ipairs(shop.cards) do
        local it = ns.SHOP[(shopPage - 1) * SHOP_PER_PAGE + i]
        b.item = it
        if not it then
            b:Hide()
        else
            b:Show()
            b.icon:SetTexture(it.icon)
            b.label:SetText(it.name)
            b.desc:SetText(it.desc)
            local rank, price = Meta.Rank(it.key), Meta.Price(it.key)
            b.rank:SetText(("Rank %d of %d"):format(rank, it.max))
            if price then
                SetOn(b, marks >= price)
                b.cost:SetText(("%d marks"):format(price))
                if marks >= price then b.cost:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) else b.cost:SetTextColor(0.6, 0.3, 0.25) end
            else
                SetOn(b, false)
                b.icon:SetDesaturated(false)
                b.cost:SetText("Maxed")
                b.cost:SetTextColor(0.5, 1, 0.5)
            end
            b.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        end
    end
end

function UI.ShowShop()
    UI.RefreshShop()
    shop:Show()
end

-- The armoury: pick the nine towers for your runs.
local function BuildArmoury()
    armoury = Overlay("all", 30)
    Centered(armoury, "GameFontNormalHuge", -12, "The Armoury")
    armoury.head = Centered(armoury, "GameFontHighlight", -40)
    local back = Button(armoury, 70, 20, "Back", function()
        armoury:Hide()
        UI.RefreshMenu()
    end)
    back:SetPoint("TOPRIGHT", -8, -8)
    armoury.cards = {}
    for i, def in ipairs(ns.TOWERS) do
        local b = Button(armoury, 122, 64, "", function()
            if not G.Unlocked(def.key) then
                Toast("Win " .. ns.LEVEL[def.unlock].name .. " to unlock the " .. def.name .. ".", BAD)
                return
            end
            if not Meta.ToggleLoadout(def.key) then
                Toast(#Meta.Loadout() >= ns.LOADOUT_SIZE and "The loadout is full: take a tower out first." or "Bring at least one tower.", BAD)
            end
            UI.RefreshArmoury()
            if not G.s then UI.SetTowerButtons() end
        end)
        local col, row = (i - 1) % 6, floor((i - 1) / 6)
        b:SetPoint("TOPLEFT", 4 + col * 128, -62 - row * 70)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(30, 30)
        b.icon:SetPoint("TOPLEFT", 6, -6)
        b.icon:SetTexture(def.icon)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.label:ClearAllPoints()
        b.label:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 5, -1)
        b.label:SetPoint("RIGHT", -4, 0)
        b.label:SetJustifyH("LEFT")
        b.label:SetText(def.short)
        b.cost = Text(b, "GameFontHighlightSmall")
        b.cost:SetPoint("TOPLEFT", b.label, "BOTTOMLEFT", 0, -3)
        b.state = Text(b, "GameFontDisableSmall")
        b.state:SetPoint("BOTTOMLEFT", 6, 6)
        b.state:SetPoint("RIGHT", -4, 0)
        b.def = def
        b.tip = TowerTip(def)
        armoury.cards[i] = b
    end
end

function UI.RefreshArmoury()
    local list = Meta.Loadout()
    armoury.head:SetText(("Bring up to %d towers on a run: %d chosen. Click to add or take out.%s"):format(
        ns.LOADOUT_SIZE, #list, Live(G.s) and " Changes start with your next run." or ""))
    for _, b in ipairs(armoury.cards) do
        local def = b.def
        local unlocked = G.Unlocked(def.key)
        local inl = Meta.InLoadout(def.key)
        b.cost:SetText(def.cost .. "g" .. (def.on and ("  ·  " .. ({ ["#"] = "road", R = "rocks", ["~"] = "water" })[def.on]) or ""))
        if not unlocked then
            b.state:SetText("Win " .. ns.LEVEL[def.unlock].name)
            b.icon:SetDesaturated(true)
            b.label:SetTextColor(0.5, 0.47, 0.42)
        else
            b.state:SetText(inl and "|cff60ff60In the loadout|r" or "In reserve")
            b.icon:SetDesaturated(not inl)
            b.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        end
        Light(b, inl)
    end
end

function UI.ShowArmoury()
    UI.RefreshArmoury()
    armoury:Show()
end

-- The book of deeds.
local DEEDS_PER_PAGE = 18

local function BuildDeeds()
    deeds = Overlay("all", 30)
    Centered(deeds, "GameFontNormalHuge", -12, "Deeds")
    deeds.head = Centered(deeds, "GameFontHighlight", -40)
    local back = Button(deeds, 70, 20, "Back", function()
        deeds:Hide()
        UI.RefreshMenu()
    end)
    back:SetPoint("TOPRIGHT", -8, -8)
    deeds.pager = Pager(deeds, function(d)
        deedPage = max(1, min(math.ceil(#ns.DEEDS / DEEDS_PER_PAGE), deedPage + d))
        UI.RefreshDeeds()
    end)
    deeds.rows = {}
    for i = 1, DEEDS_PER_PAGE do
        local r = CreateFrame("Frame", nil, deeds, "BackdropTemplate")
        r:SetSize(252, 46)
        Flat(r, 0.12, 0.1, 0.08)
        local col, row = (i - 1) % 3, floor((i - 1) / 3)
        r:SetPoint("TOPLEFT", 6 + col * 256, -60 - row * 49)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(34, 34)
        r.icon:SetPoint("LEFT", 6, 0)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.name = Text(r, "GameFontNormalSmall")
        r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 6, -1)
        r.name:SetPoint("RIGHT", -44, 0)
        r.desc = Text(r, "GameFontHighlightSmall")
        r.desc:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
        r.desc:SetPoint("RIGHT", -6, 0)
        r.desc:SetHeight(24)
        r.desc:SetJustifyV("TOP")
        r.marks = Text(r, "GameFontNormalSmall")
        r.marks:SetPoint("TOPRIGHT", -6, -5)
        r.marks:SetJustifyH("RIGHT")
        deeds.rows[i] = r
    end
end

function UI.RefreshDeeds()
    local pages = math.ceil(#ns.DEEDS / DEEDS_PER_PAGE)
    deedPage = min(deedPage, pages)
    deeds.pager.Set(deedPage, pages)
    deeds.head:SetText(("%d of %d deeds done. Each pays marks once."):format(Meta.DeedCount(), #ns.DEEDS))
    for i, r in ipairs(deeds.rows) do
        local d = ns.DEEDS[(deedPage - 1) * DEEDS_PER_PAGE + i]
        if not d then
            r:Hide()
        else
            r:Show()
            local done = Meta.HasDeed(d.key)
            r.icon:SetTexture(d.icon)
            r.icon:SetDesaturated(not done)
            r.name:SetText(d.name)
            if done then r.name:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) else r.name:SetTextColor(0.6, 0.56, 0.5) end
            r.desc:SetText(d.desc)
            r.marks:SetText(done and "|cff60ff60Done|r" or (d.marks .. "m"))
            r:SetBackdropBorderColor((done and GOLD or EDGE)[1], (done and GOLD or EDGE)[2], (done and GOLD or EDGE)[3], 1)
        end
    end
end

function UI.ShowDeeds()
    UI.RefreshDeeds()
    deeds:Show()
end

local function BuildDraft()
    draft = Overlay("board")
    draft.head = Centered(draft, "GameFontNormalLarge", -16)
    Centered(draft, "GameFontHighlightSmall", -40, "Choose a blessing. It lasts for the rest of the run.")
    draft.cards = {}
    for i = 1, 5 do
        local b = Button(draft, 160, 200, "", function(self)
            if self.bkey then
                G.Bless(self.bkey)
                Toast(ns.BLESSING[self.bkey].name .. "!")
                if not G.s.draft then draft:Hide() end
                Save()
                UI.Refresh()
            end
        end)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(40, 40)
        b.icon:SetPoint("TOP", 0, -14)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.label:ClearAllPoints()
        b.label:SetPoint("TOP", b.icon, "BOTTOM", 0, -10)
        b.label:SetFontObject("GameFontNormal")
        b.desc = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.desc:SetPoint("TOP", b.label, "BOTTOM", 0, -8)
        b.stack = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        b.stack:SetPoint("BOTTOM", 0, 10)
        draft.cards[i] = b
    end
    draft.reroll = Button(draft, 170, 22, "", function()
        if G.Reroll() then Save() end
    end)
    draft.reroll:SetPoint("TOP", 0, -282)
end

function UI.ShowDraft()
    local s = G.s
    if not s or not s.draft then return end
    draft.head:SetText(s.wave == 0 and "A blessing for the road" or ("Wave " .. s.wave .. " held!"))
    local n = #s.draft
    local w = n >= 5 and 104 or (n == 4 and 132 or 160)
    for i, b in ipairs(draft.cards) do
        local bk = s.draft[i]
        if bk then
            local d = ns.BLESSING[bk]
            b.bkey = bk
            b:SetWidth(w)
            b:ClearAllPoints()
            b:SetPoint("TOP", (i - (n + 1) / 2) * (w + 10), -64)
            b.desc:SetWidth(w - 16)
            b.icon:SetTexture(d.icon)
            b.label:SetText(d.name)
            b.desc:SetText(d.desc)
            local have = s.bless[bk] or 0
            b.stack:SetText(d.max > 1 and ("Taken %d of %d"):format(have, d.max) or "Once only")
            b:Show()
        else
            b.bkey = nil
            b:Hide()
        end
    end
    local left = s.rerollsLeft or 0
    draft.reroll.label:SetText(("Reroll  (%d left)"):format(left))
    draft.reroll:SetShown(left > 0)
    draft:Show()
end

local function BuildVictory()
    victory = Overlay("board")
    victory.head = Centered(victory, "GameFontNormalHuge", -34, "Victory!")
    victory.sub = Centered(victory, "GameFontHighlight", -66)
    victory.stars = Stars(victory, 32)
    for k, t in ipairs(victory.stars) do t:SetPoint("TOP", (k - 2) * 40, -92) end
    victory.body = Centered(victory, "GameFontHighlight", -140)
    victory.endless = Button(victory, 170, 26, "Keep going (endless)", function()
        G.Endless()
        victory:Hide()
        Save()
        Toast("Endless: how long can the keep hold?")
        UI.Refresh()
    end)
    victory.endless:SetPoint("TOPRIGHT", victory, "TOP", -91, -262)
    victory.endless.tip = function(tt)
        tt:AddLine("Endless")
        tt:AddLine("Carry on past the last wave. Waves keep getting harder, with a boss every tenth, and each one held pays an extra mark.", 1, 1, 1, true)
    end
    victory.next = Button(victory, 170, 26, "Next level", function()
        if victory.nextKey then StartMap(victory.nextKey) end
    end)
    victory.next:SetPoint("TOP", 0, -262)
    local maps = Button(victory, 170, 26, "Pick a level", function()
        victory:Hide()
        UI.ShowMenu()
    end)
    maps:SetPoint("TOPLEFT", victory, "TOP", 91, -262)
end

local function ShowVictory(stars)
    local s = G.s
    local r = Meta.Victory(s.mapKey, stars, s.heroic)
    Meta.CheckDeeds("win", s, stars)
    victory.head:SetText(s.heroic and "Heroic victory!" or "Victory!")
    victory.sub:SetText(("%s held for all %d waves."):format(s.map.name, s.level.waves))
    SetStars(victory.stars, stars)
    for _, t in ipairs(victory.stars) do t:SetTexture(s.heroic and SKULL or STAR) end
    local text = {}
    text[#text + 1] = s.lost == 0 and "Not a single life lost!" or ("Lives lost: %d"):format(s.lost)
    text[#text + 1] = ("Marks this run: |cffffd100%d|r  (you have %d)"):format(s.marks, Meta.Marks())
    if r.tower then
        text[#text + 1] = ("New tower: |cff80d0ff%s|r%s"):format(r.tower.name,
            Meta.InLoadout(r.tower.key) and " (added to your loadout)" or " (add it in the Armoury)")
    end
    if r.first and not r.heroic and r.nextLevel then
        local ch = ns.CHAPTERS[r.nextLevel.chapter]
        if r.nextLevel.chapter ~= s.level.chapter then
            text[#text + 1] = ("New chapter: |cff80d0ff%s|r"):format(ch.name)
        else
            text[#text + 1] = ("New road open: |cff80d0ff%s|r"):format(r.nextLevel.name)
        end
    end
    if r.first and not r.heroic and not r.nextLevel then text[#text + 1] = "The campaign is won. Stryguard salutes you! Now try it on Heroic." end
    if r.first and r.heroic then text[#text + 1] = "First Heroic win here!" end
    victory.body:SetText(table.concat(text, "\n"))
    victory.nextKey = r.nextLevel and r.nextLevel.key or nil
    victory.next:SetShown(r.nextLevel ~= nil)
    victory:Show()
end

local function BuildOver()
    over = Overlay("board")
    over.head = Centered(over, "GameFontNormalHuge", -70, "Stryguard keep has fallen")
    over.head:SetTextColor(1, 0.35, 0.25)
    over.body = Centered(over, "GameFontHighlight", -110)
    local again = Button(over, 140, 26, "Try again", function()
        if G.s then StartMap(G.s.mapKey) end
    end)
    again:SetScript("OnClick", function()
        if G.s then StartMap(G.s.mapKey, G.s.heroic) end
    end)
    again:SetPoint("TOPRIGHT", over, "TOP", -6, -200)
    local maps = Button(over, 140, 26, "Pick a level", function() over:Hide() UI.ShowMenu() end)
    maps:SetPoint("TOPLEFT", over, "TOP", 6, -200)
end

local function ShowOver(wave)
    local s = G.s
    local held = max(0, wave - 1)
    local text
    if s.endless then
        text = ("You held %s until wave %d, %d past the end."):format(s.map.name, held, held - s.level.waves)
    else
        text = ("You held %s for %d of %d waves, with %s foes slain."):format(s.map.name, held, s.level.waves, Num(s.kills))
    end
    over.body:SetText(text .. ("\nMarks this run: |cffffd100%d|r. Spend them in the shop."):format(s.marks))
    over:Show()
end

-- Events from the game ---------------------------------------------------------------

local function OnGame(event, a, b, c, d, e)
    if not f then return end
    if event == "beam" then
        Beam(a, b, c, d, e)
    elseif event == "splash" then
        Ring(a, b, c, d)
    elseif event == "heal" then
        Ring(a, b, 1.5, "heal", 0.5)
    elseif event == "ward" then
        Ring(a, b, 1.5, "ward", 0.5)
    elseif event == "revive" then
        Ring(a.x, a.y, 0.6, "revive", 0.4)
    elseif event == "shield" then
        Ring(a, b, 1.5, "shield", 0.5)
    elseif event == "silence" then
        Ring(a, b, max(0.6, c), "silence", 0.6)
    elseif event == "blink" or event == "sheep" then
        Ring(a.x, a.y, 0.6, event, 0.3)
    elseif event == "burrow" or event == "surface" then
        Ring(a.x, a.y, 0.5, "burrow", 0.35)
    elseif event == "mend" then
        Toast(("The keep is mended: +%d %s"):format(a, a == 1 and "life" or "lives"), { 0.5, 1, 0.5 })
    elseif event == "built" then
        Meta.Count("built")
    elseif event == "spec" then
        Meta.CheckDeeds("spec", a)
    elseif event == "sold" then
        Meta.CheckDeeds("sell", G.s)
    elseif event == "death" then
        Ring(a.x, a.y, 0.35, "poof", 0.25)
        Meta.Count("kills")
        Meta.Count("damage", a.max)
        if a.def.boss then Meta.Count("bosses") end
    elseif event == "leak" then
        flashT = 0.4
        if a.def.boss then Toast(a.def.name .. " broke through!", BAD) end
    elseif event == "towers" then
        towersDirty = true
    elseif event == "toast" then
        Toast(a, BAD)
    elseif event == "gold" then
        Toast(("Early call: +%d gold"):format(a))
    elseif event == "marks" then
        Toast(("%s is slain!  +%d marks"):format(b, Meta.AddMarks(a)))
    elseif event == "wave" then
        if a.boss then
            Toast((a.final and "Final wave! " or ("Wave " .. a.n .. ": ")) .. ns.ENEMIES[a.boss].name .. " approaches!", BAD)
        elseif a.new then
            Toast("Wave " .. a.n .. ". " .. ns.INTRO[a.new], NEWS)
        elseif a.affix then
            Toast("Wave " .. a.n .. ": " .. ns.AFFIXES[a.affix].name .. ". " .. ns.AFFIXES[a.affix].desc, { 1, 0.6, 0.25 })
        else
            Toast(("Wave %d  (+%d gold)"):format(a.n, b))
        end
    elseif event == "cleared" then
        local s = G.s
        local got = Meta.AddMarks(b)
        Meta.Count("waves")
        Meta.CheckDeeds("stats")
        if s.endless then Meta.RecordEndless(s.mapKey, a) end
        if a ~= s.level.waves or s.endless then Toast(("Wave %d held  (+%d marks)"):format(a, got)) end
        Save()
    elseif event == "victory" then
        Save()
        ShowVictory(a)
    elseif event == "draft" then
        if draft then UI.ShowDraft() end
    elseif event == "over" then
        Save()
        ShowOver(a)
    end
end

-- The window ------------------------------------------------------------------------

function UI.Refresh()
    local s = G.s
    if not f or not s then return end
    if selected and selected.removed then selected = nil end
    local wave = s.wave > s.level.waves and (s.wave .. " (endless)") or (s.wave .. "/" .. s.level.waves)
    stats:SetText(("%s|cffffd100Gold|r %s    |cffff7070Lives|r %d    |cffccccccWave|r %s    |cffccccccSlain|r %s    |cff80c0ffMarks|r +%d"):format(
        s.heroic and "|cffff6040Heroic|r    " or "", Num(floor(s.gold)), s.lives, wave, Num(s.kills), s.marks))
    if s.gold >= 1000 then Meta.CheckDeeds("gold", s.gold) end
    for _, b in ipairs(towerButtons) do
        local key = b.def and b.def.key
        if not key then
            -- an empty slot
        elseif G.Unlocked(key) then
            local price = G.Price(key)
            b.cost:SetText(price .. "g")
            if s.gold >= price then b.cost:SetTextColor(1, 0.82, 0.25) else b.cost:SetTextColor(0.6, 0.3, 0.25) end
            b.icon:SetDesaturated(s.gold < price)
            b.icon:SetAlpha(1)
        else
            b.cost:SetText("Locked")
            b.cost:SetTextColor(0.5, 0.47, 0.42)
            b.icon:SetDesaturated(true)
            b.icon:SetAlpha(0.5)
        end
        if key then Light(b, building == key) end
    end
    RefreshInfo()
    RefreshWave()
    speedB.label:SetText(speed .. "x")
    pauseB.label:SetText(G.paused and "Play" or "Pause")
    local blocked = menu:IsShown() or shop:IsShown() or armoury:IsShown() or deeds:IsShown() or draft:IsShown()
        or victory:IsShown() or over:IsShown()
    if G.paused and not blocked and not s.over then
        pauseBox.reason:SetText(pauseReason or "Paused")
        pauseBox:Show()
    else
        pauseBox:Hide()
    end
end

local function Resume()
    if G.s and not G.s.over then
        G.paused = false
        pauseReason = nil
        UI.Refresh()
    end
end

local function OnUpdate(_, el)
    local s = G.s
    if not s then return end
    if not G.paused and not s.over and not s.draft and not menu:IsShown() and not shop:IsShown()
        and not armoury:IsShown() and not deeds:IsShown() then
        acc = acc + min(el, 0.25) * speed
        local n = 0
        while acc >= STEP and n < 12 do
            G.Step(STEP)
            acc = acc - STEP
            n = n + 1
        end
        if n == 12 then acc = 0 end
    end
    if towersDirty then DrawTowers() end
    TintTowers()
    DrawEnemies()
    DrawEffects(el)
    DrawHover()
    if toastT > 0 then
        toastT = toastT - el
        toastText:SetAlpha(min(1, max(0, toastT)))
    end
    if flashT > 0 then
        flashT = flashT - el
        flash:SetAlpha(max(0, flashT / 0.4) * 0.35)
    end
    refreshT = refreshT - el
    if refreshT <= 0 then
        refreshT = 0.15
        UI.Refresh()
        local flying = ns.Core and ns.Core.FlightTime()
        footRight:SetText(flying and ("On a flight: %d:%02d"):format(floor(flying / 60), floor(flying % 60)) or "")
    end
end

local function Build()
    if f then return end
    f = CreateFrame("Frame", "StryguardSkywatchFrame", UIParent, "BackdropTemplate")
    f:SetSize(W, H)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        ns.db.opts.pos = { p, rp, x, y }
    end)
    Flat(f, 0.07, 0.06, 0.05, 0.97)
    local pos = ns.db.opts.pos
    if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("CENTER", 0, 80) end
    f:SetScale(ns.db.opts.scale or 1)
    tinsert(UISpecialFrames, "StryguardSkywatchFrame")

    local title = Text(f, "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("Skywatch")
    stats = Text(f, "GameFontHighlightSmall")
    stats:SetPoint("LEFT", title, "RIGHT", 16, 0)

    local close = Button(f, 20, 18, "X", function() f:Hide() end)
    close:SetPoint("TOPRIGHT", -6, -5)
    local mapsB = Button(f, 52, 18, "Levels", function() UI.ShowMenu() end)
    mapsB:SetPoint("RIGHT", close, "LEFT", -4, 0)
    pauseB = Button(f, 48, 18, "Pause", function()
        if not G.s or G.s.over then return end
        if G.paused then Resume() else G.paused = true pauseReason = nil UI.Refresh() end
    end)
    pauseB:SetPoint("RIGHT", mapsB, "LEFT", -4, 0)
    speedB = Button(f, 34, 18, "1x", function()
        speed = speed % 3 + 1
        UI.Refresh()
    end)
    speedB:SetPoint("RIGHT", pauseB, "LEFT", -4, 0)
    speedB.tip = function(tt) tt:AddLine("Game speed") tt:AddLine("1x, 2x or 3x.", 1, 1, 1) end

    board = CreateFrame("Frame", nil, f)
    board:SetSize(BW, BH)
    board:SetPoint("TOPLEFT", PAD, -TOP)
    board:EnableMouse(true)
    board:SetScript("OnMouseDown", OnBoardClick)
    for r = 0, ROWS - 1 do
        for c = 0, COLS - 1 do
            local t = Tex(board, "BACKGROUND")
            t:SetSize(CELL, CELL)
            t:SetPoint("TOPLEFT", c * CELL, -r * CELL)
            cells[r * 100 + c] = t
        end
    end
    mapArt = Tex(board, "BACKGROUND", nil, nil, nil, nil, 7)
    mapArt:SetAllPoints()
    mapArt:SetTexCoord(0, BW / ART_W, 0, BH / ART_H)
    lairIcon = Tex(board, "ARTWORK")
    lairIcon:SetSize(CELL - 6, CELL - 6)
    lairIcon:SetTexture(ICON .. "INV_Misc_Bone_HumanSkull_01")
    lairIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    keepIcon = Tex(board, "ARTWORK")
    keepIcon:SetSize(CELL - 4, CELL - 4)
    keepIcon:SetTexture(ICON .. "INV_BannerPVP_02")
    keepIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local base = f:GetFrameLevel()
    local function layer(n)
        local l = CreateFrame("Frame", nil, board)
        l:SetAllPoints()
        l:SetFrameLevel(base + n)
        return l
    end
    rangeLayer, towerLayer, enemyLayer, fxLayer = layer(2), layer(3), layer(4), layer(8)
    rangeTex = Round(rangeLayer, "ARTWORK")
    rangeTex:Hide()
    selTex = CreateFrame("Frame", nil, rangeLayer, "BackdropTemplate")
    selTex:SetSize(CELL, CELL)
    selTex:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
    selTex:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
    selTex:SetFrameLevel(base + 6)
    selTex:Hide()
    ghost = CreateFrame("Frame", nil, fxLayer)
    ghost:SetSize(CELL, CELL)
    ghost.cell = Tex(ghost, "BACKGROUND")
    ghost.cell:SetAllPoints()
    ghost.icon = Tex(ghost, "ARTWORK")
    ghost.icon:SetPoint("TOPLEFT", 4, -4)
    ghost.icon:SetPoint("BOTTOMRIGHT", -4, 4)
    ghost.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ghost.icon:SetAlpha(0.7)
    ghost:Hide()
    flash = Tex(fxLayer, "OVERLAY", 1, 0.1, 0.05, 1)
    flash:SetAllPoints(board)
    flash:SetAlpha(0)
    toastText = fxLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    toastText:SetPoint("TOP", board, "TOP", 0, -8)
    toastText:SetWidth(BW - 20)
    toastText:SetAlpha(0)

    footLeft = Text(f, "GameFontDisableSmall")
    footLeft:SetPoint("TOPLEFT", board, "BOTTOMLEFT", 2, -6)
    footLeft:SetText("Shift-click keeps building. Right-click cancels. Esc closes and pauses.")
    footRight = Text(f, "GameFontHighlightSmall")
    footRight:SetPoint("TOPRIGHT", board, "BOTTOMRIGHT", -2, -6)
    footRight:SetJustifyH("RIGHT")

    BuildSide()
    BuildMenu()
    BuildShop()
    BuildArmoury()
    BuildDeeds()
    BuildDraft()
    BuildVictory()
    BuildOver()

    pauseBox = CreateFrame("Button", nil, f)
    pauseBox:SetAllPoints(board)
    pauseBox:SetFrameLevel(base + 15)
    local dim = Tex(pauseBox, "BACKGROUND", 0, 0, 0, 0.55)
    dim:SetAllPoints()
    pauseBox.reason = pauseBox:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    pauseBox.reason:SetPoint("CENTER", 0, 12)
    local hint = pauseBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hint:SetPoint("TOP", pauseBox.reason, "BOTTOM", 0, -8)
    hint:SetText("Click to carry on")
    pauseBox:SetScript("OnClick", Resume)
    pauseBox:Hide()

    G.listener = OnGame
    G.auto = ns.db.opts.auto ~= false
    Meta.onDeed = function(d, paid)
        Toast(("Deed done: %s  (+%d marks)"):format(d.name, paid), { 0.5, 1, 0.5 })
        print(("|cffffd100Skywatch|r deed done: |cff80ff80%s|r. %s +%d marks."):format(d.name, d.desc, paid))
    end
    UI.SetTowerButtons()
    f:SetScript("OnUpdate", OnUpdate)
    f:SetScript("OnHide", function()
        if G.s and not G.s.over then G.paused = true end
        building = nil
        GameTooltip:Hide()
        Save()
    end)
    f:Hide()
end

-- Called from Core ---------------------------------------------------------------------

function UI.Show()
    Build()
    pauseReason = nil
    f:Show()
    if not G.s or G.s.over then
        UI.ShowMenu()
    end
    UI.Refresh()
end

function UI.Toggle()
    if f and f:IsShown() then f:Hide() else UI.Show() end
end

function UI.IsShown()
    return f ~= nil and f:IsShown()
end

function UI.Landed()
    if UI.IsShown() and G.s and not G.s.over and not G.paused then
        G.paused = true
        pauseReason = "You've landed"
        UI.Refresh()
    end
end

function UI.Combat()
    if UI.IsShown() then
        pauseReason = "Paused for combat"
        f:Hide()
        print("|cffffd100Skywatch|r hid for combat. Type /skywatch to come back.")
    end
end

function UI.SetScale(v)
    ns.db.opts.scale = v
    if f then f:SetScale(v) end
end

function UI.ResetPosition()
    ns.db.opts.pos = nil
    if f then
        f:ClearAllPoints()
        f:SetPoint("CENTER", 0, 80)
    end
end
