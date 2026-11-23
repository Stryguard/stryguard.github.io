local _, ns = ...

-- Towers, affixes, blessings and the shop, plus how waves are put together. Foes are in
-- Foes.lua, the campaign in Levels.lua, the maps in Maps.lua and deeds in Deeds.lua.

ns.COLS, ns.ROWS, ns.CELL = 22, 13, 26
local I = "Interface\\Icons\\"
ns.LOADOUT_SIZE = 9

-- Damage at each tower level (level 4 is a specialisation), and the price of reaching
-- each level as a share of what the tower cost to build.
ns.LEVEL_DAMAGE = { 1, 1.6, 2.4, 3.4 }
ns.UPGRADE_COST = { 0, 1.0, 1.6, 2.4 }

-- A tower's `attack` says how it fights (see Game.lua). `on` is what it's built on: "#"
-- road, "R" rocks, "~" water or lava; nothing means open ground. `unlock` is the level
-- that must be won first. `school` "magic" towers are resisted by warded foes, the rest
-- by ironclad ones. A specialisation changes the tower with `add`, `mul` and `set`.
ns.TOWERS = {
    { key = "archer", name = "Archer Tower", short = "Archer", icon = I .. "Ability_Marksmanship", color = { 0.85, 0.68, 0.38 },
      attack = "arrow", cost = 50, range = 3, damage = 10, rate = 1.2, air = true,
      blurb = "Cheap and steady, and hits flyers. Armour blunts its arrows.",
      specs = {
          { key = "marksman", name = "Marksman", icon = I .. "INV_Spear_07", desc = "Huge range. Slow, heavy shots that ignore armour and often crit.",
            add = { range = 2.5 }, mul = { rate = 0.5, damage = 2.2 }, set = { pierce = true, crit = 0.25 } },
          { key = "volley", name = "Volley", icon = I .. "Ability_UpgradeMoonGlaive", desc = "Looses arrows at three foes at once.",
            set = { targets = 3 } },
      } },
    { key = "frost", name = "Frost Spire", short = "Frost", icon = I .. "Spell_Frost_FrostBolt02", color = { 0.45, 0.7, 1 },
      attack = "frost", school = "magic", cost = 70, range = 2.5, damage = 4, rate = 1.0, air = true, slow = 0.35, slowTime = 2, slowGrow = true,
      blurb = "Chills foes so they crawl. Fire hits chilled foes 50% harder.",
      specs = {
          { key = "blizzard", name = "Blizzard", icon = I .. "Spell_Frost_IceStorm", desc = "Every bolt chills and hurts everything around its target.",
            set = { splash = 1.0 } },
          { key = "deepfreeze", name = "Deep Freeze", icon = I .. "Spell_Frost_FrostNova", desc = "One bolt in five freezes its target solid for a second.",
            set = { freeze = 0.2 } },
      } },
    { key = "fire", name = "Fire Tower", short = "Fire", icon = I .. "Spell_Fire_FlameBolt", color = { 1, 0.45, 0.15 },
      attack = "blast", school = "magic", cost = 90, range = 2.5, damage = 14, rate = 0.6, splash = 0.9, chillBonus = 0.5,
      blurb = "Fireballs that splash. Can't hit flyers.",
      specs = {
          { key = "inferno", name = "Inferno", icon = I .. "Spell_Fire_SelfDestruct", desc = "Bigger blasts, more damage.",
            set = { splash = 1.5 }, mul = { damage = 1.3 } },
          { key = "ignite", name = "Ignite", icon = I .. "Spell_Fire_Incinerate", desc = "Sets foes ablaze. The burn ignores armour.",
            set = { burn = 0.6 } },
      } },
    { key = "trap", name = "Spike Trap", short = "Trap", icon = I .. "Ability_Ensnare", color = { 0.7, 0.7, 0.7 },
      attack = "pulse", on = "#", ground = true, cost = 45, range = 0.7, damage = 6, rate = 2,
      blurb = "Built on the road. Stabs every ground foe that walks over it. Flyers pass above.",
      specs = {
          { key = "tar", name = "Tar Pit", icon = I .. "Spell_Nature_StrangleVines", desc = "Foes on it are slowed by half.",
            set = { slow = 0.5, slowTime = 1 } },
          { key = "mine", name = "Goblin Mine", icon = I .. "INV_Misc_Bomb_02", desc = "Every three seconds it blows up for six times the damage, ignoring armour, over a wider area.",
            set = { mine = true, pierce = true, rate = 1 / 3, range = 1.3 }, mul = { damage = 6 } },
      } },
    { key = "holy", name = "Holy Beacon", short = "Holy", icon = I .. "Spell_Holy_HolyBolt", color = { 1, 0.9, 0.5 }, unlock = "goldshire",
      attack = "smite", school = "magic", cost = 80, range = 2.5, damage = 6, rate = 0.8, air = true, pierce = true, reveal = true,
      aura = { 0.15, 0.2, 0.25, 0.25 },
      blurb = "Reveals stealthed foes in range. Towers touching it deal 15% more damage.",
      specs = {
          { key = "crusader", name = "Crusader Aura", icon = I .. "Spell_Holy_HolySmite", desc = "Towers touching it deal 50% more damage.",
            set = { auraFlat = 0.5 } },
          { key = "consecration", name = "Consecration", icon = I .. "Spell_Holy_InnerFire", desc = "Holy ground: hurts every foe in range each second, ignoring armour.",
            set = { attack = "pulse", rate = 1 } },
      } },
    { key = "mint", name = "Goblin Mint", short = "Mint", icon = I .. "INV_Misc_Coin_02", color = { 1, 0.8, 0.2 }, unlock = "westfall",
      attack = "none", cost = 100, range = 2.5, damage = 0, rate = 0, income = { 10, 18, 28, 40 },
      blurb = "Doesn't attack. Pays gold at the start of every wave.",
      specs = {
          { key = "bank", name = "Bank", icon = I .. "INV_Misc_Bag_10", desc = "Also pays 5% interest on your gold each wave (up to 40).",
            set = { interest = 0.05 } },
          { key = "bounty", name = "Bounty Office", icon = I .. "INV_Misc_Coin_04", desc = "Foes slain in range drop 50% more gold.",
            set = { bounty = 1.5 } },
      } },
    { key = "storm", name = "Storm Totem", short = "Storm", icon = I .. "Spell_Nature_Lightning", color = { 0.65, 0.7, 1 }, unlock = "duskwood",
      attack = "chain", school = "magic", cost = 120, range = 2.75, damage = 12, rate = 0.7, air = true, chain = 3,
      blurb = "Lightning leaps between up to three foes. Great against swarms.",
      specs = {
          { key = "thunderstorm", name = "Thunderstorm", icon = I .. "Spell_Nature_ChainLightning", desc = "Lightning leaps to six foes.",
            set = { chain = 6 } },
          { key = "overload", name = "Overload", icon = I .. "Spell_Lightning_LightningBolt01", desc = "Bolts hit harder and often stun.",
            mul = { damage = 1.3 }, set = { stun = 0.25 } },
      } },
    { key = "venom", name = "Serpent Ward", short = "Venom", icon = I .. "Spell_Nature_CorrosiveBreath", color = { 0.45, 0.85, 0.3 }, unlock = "wetlands",
      attack = "venom", cost = 85, range = 2.75, damage = 3, rate = 1.0, air = true, poison = 2.4, stacks = 5,
      blurb = "Spits venom. Each hit adds a stack of poison (up to five) that ignores armour.",
      specs = {
          { key = "plague", name = "Plague", icon = I .. "Spell_Shadow_PlagueCloud", desc = "A poisoned foe that dies passes its poison to those around it.",
            set = { plague = true } },
          { key = "viper", name = "Viper Sting", icon = I .. "Ability_Hunter_AimedShot", desc = "Poison stacks up to ten, and every hit slows a little.",
            set = { stacks = 10, slow = 0.2, slowTime = 1 } },
      } },
    { key = "arcane", name = "Arcane Obelisk", short = "Arcane", icon = I .. "Spell_Nature_StarFall", color = { 0.8, 0.5, 1 }, unlock = "needles",
      attack = "beam", school = "magic", cost = 130, range = 3, damage = 2, rate = 5, air = true, pierce = true, gain = 0.5, cap = 3,
      blurb = "A beam that grows stronger the longer it holds one foe, up to four times. Ignores armour.",
      specs = {
          { key = "focus", name = "Focus", icon = I .. "Spell_Arcane_StarFire", desc = "Builds up faster and reaches five and a half times the damage.",
            mul = { gain = 1.5 }, set = { cap = 4.5 } },
          { key = "prism", name = "Prism", icon = I .. "Spell_Arcane_Blink", desc = "The beam splits to hit a second foe.",
            set = { targets = 2 } },
      } },

    -- Chapter two onwards.
    { key = "cannon", name = "Dwarven Cannon", short = "Cannon", icon = I .. "INV_Misc_Bomb_04", color = { 0.55, 0.5, 0.45 }, unlock = "morogh3",
      attack = "blast", cost = 110, range = 2.75, damage = 30, rate = 0.45, splash = 1.0,
      blurb = "Heavy shells that burst over a wide area. Ground only.",
      specs = {
          { key = "siege", name = "Siege Cannon", icon = I .. "INV_Misc_Bomb_05", desc = "Bigger shells that knock a point of armour off everything they hit.",
            mul = { damage = 1.5 }, set = { shred = 1 } },
          { key = "mortar", name = "Mortar", icon = I .. "INV_Misc_Bomb_08", desc = "Lobs shells much further, with wider blasts.",
            add = { range = 2.5 }, set = { splash = 1.4 }, mul = { rate = 0.8 } },
      } },
    { key = "ballista", name = "Ballista", short = "Ballista", icon = I .. "INV_Weapon_Crossbow_04", color = { 0.7, 0.55, 0.35 }, unlock = "morogh6",
      attack = "line", cost = 95, range = 3.5, damage = 22, rate = 0.55, air = true,
      blurb = "Giant bolts that skewer every foe in a line.",
      specs = {
          { key = "boltthrower", name = "Bolt Thrower", icon = I .. "INV_Ammo_Arrow_02", desc = "Heavier bolts that ignore armour.",
            mul = { damage = 1.6 }, set = { pierce = true } },
          { key = "harpoon", name = "Harpoon", icon = I .. "Ability_Rogue_Trip", desc = "Bolts drag foes back and slow them.",
            set = { knock = 0.35, slow = 0.4, slowTime = 1.5 } },
      } },
    { key = "drums", name = "War Drums", short = "Drums", icon = I .. "Ability_Warrior_WarCry", color = { 0.85, 0.3, 0.25 }, unlock = "redridge3",
      attack = "none", cost = 90, range = 1.5, damage = 0, rate = 0, hasteAura = { 0.1, 0.14, 0.18, 0.18 },
      blurb = "Doesn't attack. Towers touching it attack 10% faster.",
      specs = {
          { key = "bloodlust", name = "Bloodlust Drums", icon = I .. "Spell_Nature_BloodLust", desc = "Towers touching it attack 35% faster.",
            set = { hasteFlat = 0.35 } },
          { key = "battle", name = "Drums of Battle", icon = I .. "Ability_Warrior_BattleShout", desc = "Towers touching it attack 20% faster and reach half a square further.",
            set = { hasteFlat = 0.2, rangeAura = 0.5 } },
      } },
    { key = "shadow", name = "Shadow Spire", short = "Shadow", icon = I .. "Spell_Shadow_ShadowWordPain", color = { 0.5, 0.3, 0.65 }, unlock = "redridge6",
      attack = "curse", school = "magic", cost = 100, range = 2.75, damage = 8, rate = 0.9, air = true, weaken = 0.2,
      blurb = "Curses a foe: it takes 20% more damage from everything for four seconds.",
      specs = {
          { key = "swpain", name = "Shadow Word: Pain", icon = I .. "Spell_Shadow_ShadowWordPain", desc = "A deeper curse (30%) that also burns away health, ignoring armour.",
            set = { weaken = 0.3, burn = 0.9 } },
          { key = "mindflay", name = "Mind Flay", icon = I .. "Spell_Shadow_SiphonMana", desc = "Curses faster and slows the cursed.",
            mul = { rate = 1.5 }, set = { slow = 0.35, slowTime = 1.5 } },
      } },
    { key = "earthbind", name = "Earthbind Totem", short = "Earthbind", icon = I .. "Spell_Nature_StrengthOfEarthTotem02", color = { 0.6, 0.45, 0.25 }, unlock = "ashen3",
      attack = "pulse", ground = true, quiet = true, cost = 60, range = 1.75, damage = 0, rate = 2, slow = 0.25, slowTime = 0.6, slowGrow = true,
      blurb = "Doesn't hurt. Every ground foe near it is slowed by a quarter.",
      specs = {
          { key = "earthgrab", name = "Earthgrab", icon = I .. "Spell_Nature_EarthBind", desc = "Slows by half.",
            set = { slow = 0.5 } },
          { key = "grounding", name = "Grounding", icon = I .. "Spell_Nature_GroundingTotem", desc = "Slows flyers too, and reveals stealthed foes.",
            set = { ground = false, reveal = true, air = true } },
      } },
    { key = "mage", name = "Mage Tower", short = "Mage", icon = I .. "Spell_Nature_Polymorph", color = { 0.4, 0.75, 1 }, unlock = "ashen6",
      attack = "missile", school = "magic", cost = 115, range = 3, damage = 7, rate = 0.8, air = true, missiles = 3, sheep = 0.1, sheepTime = 2,
      blurb = "Three arcane missiles a cast. Sometimes turns a foe into a sheep.",
      specs = {
          { key = "polymorph", name = "Polymorph Master", icon = I .. "Spell_Nature_Polymorph", desc = "Turns foes into sheep far more often, for longer.",
            set = { sheep = 0.3, sheepTime = 3 } },
          { key = "barrage", name = "Arcane Barrage", icon = I .. "Spell_Nature_StarFall", desc = "Five missiles a cast.",
            set = { missiles = 5 }, mul = { damage = 1.15 } },
      } },
    { key = "harbor", name = "Harbor Battery", short = "Harbor", icon = I .. "INV_Misc_Bomb_06", color = { 0.3, 0.5, 0.7 }, unlock = "thorn3",
      attack = "blast", on = "~", cost = 100, range = 3.5, damage = 26, rate = 0.5, splash = 0.8,
      blurb = "Built on water (or lava). Long-range cannon fire. Ground only.",
      specs = {
          { key = "broadside", name = "Broadside", icon = I .. "INV_Misc_Bomb_06", desc = "Fires at two foes at once.",
            set = { targets = 2 } },
          { key = "chainshot", name = "Chain Shot", icon = I .. "Ability_Rogue_Trip", desc = "Harder hits that slow.",
            mul = { damage = 1.2 }, set = { slow = 0.4, slowTime = 1.5 } },
      } },
    { key = "roots", name = "Entangling Briars", short = "Briars", icon = I .. "Spell_Nature_StrangleVines", color = { 0.3, 0.6, 0.25 }, unlock = "thorn6",
      attack = "pulse", on = "#", ground = true, cost = 60, range = 0.7, damage = 4, rate = 0.4, root = 1.0,
      blurb = "Built on the road. Every few seconds it roots every ground foe on it in place.",
      specs = {
          { key = "thornweave", name = "Thornweave", icon = I .. "Spell_Nature_Thorns", desc = "The roots are thorny: five times the damage, ignoring armour.",
            mul = { damage = 5 }, set = { pierce = true } },
          { key = "wildgrowth", name = "Wild Growth", icon = I .. "Spell_Nature_ProtectionformNature", desc = "Roots everything within a square and a half.",
            set = { range = 1.4 } },
      } },
    { key = "camp", name = "Mining Camp", short = "Mine", icon = I .. "INV_Pick_02", color = { 0.6, 0.55, 0.5 }, unlock = "bad3",
      attack = "none", on = "R", cost = 90, range = 1, damage = 0, rate = 0, income = { 12, 20, 30, 42 },
      blurb = "Built on rocks. Doesn't attack. Digs up gold every wave.",
      specs = {
          { key = "thorium", name = "Thorium Vein", icon = I .. "INV_Ore_Thorium_01", desc = "Digs up 60% more gold.",
            set = { incomeMul = 1.6 } },
          { key = "gemcutter", name = "Gem Cutter", icon = I .. "INV_Misc_Gem_Ruby_01", desc = "Also earns a mark for every wave held.",
            set = { markIncome = 1 } },
      } },
    { key = "rifle", name = "Rifleman's Nest", short = "Rifle", icon = I .. "INV_Weapon_Rifle_01", color = { 0.75, 0.6, 0.4 }, unlock = "bad6",
      attack = "arrow", cost = 120, range = 5, damage = 45, rate = 0.35, air = true, crit = 0.1, mode = "strong",
      blurb = "A dwarf with a very long rifle. Huge range, slow, heavy shots.",
      specs = {
          { key = "headshot", name = "Headshot", icon = I .. "Ability_Hunter_SniperShot", desc = "A third of its shots crit for triple damage.",
            set = { crit = 0.35 } },
          { key = "biggame", name = "Big Game Hunter", icon = I .. "Ability_Hunter_BeastTaming", desc = "Double damage to bosses.",
            set = { bossBonus = 1 } },
      } },
    { key = "rocket", name = "Rocket Battery", short = "Rocket", icon = I .. "INV_Gizmo_RocketBoot_01", color = { 0.9, 0.4, 0.3 }, unlock = "tanaris3",
      attack = "arrow", cost = 105, range = 3.5, damage = 18, rate = 0.9, air = true, airOnly = true, targets = 2,
      blurb = "Shoots only flyers, two at a time, very hard.",
      specs = {
          { key = "flak", name = "Flak Cannons", icon = I .. "INV_Misc_Bomb_07", desc = "Rockets burst, hurting every flyer near the target.",
            set = { airSplash = 1.0 } },
          { key = "homing", name = "Homing Rockets", icon = I .. "INV_Gizmo_01", desc = "Longer range, and a third of rockets crit.",
            add = { range = 1.5 }, set = { crit = 0.3 } },
      } },
    { key = "quake", name = "Earthshaker Totem", short = "Quake", icon = I .. "Spell_Nature_Earthquake", color = { 0.65, 0.5, 0.3 }, unlock = "tanaris6",
      attack = "pulse", ground = true, pierce = true, cost = 110, range = 1.5, damage = 10, rate = 0.33, knock = 0.6,
      blurb = "Shakes the ground every three seconds, throwing ground foes back down the road.",
      specs = {
          { key = "earthquake", name = "Earthquake", icon = I .. "Spell_Nature_Earthquake", desc = "Hits much harder and roots foes for half a second.",
            mul = { damage = 2.5 }, set = { root = 0.5 } },
          { key = "tremor", name = "Tremor", icon = I .. "Spell_Nature_TremorTotem", desc = "Throws foes twice as far, from further away.",
            set = { knock = 1.2, range = 2 } },
      } },
    { key = "chapel", name = "Chapel of Light", short = "Chapel", icon = I .. "Spell_Holy_PrayerOfHealing02", color = { 1, 0.95, 0.75 }, unlock = "plague3",
      attack = "none", cost = 120, range = 1.5, damage = 0, rate = 0, mend = { 0.25, 0.34, 0.5, 0.5 },
      blurb = "Doesn't attack. Mends the keep: a life back every four waves.",
      specs = {
          { key = "cathedral", name = "Cathedral", icon = I .. "Spell_Holy_Resurrection", desc = "A life back every wave.",
            set = { mendFlat = 1 } },
          { key = "lightshope", name = "Light's Hope", icon = I .. "Spell_Holy_SealOfWisdom", desc = "A life every other wave, and towers touching it deal 20% more damage.",
            set = { mendFlat = 0.5, auraFlat = 0.2 } },
      } },
    { key = "tesla", name = "Tesla Coil", short = "Tesla", icon = I .. "INV_Gizmo_02", color = { 0.5, 0.85, 1 }, unlock = "rock3",
      attack = "pulse", school = "magic", cost = 135, range = 2, damage = 38, rate = 0.4, air = true,
      blurb = "Discharges into every foe around it, flyers too.",
      specs = {
          { key = "overcharger", name = "Overcharger", icon = I .. "Spell_Nature_LightningOverload", desc = "Bigger, slower discharges.",
            mul = { damage = 1.8, rate = 0.75 } },
          { key = "arcfield", name = "Arc Field", icon = I .. "Spell_Nature_LightningShield", desc = "Twice as often, a little weaker, and slows.",
            mul = { damage = 0.6, rate = 2 }, set = { slow = 0.3, slowTime = 1 } },
      } },
    { key = "gryphon", name = "Wildhammer Roost", short = "Gryphon", icon = I .. "INV_Hammer_04", color = { 0.95, 0.75, 0.35 }, unlock = "silithus3",
      attack = "arrow", cost = 150, range = 3.5, damage = 30, rate = 0.7, air = true, airBonus = 1,
      blurb = "Gryphon riders hurl stormhammers. Double damage to flyers. Fitting, up here.",
      specs = {
          { key = "stormhammer", name = "Stormhammer", icon = I .. "Spell_Nature_ChainLightning", desc = "Hammers leap between three foes.",
            set = { attack = "chain", chain = 3 } },
          { key = "skymarshal", name = "Sky Marshal", icon = I .. "Ability_Hunter_EagleEye", desc = "Longer reach and harder hits.",
            add = { range = 2 }, mul = { damage = 1.4 } },
      } },
}
ns.TOWER = {}
for i, t in ipairs(ns.TOWERS) do
    t.index = i
    ns.TOWER[t.key] = t
    for _, sp in ipairs(t.specs) do sp.tower = t.key end
end

ns.AFFIXES = {
    hasted = { name = "Hasted", desc = "Foes move 30% faster.", from = 1 },
    armored = { name = "Armoured", desc = "Foes have 3 more armour.", from = 1 },
    regen = { name = "Regenerating", desc = "Foes heal 2% of their health each second.", from = 1 },
    swarm = { name = "Swarming", desc = "Half again as many foes, but frailer.", from = 1 },
    shielded = { name = "Shielded", desc = "Foes carry a shield worth a quarter of their health.", from = 2 },
    cloaked = { name = "Cloaked", desc = "One foe in three is stealthed.", from = 2 },
    giants = { name = "Giants", desc = "Half as many foes, each twice as big and tough.", from = 3 },
    frenzied = { name = "Frenzied", desc = "Foes speed up when one of their friends dies nearby.", from = 3 },
    bolstering = { name = "Bolstering", desc = "A dying foe makes those around it tougher.", from = 4 },
    sabotage = { name = "Sabotage", desc = "Every ten seconds a tower is silenced for three.", from = 4 },
    undying = { name = "Undying", desc = "One foe in four gets back up once.", from = 5 },
    warded = { name = "Warded", desc = "Foes shrug off 40% of magic damage.", from = 5 },
    ironclad = { name = "Ironclad", desc = "Foes shrug off 30% of physical damage.", from = 6 },
    elite = { name = "Elite", desc = "One foe in five is an elite: three times the health and gold.", from = 6 },
    grievous = { name = "Grievous", desc = "Each foe that gets through costs a life more.", from = 7 },
    bountiful = { name = "Bountiful", desc = "Foes are 20% tougher but drop double gold.", from = 1 },
}
ns.AFFIX_ORDER = { "hasted", "armored", "regen", "swarm", "bountiful", "shielded", "cloaked", "giants", "frenzied",
    "bolstering", "sabotage", "undying", "warded", "ironclad", "elite", "grievous" }

-- Offered after every fourth wave. `max` is how many times one can be taken; `tower`
-- blessings only turn up once that tower is unlocked and in the loadout. Simple ones are
-- worked out from their fields: dmg, rate and range (per tower, `school` or everyone),
-- and air (more damage to flyers). The rest are handled by key in Game.lua.
ns.BLESSINGS = {
    { key = "haste", name = "Battle Shout", icon = I .. "Ability_Warrior_BattleShout", max = 3, desc = "All towers attack 15% faster." },
    { key = "eagle", name = "Eagle Eye", icon = I .. "Ability_Hunter_EagleEye", max = 2, desc = "All towers reach half a square further." },
    { key = "mark", name = "Hunter's Mark", icon = I .. "Ability_Hunter_SniperShot", max = 1, desc = "Every tower can see stealthed foes." },
    { key = "banking", name = "Goblin Banking", icon = I .. "INV_Misc_Coin_01", max = 1, desc = "Earn 6% interest on your gold at the start of each wave (up to 60)." },
    { key = "shield", name = "Divine Shield", icon = I .. "Spell_Holy_DivineIntervention", max = 3, desc = "Gain 8 lives." },
    { key = "bounty", name = "Bounty Board", icon = I .. "INV_Misc_Note_01", max = 3, desc = "Foes drop 25% more gold." },
    { key = "permafrost", name = "Permafrost", icon = I .. "Spell_Frost_FrostShock", max = 1, tower = "frost", desc = "Frost slows last 50% longer and bite 10% harder." },
    { key = "wildfire", name = "Wildfire", icon = I .. "Spell_Fire_Fire", max = 1, tower = "fire", desc = "Fire Tower blasts are 40% wider." },
    { key = "static", name = "Static Charge", icon = I .. "Spell_Nature_LightningShield", max = 2, tower = "storm", desc = "Lightning leaps to two more foes." },
    { key = "discount", name = "Guild Discount", icon = I .. "INV_Misc_Coin_03", max = 2, desc = "Towers and upgrades cost 15% less." },
    { key = "execute", name = "Execute", icon = I .. "INV_Sword_48", max = 1, desc = "Hits on foes below a quarter of their health deal double damage." },
    { key = "lucky", name = "Lucky Strikes", icon = I .. "Ability_CriticalStrike", max = 2, desc = "Every hit has a 10% chance to deal triple damage." },
    { key = "merchant", name = "Honest Merchant", icon = I .. "INV_Misc_Bag_11", max = 1, desc = "Selling a tower refunds everything you spent on it." },
    { key = "sunder", name = "Sunder Armor", icon = I .. "Ability_Warrior_Sunder", max = 2, desc = "Foes have 3 less armour." },
    { key = "thorium", name = "Thorium Arrows", icon = I .. "INV_Ammo_Arrow_02", max = 1, tower = "archer", dmg = 0.4, desc = "Archer Towers deal 40% more damage." },
    { key = "shatter", name = "Shatter", icon = I .. "Spell_Frost_Glacier", max = 1, tower = "frost", desc = "Chilled foes take 20% more damage from everything." },
    { key = "combustion", name = "Combustion", icon = I .. "Spell_Fire_SealOfFire", max = 1, tower = "fire", desc = "Foes slain by a Fire Tower explode, hurting those nearby for 15% of their health." },
    { key = "overcharge", name = "Overcharge", icon = I .. "Spell_Nature_LightningOverload", max = 1, tower = "storm", desc = "Lightning keeps its full power as it leaps." },
    { key = "radiance", name = "Radiance", icon = I .. "Spell_Holy_SearingLight", max = 1, tower = "holy", desc = "Holy Beacons lift towers up to two squares away." },
    { key = "virulence", name = "Virulence", icon = I .. "Spell_Nature_NullifyPoison", max = 1, tower = "venom", desc = "Each venom hit adds two stacks of poison." },
    { key = "leylines", name = "Ley Lines", icon = I .. "Spell_Arcane_ArcanePotency", max = 1, tower = "arcane", desc = "Arcane beams build up twice as fast." },
    { key = "barbed", name = "Barbed Wire", icon = I .. "Spell_Shadow_PainSpike", max = 1, tower = "trap", desc = "Spike Traps slow the foes they stab by 40%." },
    { key = "laststand", name = "Last Stand", icon = I .. "Spell_Holy_AshesToAshes", max = 1, desc = "The first time the keep would fall, it holds on with 5 lives." },
    { key = "cartographer", name = "Cartographer", icon = I .. "INV_Misc_Map_01", max = 1, desc = "Blessing offers show four cards instead of three." },
    { key = "treasure", name = "Treasure Hunter", icon = I .. "INV_Misc_Bag_08", max = 2, desc = "Earn 1 more mark for every wave you hold this run." },
    { key = "giant", name = "Giant Slayer", icon = I .. "Ability_Warrior_Decisivestrike", max = 2, desc = "Towers deal 30% more damage to bosses." },
    { key = "apprentice", name = "Apprentices", icon = I .. "INV_Misc_Book_08", max = 1, desc = "Upgrades to level 2 and 3 cost 30% less." },
    { key = "scavenger", name = "Scavengers", icon = I .. "INV_Misc_Bone_01", max = 2, desc = "Every foe drops 1 more gold." },
    { key = "ramparts", name = "Ramparts", icon = I .. "INV_Shield_05", max = 1, desc = "Bosses that reach the keep cost half as many lives." },
    { key = "bloodlust", name = "Bloodlust", icon = I .. "Spell_Nature_BloodLust", max = 1, desc = "Towers attack 30% faster during boss waves." },

    -- Everyone.
    { key = "goldrush", name = "Gold Rush", icon = I .. "INV_Misc_Coin_06", max = 3, desc = "Gain 150 gold right now." },
    { key = "fortify", name = "Fortify", icon = I .. "INV_Shield_09", max = 2, desc = "Gain 4 lives, and 1 more for every boss slain this run." },
    { key = "arcaneint", name = "Arcane Intellect", icon = I .. "Spell_Holy_MagicalSentry", max = 2, school = "magic", dmg = 0.2, desc = "Magic towers deal 20% more damage." },
    { key = "weaponmastery", name = "Weapon Mastery", icon = I .. "Ability_Warrior_WeaponMastery", max = 2, school = "phys", dmg = 0.2, desc = "Physical towers deal 20% more damage." },
    { key = "antiair", name = "Flak Doctrine", icon = I .. "INV_Ammo_Bullet_02", max = 2, air = 0.4, desc = "Towers deal 40% more damage to flyers." },
    { key = "cleanse", name = "Cleanse", icon = I .. "Spell_Holy_Renew", max = 1, desc = "Foes heal and regenerate half as much." },
    { key = "disruption", name = "Disruption", icon = I .. "Spell_Shadow_ManaBurn", max = 1, desc = "Shields only absorb half as much." },
    { key = "spellbreaker", name = "Spellbreaker", icon = I .. "Spell_Holy_DispelMagic", max = 1, desc = "Towers can't be silenced." },
    { key = "momentum", name = "Momentum", icon = I .. "Ability_Rogue_Sprint", max = 1, desc = "Every wave held without a leak adds 3% damage, up to 30%. A leak resets it." },
    { key = "hoard", name = "Dragon's Hoard", icon = I .. "INV_Misc_Coin_09", max = 1, desc = "Towers deal 1% more damage for every 50 gold you hold, up to 30%." },
    { key = "rally", name = "Rally", icon = I .. "INV_Banner_02", max = 1, desc = "Towers touching three or more towers deal 15% more damage." },
    { key = "lonewolf", name = "Lone Wolf", icon = I .. "Ability_Hunter_Pet_Wolf", max = 1, desc = "Towers touching no other tower deal 35% more damage." },
    { key = "secondwind", name = "Second Wind", icon = I .. "Spell_Nature_Rejuvenation", max = 1, desc = "The first time you fall below 5 lives, gain 10." },
    { key = "overtime", name = "Overtime", icon = I .. "INV_Misc_PocketWatch_01", max = 1, desc = "Calling waves early pays double." },
    { key = "engineers", name = "Field Engineers", icon = I .. "INV_Misc_Wrench_01", max = 1, desc = "Level 4 specialisations cost 30% less." },
    { key = "siegebreaker", name = "Siegebreaker", icon = I .. "Ability_Warrior_ShieldBash", max = 1, desc = "Hits tear through shields for double damage." },
    { key = "tremorsense", name = "Tremorsense", icon = I .. "Spell_Nature_TremorTotem", max = 1, desc = "Burrowed foes can be hit." },
    { key = "slowtime", name = "Slow Time", icon = I .. "Spell_Nature_Sleep", max = 2, desc = "All foes move 8% slower." },
    { key = "killbounty", name = "Headhunter", icon = I .. "INV_Misc_Bone_OrcSkull_01", max = 1, desc = "Every 25 foes slain pay 30 gold." },
    { key = "biggame", name = "Big Game", icon = I .. "Ability_Hunter_BeastTaming", max = 1, desc = "Bosses drop triple gold." },
    { key = "harmony", name = "Elemental Harmony", icon = I .. "Spell_Nature_ResistNature", max = 1, desc = "Towers deal 4% more damage for each different kind of tower built (up to six)." },
    { key = "craftsmen", name = "Craftsmen", icon = I .. "INV_Hammer_01", max = 2, desc = "Upgrades cost 12% less." },
    { key = "deeppockets", name = "Deep Pockets", icon = I .. "INV_Misc_Bag_07", max = 1, desc = "Interest from every source can pay 50 more." },
    { key = "hawkeye", name = "Hawk Eye", icon = I .. "Ability_Hunter_Pathfinding", max = 2, range = 0.25, desc = "All towers reach a quarter of a square further and deal 5% more damage.", dmg = 0.05 },
    { key = "fervor", name = "Fervor", icon = I .. "Spell_Holy_SealOfFury", max = 3, dmg = 0.08, desc = "All towers deal 8% more damage." },
    { key = "quickdraw", name = "Quick Draw", icon = I .. "Ability_Hunter_Quickshot", max = 3, rate = 0.08, desc = "All towers attack 8% faster." },
    { key = "groundpound", name = "Ground Pound", icon = I .. "Ability_Smash", max = 2, desc = "Towers deal 20% more damage to ground foes." },
    { key = "lifesteal", name = "Vampiric Touch", icon = I .. "Spell_Shadow_UnsummonBuilding", max = 1, desc = "Every 100 foes slain mend a life." },
    { key = "piety", name = "Piety", icon = I .. "Spell_Holy_PowerWordShield", max = 1, desc = "Bosses cost 3 fewer lives if they get through." },

    -- One tower each.
    { key = "longbow", name = "Yew Longbows", icon = I .. "INV_Weapon_Bow_01", max = 1, tower = "archer", range = 0.75, desc = "Archer Towers reach three quarters of a square further." },
    { key = "rapidfire", name = "Rapid Fire", icon = I .. "Ability_Hunter_RunningShot", max = 1, tower = "archer", rate = 0.35, desc = "Archer Towers shoot 35% faster." },
    { key = "icyveins", name = "Icy Veins", icon = I .. "Spell_Frost_ColdHearted", max = 1, tower = "frost", rate = 0.4, desc = "Frost Spires cast 40% faster." },
    { key = "frostbite", name = "Frostbite", icon = I .. "Spell_Frost_FrostArmor", max = 1, tower = "frost", dmg = 1.0, desc = "Frost Spires deal double damage." },
    { key = "pyroblast", name = "Pyroblast", icon = I .. "Spell_Fire_Fireball02", max = 1, tower = "fire", dmg = 0.4, desc = "Fire Towers deal 40% more damage." },
    { key = "firestorm", name = "Firestorm", icon = I .. "Spell_Fire_SelfDestruct", max = 1, tower = "fire", rate = 0.3, desc = "Fire Towers cast 30% faster." },
    { key = "sharpspikes", name = "Serrated Spikes", icon = I .. "INV_Misc_MonsterClaw_04", max = 1, tower = "trap", dmg = 0.6, desc = "Spike Traps deal 60% more damage." },
    { key = "caltrops", name = "Caltrops", icon = I .. "Ability_Rogue_Trip", max = 1, tower = "trap", rate = 0.4, desc = "Spike Traps stab 40% faster." },
    { key = "blessedlight", name = "Blessed Light", icon = I .. "Spell_Holy_HolyNova", max = 1, tower = "holy", dmg = 0.6, desc = "Holy Beacons deal 60% more damage." },
    { key = "sanctity", name = "Sanctity Aura", icon = I .. "Spell_Holy_MindVision", max = 1, tower = "holy", desc = "Holy Beacon auras are 10% stronger." },
    { key = "minted", name = "Freshly Minted", icon = I .. "INV_Misc_Coin_17", max = 2, tower = "mint", desc = "Goblin Mints pay 30% more." },
    { key = "goblinbank", name = "Venture Co. Shares", icon = I .. "INV_Misc_Coin_16", max = 1, tower = "mint", desc = "Each Goblin Mint pays 2% interest on your gold too (up to 20 each)." },
    { key = "thunder", name = "Thunderhead", icon = I .. "Spell_Nature_StormReach", max = 1, tower = "storm", dmg = 0.4, desc = "Storm Totems deal 40% more damage." },
    { key = "galeforce", name = "Galeforce", icon = I .. "Spell_Nature_Cyclone", max = 1, tower = "storm", rate = 0.3, desc = "Storm Totems strike 30% faster." },
    { key = "toxins", name = "Concentrated Toxins", icon = I .. "Ability_Poisons", max = 1, tower = "venom", dmg = 0.5, desc = "Serpent Ward poison is 50% stronger." },
    { key = "spitfire", name = "Spitfire", icon = I .. "Ability_Creature_Poison_05", max = 1, tower = "venom", rate = 0.4, desc = "Serpent Wards spit 40% faster." },
    { key = "arcanepower", name = "Arcane Power", icon = I .. "Spell_Nature_Lightning", max = 1, tower = "arcane", dmg = 0.4, desc = "Arcane beams deal 40% more damage." },
    { key = "presence", name = "Presence of Mind", icon = I .. "Spell_Nature_EnchantArmor", max = 1, tower = "arcane", range = 0.75, desc = "Arcane Obelisks reach three quarters of a square further." },
    { key = "blackpowder", name = "Black Powder", icon = I .. "INV_Misc_Ammo_Gunpowder_01", max = 1, tower = "cannon", dmg = 0.4, desc = "Dwarven Cannons deal 40% more damage." },
    { key = "shrapnel", name = "Shrapnel", icon = I .. "INV_Misc_Bomb_03", max = 1, tower = "cannon", desc = "Cannon blasts are 40% wider." },
    { key = "torsion", name = "Torsion Springs", icon = I .. "INV_Gizmo_03", max = 1, tower = "ballista", rate = 0.35, desc = "Ballistas fire 35% faster." },
    { key = "ironbolts", name = "Iron Bolts", icon = I .. "INV_Ammo_Arrow_01", max = 1, tower = "ballista", dmg = 0.5, desc = "Ballista bolts deal 50% more damage." },
    { key = "warbeat", name = "War Beat", icon = I .. "Spell_Nature_AncestralGuardian", max = 1, tower = "drums", desc = "War Drums lift towers up to two squares away." },
    { key = "thunderdrums", name = "Thunder Drums", icon = I .. "Spell_Nature_ThunderClap", max = 1, tower = "drums", desc = "War Drums speed towers 10% more." },
    { key = "misery", name = "Misery", icon = I .. "Spell_Shadow_Misery", max = 1, tower = "shadow", desc = "Shadow curses are 15% deeper." },
    { key = "darkness", name = "Darkness", icon = I .. "Spell_Shadow_Twilight", max = 1, tower = "shadow", dmg = 0.6, desc = "Shadow Spires deal 60% more damage." },
    { key = "earthenpower", name = "Earthen Power", icon = I .. "Spell_Nature_EarthBindTotem", max = 1, tower = "earthbind", desc = "Earthbind slows are 15% stronger." },
    { key = "stoneclaw", name = "Stoneclaw", icon = I .. "Spell_Nature_StoneClawTotem", max = 1, tower = "earthbind", desc = "Earthbind Totems also hurt what they slow (12 a second)." },
    { key = "sheepish", name = "Improved Polymorph", icon = I .. "Spell_Magic_PolymorphChicken", max = 1, tower = "mage", desc = "Polymorph happens twice as often." },
    { key = "missilestorm", name = "Missile Storm", icon = I .. "Spell_Nature_StarFall", max = 1, tower = "mage", desc = "Mage Towers fire two more missiles." },
    { key = "grapeshot", name = "Grapeshot", icon = I .. "INV_Ammo_Bullet_03", max = 1, tower = "harbor", desc = "Harbor blasts are 40% wider." },
    { key = "admiralty", name = "Admiralty", icon = I .. "INV_Misc_Spyglass_02", max = 1, tower = "harbor", dmg = 0.4, range = 0.5, desc = "Harbor Batteries deal 40% more damage and reach half a square further." },
    { key = "naturesgrasp", name = "Nature's Grasp", icon = I .. "Spell_Nature_NaturesWrath", max = 1, tower = "roots", desc = "Briar roots last 60% longer." },
    { key = "overgrowth", name = "Overgrowth", icon = I .. "Spell_Nature_Regenerate", max = 1, tower = "roots", rate = 0.5, desc = "Briars root 50% more often." },
    { key = "motherlode", name = "Motherlode", icon = I .. "INV_Ore_Mithril_02", max = 2, tower = "camp", desc = "Mining Camps dig up 30% more gold." },
    { key = "dynamite", name = "Seaforium Charges", icon = I .. "INV_Misc_Bomb_01", max = 1, tower = "camp", desc = "Mining Camps blast the foes near them for 40 a second." },
    { key = "steadyaim", name = "Steady Aim", icon = I .. "Ability_Hunter_AimedShot", max = 1, tower = "rifle", dmg = 0.5, desc = "Riflemen deal 50% more damage." },
    { key = "scopes", name = "Telescopic Sights", icon = I .. "INV_Misc_Spyglass_03", max = 1, tower = "rifle", range = 1.5, desc = "Riflemen reach a square and a half further." },
    { key = "fuel", name = "Goblin Rocket Fuel", icon = I .. "INV_Potion_99", max = 1, tower = "rocket", rate = 0.5, desc = "Rocket Batteries fire 50% faster." },
    { key = "payload", name = "Big Payload", icon = I .. "INV_Misc_Bomb_09", max = 1, tower = "rocket", dmg = 0.5, desc = "Rockets deal 50% more damage." },
    { key = "aftershock", name = "Aftershock", icon = I .. "Spell_Nature_Earthquake", max = 1, tower = "quake", rate = 0.4, desc = "Earthshakers shake 40% more often." },
    { key = "faultline", name = "Fault Line", icon = I .. "Ability_Warrior_Revenge", max = 1, tower = "quake", desc = "Earthshakers throw foes 50% further." },
    { key = "prayer", name = "Prayer of Mending", icon = I .. "Spell_Holy_GreaterHeal", max = 1, tower = "chapel", desc = "Chapels mend 50% more." },
    { key = "sanctuary", name = "Sanctuary", icon = I .. "Spell_Holy_Restoration", max = 1, tower = "chapel", desc = "Each Chapel lifts towers touching it by 10%." },
    { key = "capacitors", name = "Capacitors", icon = I .. "INV_Gizmo_05", max = 1, tower = "tesla", dmg = 0.4, desc = "Tesla Coils deal 40% more damage." },
    { key = "conductors", name = "Copper Conductors", icon = I .. "INV_Misc_Wire_01", max = 1, tower = "tesla", range = 0.5, desc = "Tesla Coils reach half a square further." },
    { key = "aerie", name = "Aerie Peak Veterans", icon = I .. "INV_Hammer_15", max = 1, tower = "gryphon", dmg = 0.4, desc = "Gryphon riders deal 40% more damage." },
    { key = "skyfury", name = "Sky Fury", icon = I .. "Spell_Nature_Windfury", max = 1, tower = "gryphon", rate = 0.35, desc = "Gryphon riders attack 35% faster." },
}
ns.BLESSING = {}
for _, b in ipairs(ns.BLESSINGS) do ns.BLESSING[b.key] = b end

-- Permanent upgrades, bought with marks between runs. Each rank costs `base` times the
-- rank you're buying. `tab` sorts them in the shop; mastery items are made per tower below.
ns.SHOP = {
    { key = "warchest", name = "War Chest", icon = I .. "INV_Misc_Bag_10", max = 10, base = 8, desc = "Start every run with 25 more gold." },
    { key = "walls", name = "Stone Walls", icon = I .. "INV_Shield_06", max = 10, base = 8, desc = "Start every run with 2 more lives." },
    { key = "steel", name = "Sharpened Steel", icon = I .. "INV_Sword_04", max = 10, base = 12, desc = "Towers deal 5% more damage." },
    { key = "drill", name = "Drill Sergeant", icon = I .. "Ability_Warrior_Charge", max = 10, base = 12, desc = "Towers attack 4% faster." },
    { key = "spyglass", name = "Spyglasses", icon = I .. "Ability_TownWatch", max = 3, base = 15, desc = "Towers reach a tenth of a square further." },
    { key = "masons", name = "Master Masons", icon = I .. "INV_Hammer_01", max = 8, base = 10, desc = "Towers and upgrades cost 3% less." },
    { key = "tax", name = "Tax Collector", icon = I .. "INV_Misc_Coin_05", max = 10, base = 10, desc = "5% more gold from foes and from each wave." },
    { key = "salvage", name = "Salvage Crew", icon = I .. "INV_Box_01", max = 3, base = 6, desc = "Selling a tower refunds 6% more." },
    { key = "headstart", name = "Head Start", icon = I .. "Ability_Rogue_Sprint", max = 1, base = 40, desc = "Choose a blessing before the first wave." },
    { key = "fortune", name = "Fortune's Favour", icon = I .. "INV_Misc_Dice_01", max = 3, base = 30, desc = "Reroll each blessing offer once more." },
    { key = "scholar", name = "Guild Scholar", icon = I .. "INV_Misc_Book_09", max = 5, base = 20, desc = "Earn 10% more marks." },
    { key = "siegecraft", name = "Siegecraft", icon = I .. "Ability_Warrior_Decisivestrike", max = 5, base = 15, desc = "Towers deal 6% more damage to bosses." },
    { key = "skyward", name = "Skyward Doctrine", icon = I .. "INV_Ammo_Bullet_02", max = 5, base = 12, desc = "Towers deal 6% more damage to flyers." },
    { key = "medic", name = "Field Medic", icon = I .. "Spell_Holy_Heal", max = 3, base = 25, desc = "Mend a life every 6 waves (5, then 4, with more ranks)." },
    { key = "ledger", name = "Quartermaster's Ledger", icon = I .. "INV_Misc_Note_02", max = 5, base = 8, desc = "Calling a wave early pays 20% more." },
    { key = "corps", name = "Engineering Corps", icon = I .. "INV_Misc_Wrench_01", max = 3, base = 18, desc = "Level 4 specialisations cost 8% less." },
    { key = "library", name = "Royal Library", icon = I .. "INV_Misc_Book_11", max = 1, base = 80, desc = "Blessing offers show one more card." },
    { key = "resolve", name = "Heroic Resolve", icon = I .. "Spell_Holy_SealOfMight", max = 5, base = 20, desc = "Heroic runs start with 2 more lives." },
    { key = "relics", name = "Relic Hunter", icon = I .. "INV_Misc_Gem_Pearl_01", max = 5, base = 15, desc = "Bosses pay 15% more marks." },
}
-- One mastery per tower: more damage for that tower alone.
for _, t in ipairs(ns.TOWERS) do
    ns.SHOP[#ns.SHOP + 1] = { key = "m_" .. t.key, name = t.short .. " Mastery", icon = t.icon, max = 5, base = 10, tower = t.key,
        desc = t.name .. ": 8% more damage a rank." }
end
ns.SHOP_ITEM = {}
for _, it in ipairs(ns.SHOP) do ns.SHOP_ITEM[it.key] = it end

-- A small seeded random number generator (Park-Miller), so a run's waves and blessing
-- offers come out the same after a reload. Called with (a, b) it returns a whole number
-- from a to b; with nothing, a fraction from 0 up to 1.
function ns.Rng(seed)
    local s = (math.floor(seed) % 2147483646) + 1
    return function(a, b)
        s = (s * 16807) % 2147483647
        local f = (s - 1) / 2147483646
        if a then return a + math.floor(f * (b - a + 1)) end
        return f
    end
end

function ns.HpScale(x)
    return (1 + 0.13 * (x - 1)) * 1.035 ^ (x - 1)
end

-- How hard wave n of a level is, on the old endless scale. The first four waves step up
-- gently while you build up; after that it climbs `ramp` a wave.
function ns.Difficulty(level, n)
    return 1 + (n - 1) * level.ramp - (level.ramp - 1) * math.min(n - 1, 4)
end

ns.HEROIC_HP = 1.35

-- Wave n of a level: a list of groups { kind, count, gap, delay }, plus the health scale,
-- an optional affix, the boss and the foe making its debut. Waves past the last one
-- (endless) keep getting harder, with a boss every tenth.
function ns.MakeWave(level, n, seed, heroic)
    local rand = ns.Rng(seed * 7 + n * 104729)
    local x = ns.Difficulty(level, n)
    local open, newest = {}, nil
    for _, f in ipairs(level.foes) do
        if n >= f[2] then open[#open + 1] = f[1] end
        if n == f[2] and ns.INTRO[f[1]] and not newest then newest = f[1] end
    end
    local boss = level.bosses[n]
    local extra = n - level.waves
    if not boss and extra > 0 and extra % 10 == 0 then
        local list = level.endlessBosses or ns.BOSSES
        boss = list[(extra / 10 - 1) % #list + 1]
    end
    -- The level's extra toughness builds up over the first nine waves, so the opening
    -- (on starting gold) plays much the same everywhere.
    local tough = 1 + (level.hp - 1) * math.min(1, (n - 1) / 8)
    if heroic then tough = tough * ns.HEROIC_HP end
    local wave = { n = n, x = x, groups = {}, hp = ns.HpScale(x) * tough, new = newest, boss = boss, final = n == level.waves }
    if not boss and ((x >= 12 and n % 3 == 0) or (heroic and n >= 3 and n % 2 == 1)) then
        local pool = {}
        for _, k in ipairs(ns.AFFIX_ORDER) do
            if ns.AFFIXES[k].from <= (level.chapter or 1) then pool[#pool + 1] = k end
        end
        wave.affix = pool[rand(1, #pool)]
    end

    local budget = 8 + 5 * x + 0.22 * x * x
    if boss then budget = budget * (wave.final and 0.5 or 0.4) end

    local kinds = {}
    if newest then kinds[1] = newest end
    local want = math.min(#open, x < 5 and 1 or (x < 15 and 2 or 3))
    if newest and want < 2 and #open > 1 then want = 2 end
    while #kinds < want do
        local k, dup = open[rand(1, #open)], false
        for _, y in ipairs(kinds) do if y == k then dup = true end end
        if not dup then kinds[#kinds + 1] = k end
    end

    -- A foe making its debut takes about a third of the wave.
    local delay = 0
    for _, k in ipairs(kinds) do
        local def = ns.ENEMIES[k]
        local share = budget / #kinds
        if newest and #kinds > 1 then share = k == newest and budget * 0.35 or budget * 0.65 / (#kinds - 1) end
        local count = math.max(1, math.floor(share / def.cost + 0.5))
        if wave.affix == "swarm" then count = math.floor(count * 1.5 + 0.5) end
        if wave.affix == "giants" then count = math.max(1, math.floor(count * 0.5 + 0.5)) end
        local gap = def.gap * (wave.affix == "giants" and 1.4 or 1)
        wave.groups[#wave.groups + 1] = { kind = k, count = count, gap = gap, delay = delay }
        delay = delay + count * gap * 0.6
    end
    if boss then
        wave.groups[#wave.groups + 1] = { kind = boss, count = 1, gap = 0, delay = delay + 2 }
    end
    return wave
end
