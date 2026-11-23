local _, ns = ...

-- Every foe and boss. Abilities (see Game.lua):
--   armor, flying, stealth, regen (share of health a second), sprint (faster when hurt),
--   heals, ward (allies take 30% less), revive (gets up once), split/splitCount,
--   shield (share of health as a shield), burrow (seconds between dives, untouchable while down),
--   blink (seconds between hops forward), frenzy (faster when friends die nearby),
--   brood = { kind, every } (drops foes as it walks), silence = { every, radius, time } (stops towers),
--   shields (shields allies), warcry (allies move faster), magicRes / physRes (shrugs off a share),
--   steal (gold lost if it gets through), deathHeal (heals allies when it dies).
-- Bosses also: lives, summon = { at = { health shares }, kind, count }, submerge = { at, time },
--   unstoppable (can't be slowed or stunned).
-- `cost` (its share of a wave's budget), `gap` (spacing) and `gold` are worked out below
-- when not given.

local I = "Interface\\Icons\\"
local E = {}
ns.ENEMIES = E

local function add(list)
    for k, v in pairs(list) do E[k] = v end
end

-- Chapter one: the road to Stryguard.
add {
    kobold   = { name = "Kobold Tunneler", icon = I .. "INV_Pick_02", color = { 0.75, 0.55, 0.3 }, hp = 26, speed = 1.0, gold = 3, cost = 1, gap = 0.9 },
    wolf     = { name = "Mangy Wolf", icon = I .. "Ability_Hunter_Pet_Wolf", color = { 0.55, 0.55, 0.6 }, hp = 17, speed = 1.9, gold = 3, cost = 1, gap = 0.6 },
    murloc   = { name = "Murloc Raider", icon = I .. "INV_Misc_Head_Murloc_01", color = { 0.3, 0.6, 0.5 }, hp = 10, speed = 1.35, gold = 1, size = 15, cost = 0.45, gap = 0.35 },
    brute    = { name = "Gnoll Brute", icon = I .. "Ability_Warrior_ShieldWall", color = { 0.6, 0.45, 0.35 }, hp = 60, speed = 0.7, gold = 6, armor = 4, size = 22, cost = 2.6, gap = 1.4 },
    golem    = { name = "Harvest Golem", icon = I .. "INV_Misc_Gear_01", color = { 0.65, 0.58, 0.4 }, hp = 90, speed = 0.6, gold = 7, armor = 6, size = 23, cost = 3.4, gap = 1.6 },
    bat      = { name = "Vampire Bat", icon = I .. "Ability_Hunter_Pet_Bat", color = { 0.55, 0.35, 0.65 }, hp = 20, speed = 1.25, gold = 4, flying = true, cost = 1.6, gap = 0.8 },
    ooze     = { name = "Swamp Ooze", icon = I .. "Spell_Nature_Acid_01", color = { 0.4, 0.65, 0.2 }, hp = 44, speed = 0.8, gold = 3, split = "oozeling", splitCount = 2, size = 21, cost = 2.2, gap = 1.3 },
    oozeling = { name = "Oozeling", icon = I .. "Spell_Nature_Acid_01", color = { 0.4, 0.65, 0.2 }, hp = 14, speed = 1.15, gold = 1, size = 13 },
    stalker  = { name = "Defias Stalker", icon = I .. "Ability_Stealth", color = { 0.6, 0.2, 0.2 }, hp = 34, speed = 1.3, gold = 6, stealth = true, cost = 2.2, gap = 1.0 },
    mystic   = { name = "Gnoll Mystic", icon = I .. "Spell_Nature_HealingTouch", color = { 0.3, 0.6, 0.8 }, hp = 40, speed = 0.85, gold = 7, heals = true, cost = 3, gap = 1.6 },
    ghoul    = { name = "Risen Ghoul", icon = I .. "Spell_Shadow_RaiseDead", color = { 0.5, 0.6, 0.45 }, hp = 30, speed = 1.05, gold = 4, revive = true, cost = 1.6, gap = 0.9 },
    raptor   = { name = "Marsh Raptor", icon = I .. "Ability_Hunter_Pet_Raptor", color = { 0.55, 0.65, 0.3 }, hp = 30, speed = 1.5, gold = 4, sprint = true, cost = 1.5, gap = 0.6 },
    harpy    = { name = "Windfury Harpy", icon = I .. "Ability_Hunter_Pet_Owl", color = { 0.75, 0.6, 0.5 }, hp = 24, speed = 1.7, gold = 4, flying = true, size = 17, cost = 1.7, gap = 0.7 },
    whelp    = { name = "Black Whelp", icon = I .. "INV_Misc_Head_Dragon_Black", color = { 0.35, 0.25, 0.3 }, hp = 24, speed = 1.4, gold = 2, flying = true, size = 15, cost = 1.1, gap = 0.6 },
    grunt    = { name = "Blackrock Grunt", icon = I .. "Ability_Warrior_Cleave", color = { 0.5, 0.35, 0.3 }, hp = 75, speed = 1.0, gold = 7, armor = 3, size = 21, cost = 3.0, gap = 1.2 },
    shaman   = { name = "Blackrock Shaman", icon = I .. "Spell_Nature_SkinofEarth", color = { 0.4, 0.5, 0.75 }, hp = 45, speed = 0.85, gold = 7, ward = true, cost = 3.2, gap = 1.6 },

    hogger   = { name = "Hogger", icon = I .. "Ability_Hunter_Pet_Hyena", hp = 400, speed = 0.6, gold = 60, armor = 2, size = 28, boss = true, lives = 10 },
    vancleef = { name = "Edwin VanCleef", icon = I .. "INV_Misc_Head_Human_01", hp = 700, speed = 0.7, gold = 100, armor = 3, size = 28, boss = true, lives = 10,
                 summon = { at = { 0.66, 0.33 }, kind = "stalker", count = 3 } },
    stitches = { name = "Stitches", icon = I .. "Spell_Shadow_AnimateDead", hp = 1000, speed = 0.45, gold = 140, armor = 3, size = 30, boss = true, lives = 10, unstoppable = true },
    mutanus  = { name = "Mutanus the Devourer", icon = I .. "INV_Misc_Head_Murloc_01", hp = 900, speed = 0.55, gold = 140, armor = 4, regen = 0.012, size = 30, boss = true, lives = 10 },
    arikara  = { name = "Arikara", icon = I .. "Ability_Hunter_Pet_WindSerpent", hp = 950, speed = 0.75, gold = 180, armor = 2, flying = true, size = 30, boss = true, lives = 10,
                 summon = { at = { 0.66, 0.33 }, kind = "harpy", count = 4 } },
    onyxia   = { name = "Onyxia", icon = I .. "INV_Misc_Head_Dragon_Black", hp = 1100, speed = 0.5, gold = 200, armor = 5, flying = true, size = 30, boss = true, lives = 15,
                 summon = { at = { 0.75, 0.5, 0.25 }, kind = "whelp", count = 4 } },
}

-- Chapter two: Dun Morogh and Gnomeregan.
add {
    trogg      = { name = "Rockjaw Trogg", icon = I .. "INV_Misc_Head_Kobold_01", color = { 0.55, 0.5, 0.45 }, hp = 34, speed = 0.9, armor = 2 },
    frostmane  = { name = "Frostmane Headhunter", icon = I .. "INV_Misc_Head_Troll_01", color = { 0.5, 0.7, 0.85 }, hp = 30, speed = 1.15 },
    leopard    = { name = "Snow Leopard", icon = I .. "Ability_Hunter_Pet_Cat", color = { 0.85, 0.85, 0.9 }, hp = 20, speed = 1.9, sprint = true },
    wendigo    = { name = "Young Wendigo", icon = I .. "Ability_Hunter_Pet_Bear", color = { 0.8, 0.82, 0.88 }, hp = 70, speed = 0.7, armor = 2, regen = 0.01, size = 22 },
    leper      = { name = "Leper Gnome", icon = I .. "INV_Misc_Head_Gnome_01", color = { 0.55, 0.75, 0.45 }, hp = 18, speed = 1.3, shield = 0.4, size = 15 },
    seer       = { name = "Frostmane Seer", icon = I .. "Spell_Frost_SummonWaterElemental", color = { 0.4, 0.6, 0.9 }, hp = 38, speed = 0.85, heals = true },
    tunneler   = { name = "Trogg Tunneler", icon = I .. "INV_Misc_Shovel_01", color = { 0.5, 0.4, 0.3 }, hp = 32, speed = 1.0, burrow = 4 },
    yeti       = { name = "Ice Yeti", icon = I .. "Ability_Hunter_Pet_Gorilla", color = { 0.75, 0.85, 0.95 }, hp = 110, speed = 0.6, armor = 4, size = 24 },
    mechano    = { name = "Mechano-Tank", icon = I .. "INV_Gizmo_07", color = { 0.6, 0.6, 0.65 }, hp = 85, speed = 0.65, armor = 6, physRes = 0.3, size = 23 },
    walkbomb   = { name = "Walking Bomb", icon = I .. "INV_Misc_Bomb_02", color = { 0.7, 0.4, 0.3 }, hp = 22, speed = 1.4, size = 15 },

    grikni     = { name = "Grik'nir the Cold", icon = I .. "Spell_Frost_FrostArmor02", hp = 650, speed = 0.65, gold = 120, armor = 3, size = 28, boss = true, lives = 10,
                   summon = { at = { 0.6, 0.3 }, kind = "trogg", count = 4 } },
    icebeard   = { name = "Old Icebeard", icon = I .. "Ability_Hunter_Pet_Gorilla", hp = 950, speed = 0.5, gold = 140, armor = 6, regen = 0.01, size = 30, boss = true, lives = 10 },
    beld       = { name = "Captain Beld", icon = I .. "INV_Misc_Head_Dwarf_01", hp = 850, speed = 0.65, gold = 150, armor = 5, size = 28, boss = true, lives = 10, warcry = true,
                   summon = { at = { 0.5 }, kind = "frostmane", count = 6 } },
    vagash     = { name = "Vagash", icon = I .. "Ability_Hunter_Pet_Bear", hp = 1100, speed = 0.55, gold = 160, armor = 4, size = 30, boss = true, lives = 12, sprint = true },
    fallout    = { name = "Viscous Fallout", icon = I .. "Spell_Nature_Acid_01", hp = 1000, speed = 0.5, gold = 170, armor = 2, size = 30, boss = true, lives = 12,
                   split = "ooze", splitCount = 6 },
    thermaplugg = { name = "Mekgineer Thermaplugg", icon = I .. "INV_Gizmo_02", hp = 1300, speed = 0.5, gold = 220, armor = 5, shield = 0.3, physRes = 0.2, size = 30, boss = true, lives = 15,
                   summon = { at = { 0.75, 0.5, 0.25 }, kind = "walkbomb", count = 5 } },
}

-- Chapter three: Redridge and Duskwood.
add {
    mongrel    = { name = "Redridge Mongrel", icon = I .. "INV_Misc_Head_Gnoll_01", color = { 0.7, 0.45, 0.3 }, hp = 28, speed = 1.2 },
    poacher    = { name = "Redridge Poacher", icon = I .. "Ability_Rogue_Ambush", color = { 0.6, 0.35, 0.25 }, hp = 30, speed = 1.2, stealth = true },
    outrunner  = { name = "Blackrock Outrunner", icon = I .. "Ability_Rogue_Sprint", color = { 0.55, 0.3, 0.25 }, hp = 26, speed = 1.7, sprint = true },
    warcaller  = { name = "Blackrock Warcaller", icon = I .. "Ability_Warrior_BattleShout", color = { 0.7, 0.3, 0.2 }, hp = 50, speed = 0.9, armor = 2, warcry = true },
    worg       = { name = "Black Worg", icon = I .. "Ability_Hunter_Pet_Wolf", color = { 0.25, 0.22, 0.25 }, hp = 24, speed = 2.0, frenzy = true },
    dragonspawn = { name = "Black Dragonspawn", icon = I .. "INV_Misc_Head_Dragon_Black", color = { 0.3, 0.2, 0.25 }, hp = 120, speed = 0.6, armor = 5, size = 24 },
    worgen     = { name = "Nightbane Worgen", icon = I .. "Ability_Hunter_Pet_Wolf", color = { 0.45, 0.4, 0.35 }, hp = 55, speed = 1.2, frenzy = true, sprint = true, size = 21 },
    shadowcaster = { name = "Shadowcaster", icon = I .. "Spell_Shadow_Curse", color = { 0.5, 0.25, 0.6 }, hp = 40, speed = 0.9, silence = { every = 7, radius = 1.6, time = 2 } },
    webspider  = { name = "Venom Web Spider", icon = I .. "Ability_Hunter_Pet_Spider", color = { 0.4, 0.45, 0.3 }, hp = 70, speed = 0.75, armor = 2, brood = { kind = "spiderling", every = 3.5 }, size = 22 },
    spiderling = { name = "Spiderling", icon = I .. "Ability_Hunter_Pet_Spider", color = { 0.45, 0.5, 0.35 }, hp = 8, speed = 1.6, gold = 1, size = 12 },

    gathilzogg = { name = "Gath'Ilzogg", icon = I .. "INV_Misc_Head_Orc_01", hp = 900, speed = 0.65, gold = 150, armor = 4, size = 28, boss = true, lives = 10, warcry = true,
                   summon = { at = { 0.5 }, kind = "outrunner", count = 6 } },
    morganth   = { name = "Morganth", icon = I .. "Spell_Shadow_RaiseDead", hp = 950, speed = 0.55, gold = 160, armor = 2, size = 28, boss = true, lives = 10,
                   silence = { every = 8, radius = 2, time = 2 }, summon = { at = { 0.66, 0.33 }, kind = "ghoul", count = 4 } },
    tharilzun  = { name = "Tharil'zun", icon = I .. "Ability_Warrior_SavageBlow", hp = 1150, speed = 0.6, gold = 170, armor = 6, size = 30, boss = true, lives = 12, unstoppable = true },
    malathrom  = { name = "Lord Malathrom", icon = I .. "Spell_Shadow_AnimateDead", hp = 900, speed = 0.55, gold = 170, armor = 3, size = 30, boss = true, lives = 12, revive = true },
    stalvan    = { name = "Stalvan Mistmantle", icon = I .. "Spell_Shadow_Haunting", hp = 1100, speed = 0.6, gold = 180, physRes = 0.5, size = 28, boss = true, lives = 12, blink = 6 },
    morbent    = { name = "Morbent Fel", icon = I .. "Spell_Shadow_DeathCoil", hp = 1400, speed = 0.5, gold = 240, armor = 3, shield = 0.5, regen = 0.008, size = 30, boss = true, lives = 15,
                   summon = { at = { 0.66, 0.33 }, kind = "worgen", count = 4 } },
}

-- Chapter four: Ashenvale and Blackfathom Deeps.
add {
    furbolg    = { name = "Foulweald Totemic", icon = I .. "Ability_Racial_BearForm", color = { 0.55, 0.42, 0.3 }, hp = 50, speed = 0.9, armor = 2 },
    ursa       = { name = "Foulweald Shaman", icon = I .. "Spell_Nature_StoneSkinTotem", color = { 0.45, 0.55, 0.7 }, hp = 45, speed = 0.85, ward = true },
    trickster  = { name = "Satyr Trickster", icon = I .. "Spell_Shadow_SummonFelHunter", color = { 0.6, 0.35, 0.55 }, hp = 35, speed = 1.2, stealth = true, blink = 5 },
    felhound   = { name = "Felhound", icon = I .. "Spell_Shadow_SummonFelHunter", color = { 0.45, 0.6, 0.3 }, hp = 45, speed = 1.4, magicRes = 0.5 },
    myrmidon   = { name = "Naga Myrmidon", icon = I .. "INV_Spear_04", color = { 0.3, 0.55, 0.55 }, hp = 75, speed = 0.85, armor = 3, shield = 0.3, size = 22 },
    siren      = { name = "Naga Siren", icon = I .. "Spell_Frost_SummonWaterElemental", color = { 0.35, 0.65, 0.75 }, hp = 40, speed = 0.9, shields = true },
    snapclaw   = { name = "Murkshallow Snapclaw", icon = I .. "Ability_Hunter_Pet_Crab", color = { 0.7, 0.35, 0.25 }, hp = 60, speed = 0.7, armor = 8, size = 21 },
    wisp       = { name = "Corrupted Wisp", icon = I .. "Spell_Nature_WispSplode", color = { 0.6, 0.8, 0.6 }, hp = 22, speed = 1.6, flying = true, magicRes = 0.5, size = 14 },
    nightsaber = { name = "Shadowclaw", icon = I .. "Ability_Druid_SupriseAttack", color = { 0.35, 0.3, 0.45 }, hp = 26, speed = 2.0, stealth = true },

    ursangous  = { name = "Ursangous", icon = I .. "Ability_Racial_BearForm", hp = 1000, speed = 0.6, gold = 160, armor = 4, regen = 0.01, size = 30, boss = true, lives = 10, frenzy = true },
    ghamoora   = { name = "Ghamoo-ra", icon = I .. "Ability_Hunter_Pet_Turtle", hp = 900, speed = 0.45, gold = 170, armor = 12, size = 30, boss = true, lives = 10 },
    sarevess   = { name = "Lady Sarevess", icon = I .. "INV_Spear_04", hp = 1050, speed = 0.6, gold = 180, armor = 3, shield = 0.3, size = 28, boss = true, lives = 12,
                   summon = { at = { 0.66, 0.33 }, kind = "myrmidon", count = 3 } },
    kelris     = { name = "Twilight Lord Kelris", icon = I .. "Spell_Shadow_Twilight", hp = 1100, speed = 0.55, gold = 190, armor = 2, size = 28, boss = true, lives = 12,
                   silence = { every = 7, radius = 2.2, time = 2.5 }, summon = { at = { 0.5 }, kind = "trickster", count = 5 } },
    serrakis   = { name = "Old Serra'kis", icon = I .. "INV_Misc_MonsterScales_05", hp = 1150, speed = 0.75, gold = 190, armor = 3, flying = true, size = 30, boss = true, lives = 12 },
    akumai     = { name = "Aku'mai", icon = I .. "INV_Misc_MonsterScales_09", hp = 1600, speed = 0.45, gold = 260, armor = 6, regen = 0.012, size = 30, boss = true, lives = 15,
                   submerge = { at = { 0.5 }, time = 4 }, summon = { at = { 0.5 }, kind = "snapclaw", count = 5 } },
}

-- Chapter five: Stranglethorn Vale and Zul'Gurub.
add {
    tiger      = { name = "Stranglethorn Tiger", icon = I .. "Ability_Mount_JungleTiger", color = { 0.85, 0.55, 0.25 }, hp = 30, speed = 1.9, stealth = true },
    jraptor    = { name = "Jungle Raptor", icon = I .. "Ability_Hunter_Pet_Raptor", color = { 0.45, 0.6, 0.35 }, hp = 40, speed = 1.6, sprint = true, frenzy = true },
    axethrower = { name = "Skullsplitter Axe Thrower", icon = I .. "INV_Axe_04", color = { 0.4, 0.55, 0.6 }, hp = 50, speed = 1.0, armor = 2 },
    witchdoctor = { name = "Witch Doctor", icon = I .. "Spell_Nature_Regenerate", color = { 0.5, 0.7, 0.5 }, hp = 42, speed = 0.85, heals = true, revive = true },
    shadowhunter = { name = "Shadowhunter", icon = I .. "Spell_Shadow_ShadowWordPain", color = { 0.35, 0.3, 0.45 }, hp = 45, speed = 1.3, stealth = true, blink = 6 },
    pirate     = { name = "Bloodsail Swashbuckler", icon = I .. "INV_Sword_30", color = { 0.7, 0.2, 0.2 }, hp = 55, speed = 1.0, armor = 2, steal = 15 },
    silverback = { name = "Silverback Gorilla", icon = I .. "Ability_Hunter_Pet_Gorilla", color = { 0.5, 0.5, 0.5 }, hp = 140, speed = 0.65, armor = 3, size = 24 },
    batrider   = { name = "Gurubashi Bat Rider", icon = I .. "Ability_Hunter_Pet_Bat", color = { 0.5, 0.3, 0.5 }, hp = 38, speed = 1.4, flying = true, deathHeal = true },
    basilisk   = { name = "Crystal Spine Basilisk", icon = I .. "INV_Misc_MonsterScales_03", color = { 0.6, 0.75, 0.75 }, hp = 90, speed = 0.7, armor = 9, physRes = 0.2, size = 22 },

    bangalash  = { name = "King Bangalash", icon = I .. "Ability_Mount_WhiteTiger", hp = 1000, speed = 0.75, gold = 170, armor = 3, size = 30, boss = true, lives = 10,
                   summon = { at = { 0.66, 0.33 }, kind = "tiger", count = 4 } },
    moshogg    = { name = "Mosh'Ogg Butcher", icon = I .. "Ability_Warrior_Cleave", hp = 1250, speed = 0.55, gold = 180, armor = 7, size = 30, boss = true, lives = 12 },
    mandokir   = { name = "Bloodlord Mandokir", icon = I .. "Ability_Mount_Raptor", hp = 1150, speed = 0.75, gold = 190, armor = 4, size = 30, boss = true, lives = 12, sprint = true, frenzy = true,
                   summon = { at = { 0.5 }, kind = "jraptor", count = 5 } },
    grilek     = { name = "Gri'lek", icon = I .. "Ability_Warrior_InnerRage", hp = 1500, speed = 0.45, gold = 200, armor = 6, size = 30, boss = true, lives = 12, unstoppable = true },
    jindo      = { name = "Jin'do the Hexxer", icon = I .. "Spell_Shadow_ShadowWordDominate", hp = 1200, speed = 0.55, gold = 210, armor = 2, size = 28, boss = true, lives = 12,
                   silence = { every = 6, radius = 2.2, time = 2.5 }, summon = { at = { 0.75, 0.5, 0.25 }, kind = "shadowhunter", count = 3 } },
    hakkar     = { name = "Hakkar the Soulflayer", icon = I .. "Spell_Shadow_BloodBoil", hp = 1800, speed = 0.45, gold = 280, armor = 5, regen = 0.01, size = 30, boss = true, lives = 15,
                   silence = { every = 8, radius = 2.5, time = 2 }, summon = { at = { 0.66, 0.33 }, kind = "batrider", count = 4 } },
}

-- Chapter six: the Badlands and Uldaman.
add {
    ogre       = { name = "Dustbelcher Ogre", icon = I .. "INV_Misc_Head_Orc_01", color = { 0.6, 0.5, 0.4 }, hp = 85, speed = 0.8, armor = 2, size = 23 },
    ogremage   = { name = "Dustbelcher Mystic", icon = I .. "Spell_Holy_PowerWordShield", color = { 0.45, 0.45, 0.75 }, hp = 50, speed = 0.8, shields = true },
    ambusher   = { name = "Stonevault Ambusher", icon = I .. "INV_Misc_Head_Kobold_01", color = { 0.55, 0.45, 0.35 }, hp = 38, speed = 1.05, burrow = 4 },
    saboteur   = { name = "Dark Iron Saboteur", icon = I .. "INV_Misc_Bomb_05", color = { 0.4, 0.35, 0.4 }, hp = 42, speed = 1.1, silence = { every = 6, radius = 1.5, time = 2.5 } },
    scalding   = { name = "Scalding Whelp", icon = I .. "INV_Misc_Head_Dragon_Red", color = { 0.85, 0.35, 0.2 }, hp = 28, speed = 1.4, flying = true, magicRes = 0.3, size = 15 },
    coyote     = { name = "Crag Coyote", icon = I .. "Ability_Hunter_Pet_Hyena", color = { 0.75, 0.55, 0.35 }, hp = 22, speed = 2.0, frenzy = true },
    stonekeeper = { name = "Stone Keeper", icon = I .. "INV_Stone_15", color = { 0.55, 0.55, 0.5 }, hp = 160, speed = 0.5, armor = 10, physRes = 0.3, size = 25 },
    earthen    = { name = "Earthen Guardian", icon = I .. "Spell_Nature_StoneClawTotem", color = { 0.5, 0.45, 0.4 }, hp = 90, speed = 0.7, armor = 6, shield = 0.3, size = 23 },
    buzzard    = { name = "Ridge Buzzard", icon = I .. "Ability_Hunter_Pet_Vulture", color = { 0.5, 0.4, 0.35 }, hp = 26, speed = 1.5, flying = true },
    shard      = { name = "Obsidian Shard", icon = I .. "INV_Stone_15", color = { 0.25, 0.22, 0.28 }, hp = 40, speed = 0.8, armor = 6, size = 15 },

    revelosh   = { name = "Revelosh", icon = I .. "Spell_Nature_Lightning", hp = 1050, speed = 0.6, gold = 180, armor = 3, size = 28, boss = true, lives = 10, shields = true,
                   summon = { at = { 0.5 }, kind = "ambusher", count = 6 } },
    ironaya    = { name = "Ironaya", icon = I .. "INV_Stone_15", hp = 1500, speed = 0.4, gold = 190, armor = 10, size = 30, boss = true, lives = 12, unstoppable = true },
    sentinel   = { name = "Obsidian Sentinel", icon = I .. "INV_Stone_15", hp = 1200, speed = 0.5, gold = 200, armor = 8, size = 30, boss = true, lives = 12, split = "shard", splitCount = 6 },
    keeper     = { name = "Ancient Stone Keeper", icon = I .. "Spell_Nature_StoneSkinTotem", hp = 1450, speed = 0.45, gold = 210, armor = 9, physRes = 0.3, size = 30, boss = true, lives = 12, regen = 0.008 },
    galgann    = { name = "Galgann Firehammer", icon = I .. "INV_Hammer_03", hp = 1300, speed = 0.55, gold = 220, armor = 5, size = 28, boss = true, lives = 12,
                   silence = { every = 6, radius = 2.2, time = 3 }, summon = { at = { 0.66, 0.33 }, kind = "saboteur", count = 3 } },
    archaedas  = { name = "Archaedas", icon = I .. "Spell_Nature_EarthBindTotem", hp = 2000, speed = 0.4, gold = 300, armor = 8, size = 30, boss = true, lives = 15,
                   submerge = { at = { 0.66, 0.33 }, time = 3 }, summon = { at = { 0.66, 0.33 }, kind = "earthen", count = 4 } },
}

-- Chapter seven: Tanaris and Zul'Farrak.
add {
    sandfury   = { name = "Sandfury Hideskinner", icon = I .. "INV_Misc_Head_Troll_01", color = { 0.75, 0.6, 0.4 }, hp = 38, speed = 1.1 },
    sandcaster = { name = "Sandfury Shadowcaster", icon = I .. "Spell_Shadow_Curse", color = { 0.55, 0.4, 0.6 }, hp = 42, speed = 0.9, silence = { every = 6, radius = 1.6, time = 2.5 } },
    scorpid    = { name = "Scorpid Hunter", icon = I .. "Ability_Hunter_Pet_Scorpid", color = { 0.7, 0.5, 0.25 }, hp = 55, speed = 0.9, armor = 6 },
    duneworm   = { name = "Dune Worm", icon = I .. "INV_Misc_MonsterTail_03", color = { 0.8, 0.7, 0.5 }, hp = 70, speed = 0.9, burrow = 3.5, size = 22 },
    thief      = { name = "Wastewander Thief", icon = I .. "Ability_Rogue_Disguise", color = { 0.6, 0.5, 0.4 }, hp = 36, speed = 1.3, stealth = true, steal = 25 },
    hyena      = { name = "Blisterpaw Hyena", icon = I .. "Ability_Hunter_Pet_Hyena", color = { 0.8, 0.6, 0.35 }, hp = 26, speed = 1.9, frenzy = true },
    zombie     = { name = "Zul'Farrak Zombie", icon = I .. "Spell_Shadow_RaiseDead", color = { 0.55, 0.6, 0.45 }, hp = 48, speed = 0.85, revive = true },
    roc        = { name = "Searing Roc", icon = I .. "Ability_Hunter_Pet_Owl", color = { 0.9, 0.5, 0.25 }, hp = 48, speed = 1.3, flying = true, size = 19 },
    dustdevil  = { name = "Dust Devil", icon = I .. "Spell_Nature_Cyclone", color = { 0.8, 0.75, 0.6 }, hp = 40, speed = 1.6, physRes = 0.5, blink = 5 },

    antusul    = { name = "Antu'sul", icon = I .. "Spell_Nature_Earthquake", hp = 1300, speed = 0.55, gold = 200, armor = 4, size = 28, boss = true, lives = 10,
                   summon = { at = { 0.75, 0.5, 0.25 }, kind = "scorpid", count = 3 } },
    theka      = { name = "Theka the Martyr", icon = I .. "Spell_Holy_Excorcism", hp = 1200, speed = 0.55, gold = 210, armor = 4, shield = 0.4, revive = true, size = 28, boss = true, lives = 12 },
    zumrah     = { name = "Witch Doctor Zum'rah", icon = I .. "Spell_Shadow_RaiseDead", hp = 1250, speed = 0.55, gold = 220, armor = 2, size = 28, boss = true, lives = 12, heals = true,
                   summon = { at = { 0.8, 0.6, 0.4, 0.2 }, kind = "zombie", count = 4 } },
    bly        = { name = "Sergeant Bly", icon = I .. "INV_Weapon_Rifle_02", hp = 1350, speed = 0.65, gold = 230, armor = 5, size = 28, boss = true, lives = 12, steal = 100, blink = 7 },
    velratha   = { name = "Hydromancer Velratha", icon = I .. "Spell_Frost_SummonWaterElemental", hp = 1300, speed = 0.55, gold = 230, magicRes = 0.5, size = 28, boss = true, lives = 12, shields = true },
    gahzrilla  = { name = "Gahz'rilla", icon = I .. "INV_Misc_MonsterScales_08", hp = 2200, speed = 0.4, gold = 320, armor = 7, regen = 0.012, size = 30, boss = true, lives = 15, unstoppable = true,
                   summon = { at = { 0.5 }, kind = "duneworm", count = 4 } },
}

-- Chapter eight: the Plaguelands and Stratholme.
add {
    skeleton   = { name = "Skeletal Warrior", icon = I .. "INV_Misc_Bone_HumanSkull_01", color = { 0.85, 0.82, 0.72 }, hp = 40, speed = 0.95, armor = 3, revive = true },
    plagueghoul = { name = "Plague Ghoul", icon = I .. "Spell_Shadow_CallofBone", color = { 0.5, 0.6, 0.4 }, hp = 44, speed = 1.15, frenzy = true },
    horror     = { name = "Patchwork Horror", icon = I .. "Spell_Shadow_AnimateDead", color = { 0.6, 0.55, 0.5 }, hp = 160, speed = 0.55, armor = 4, split = "maggot", splitCount = 4, size = 25 },
    maggot     = { name = "Plague Maggot", icon = I .. "INV_Misc_MonsterTail_03", color = { 0.75, 0.75, 0.6 }, hp = 12, speed = 1.3, gold = 1, size = 12 },
    gargoyle   = { name = "Stonewing Gargoyle", icon = I .. "Spell_Shadow_Shadowfiend", color = { 0.45, 0.45, 0.5 }, hp = 40, speed = 1.3, flying = true, armor = 3, size = 18 },
    necromancer = { name = "Scourge Necromancer", icon = I .. "Spell_Shadow_RaiseDead", color = { 0.4, 0.3, 0.5 }, hp = 50, speed = 0.8, brood = { kind = "skeleton", every = 5 } },
    banshee    = { name = "Wailing Banshee", icon = I .. "Spell_Shadow_SoulLeech_3", color = { 0.7, 0.75, 0.85 }, hp = 40, speed = 1.1, physRes = 0.6, silence = { every = 8, radius = 1.5, time = 2 } },
    acolyte    = { name = "Cult of the Damned Acolyte", icon = I .. "Spell_Shadow_AntiShadow", color = { 0.35, 0.3, 0.35 }, hp = 45, speed = 0.9, shields = true },
    plaguehound = { name = "Plaguehound", icon = I .. "Ability_Hunter_Pet_Hyena", color = { 0.45, 0.55, 0.35 }, hp = 30, speed = 1.8, frenzy = true },
    crawler    = { name = "Crypt Crawler", icon = I .. "Ability_Hunter_Pet_Spider", color = { 0.35, 0.35, 0.3 }, hp = 65, speed = 0.9, armor = 6, burrow = 5 },

    forresten  = { name = "Hearthsinger Forresten", icon = I .. "Spell_Shadow_Haunting", hp = 1300, speed = 0.6, gold = 220, physRes = 0.5, size = 28, boss = true, lives = 10,
                   silence = { every = 7, radius = 2, time = 2 } },
    timmy      = { name = "Timmy the Cruel", icon = I .. "Spell_Shadow_UnholyStrength", hp = 1500, speed = 0.6, gold = 230, armor = 6, size = 30, boss = true, lives = 12, frenzy = true, sprint = true },
    ramstein   = { name = "Ramstein the Gorger", icon = I .. "Spell_Shadow_AnimateDead", hp = 1800, speed = 0.4, gold = 240, armor = 7, size = 30, boss = true, lives = 12, unstoppable = true,
                   summon = { at = { 0.5 }, kind = "horror", count = 2 } },
    gandling   = { name = "Darkmaster Gandling", icon = I .. "Spell_Shadow_Teleport", hp = 1500, speed = 0.55, gold = 250, armor = 3, size = 28, boss = true, lives = 12, blink = 5,
                   summon = { at = { 0.75, 0.5, 0.25 }, kind = "skeleton", count = 5 } },
    barthilas  = { name = "Magistrate Barthilas", icon = I .. "INV_Misc_Head_Human_01", hp = 1600, speed = 0.6, gold = 250, armor = 4, shield = 0.4, size = 28, boss = true, lives = 12, revive = true },
    rivendare  = { name = "Baron Rivendare", icon = I .. "Ability_Mount_Undeadhorse", hp = 2300, speed = 0.45, gold = 340, armor = 7, size = 30, boss = true, lives = 15,
                   silence = { every = 7, radius = 2.5, time = 2.5 }, summon = { at = { 0.8, 0.6, 0.4, 0.2 }, kind = "skeleton", count = 4 } },
}

-- Chapter nine: Blackrock Depths and the Molten Core.
add {
    anvilrage  = { name = "Anvilrage Guardsman", icon = I .. "INV_Shield_09", color = { 0.45, 0.4, 0.42 }, hp = 90, speed = 0.8, armor = 6, size = 22 },
    imp        = { name = "Fire Imp", icon = I .. "Spell_Shadow_SummonImp", color = { 0.9, 0.45, 0.2 }, hp = 24, speed = 1.6, magicRes = 0.5, size = 14 },
    corehound  = { name = "Core Hound", icon = I .. "Ability_Hunter_Pet_Hyena", color = { 0.75, 0.35, 0.2 }, hp = 140, speed = 0.8, armor = 4, revive = true, size = 24 },
    lavaspawn  = { name = "Lava Spawn", icon = I .. "Spell_Fire_Volcano", color = { 1, 0.45, 0.1 }, hp = 60, speed = 0.9, split = "lavalet", splitCount = 3, magicRes = 0.3 },
    lavalet    = { name = "Lavalet", icon = I .. "Spell_Fire_Volcano", color = { 1, 0.55, 0.15 }, hp = 18, speed = 1.3, gold = 1, size = 13 },
    geologist  = { name = "Dark Iron Geologist", icon = I .. "INV_Pick_03", color = { 0.4, 0.35, 0.35 }, hp = 50, speed = 1.0, armor = 3, burrow = 4 },
    flamewaker = { name = "Flamewaker", icon = I .. "Spell_Fire_Immolation", color = { 0.85, 0.4, 0.2 }, hp = 110, speed = 0.75, armor = 6, warcry = true, size = 23 },
    giant      = { name = "Molten Giant", icon = I .. "Spell_Fire_SoulBurn", color = { 0.7, 0.3, 0.2 }, hp = 260, speed = 0.45, armor = 8, size = 26 },
    surger     = { name = "Lava Surger", icon = I .. "Spell_Fire_Fire", color = { 1, 0.6, 0.2 }, hp = 60, speed = 1.5, blink = 4, magicRes = 0.3 },
    firepriest = { name = "Flamewaker Priest", icon = I .. "Spell_Fire_SealOfFire", color = { 0.9, 0.6, 0.3 }, hp = 60, speed = 0.8, heals = true, shields = true },

    roccor     = { name = "Lord Roccor", icon = I .. "Spell_Fire_Elemental_Totem", hp = 1500, speed = 0.5, gold = 240, armor = 8, magicRes = 0.3, size = 30, boss = true, lives = 10 },
    argelmach  = { name = "Golem Lord Argelmach", icon = I .. "INV_Gizmo_07", hp = 1600, speed = 0.5, gold = 250, armor = 8, shield = 0.3, size = 30, boss = true, lives = 12,
                   summon = { at = { 0.66, 0.33 }, kind = "anvilrage", count = 3 } },
    angerforge = { name = "General Angerforge", icon = I .. "INV_Hammer_09", hp = 1700, speed = 0.55, gold = 260, armor = 7, size = 30, boss = true, lives = 12, warcry = true,
                   summon = { at = { 0.3 }, kind = "anvilrage", count = 6 } },
    thaurissan = { name = "Emperor Dagran Thaurissan", icon = I .. "INV_Hammer_09", hp = 1900, speed = 0.5, gold = 270, armor = 6, size = 30, boss = true, lives = 12, shield = 0.4,
                   silence = { every = 7, radius = 2.2, time = 2.5 } },
    executus   = { name = "Majordomo Executus", icon = I .. "Spell_Fire_SealOfFire", hp = 1800, speed = 0.5, gold = 280, armor = 6, shields = true, size = 30, boss = true, lives = 12,
                   summon = { at = { 0.8, 0.6, 0.4, 0.2 }, kind = "flamewaker", count = 2 } },
    ragnaros   = { name = "Ragnaros", icon = I .. "Spell_Fire_LavaSpawn", hp = 2700, speed = 0.4, gold = 380, armor = 8, magicRes = 0.3, size = 30, boss = true, lives = 15, unstoppable = true,
                   submerge = { at = { 0.66, 0.33 }, time = 4 }, summon = { at = { 0.66, 0.33 }, kind = "surger", count = 6 } },
}

-- Chapter ten: Silithus, Ahn'Qiraj and Naxxramas.
add {
    drone      = { name = "Hive'Zara Drone", icon = I .. "INV_Misc_AhnQirajTrinket_01", color = { 0.7, 0.6, 0.3 }, hp = 30, speed = 1.5, frenzy = true },
    wasp       = { name = "Hive'Zara Wasp", icon = I .. "INV_Misc_AhnQirajTrinket_02", color = { 0.8, 0.7, 0.25 }, hp = 30, speed = 1.7, flying = true, size = 15 },
    qiraji     = { name = "Qiraji Warrior", icon = I .. "INV_Misc_AhnQirajTrinket_03", color = { 0.6, 0.45, 0.25 }, hp = 160, speed = 0.7, armor = 8, physRes = 0.2, size = 24 },
    anubisath  = { name = "Anubisath Sentinel", icon = I .. "INV_Misc_AhnQirajTrinket_04", color = { 0.7, 0.6, 0.45 }, hp = 300, speed = 0.45, armor = 10, magicRes = 0.4, ward = true, size = 26 },
    eradicator = { name = "Obsidian Eradicator", icon = I .. "INV_Stone_15", color = { 0.3, 0.25, 0.35 }, hp = 120, speed = 0.7, armor = 4, magicRes = 0.8, size = 23 },
    swarmguard = { name = "Qiraji Swarmguard", icon = I .. "INV_Misc_AhnQirajTrinket_05", color = { 0.55, 0.5, 0.3 }, hp = 90, speed = 0.75, armor = 5, brood = { kind = "scarab", every = 2.5 }, size = 22 },
    scarab     = { name = "Scarab", icon = I .. "INV_Misc_AhnQirajTrinket_06", color = { 0.5, 0.4, 0.2 }, hp = 9, speed = 1.7, gold = 1, size = 12 },
    geolord    = { name = "Twilight Geolord", icon = I .. "Spell_Shadow_Twilight", color = { 0.45, 0.35, 0.6 }, hp = 55, speed = 0.85, silence = { every = 6, radius = 1.8, time = 3 }, shields = true },
    stinger    = { name = "Hive'Zara Stinger", icon = I .. "Ability_Hunter_Pet_Scorpid", color = { 0.75, 0.55, 0.3 }, hp = 55, speed = 1.2, burrow = 3.5, stealth = true },
    tentacle   = { name = "Eye Tentacle", icon = I .. "Spell_Shadow_Charm", color = { 0.55, 0.3, 0.45 }, hp = 70, speed = 0.9, magicRes = 0.3, physRes = 0.3 },

    skeram     = { name = "The Prophet Skeram", icon = I .. "Spell_Arcane_Blink", hp = 1900, speed = 0.55, gold = 280, armor = 4, size = 28, boss = true, lives = 12, blink = 4,
                   summon = { at = { 0.75, 0.5, 0.25 }, kind = "geolord", count = 2 } },
    huhuran    = { name = "Princess Huhuran", icon = I .. "Ability_Hunter_Pet_Wasp", hp = 2100, speed = 0.6, gold = 290, armor = 6, size = 30, boss = true, lives = 12, frenzy = true, sprint = true,
                   summon = { at = { 0.5 }, kind = "wasp", count = 8 } },
    ouro       = { name = "Ouro", icon = I .. "INV_Misc_MonsterTail_03", hp = 2300, speed = 0.5, gold = 300, armor = 8, size = 30, boss = true, lives = 12, burrow = 5,
                   summon = { at = { 0.66, 0.33 }, kind = "scarab", count = 10 } },
    veklor     = { name = "Emperor Vek'lor", icon = I .. "INV_Misc_AhnQirajTrinket_04", hp = 2200, speed = 0.5, gold = 310, armor = 6, magicRes = 0.5, physRes = 0.3, size = 30, boss = true, lives = 12, blink = 6 },
    cthun      = { name = "C'Thun", icon = I .. "Spell_Shadow_Charm", hp = 3000, speed = 0.35, gold = 360, armor = 6, size = 30, boss = true, lives = 15, regen = 0.008,
                   silence = { every = 6, radius = 2.5, time = 3 }, summon = { at = { 0.8, 0.6, 0.4, 0.2 }, kind = "tentacle", count = 4 } },
    kelthuzad  = { name = "Kel'Thuzad", icon = I .. "Spell_Shadow_DarkRitual", hp = 3400, speed = 0.4, gold = 450, armor = 7, magicRes = 0.3, size = 30, boss = true, lives = 20, unstoppable = true,
                   silence = { every = 7, radius = 2.5, time = 3 }, submerge = { at = { 0.66, 0.33 }, time = 4 },
                   summon = { at = { 0.66, 0.33 }, kind = "horror", count = 3 } },
}

-- What it costs out of a wave's budget: health, scaled for speed, armour and abilities.
local function cost(d)
    local c = d.hp / 26 * d.speed ^ 0.6 * (1 + 0.06 * (d.armor or 0))
    if d.flying then c = c * 1.7 end
    if d.stealth then c = c * 1.6 end
    if d.heals then c = c * 2.2 end
    if d.ward then c = c * 2.0 end
    if d.revive then c = c * 1.5 end
    if d.sprint then c = c * 1.2 end
    if d.shield then c = c * (1 + d.shield) end
    if d.burrow then c = c * 1.3 end
    if d.blink then c = c * 1.3 end
    if d.frenzy then c = c * 1.15 end
    if d.brood then c = c * 1.8 end
    if d.silence then c = c * 1.8 end
    if d.shields then c = c * 2.0 end
    if d.warcry then c = c * 1.8 end
    if d.deathHeal then c = c * 1.4 end
    if d.steal then c = c * 1.1 end
    c = c * (1 + 0.6 * (d.magicRes or 0)) * (1 + 0.8 * (d.physRes or 0)) * (1 + 20 * (d.regen or 0))
    if d.split then c = c + cost(E[d.split]) * d.splitCount * 0.6 end
    return c
end

for _, d in pairs(E) do
    if not d.boss then
        d.cost = d.cost or math.floor(cost(d) * 100 + 0.5) / 100
        d.gap = d.gap or math.max(0.35, math.min(1.6, 0.9 * d.cost ^ 0.4 / d.speed ^ 0.5))
        d.gold = d.gold or math.max(1, math.floor(1 + 1.9 * d.cost + 0.5))
    end
end

-- What the game says the first time a foe shows up in a level.
ns.INTRO = {
    wolf = "Wolves: fast but frail.",
    murloc = "Murlocs come in big packs. Mrglglgl!",
    brute = "Gnoll Brutes wear armour. Small hits barely scratch them.",
    golem = "Harvest Golems are slow and heavily armoured. Bring big hits.",
    bat = "Bats fly over the road, cutting across its bends.",
    ooze = "Oozes split in two when they die.",
    stalker = "Defias Stalkers can't be seen without a Holy Beacon nearby.",
    mystic = "Gnoll Mystics heal the foes around them.",
    ghoul = "Risen Ghouls get back up once after they fall.",
    raptor = "Raptors sprint when they're hurt.",
    harpy = "Harpies fly fast, cutting across the bends of the road.",
    whelp = "Black Whelps fly over the road, cutting across its bends.",
    grunt = "Blackrock Grunts are tough and armoured.",
    shaman = "Blackrock Shamans ward the foes around them: they take 30% less damage.",
    stitches = "Stitches can't be slowed or stunned.",

    frostmane = "Frostmane trolls: quick on their feet.",
    leopard = "Snow Leopards pounce faster when hurt.",
    wendigo = "Wendigos are shaggy and slowly heal themselves.",
    leper = "Leper Gnomes carry tinkered shields. Break the shield first.",
    seer = "Frostmane Seers heal the foes around them.",
    tunneler = "Trogg Tunnelers burrow: while they're underground nothing can hit them.",
    yeti = "Ice Yetis are big, slow and armoured.",
    mechano = "Mechano-Tanks shrug off physical hits. Magic works better.",
    mongrel = "Redridge gnolls, a whole pack of them.",
    poacher = "Poachers sneak. You'll need a way to see them.",
    outrunner = "Blackrock Outrunners sprint when hurt.",
    warcaller = "Warcallers urge the foes near them on: they move faster.",
    worg = "Black Worgs grow frenzied when their packmates fall.",
    dragonspawn = "Dragonspawn: big, armoured and slow.",
    worgen = "Worgen frenzy and sprint. Bring them down fast.",
    shadowcaster = "Shadowcasters silence towers near them for a moment.",
    webspider = "Venom Web Spiders leave spiderlings behind them.",
    furbolg = "Foulweald furbolgs, thick-furred.",
    ursa = "Furbolg shamans ward the foes around them.",
    trickster = "Satyr Tricksters are stealthed and blink forward.",
    felhound = "Felhounds eat magic: it barely hurts them.",
    myrmidon = "Naga Myrmidons carry water shields.",
    siren = "Naga Sirens shield the foes around them.",
    snapclaw = "Snapclaws are crabs. Very, very armoured.",
    wisp = "Corrupted Wisps fly, and shrug off magic.",
    nightsaber = "Shadowclaws stalk unseen, and fast.",
    tiger = "Stranglethorn Tigers: fast and stealthed.",
    jraptor = "Jungle Raptors frenzy and sprint.",
    axethrower = "Skullsplitter trolls, tough and many.",
    witchdoctor = "Witch Doctors heal their friends and get back up once.",
    shadowhunter = "Shadowhunters vanish and blink forward.",
    pirate = "Bloodsail pirates steal gold if they get through!",
    silverback = "Silverbacks are huge. Huge.",
    batrider = "Bat Riders heal the foes below them when they're shot down.",
    basilisk = "Basilisks are armoured and shrug off physical hits.",
    ogre = "Dustbelcher Ogres: big and dim.",
    ogremage = "Ogre Mystics shield the foes around them.",
    ambusher = "Stonevault troggs burrow under your fire.",
    saboteur = "Dark Iron Saboteurs silence the towers they pass.",
    scalding = "Scalding Whelps fly and resist magic.",
    coyote = "Crag Coyotes frenzy as their pack falls.",
    stonekeeper = "Stone Keepers: armour on armour.",
    earthen = "Earthen Guardians carry stone shields.",
    buzzard = "Buzzards circle over the road.",
    sandfury = "Sandfury trolls swarm out of Zul'Farrak.",
    sandcaster = "Sandfury Shadowcasters silence towers.",
    scorpid = "Scorpids are well armoured.",
    duneworm = "Dune Worms dive under the sand.",
    thief = "Wastewander Thieves sneak, and steal gold if they get through.",
    hyena = "Hyenas frenzy when their pack falls.",
    zombie = "Zul'Farrak Zombies get back up once.",
    roc = "Searing Rocs: big flyers.",
    dustdevil = "Dust Devils blink about, and physical hits pass through them.",
    skeleton = "Skeletal Warriors pull themselves back together once.",
    plagueghoul = "Plague Ghouls frenzy.",
    horror = "Patchwork Horrors burst into maggots.",
    gargoyle = "Gargoyles fly, armoured.",
    necromancer = "Necromancers raise skeletons as they walk.",
    banshee = "Banshees: physical hits barely touch them, and they silence towers.",
    acolyte = "Cultists shield the foes around them.",
    plaguehound = "Plaguehounds frenzy.",
    crawler = "Crypt Crawlers burrow.",
    anvilrage = "Anvilrage Guardsmen: heavy armour.",
    imp = "Fire Imps shrug off magic.",
    corehound = "Core Hounds get back up once.",
    lavaspawn = "Lava Spawn burst into Lavalets.",
    geologist = "Geologists burrow.",
    flamewaker = "Flamewakers urge the foes near them on.",
    giant = "Molten Giants. Bring everything.",
    surger = "Lava Surgers blink forward.",
    firepriest = "Flamewaker Priests heal and shield.",
    drone = "Silithid drones frenzy as the swarm falls.",
    wasp = "Wasps: fast flyers.",
    qiraji = "Qiraji Warriors are armoured and shrug off physical hits.",
    anubisath = "Anubisath Sentinels resist magic and ward their friends.",
    eradicator = "Obsidian Eradicators all but ignore magic.",
    swarmguard = "Swarmguards spill scarabs as they walk.",
    geolord = "Twilight Geolords silence towers and shield their friends.",
    stinger = "Stingers are stealthed and burrow.",
    tentacle = "Eye Tentacles resist everything a little.",

    tharilzun = "Tharil'zun can't be slowed or stunned.",
    grilek = "Gri'lek can't be slowed or stunned.",
    ironaya = "Ironaya can't be slowed or stunned.",
    ramstein = "Ramstein can't be slowed or stunned.",
    gahzrilla = "Gahz'rilla can't be slowed or stunned.",
    ragnaros = "Ragnaros can't be slowed or stunned, and dives into the lava when hurt.",
    kelthuzad = "Kel'Thuzad can't be slowed or stunned.",
}
