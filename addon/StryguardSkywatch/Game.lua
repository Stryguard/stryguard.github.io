local _, ns = ...

-- The simulation. It knows nothing about frames: the UI calls Step() and reads the
-- state in G.s, and the game reports what happens through G.listener(event, ...).

local G = {}
ns.Game = G

local floor, min, max, sqrt, random = math.floor, math.min, math.max, math.sqrt, math.random
local DIRS = { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } }
local AUTO_DELAY = 8      -- seconds between waves when waves start by themselves
local START_GOLD, START_LIVES = 160, 20
local DRAFT_EVERY = 4     -- a blessing after every this many waves
local FLY_SKIP = 8        -- flyers head for every eighth square of the road, cutting across its bends
local SNAP_VERSION = 3

G.paused = false
G.auto = true

local checkDraft, hurt, spawn

local function emit(...)
    if G.listener then G.listener(...) end
end

local function key(c, r) return r * 100 + c end

local function dist2(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return dx * dx + dy * dy
end

-- A permanent upgrade's rank, from the shop (Meta.lua).
local function perk(k)
    return ns.Meta and ns.Meta.Rank(k) or 0
end

local function blessed(k)
    return G.s and G.s.bless[k] or 0
end

-- Read a map's rows into a grid and follow the road from the lair to the keep.
local function parseMap(def)
    local grid, start, goal = {}, nil, nil
    local rows = def.map.rows
    for r = 0, ns.ROWS - 1 do
        grid[r] = {}
        local line = rows[r + 1]
        for c = 0, ns.COLS - 1 do
            local ch = line:sub(c + 1, c + 1)
            grid[r][c] = ch
            if ch == "S" then start = { c, r } elseif ch == "E" then goal = { c, r } end
        end
    end
    local c, r = start[1], start[2]
    local path, seen = { { x = c + 0.5, y = r + 0.5 } }, { [key(c, r)] = true }
    while not (c == goal[1] and r == goal[2]) do
        local moved = false
        for _, d in ipairs(DIRS) do
            local nc, nr = c + d[1], r + d[2]
            local ch = grid[nr] and grid[nr][nc]
            if (ch == "#" or ch == "E") and not seen[key(nc, nr)] then
                c, r, moved = nc, nr, true
                seen[key(c, r)] = true
                path[#path + 1] = { x = c + 0.5, y = r + 0.5 }
                break
            end
        end
        if not moved then error("Skywatch: the road on " .. def.name .. " is broken") end
    end
    return grid, path
end

local function measure(path)
    local cum = { 0 }
    for i = 2, #path do cum[i] = cum[i - 1] + sqrt(dist2(path[i], path[i - 1])) end
    return cum
end

-- Blessing modifiers worked out from their fields, gathered once whenever a blessing is taken.
local function gatherMods()
    local s = G.s
    local m = { all = { dmg = 0, rate = 0, range = 0 }, phys = { dmg = 0, rate = 0, range = 0 },
        magic = { dmg = 0, rate = 0, range = 0 }, tower = {}, air = 0 }
    for k, n in pairs(s.bless) do
        local b = ns.BLESSING[k]
        if b and (b.dmg or b.rate or b.range or b.air) then
            local into
            if b.tower then
                m.tower[b.tower] = m.tower[b.tower] or { dmg = 0, rate = 0, range = 0 }
                into = m.tower[b.tower]
            elseif b.school then
                into = m[b.school]
            else
                into = m.all
            end
            into.dmg = into.dmg + (b.dmg or 0) * n
            into.rate = into.rate + (b.rate or 0) * n
            into.range = into.range + (b.range or 0) * n
            m.air = m.air + (b.air or 0) * n
        end
    end
    s.mods = m
end

-- The towers this run can build: the loadout chosen in the armoury.
local function loadoutSet(list)
    local set = {}
    for _, k in ipairs(list or {}) do set[k] = true end
    return set
end

-- A fresh run on a level. `restoring` skips the opening blessing, since Restore sets
-- the run up itself.
function G.New(levelKey, seed, restoring, heroic, loadout)
    local def = ns.LEVEL[levelKey]
    local grid, path = parseMap(def)
    local cum = measure(path)
    local air = { path[1] }
    for i = 1 + FLY_SKIP, #path - 1, FLY_SKIP do air[#air + 1] = path[i] end
    air[#air + 1] = path[#path]
    local acum = measure(air)
    local lives = START_LIVES + 2 * perk("walls")
    if heroic then lives = floor(lives / 2) + 2 * perk("resolve") end
    loadout = loadout or (ns.Meta and ns.Meta.Loadout()) or {}
    local s = {
        mapKey = levelKey, map = def, level = def, grid = grid, path = path, cum = cum, len = cum[#cum],
        air = air, acum = acum, alen = acum[#acum], heroic = heroic and true or nil,
        seed = seed or random(1, 2000000000),
        towers = {}, at = {}, enemies = {}, spawns = {},
        clock = 0, gold = (def.gold or START_GOLD) + 25 * perk("warchest"), lives = lives, startLives = lives, lost = 0,
        wave = 0, kills = 0, marks = 0,
        bless = {}, drafts = 0, rerollN = 0, idle = true, head = perk("headstart") > 0,
        loadout = loadout, inLoadout = loadoutSet(loadout),
        mendAcc = 0, momentum = 0, bossesSlain = 0, killN = 0, sabotageT = 10, spawnN = 0,
        run = { built = {}, upgrades = 0, sold = 0, early = 0, spent = 0 },
    }
    G.s = s
    gatherMods()
    G.dirty = true
    G.paused = false
    G.preview = nil
    if not restoring then checkDraft() end
    return s
end

-- Prices and building --------------------------------------------------------

local function costMult()
    return 0.85 ^ blessed("discount") * (1 - 0.03 * perk("masons"))
end

function G.Price(kind)
    return floor(ns.TOWER[kind].cost * costMult() + 0.5)
end

function G.UpgradePrice(t)
    if t.level >= 4 then return nil end
    local p = t.def.cost * ns.UPGRADE_COST[t.level + 1] * costMult() * 0.88 ^ blessed("craftsmen")
    if t.level < 3 and blessed("apprentice") > 0 then p = p * 0.7 end
    if t.level == 3 then
        p = p * (1 - 0.08 * perk("corps"))
        if blessed("engineers") > 0 then p = p * 0.7 end
    end
    return floor(p + 0.5)
end

function G.SellValue(t)
    local rate = blessed("merchant") > 0 and 1 or (0.7 + 0.06 * perk("salvage"))
    return floor(t.spent * rate)
end

function G.BaseRange(kind)
    local d = ns.TOWER[kind]
    if d.on == "#" then return d.range end
    local m = G.s.mods
    local school = d.school or "phys"
    local tm = m.tower[kind]
    return d.range + 0.5 * blessed("eagle") + 0.1 * perk("spyglass") + m.all.range + m[school].range + (tm and tm.range or 0)
end

function G.Unlocked(kind)
    return not ns.Meta or ns.Meta.TowerUnlocked(kind)
end

function G.InLoadout(kind)
    if G.s then return G.s.inLoadout[kind] == true end
    return true
end

-- Each tower goes on its own ground: road, rocks, water, or (most) open ground.
function G.CanBuild(c, r, kind)
    local row = G.s.grid[r]
    if not row or G.s.at[key(c, r)] then return false end
    local def = kind and ns.TOWER[kind]
    if def and def.on then
        if def.on == "~" then return row[c] == "~" end
        return row[c] == def.on
    end
    return row[c] == "."
end

local function addTower(kind, c, r, saved)
    local s = G.s
    local def = ns.TOWER[kind]
    local t = { kind = kind, def = def, c = c, r = r, x = c + 0.5, y = r + 0.5,
        level = 1, cd = 0, mode = def.mode or "first", spent = 0, dealt = 0, ramp = 0, silenceT = 0 }
    if saved then
        t.level, t.spec, t.mode = saved.level or 1, saved.spec, saved.mode or t.mode
        t.spent, t.dealt = saved.spent or def.cost, saved.dealt or 0
    end
    s.towers[#s.towers + 1] = t
    s.at[key(c, r)] = t
    G.dirty = true
    return t
end

function G.Build(kind, c, r)
    local s = G.s
    local price = G.Price(kind)
    if s.over or not G.Unlocked(kind) or not G.InLoadout(kind) or not G.CanBuild(c, r, kind) or s.gold < price then return nil end
    s.gold = s.gold - price
    local t = addTower(kind, c, r)
    t.spent = price
    s.run.built[kind] = (s.run.built[kind] or 0) + 1
    s.run.spent = s.run.spent + price
    G.Refresh()
    emit("built", t)
    return t
end

function G.Upgrade(t, specKey)
    local s, price = G.s, G.UpgradePrice(t)
    if s.over or not price or s.gold < price then return false end
    if t.level == 3 then
        local ok = false
        for _, sp in ipairs(t.def.specs) do if sp.key == specKey then ok = true end end
        if not ok then return false end
        t.spec = specKey
    end
    s.gold = s.gold - price
    t.level = t.level + 1
    t.spent = t.spent + price
    s.run.upgrades = s.run.upgrades + 1
    s.run.spent = s.run.spent + price
    G.dirty = true
    G.Refresh()
    if t.level == 4 then emit("spec", t) end
    return true
end

function G.Sell(t)
    local s = G.s
    if s.over or t.removed then return end
    s.gold = s.gold + G.SellValue(t)
    for i, o in ipairs(s.towers) do
        if o == t then table.remove(s.towers, i) break end
    end
    s.at[key(t.c, t.r)] = nil
    t.removed = true
    s.run.sold = s.run.sold + 1
    G.dirty = true
    G.Refresh()
    emit("sold", t)
end

local MODES = { "first", "strong", "close" }
function G.CycleMode(t)
    for i, m in ipairs(MODES) do
        if m == t.mode then t.mode = MODES[i % #MODES + 1] return end
    end
    t.mode = "first"
end

-- Tower stats ----------------------------------------------------------------

function G.Spec(t)
    if not t.spec then return nil end
    for _, sp in ipairs(t.def.specs) do if sp.key == t.spec then return sp end end
end

-- The best aura from a neighbouring support tower (they don't stack): Holy Beacons and
-- Chapels lift damage, War Drums lift speed (and with Drums of Battle, reach).
local function auras(t)
    local s = G.s
    local dmg, haste, range = 0, 0, 0
    local holyReach = blessed("radiance") > 0 and 2 or 1
    local drumReach = blessed("warbeat") > 0 and 2 or 1
    local reach = max(holyReach, drumReach)
    for dr = -reach, reach do
        for dc = -reach, reach do
            local o = s.at[key(t.c + dc, t.r + dr)]
            if o and o ~= t then
                local far = max(dr < 0 and -dr or dr, dc < 0 and -dc or dc)
                if o.kind == "holy" and far <= holyReach then
                    local b = o.spec == "crusader" and 0.5 or o.def.aura[o.level]
                    if blessed("sanctity") > 0 then b = b + 0.1 end
                    if b > dmg then dmg = b end
                elseif o.kind == "chapel" and far <= 1 then
                    local b = o.spec == "lightshope" and 0.2 or 0
                    if blessed("sanctuary") > 0 then b = max(b, 0.1) end
                    if b > dmg then dmg = b end
                elseif o.kind == "drums" and far <= drumReach then
                    local h = (o.spec == "bloodlust" and 0.35) or (o.spec == "battle" and 0.2) or o.def.hasteAura[o.level]
                    h = h + 0.1 * blessed("thunderdrums")
                    if h > haste then haste = h end
                    if o.spec == "battle" then range = 0.5 end
                end
            end
        end
    end
    return dmg, haste, range
end

local function neighbours(t)
    local n = 0
    for dr = -1, 1 do
        for dc = -1, 1 do
            local o = G.s.at[key(t.c + dc, t.r + dr)]
            if o and o ~= t then n = n + 1 end
        end
    end
    return n
end

local BASE = { "attack", "range", "damage", "rate", "air", "airOnly", "ground", "splash", "chain", "slow", "slowTime",
    "poison", "stacks", "gain", "cap", "pierce", "crit", "targets", "reveal", "chillBonus", "burn", "freeze", "stun",
    "knock", "root", "weaken", "missiles", "sheep", "sheepTime", "airBonus", "bossBonus", "airSplash", "shred", "quiet" }

local function computeStats(t)
    local d, B, s = t.def, G.s.bless, G.s
    local st = {}
    for _, k in ipairs(BASE) do st[k] = d[k] end
    st.stacks, st.targets, st.perHit = st.stacks or 5, st.targets or 1, 1
    local sp = G.Spec(t)
    if sp then
        for k, v in pairs(sp.add or {}) do st[k] = (st[k] or 0) + v end
        for k, v in pairs(sp.mul or {}) do st[k] = (st[k] or 0) * v end
        for k, v in pairs(sp.set or {}) do st[k] = v end
    end
    -- Blessings that change how a tower works rather than how hard it hits.
    if t.kind == "frost" and (B.permafrost or 0) > 0 then st.slowTime = st.slowTime * 1.5 end
    if t.kind == "fire" and (B.wildfire or 0) > 0 then st.splash = st.splash * 1.4 end
    if t.kind == "cannon" and (B.shrapnel or 0) > 0 then st.splash = st.splash * 1.4 end
    if t.kind == "harbor" and (B.grapeshot or 0) > 0 then st.splash = st.splash * 1.4 end
    if t.kind == "trap" and (B.barbed or 0) > 0 and not st.slow then st.slow, st.slowTime = 0.4, 1 end
    if t.kind == "venom" and (B.virulence or 0) > 0 then st.perHit = 2 end
    if t.kind == "arcane" and (B.leylines or 0) > 0 then st.gain = st.gain * 2 end
    if t.kind == "mage" then
        if (B.sheepish or 0) > 0 then st.sheep = st.sheep * 2 end
        if (B.missilestorm or 0) > 0 then st.missiles = st.missiles + 2 end
    end
    if t.kind == "roots" and (B.naturesgrasp or 0) > 0 then st.root = st.root * 1.6 end
    if t.kind == "quake" and (B.faultline or 0) > 0 then st.knock = st.knock * 1.5 end
    if t.kind == "shadow" and (B.misery or 0) > 0 then st.weaken = st.weaken + 0.15 end
    if t.kind == "earthbind" then
        if (B.earthenpower or 0) > 0 then st.slow = st.slow + 0.15 end
        if (B.stoneclaw or 0) > 0 then st.damage, st.pierce = 6, true end
    end
    if t.kind == "camp" and (B.dynamite or 0) > 0 then
        st.attack, st.damage, st.rate, st.range, st.pierce = "pulse", 20, 2, 1.5, true
    end
    if st.chain then st.chain = st.chain + 2 * (B.static or 0) * (t.kind == "storm" and 1 or 0) end

    local m = s.mods
    local school = d.school or "phys"
    local tm = m.tower[t.kind] or { dmg = 0, rate = 0, range = 0 }
    local auraDmg, auraHaste, auraRange = auras(t)
    local lvl = t.level
    if d.on ~= "#" then
        st.range = st.range + 0.25 * (lvl - 1) + 0.5 * (B.eagle or 0) + 0.1 * perk("spyglass")
            + m.all.range + m[school].range + tm.range + auraRange
    end
    if d.slowGrow and st.slow then st.slow = st.slow + 0.05 * (lvl - 1) end
    if t.kind == "frost" and (B.permafrost or 0) > 0 then st.slow = st.slow + 0.1 end
    if st.slow then st.slow = min(0.8, st.slow) end
    if st.weaken then st.weaken = st.weaken + 0.03 * (lvl - 1) end

    local haste = (1 + 0.15 * (B.haste or 0)) * (1 + 0.04 * perk("drill")) * (1 + auraHaste)
        * (1 + m.all.rate + m[school].rate + tm.rate)
    if s.bossWave and (B.bloodlust or 0) > 0 then haste = haste * 1.3 end
    local power = ns.LEVEL_DAMAGE[lvl] * (1 + 0.05 * perk("steel")) * (1 + auraDmg) * (1 + 0.08 * perk("m_" .. t.kind))
        * (1 + m.all.dmg + m[school].dmg + tm.dmg)
    if t.kind == "frost" and (B.permafrost or 0) > 0 then power = power * 1.1 end
    if (B.momentum or 0) > 0 then power = power * (1 + 0.03 * s.momentum) end
    if (B.harmony or 0) > 0 then
        local kinds = {}
        for _, o in ipairs(s.towers) do kinds[o.kind] = true end
        local n = 0
        for _ in pairs(kinds) do n = n + 1 end
        power = power * (1 + 0.04 * min(6, n))
    end
    if (B.rally or 0) > 0 or (B.lonewolf or 0) > 0 then
        local n = neighbours(t)
        if (B.rally or 0) > 0 and n >= 3 then power = power * 1.15 end
        if (B.lonewolf or 0) > 0 and n == 0 then power = power * 1.35 end
    end

    st.aura = auraDmg
    st.rate = (st.rate or 0) * haste
    st.damage = (st.damage or 0) * power
    if st.poison then st.poison = st.poison * power end
    if st.attack == "pulse" then st.pulse = true end
    if st.reveal then st.reveal = st.range end
    if d.income then
        st.range = d.range
        st.income = d.income[lvl] * (sp and sp.set and sp.set.incomeMul or 1)
        if t.kind == "mint" then st.income = st.income * 1.3 ^ (B.minted or 0) end
        if t.kind == "camp" then st.income = st.income * 1.3 ^ (B.motherlode or 0) end
        if sp and sp.set then st.bounty, st.interest, st.markIncome = sp.set.bounty, sp.set.interest, sp.set.markIncome end
    end
    if d.mend then
        st.mend = (sp and sp.set and sp.set.mendFlat) or d.mend[lvl]
        if (B.prayer or 0) > 0 then st.mend = st.mend * 1.5 end
    end
    t.st = st
end

function G.Refresh()
    if G.dirty and G.s then
        for _, t in ipairs(G.s.towers) do computeStats(t) end
        G.dirty = false
        emit("towers")
    end
end

-- Foes -----------------------------------------------------------------------

-- Put a foe at its distance along the road (or along the flyers' shortcut).
local function place(e)
    local s = G.s
    local P, cum, len = s.path, s.cum, s.len
    if e.flying then P, cum, len = s.air, s.acum, s.alen end
    if e.d < 0 then e.d = 0 end
    local i = e.seg
    while i > 1 and cum[i] > e.d do i = i - 1 end
    while i < #P - 1 and cum[i + 1] < e.d do i = i + 1 end
    e.seg = i
    local a, b = P[i], P[i + 1]
    local span = cum[i + 1] - cum[i]
    local t = span > 0 and max(0, min(1, (e.d - cum[i]) / span)) or 0
    e.x, e.y, e.prog = a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, e.d / len
end

spawn = function(kind, hpScale, affix, d, nth)
    local s, def = G.s, ns.ENEMIES[kind]
    local hp = def.hp * hpScale * (affix == "swarm" and 0.7 or 1) * (affix == "giants" and 2.2 or 1) * (affix == "bountiful" and 1.2 or 1)
    local elite = affix == "elite" and nth and nth % 5 == 0 and not def.boss
    if elite then hp = hp * 3 end
    local e = {
        kind = kind, def = def, hp = hp, max = hp, d = d or 0, seg = 1,
        armor = max(0, (def.armor or 0) + (affix == "armored" and 3 or 0) - 3 * blessed("sunder")),
        speed = def.speed * (affix == "hasted" and 1.3 or 1) * (1 - 0.08 * blessed("slowtime")),
        regen = (def.regen or 0) + (affix == "regen" and 0.02 or 0),
        flying = def.flying, stealth = def.stealth or (affix == "cloaked" and nth and nth % 3 == 0),
        revive = def.revive or (affix == "undying" and nth and nth % 4 == 0),
        frenzy = def.frenzy or affix == "frenzied",
        magicRes = min(0.9, (def.magicRes or 0) + (affix == "warded" and 0.4 or 0)),
        physRes = min(0.9, (def.physRes or 0) + (affix == "ironclad" and 0.3 or 0)),
        shield = hp * ((def.shield or 0) + (affix == "shielded" and 0.25 or 0)),
        slowT = 0, slowP = 0, stunT = 0, burnT = 0, burnDps = 0, healCd = 2, summoned = 0, submerged = 0,
        poisonN = 0, poisonT = 0, poisonDps = 0, weakT = 0, weakP = 0, sheepT = 0, submergeT = 0, frenzyN = 0,
        burrowCd = def.burrow, burrowT = 0, blinkCd = def.blink, broodCd = def.brood and def.brood.every, brooded = 0,
        silCd = def.silence and def.silence.every * 0.6,
        hpScale = hpScale, affix = affix, elite = elite, giant = affix == "giants",
    }
    if def.regen and blessed("cleanse") > 0 then e.regen = e.regen * 0.5 end
    if e.regen > 0 and blessed("cleanse") > 0 and not def.regen then e.regen = e.regen * 0.5 end
    e.seen = not e.stealth
    s.enemies[#s.enemies + 1] = e
    place(e)
    return e
end

-- Every living foe within `radius` of `e`, including `e`.
local function around(e, radius, groundOnly)
    local out, r2 = {}, radius * radius
    for _, o in ipairs(G.s.enemies) do
        if not o.dead and not (groundOnly and o.flying) and dist2(o, e) <= r2 then out[#out + 1] = o end
    end
    return out
end

-- Can a tower touch this foe right now? Not while it's underground or under the lava.
local function touchable(e)
    if e.submergeT > 0 then return false end
    if e.burrowT > 0 and blessed("tremorsense") == 0 then return false end
    return true
end
G.Touchable = function(e) return touchable(e) end

local function chill(e, p, dur)
    if e.def.unstoppable then return end
    if e.def.boss then p = p * 0.6 end
    e.slowP = max(e.slowT > 0 and e.slowP or 0, p)
    e.slowT = max(e.slowT, dur)
end

local function stun(e, dur)
    if e.def.unstoppable then return end
    if e.def.boss then dur = dur * 0.4 end
    e.stunT = max(e.stunT, dur)
end

-- Throw a ground foe back down the road.
local function knock(e, dist)
    if e.flying or e.def.unstoppable then return end
    if e.def.boss then dist = dist * 0.3 end
    e.d = max(0, e.d - dist)
end

local function poison(e, t, st)
    e.poisonN = min(st.stacks, e.poisonN + st.perHit)
    e.poisonT = 4
    e.poisonDps = max(e.poisonDps, st.poison)
    e.poisonSrc = t
    if st.plague then e.plague = true end
    if st.slow then chill(e, st.slow, st.slowTime) end
end

local function silenceTowers(x, y, radius, time)
    if blessed("spellbreaker") > 0 then return end
    local r2, hit = radius * radius, false
    for _, t in ipairs(G.s.towers) do
        local dx, dy = t.x - x, t.y - y
        if dx * dx + dy * dy <= r2 and (t.st.rate or 0) > 0 then
            t.silenceT = max(t.silenceT, time)
            hit = true
        end
    end
    if hit then emit("silence", x, y, radius) end
end

local function kill(e, t)
    local s, B = G.s, G.s.bless
    -- Some foes get back up once, at half health.
    if e.revive and not e.revived then
        e.revived = true
        e.hp = e.max * 0.5
        e.stunT = max(e.stunT, 1.2)
        e.poisonN, e.poisonT, e.burnT = 0, 0, 0
        emit("revive", e)
        return
    end
    e.dead = true
    s.kills = s.kills + 1
    s.killN = s.killN + 1
    local gold = e.def.gold * (1 + 0.25 * (B.bounty or 0)) + (B.scavenger or 0)
    if e.elite then gold = gold * 3 end
    if e.affix == "bountiful" then gold = gold * 2 end
    if e.def.boss and (B.biggame or 0) > 0 then gold = gold * 3 end
    gold = gold * s.level.ramp * (1 + 0.05 * perk("tax"))
    for _, o in ipairs(s.towers) do
        if o.st and o.st.bounty and dist2(o, e) <= o.st.range * o.st.range then gold = gold * o.st.bounty break end
    end
    s.gold = s.gold + gold
    if (B.killbounty or 0) > 0 and s.killN % 25 == 0 then s.gold = s.gold + 30 end
    if (B.lifesteal or 0) > 0 and s.killN % 100 == 0 then s.lives = s.lives + 1 end
    if e.def.split then
        for i = 1, e.def.splitCount do spawn(e.def.split, e.hpScale, e.affix, max(0, e.d - 0.2 * (i - 1))) end
    end
    if e.plague and e.poisonN > 0 then
        emit("splash", e.x, e.y, 1.3, "venom")
        for _, o in ipairs(around(e, 1.3)) do
            o.poisonN = max(o.poisonN, e.poisonN)
            o.poisonT = 4
            o.poisonDps = max(o.poisonDps, e.poisonDps)
            o.poisonSrc, o.plague = e.poisonSrc, true
        end
    end
    if t and t.kind == "fire" and (B.combustion or 0) > 0 then
        emit("splash", e.x, e.y, 1.1, "fire")
        for _, o in ipairs(around(e, 1.1, true)) do hurt(o, e.max * 0.15, nil, true) end
    end
    -- Friends nearby react: frenzy, bolstering, a last heal.
    for _, o in ipairs(around(e, 2)) do
        if o ~= e then
            if o.frenzy then o.frenzyN = min(5, o.frenzyN + 1) end
            if e.affix == "bolstering" and dist2(o, e) <= 2.25 then
                o.max = o.max * 1.15
                o.hp = min(o.max, o.hp + o.max * 0.15)
            end
            if e.def.deathHeal and dist2(o, e) <= 2.25 then o.hp = min(o.max, o.hp + o.max * 0.2) end
        end
    end
    if e.def.deathHeal then emit("heal", e.x, e.y) end
    if e.def.boss then
        s.bossesSlain = s.bossesSlain + 1
        if (B.fortify or 0) > 0 then s.lives = s.lives + B.fortify end
        emit("marks", floor(3 * s.level.marks * (1 + 0.15 * perk("relics")) + 0.5), e.def.name)
    end
    emit("death", e, gold)
end

hurt = function(e, amount, t, pierce)
    if e.dead or not touchable(e) then return end
    local s, B = G.s, G.s.bless
    if not pierce and e.armor > 0 and e.sheepT <= 0 then amount = max(amount * 0.25, amount - e.armor) end
    if t then
        local res = t.def.school == "magic" and e.magicRes or e.physRes
        if res > 0 then amount = amount * (1 - res) end
        local st = t.st
        if st then
            if st.airBonus and e.flying then amount = amount * (1 + st.airBonus) end
            if st.bossBonus and e.def.boss then amount = amount * (1 + st.bossBonus) end
        end
    end
    if e.ward then amount = amount * 0.7 end
    if e.slowT > 0 and (B.shatter or 0) > 0 then amount = amount * 1.2 end
    if e.weakT > 0 then amount = amount * (1 + e.weakP) end
    if e.def.boss then amount = amount * (1 + 0.3 * (B.giant or 0)) * (1 + 0.06 * perk("siegecraft")) end
    if e.flying then
        amount = amount * (1 + s.mods.air) * (1 + 0.06 * perk("skyward"))
    elseif (B.groundpound or 0) > 0 then
        amount = amount * (1 + 0.2 * B.groundpound)
    end
    if (B.execute or 0) > 0 and e.hp < e.max * 0.25 then amount = amount * 2 end
    if (B.lucky or 0) > 0 and random() < 0.1 * B.lucky then amount = amount * 3 end
    if (B.hoard or 0) > 0 then amount = amount * (1 + min(0.3, s.gold / 5000)) end
    -- Shields soak up damage first.
    if e.shield > 0 then
        local mult = ((B.siegebreaker or 0) > 0 and 2 or 1) * ((B.disruption or 0) > 0 and 2 or 1)
        local soak = min(e.shield, amount * mult)
        e.shield = e.shield - soak
        amount = amount - soak / mult
        if t then t.dealt = t.dealt + soak / mult end
        if amount <= 0 then return end
    end
    amount = min(amount, e.hp)
    e.hp = e.hp - amount
    if t then t.dealt = t.dealt + amount end
    local frac = e.hp / e.max
    local sm = e.def.summon
    if sm and e.hp > 0 then
        while e.summoned < #sm.at and frac <= sm.at[e.summoned + 1] do
            e.summoned = e.summoned + 1
            for i = 1, sm.count do spawn(sm.kind, e.hpScale, nil, max(0, e.d - 0.35 * i)) end
            emit("toast", e.def.name .. " calls for help!")
        end
    end
    local sub = e.def.submerge
    if sub and e.hp > 0 then
        while e.submerged < #sub.at and frac <= sub.at[e.submerged + 1] do
            e.submerged = e.submerged + 1
            e.submergeT = sub.time
            emit("toast", e.def.name .. " dives out of reach!")
        end
    end
    if e.hp <= 0.001 then kill(e, t) end
end

-- Targets in reach, best first by the tower's targeting mode.
local function pick(t)
    local s, st = G.s, t.st
    local r2 = st.range * st.range
    local list = {}
    for _, e in ipairs(s.enemies) do
        if not e.dead and e.seen and touchable(e) then
            local ok
            if st.airOnly then ok = e.flying else ok = st.air or not e.flying end
            if ok then
                local d2 = dist2(t, e)
                if d2 <= r2 then e.d2 = d2 list[#list + 1] = e end
            end
        end
    end
    if #list > 1 then
        local mode = t.mode
        if mode == "strong" then table.sort(list, function(a, b) return a.hp > b.hp end)
        elseif mode == "close" then table.sort(list, function(a, b) return a.d2 < b.d2 end)
        else table.sort(list, function(a, b) return a.prog > b.prog end) end
    end
    return list
end

local function sheep(e, st)
    if st.sheep and not e.def.boss and random() < st.sheep then
        e.sheepT = st.sheepTime or 2
        emit("sheep", e)
    end
end

local function attack(t, targets)
    local st, kind, e = t.st, t.kind, targets[1]
    local how = st.attack
    if how == "arrow" then
        for i = 1, min(#targets, st.targets) do
            local x, dmg = targets[i], st.damage
            if st.crit and random() < st.crit then dmg = dmg * 3 end
            emit("beam", t.x, t.y, x.x, x.y, kind)
            if st.airSplash then
                emit("splash", x.x, x.y, st.airSplash, kind)
                for _, o in ipairs(around(x, st.airSplash)) do
                    if o.flying then hurt(o, o == x and dmg or dmg * 0.5, t, st.pierce) end
                end
            else
                hurt(x, dmg, t, st.pierce)
            end
        end
    elseif how == "frost" then
        emit("beam", t.x, t.y, e.x, e.y, kind)
        if st.splash then emit("splash", e.x, e.y, st.splash, kind) end
        if st.freeze and random() < st.freeze then stun(e, 1) end
        for _, x in ipairs(st.splash and around(e, st.splash) or { e }) do
            chill(x, st.slow, st.slowTime)
            hurt(x, st.damage, t)
        end
    elseif how == "blast" then
        for i = 1, min(#targets, st.targets) do
            local x = targets[i]
            emit("beam", t.x, t.y, x.x, x.y, kind)
            emit("splash", x.x, x.y, st.splash, kind)
            for _, o in ipairs(around(x, st.splash, not st.air)) do
                local dmg = st.damage * ((st.chillBonus and o.slowT > 0) and (1 + st.chillBonus) or 1)
                if st.shred and o.armor > 0 then o.armor = max(0, o.armor - st.shred) end
                if st.slow then chill(o, st.slow, st.slowTime) end
                hurt(o, dmg, t, st.pierce)
                if st.burn and not o.dead then
                    o.burnT, o.burnDps, o.burnSrc = 3, max(o.burnDps, dmg * st.burn / 3), t
                end
            end
        end
    elseif how == "chain" then
        local hit, fx, fy, cur, dmg = {}, t.x, t.y, e, st.damage
        local keep = (kind == "storm" and blessed("overcharge") > 0) and 1 or 0.85
        for _ = 1, st.chain do
            hit[cur] = true
            emit("beam", fx, fy, cur.x, cur.y, kind == "gryphon" and "storm" or kind)
            if st.stun and random() < st.stun then stun(cur, 0.6) end
            hurt(cur, dmg, t, st.pierce)
            local nextE, best = nil, 1.8 * 1.8
            for _, o in ipairs(G.s.enemies) do
                if not o.dead and not hit[o] and o.seen and touchable(o) then
                    local d2 = dist2(o, cur)
                    if d2 < best then best, nextE = d2, o end
                end
            end
            if not nextE then break end
            fx, fy, cur, dmg = cur.x, cur.y, nextE, dmg * keep
        end
    elseif how == "smite" then
        emit("beam", t.x, t.y, e.x, e.y, kind)
        hurt(e, st.damage, t, true)
    elseif how == "venom" then
        emit("beam", t.x, t.y, e.x, e.y, kind)
        poison(e, t, st)
        hurt(e, st.damage, t)
    elseif how == "beam" then
        -- Stay on the same foe while it's in reach, so the beam keeps building.
        local held = false
        for i, x in ipairs(targets) do
            if x == t.focus then
                targets[1], targets[i] = targets[i], targets[1]
                held = true
                break
            end
        end
        if not held then t.focus, t.ramp = targets[1], 0 end
        local mult = 1 + t.ramp
        for i = 1, min(#targets, st.targets) do
            local x = targets[i]
            emit("beam", t.x, t.y, x.x, x.y, kind)
            hurt(x, st.damage * mult, t, true)
        end
        t.ramp = min(st.cap, t.ramp + st.gain / st.rate)
    elseif how == "line" then
        -- A bolt from the tower through the target, out to the edge of its reach.
        local dx, dy = e.x - t.x, e.y - t.y
        local len = sqrt(dx * dx + dy * dy)
        if len < 0.01 then len, dx, dy = 1, 1, 0 end
        dx, dy = dx / len, dy / len
        local ex, ey = t.x + dx * st.range, t.y + dy * st.range
        emit("beam", t.x, t.y, ex, ey, kind)
        for _, o in ipairs(G.s.enemies) do
            if not o.dead and o.seen and touchable(o) and (st.air or not o.flying) then
                local px, py = o.x - t.x, o.y - t.y
                local along = px * dx + py * dy
                if along >= 0 and along <= st.range then
                    local ox, oy = px - dx * along, py - dy * along
                    if ox * ox + oy * oy <= 0.45 * 0.45 then
                        if st.slow then chill(o, st.slow, st.slowTime) end
                        if st.knock then knock(o, st.knock) end
                        hurt(o, st.damage, t, st.pierce)
                    end
                end
            end
        end
    elseif how == "curse" then
        emit("beam", t.x, t.y, e.x, e.y, kind)
        e.weakT, e.weakP = 4, max(e.weakT > 0 and e.weakP or 0, st.weaken)
        if st.slow then chill(e, st.slow, st.slowTime) end
        hurt(e, st.damage, t)
        if st.burn and not e.dead then
            e.burnT, e.burnDps, e.burnSrc = 3, max(e.burnDps, st.damage * st.burn), t
        end
    elseif how == "missile" then
        for i = 1, st.missiles do
            local x = targets[(i - 1) % min(#targets, 2) + 1]
            if not x.dead then
                emit("beam", t.x, t.y, x.x, x.y, "arcane")
                hurt(x, st.damage, t)
            end
        end
        if not e.dead then sheep(e, st) end
    end
end

-- Waves ----------------------------------------------------------------------

checkDraft = function()
    local s = G.s
    if s.over or s.draft or (s.won and not s.endless) then return end
    local due = floor(s.wave / DRAFT_EVERY) + (s.head and 1 or 0)
    if s.drafts < due then
        if s.rerollsLeft == nil then s.rerollsLeft = perk("fortune") end
        s.draft = G.DraftChoices()
        emit("draft", s.draft)
        return true
    end
end

function G.DraftChoices()
    local s = G.s
    local rand = ns.Rng(s.seed + s.wave * 31 + s.drafts * 131 + s.rerollN * 7919)
    local pool = {}
    for _, b in ipairs(ns.BLESSINGS) do
        if (s.bless[b.key] or 0) < b.max and (not b.tower or (G.Unlocked(b.tower) and G.InLoadout(b.tower))) then pool[#pool + 1] = b end
    end
    local out = {}
    local n = 3 + blessed("cartographer") + perk("library")
    while #out < n and #pool > 0 do
        out[#out + 1] = table.remove(pool, rand(1, #pool)).key
    end
    return out
end

function G.Reroll()
    local s = G.s
    if not s or not s.draft or (s.rerollsLeft or 0) <= 0 then return false end
    s.rerollsLeft = s.rerollsLeft - 1
    s.rerollN = s.rerollN + 1
    s.draft = G.DraftChoices()
    emit("draft", s.draft)
    return true
end

function G.Bless(bkey)
    local s = G.s
    if not s.draft then return end
    s.bless[bkey] = (s.bless[bkey] or 0) + 1
    if bkey == "shield" then s.lives = s.lives + 8 end
    if bkey == "goldrush" then s.gold = s.gold + 150 end
    if bkey == "fortify" then s.lives = s.lives + 4 end
    s.drafts = s.drafts + 1
    s.draft, s.rerollsLeft = nil, nil
    s.autoT = AUTO_DELAY
    gatherMods()
    G.dirty = true
    G.Refresh()
    emit("blessed", bkey)
    checkDraft()
end

function G.Preview()
    local s = G.s
    local n = s.wave + 1
    if not G.preview or G.preview.n ~= n or G.preview.seed ~= s.seed or G.preview.level ~= s.mapKey then
        G.preview = ns.MakeWave(s.level, n, s.seed, s.heroic)
        G.preview.seed, G.preview.level = s.seed, s.mapKey
    end
    return G.preview
end

function G.EarlyBonus()
    local b = (5 + G.s.wave) * G.s.level.ramp * (1 + 0.2 * perk("ledger"))
    if blessed("overtime") > 0 then b = b * 2 end
    return floor(b)
end

-- Stars for a win: none lost is three, fewer than ten is two.
function G.Stars()
    local lost = G.s.lost
    return lost == 0 and 3 or (lost < 10 and 2 or 1)
end

-- After a win, carry on past the last wave.
function G.Endless()
    local s = G.s
    if not s.won then return end
    s.endless = true
    s.autoT = AUTO_DELAY
    checkDraft()
end

function G.NextWave()
    local s = G.s
    if s.over or s.draft or (s.won and not s.endless) then return end
    G.Refresh()
    if not s.idle then
        local bonus = G.EarlyBonus()
        s.gold = s.gold + bonus
        s.run.early = s.run.early + 1
        emit("gold", bonus)
    end
    local w = G.Preview()
    s.wave = w.n
    local ramp = s.level.ramp
    local income, rate, cap, capAdd = (12 + 2 * w.x) * ramp, 0, 0, 0
    if blessed("banking") > 0 then rate, cap = 0.06, 60 end
    local mend = 0
    for _, t in ipairs(s.towers) do
        local st = t.st
        if st.income then income = income + st.income * ramp end
        if st.interest then rate, cap = rate + st.interest, cap + 40 end
        if t.kind == "mint" and blessed("goblinbank") > 0 then rate, cap = rate + 0.02, cap + 20 end
        if st.mend then mend = mend + st.mend end
    end
    if blessed("deeppockets") > 0 and cap > 0 then capAdd = 50 end
    income = income * (1 + 0.05 * perk("tax"))
    local interest = min(cap + capAdd, floor(s.gold * rate))
    s.gold = s.gold + income + interest
    -- Chapels and the field medic mend the keep.
    s.mendAcc = s.mendAcc + mend
    local medic = perk("medic")
    if medic > 0 and s.wave % (7 - medic) == 0 then s.mendAcc = s.mendAcc + 1 end
    if s.mendAcc >= 1 then
        local n = floor(s.mendAcc)
        s.mendAcc = s.mendAcc - n
        s.lives = s.lives + n
        emit("mend", n)
    end
    s.spawnN = 0
    for _, g in ipairs(w.groups) do
        for i = 1, g.count do
            s.spawns[#s.spawns + 1] = { t = s.clock + g.delay + (i - 1) * g.gap, kind = g.kind, hp = w.hp, affix = w.affix }
        end
    end
    s.idle, s.autoT, s.leaked = false, nil, false
    s.waveAffix = w.affix
    local bossWave = w.boss ~= nil
    if bossWave ~= (s.bossWave or false) then s.bossWave, G.dirty = bossWave, true end
    emit("wave", w, floor(income + interest))
end

-- The clock ------------------------------------------------------------------

local function abilities(e, dt, s)
    local def = e.def
    if e.sheepT > 0 then return end
    if e.burrowCd then
        if e.burrowT > 0 then
            e.burrowT = e.burrowT - dt
            if e.burrowT <= 0 then e.burrowCd = def.burrow emit("surface", e) end
        else
            e.burrowCd = e.burrowCd - dt
            if e.burrowCd <= 0 then e.burrowT = 1.5 emit("burrow", e) end
        end
    end
    if e.blinkCd and e.stunT <= 0 then
        e.blinkCd = e.blinkCd - dt
        if e.blinkCd <= 0 then
            e.blinkCd = def.blink
            emit("blink", e)
            e.d = e.d + (def.boss and 2 or 1.5)
        end
    end
    if e.broodCd and e.brooded < 8 then
        e.broodCd = e.broodCd - dt
        if e.broodCd <= 0 then
            e.broodCd = def.brood.every
            e.brooded = e.brooded + 1
            spawn(def.brood.kind, e.hpScale, nil, max(0, e.d - 0.1))
        end
    end
    if e.silCd then
        e.silCd = e.silCd - dt
        if e.silCd <= 0 then
            e.silCd = def.silence.every
            silenceTowers(e.x, e.y, def.silence.radius, def.silence.time)
        end
    end
    if def.heals or def.ward or def.shields then
        e.healCd = e.healCd - dt
        if e.healCd <= 0 then
            e.healCd = 2
            local cleanse = blessed("cleanse") > 0 and 0.5 or 1
            if def.heals then
                for _, o in ipairs(around(e, 1.5)) do o.hp = min(o.max, o.hp + o.max * 0.06 * cleanse) end
                emit("heal", e.x, e.y)
            end
            if def.shields then
                for _, o in ipairs(around(e, 1.5)) do o.shield = min(o.max * 0.3, o.shield + o.max * 0.15) end
                emit("shield", e.x, e.y)
            end
            if def.ward then emit("ward", e.x, e.y) end
        end
    end
end

function G.Step(dt)
    local s = G.s
    if not s or s.over or s.draft or G.paused or (s.won and not s.endless) then return end
    G.Refresh()
    s.clock = s.clock + dt
    local B = s.bless

    for i = #s.spawns, 1, -1 do
        local sp = s.spawns[i]
        if sp.t <= s.clock then
            table.remove(s.spawns, i)
            s.spawnN = s.spawnN + 1
            spawn(sp.kind, sp.hp, sp.affix, nil, s.spawnN)
        end
    end

    -- Who can be seen: stealthed foes show up near a revealing tower, or anywhere with Hunter's Mark.
    -- Who is warded or urged on: everyone near a Blackrock Shaman or a warcaller.
    for _, e in ipairs(s.enemies) do
        e.ward, e.urged = false, false
        if e.stealth then
            e.seen = (B.mark or 0) > 0
            if not e.seen then
                for _, t in ipairs(s.towers) do
                    if t.st.reveal and dist2(t, e) <= t.st.reveal * t.st.reveal then e.seen = true break end
                end
            end
        end
    end
    for _, e in ipairs(s.enemies) do
        if not e.dead and e.sheepT <= 0 and (e.def.ward or e.def.warcry) then
            for _, o in ipairs(around(e, 1.5)) do
                if e.def.ward then o.ward = true end
                if e.def.warcry then o.urged = true end
            end
        end
    end

    -- Sabotage: a tower silenced every ten seconds.
    if s.waveAffix == "sabotage" and not s.idle and #s.towers > 0 then
        s.sabotageT = s.sabotageT - dt
        if s.sabotageT <= 0 then
            s.sabotageT = 10
            local t = s.towers[random(1, #s.towers)]
            silenceTowers(t.x, t.y, 0.1, 3)
        end
    end

    for _, e in ipairs(s.enemies) do
        if not e.dead then
            if e.sheepT > 0 then e.sheepT = e.sheepT - dt end
            if e.weakT > 0 then e.weakT = e.weakT - dt end
            abilities(e, dt, s)
            if e.submergeT > 0 then
                e.submergeT = e.submergeT - dt
            elseif e.stunT > 0 then
                e.stunT = e.stunT - dt
            else
                local speed = e.speed * (e.slowT > 0 and (1 - e.slowP) or 1)
                if e.def.sprint and e.hp < e.max * 0.5 then speed = speed * 1.5 end
                if e.urged then speed = speed * 1.3 end
                if e.frenzyN > 0 then speed = speed * (1 + 0.12 * e.frenzyN) end
                if e.burrowT > 0 then speed = speed * 1.3 end
                if e.sheepT > 0 then speed = speed * 0.5 end
                e.d = e.d + speed * dt
            end
            if e.slowT > 0 then e.slowT = e.slowT - dt end
            if e.burnT > 0 then
                e.burnT = e.burnT - dt
                hurt(e, e.burnDps * dt, e.burnSrc, true)
            end
            if e.poisonT > 0 and not e.dead then
                e.poisonT = e.poisonT - dt
                hurt(e, e.poisonDps * e.poisonN * dt, e.poisonSrc, true)
                if e.poisonT <= 0 then e.poisonN, e.poisonDps, e.plague = 0, 0, nil end
            end
            if e.regen > 0 and not e.dead then e.hp = min(e.max, e.hp + e.regen * e.max * dt) end
            if not e.dead then
                place(e)
                if e.d >= (e.flying and s.alen or s.len) then
                    e.dead = true
                    local cost = e.def.lives or 1
                    if e.def.boss and (B.ramparts or 0) > 0 then cost = math.ceil(cost / 2) end
                    if e.def.boss and (B.piety or 0) > 0 then cost = max(1, cost - 3) end
                    if e.affix == "grievous" then cost = cost + 1 end
                    s.lives = s.lives - cost
                    s.lost = s.lost + cost
                    s.leaked = true
                    if e.def.steal then s.gold = max(0, s.gold - e.def.steal) end
                    emit("leak", e)
                    if s.lives < 5 and s.lives > 0 and (B.secondwind or 0) > 0 and not s.winded then
                        s.winded, s.lives = true, s.lives + 10
                        emit("toast", "Second Wind! The keep rallies: +10 lives.")
                    end
                    if s.lives <= 0 then
                        if (B.laststand or 0) > 0 and not s.stood then
                            s.stood, s.lives = true, 5
                            emit("toast", "Last Stand! The keep holds on with 5 lives.")
                        else
                            s.lives, s.over = 0, true
                            emit("over", s.wave)
                            return
                        end
                    end
                end
            end
        end
    end

    for _, t in ipairs(s.towers) do
        local st = t.st
        if t.silenceT > 0 then t.silenceT = t.silenceT - dt end
        if st.rate > 0 and t.silenceT <= 0 then
            t.cd = t.cd - dt
            if t.cd <= 0 then
                if st.pulse then
                    -- Traps, Consecration, coils and totems: hit everyone in reach at once.
                    local any, r2 = false, st.range * st.range
                    for _, e in ipairs(s.enemies) do
                        if not e.dead and touchable(e) and not (st.ground and e.flying) and dist2(t, e) <= r2 then
                            any = true
                            if st.slow then chill(e, st.slow, st.slowTime) end
                            if st.root then stun(e, st.root) end
                            if st.knock then knock(e, st.knock) end
                            if st.damage > 0 then hurt(e, st.damage, t, st.pierce) end
                        end
                    end
                    if any and not st.quiet then emit("splash", t.x, t.y, st.range, st.mine and "fire" or t.kind) end
                    t.cd = any and 1 / st.rate or 0
                else
                    local targets = pick(t)
                    if targets[1] then
                        attack(t, targets)
                        t.cd = 1 / st.rate
                    else
                        t.cd, t.focus, t.ramp = 0, nil, 0
                    end
                end
            end
        end
    end

    local n = 0
    for j = 1, #s.enemies do
        local e = s.enemies[j]
        if not e.dead then n = n + 1 s.enemies[n] = e end
    end
    for j = #s.enemies, n + 1, -1 do s.enemies[j] = nil end

    if not s.idle and #s.spawns == 0 and #s.enemies == 0 then
        s.idle = true
        s.autoT = AUTO_DELAY
        if s.bossWave then s.bossWave, G.dirty = false, true end
        if (B.momentum or 0) > 0 then
            local m = s.leaked and 0 or min(10, s.momentum + 1)
            if m ~= s.momentum then s.momentum, G.dirty = m, true end
        end
        local marks = s.level.marks + (B.treasure or 0) + (s.wave > s.level.waves and 1 or 0)
        for _, t in ipairs(s.towers) do
            if t.st.markIncome then marks = marks + t.st.markIncome end
        end
        if s.heroic then marks = floor(marks * 1.5 + 0.5) end
        emit("cleared", s.wave, marks)
        if s.wave == s.level.waves and not s.endless then
            s.won = true
            emit("victory", G.Stars())
            return
        end
        checkDraft()
    end
    if s.idle and G.auto and s.wave > 0 and not s.draft then
        s.autoT = (s.autoT or AUTO_DELAY) - dt
        if s.autoT <= 0 then G.NextWave() end
    end
end

-- Saving a run between flights -------------------------------------------------
-- Only taken between waves: a run reloaded mid-wave goes back to the start of that wave.

function G.Snapshot()
    local s = G.s
    local towers, bless, built = {}, {}, {}
    for _, t in ipairs(s.towers) do
        towers[#towers + 1] = { c = t.c, r = t.r, kind = t.kind, level = t.level, spec = t.spec,
            mode = t.mode, spent = t.spent, dealt = floor(t.dealt) }
    end
    for k, v in pairs(s.bless) do bless[k] = v end
    for k, v in pairs(s.run.built) do built[k] = v end
    local loadout = {}
    for i, k in ipairs(s.loadout) do loadout[i] = k end
    return { v = SNAP_VERSION, map = s.mapKey, seed = s.seed, gold = floor(s.gold), lives = s.lives, startLives = s.startLives,
        lost = s.lost, wave = s.wave, kills = s.kills, marks = s.marks, drafts = s.drafts, head = s.head,
        rerollN = s.rerollN, rerollsLeft = s.rerollsLeft, endless = s.endless, won = s.won, stood = s.stood,
        heroic = s.heroic, loadout = loadout, mendAcc = s.mendAcc, momentum = s.momentum, bossesSlain = s.bossesSlain,
        killN = s.killN, winded = s.winded,
        run = { built = built, upgrades = s.run.upgrades, sold = s.run.sold, early = s.run.early, spent = s.run.spent },
        towers = towers, bless = bless }
end

function G.Restore(snap)
    if type(snap) ~= "table" or (snap.v ~= 2 and snap.v ~= SNAP_VERSION) or not ns.LEVEL[snap.map] then return false end
    G.New(snap.map, snap.seed, true, snap.heroic, snap.loadout)
    local s = G.s
    s.gold, s.lives, s.wave = snap.gold or START_GOLD, snap.lives or START_LIVES, snap.wave or 0
    s.startLives, s.lost = snap.startLives or s.lives, snap.lost or 0
    s.kills, s.marks, s.drafts = snap.kills or 0, snap.marks or 0, snap.drafts or 0
    s.head, s.rerollN, s.rerollsLeft = snap.head and true or false, snap.rerollN or 0, snap.rerollsLeft
    s.endless, s.won, s.stood = snap.endless, snap.won, snap.stood
    s.mendAcc, s.momentum, s.bossesSlain = snap.mendAcc or 0, snap.momentum or 0, snap.bossesSlain or 0
    s.killN, s.winded = snap.killN or 0, snap.winded
    if type(snap.run) == "table" then
        for k, v in pairs(snap.run.built or {}) do s.run.built[k] = v end
        s.run.upgrades, s.run.sold = snap.run.upgrades or 0, snap.run.sold or 0
        s.run.early, s.run.spent = snap.run.early or 0, snap.run.spent or 0
    end
    for k, v in pairs(snap.bless or {}) do if ns.BLESSING[k] then s.bless[k] = v end end
    gatherMods()
    for _, t in ipairs(snap.towers or {}) do
        if ns.TOWER[t.kind] and G.CanBuild(t.c, t.r, t.kind) then
            -- A run saved before loadouts existed can keep the towers it already built.
            if not s.inLoadout[t.kind] then
                s.inLoadout[t.kind] = true
                s.loadout[#s.loadout + 1] = t.kind
            end
            addTower(t.kind, t.c, t.r, t)
        end
    end
    G.Refresh()
    checkDraft()
    return true
end
