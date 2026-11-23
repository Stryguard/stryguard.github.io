local _, ns = ...

-- What carries over between runs: marks, the shop, the armoury loadout, which levels
-- are cleared (and on Heroic), lifetime tallies and deeds. Everything lives in
-- SkywatchDB (ns.db), set up by Core.

local Meta = {}
ns.Meta = Meta

local floor, max = math.floor, math.max

function Meta.Marks()
    return ns.db and ns.db.marks or 0
end

function Meta.Rank(k)
    local db = ns.db
    return db and db.shop[k] or 0
end

-- The price of the next rank, or nil once it's maxed.
function Meta.Price(k)
    local it = ns.SHOP_ITEM[k]
    local r = Meta.Rank(k)
    if r >= it.max then return nil end
    return it.base * (r + 1)
end

function Meta.Buy(k)
    local price = Meta.Price(k)
    if not price or ns.db.marks < price then return false end
    ns.db.marks = ns.db.marks - price
    ns.db.shop[k] = Meta.Rank(k) + 1
    if ns.Game.s then ns.Game.dirty = true end
    Meta.CheckDeeds("shop")
    return true
end

-- Pays out marks (with the Guild Scholar bonus) and counts them towards this run.
function Meta.AddMarks(n)
    if not ns.db or n <= 0 then return 0 end
    n = floor(n * (1 + 0.1 * Meta.Rank("scholar")) + 0.5)
    ns.db.marks = ns.db.marks + n
    local s = ns.Game.s
    if s then s.marks = (s.marks or 0) + n end
    return n
end

function Meta.Progress(levelKey)
    return ns.db and ns.db.campaign[levelKey] or nil
end

function Meta.Cleared(levelKey)
    local p = Meta.Progress(levelKey)
    return p ~= nil and p.cleared == true
end

function Meta.HeroicCleared(levelKey)
    local p = Meta.Progress(levelKey)
    return p ~= nil and (p.heroic or 0) > 0
end

function Meta.LevelOpen(levelKey)
    local i = ns.LEVEL[levelKey].index
    return i == 1 or Meta.Cleared(ns.LEVELS[i - 1].key)
end

function Meta.ChapterOpen(c)
    return Meta.LevelOpen(ns.CHAPTERS[c].levels[1].key)
end

function Meta.TowerUnlocked(kind)
    local u = ns.TOWER[kind].unlock
    return u == nil or Meta.Cleared(u)
end

-- The tower that clearing a level unlocks, if any.
function Meta.TowerFrom(levelKey)
    for _, t in ipairs(ns.TOWERS) do
        if t.unlock == levelKey then return t end
    end
end

-- The armoury: which unlocked towers (up to nine) come along on a run.
function Meta.Loadout()
    local out, seen = {}, {}
    local saved = ns.db and ns.db.loadout
    if type(saved) == "table" then
        for _, k in ipairs(saved) do
            if ns.TOWER[k] and Meta.TowerUnlocked(k) and not seen[k] and #out < ns.LOADOUT_SIZE then
                out[#out + 1], seen[k] = k, true
            end
        end
    end
    if #out == 0 then
        for _, t in ipairs(ns.TOWERS) do
            if Meta.TowerUnlocked(t.key) and #out < ns.LOADOUT_SIZE then out[#out + 1] = t.key end
        end
    end
    return out
end

function Meta.InLoadout(kind)
    for _, k in ipairs(Meta.Loadout()) do if k == kind then return true end end
    return false
end

-- Add or remove a tower. Returns false (and changes nothing) when the loadout is full or
-- would be left empty.
function Meta.ToggleLoadout(kind)
    if not Meta.TowerUnlocked(kind) then return false end
    local list = Meta.Loadout()
    for i, k in ipairs(list) do
        if k == kind then
            if #list == 1 then return false end
            table.remove(list, i)
            ns.db.loadout = list
            return true
        end
    end
    if #list >= ns.LOADOUT_SIZE then return false end
    list[#list + 1] = kind
    ns.db.loadout = list
    return true
end

-- A level won: record it and pay out. The full reward is for the first win; later wins
-- pay a quarter. Each star earned for the first time pays a fifth of the reward. Heroic
-- wins are kept apart and pay half as much again.
function Meta.Victory(levelKey, stars, heroic)
    local def = ns.LEVEL[levelKey]
    local p = ns.db.campaign[levelKey] or {}
    ns.db.campaign[levelKey] = p
    local first, newStars, base
    if heroic then
        first = (p.heroic or 0) == 0
        newStars = max(0, stars - (p.heroic or 0))
        base = first and floor(def.reward * 1.5) or floor(def.reward / 3)
        p.heroic = max(p.heroic or 0, stars)
    else
        first = not p.cleared
        newStars = max(0, stars - (p.stars or 0))
        base = first and def.reward or floor(def.reward / 4)
        p.stars = max(p.stars or 0, stars)
    end
    local unlocking = not p.cleared
    p.cleared = true
    local paid = Meta.AddMarks(base + newStars * floor(def.reward / 5))
    local tower = unlocking and Meta.TowerFrom(levelKey) or nil
    -- A new tower joins the loadout by itself if there's room.
    if tower and #Meta.Loadout() < ns.LOADOUT_SIZE then
        local list = Meta.Loadout()
        list[#list + 1] = tower.key
        ns.db.loadout = list
    end
    return {
        first = first, marks = paid, newStars = newStars, heroic = heroic,
        tower = tower, nextLevel = ns.LEVELS[def.index + 1],
    }
end

-- The furthest wave held on a level once it carried on past its last wave.
function Meta.RecordEndless(levelKey, wave)
    local p = ns.db.campaign[levelKey] or {}
    ns.db.campaign[levelKey] = p
    if wave > (p.endless or 0) then p.endless = wave end
    Meta.CheckDeeds("endless", wave)
end

function Meta.BestEndless()
    local best = 0
    for _, p in pairs(ns.db.campaign) do best = max(best, p.endless or 0) end
    return best
end

-- Lifetime tallies, for deeds.
function Meta.Stat(k)
    return ns.db and ns.db.stats[k] or 0
end

function Meta.Count(k, n)
    if not ns.db then return end
    ns.db.stats[k] = (ns.db.stats[k] or 0) + (n or 1)
end

-- Deeds ------------------------------------------------------------------------

Meta.onDeed = nil   -- set by the UI to announce a deed

function Meta.HasDeed(k)
    return ns.db and ns.db.deeds[k] ~= nil
end

function Meta.DeedCount()
    local n = 0
    for _ in pairs(ns.db.deeds) do n = n + 1 end
    return n
end

-- Look at every deed listening for this event and award the ones now earned.
function Meta.CheckDeeds(event, a, b)
    if not ns.db or not ns.DEEDS then return end
    for _, d in ipairs(ns.DEEDS) do
        if d.on == event and not ns.db.deeds[d.key] then
            local ok, earned = pcall(d.test, a, b)
            if ok and earned then
                ns.db.deeds[d.key] = time and time() or 1
                local paid = Meta.AddMarks(d.marks or 0)
                if Meta.onDeed then Meta.onDeed(d, paid) end
            end
        end
    end
end

-- How many levels of a chapter meet `test`.
function Meta.ChapterAll(c, test)
    for _, l in ipairs(ns.CHAPTERS[c].levels) do
        if not test(Meta.Progress(l.key) or {}) then return false end
    end
    return true
end

-- Players of the first version get marks for the records they set on the old maps.
function Meta.Migrate()
    local db = ns.db
    if db.veteran then return end
    db.veteran = true
    local total = 0
    for _, v in pairs(db.best or {}) do total = total + (tonumber(v) or 0) end
    if total > 0 then
        local gift = math.min(80, total * 2)
        db.marks = db.marks + gift
        return gift
    end
end
