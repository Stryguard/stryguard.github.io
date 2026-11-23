local _, ns = ...

-- Deeds: feats that pay marks once. Each one listens for an event (`on`) and its test
-- says whether it's done:
--   win (run, stars)   a level was won; run is the game state
--   stats              a lifetime tally went up (kills, bosses, waves, flights, built, damage)
--   spec (tower)       a tower reached level 4
--   endless (wave)     a wave held past the end of a level
--   gold (amount)      gold held during a run
--   sell (run)         a tower was sold
--   shop               a shop rank was bought

local I = "Interface\\Icons\\"
local D = {}
ns.DEEDS = D

local function deed(t) D[#D + 1] = t end
local function M() return ns.Meta end

local function bought()
    local n = 0
    for _, it in ipairs(ns.SHOP) do n = n + M().Rank(it.key) end
    return n
end

-- The campaign.
for c, ch in ipairs(ns.CHAPTERS) do
    deed { key = "ch" .. c, name = ch.name, icon = I .. "INV_BannerPVP_02", marks = 20 + 10 * c, on = "win",
        desc = "Win every level of " .. ch.name .. ".",
        test = function() return M().ChapterAll(c, function(p) return p.cleared end) end }
    deed { key = "star" .. c, name = ch.name .. ": Flawless", icon = I .. "Spell_Holy_SealOfMight", marks = 30 + 10 * c, on = "win",
        desc = "Earn three stars on every level of " .. ch.name .. ".",
        test = function() return M().ChapterAll(c, function(p) return (p.stars or 0) >= 3 end) end }
    deed { key = "hero" .. c, name = ch.name .. ": Heroic", icon = I .. "Spell_Holy_AuraOfLight", marks = 40 + 15 * c, on = "win",
        desc = "Win every level of " .. ch.name .. " on Heroic.",
        test = function() return M().ChapterAll(c, function(p) return (p.heroic or 0) > 0 end) end }
end

-- One for each tower.
for _, t in ipairs(ns.TOWERS) do
    deed { key = "t_" .. t.key, name = t.short .. " Master", icon = t.icon, marks = 10, on = "spec",
        desc = "Raise a " .. t.name .. " to level 4.",
        test = function(tower) return tower.kind == t.key end }
end

-- Lifetime tallies, as ladders.
local function ladder(stat, steps, names, icon, say)
    for i, n in ipairs(steps) do
        deed { key = stat .. n, name = names[i], icon = icon, marks = 10 + 15 * (i - 1), on = "stats",
            desc = say:format(n >= 1000000 and (n / 1000000 .. " million") or tostring(n)),
            test = function() return M().Stat(stat) >= n end }
    end
end
ladder("kills", { 500, 2500, 10000, 50000, 150000 }, { "Pest Control", "Exterminator", "Slayer", "Annihilator", "The Unending Tide" },
    I .. "INV_Sword_27", "Slay %s foes.")
ladder("bosses", { 10, 50, 150, 400 }, { "Bounty Hunter", "Boss Slayer", "Dungeon Crawler", "Raid Leader" },
    I .. "INV_Misc_Head_Dragon_Black", "Slay %s bosses.")
ladder("waves", { 100, 500, 2000 }, { "Holding Pattern", "The Wall", "Bulwark of Azeroth" },
    I .. "INV_Shield_06", "Hold %s waves.")
ladder("flights", { 5, 25, 100 }, { "Frequent Flyer", "Gryphon Rider", "Lord of the Skies" },
    I .. "Ability_Hunter_EagleEye", "Play on %s flights.")
ladder("built", { 100, 1000 }, { "Builder", "Master Architect" },
    I .. "INV_Hammer_01", "Build %s towers.")
ladder("damage", { 1000000, 10000000, 100000000 }, { "Heavy Hitter", "Devastator", "Cataclysm" },
    I .. "Spell_Fire_SelfDestruct", "Deal %s damage.")

-- Endless.
for i, n in ipairs({ 30, 40, 50, 75, 100 }) do
    deed { key = "endless" .. n, name = ({ "Overtime", "Double Shift", "Night Watch", "Iron Will", "Eternal Vigil" })[i],
        icon = I .. "INV_Misc_PocketWatch_01", marks = 15 + 15 * i, on = "endless",
        desc = ("Hold wave %d on any level."):format(n),
        test = function(wave) return wave >= n end }
end

-- Gold.
deed { key = "gold1000", name = "Nest Egg", icon = I .. "INV_Misc_Coin_02", marks = 15, on = "gold",
    desc = "Hold 1,000 gold at once.", test = function(g) return g >= 1000 end }
deed { key = "gold5000", name = "Goblin Fortune", icon = I .. "INV_Misc_Coin_17", marks = 40, on = "gold",
    desc = "Hold 5,000 gold at once.", test = function(g) return g >= 5000 end }

-- Feats in a single run.
local function built(run)
    local kinds, total = 0, 0
    for _, n in pairs(run.run.built) do kinds, total = kinds + 1, total + n end
    return kinds, total
end
deed { key = "minimal", name = "Minimalist", icon = I .. "INV_Misc_Note_01", marks = 30, on = "win",
    desc = "Win a level with five towers or fewer on the board.", test = function(s) return #s.towers <= 5 end }
deed { key = "archers", name = "Robin's Hood", icon = I .. "Ability_Marksmanship", marks = 30, on = "win",
    desc = "Win a level building only Archer Towers.",
    test = function(s) local k = built(s) return k == 1 and (s.run.built.archer or 0) > 0 end }
deed { key = "noupgrade", name = "Good Enough", icon = I .. "INV_Hammer_02", marks = 30, on = "win",
    desc = "Win a level without upgrading a single tower.", test = function(s) return s.run.upgrades == 0 end }
deed { key = "untouchable", name = "Untouchable", icon = I .. "Spell_Holy_DivineIntervention", marks = 50, on = "win",
    desc = "Win a level on Heroic without losing a life.", test = function(s, stars) return s.heroic and stars == 3 end }
deed { key = "lastbreath", name = "By a Whisker", icon = I .. "Spell_Holy_AshesToAshes", marks = 25, on = "win",
    desc = "Win a level with a single life left.", test = function(s) return s.lives == 1 end }
deed { key = "closecall", name = "Close Call", icon = I .. "INV_Shield_05", marks = 25, on = "win",
    desc = "Win a level after Last Stand saved the keep.", test = function(s) return s.stood == true end }
deed { key = "variety", name = "Full Armoury", icon = I .. "INV_Box_01", marks = 30, on = "win",
    desc = "Win a level having built nine different kinds of tower.", test = function(s) return (built(s)) >= 9 end }
deed { key = "pennies", name = "Penny Pincher", icon = I .. "INV_Misc_Bag_10", marks = 25, on = "win",
    desc = "Win a level with 1,000 gold left over.", test = function(s) return s.gold >= 1000 end }
deed { key = "blessed", name = "Thrice Blessed", icon = I .. "Spell_Holy_PrayerOfHealing02", marks = 25, on = "win",
    desc = "Win a level holding eight blessings.", test = function(s) return s.drafts >= 8 end }
deed { key = "speedrun", name = "In a Hurry", icon = I .. "Ability_Rogue_Sprint", marks = 25, on = "win",
    desc = "Win a level after calling ten waves early.", test = function(s) return s.run.early >= 10 end }
deed { key = "banker", name = "Venture Capital", icon = I .. "INV_Misc_Coin_04", marks = 25, on = "win",
    desc = "Win a level with four gold-making towers.",
    test = function(s) local n = 0 for _, t in ipairs(s.towers) do if t.def.income then n = n + 1 end end return n >= 4 end }
deed { key = "spendthrift", name = "Spendthrift", icon = I .. "INV_Misc_Coin_06", marks = 25, on = "win",
    desc = "Win a level after spending 8,000 gold.", test = function(s) return s.run.spent >= 8000 end }
deed { key = "oops", name = "Second Thoughts", icon = I .. "INV_Misc_Wrench_01", marks = 15, on = "sell",
    desc = "Sell ten towers in one run.", test = function(s) return s.run.sold >= 10 end }

-- The shop.
deed { key = "shop25", name = "Regular Customer", icon = I .. "INV_Misc_Bag_11", marks = 20, on = "shop",
    desc = "Buy 25 ranks in the shop.", test = function() return bought() >= 25 end }
deed { key = "shop100", name = "Shopaholic", icon = I .. "INV_Misc_Bag_08", marks = 50, on = "shop",
    desc = "Buy 100 ranks in the shop.", test = function() return bought() >= 100 end }
deed { key = "masteries", name = "Grand Master", icon = I .. "INV_Misc_Book_09", marks = 100, on = "shop",
    desc = "Master every tower in the shop.",
    test = function()
        for _, it in ipairs(ns.SHOP) do if it.tower and M().Rank(it.key) < it.max then return false end end
        return true
    end }
deed { key = "stocked", name = "Fully Stocked", icon = I .. "INV_Box_01", marks = 150, on = "shop",
    desc = "Buy every rank of everything in the shop.",
    test = function()
        for _, it in ipairs(ns.SHOP) do if M().Rank(it.key) < it.max then return false end end
        return true
    end }

ns.DEED = {}
for _, d in ipairs(D) do ns.DEED[d.key] = d end
