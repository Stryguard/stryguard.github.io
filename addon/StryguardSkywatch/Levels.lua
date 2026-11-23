local _, ns = ...

-- The campaign: ten chapters of six levels. Each level is played on the map of the same
-- key in Maps.lua. `waves` win the level. `ramp` is how fast it gets harder (see
-- ns.Difficulty), and gold comes in `ramp` times as fast to keep up. `hp` scales every
-- foe's health on top of that, since long roads give towers more time to shoot. `gold`
-- is the starting gold. `foes` lists who joins on which wave, `bosses` who leads which
-- wave. `marks` is paid for each wave held, `reward` for a win.

ns.CHAPTERS = {
    { key = "road", name = "The Road to Stryguard", blurb = "Elwynn to the Burning Steppes: where it all began." },
    { key = "frost", name = "The Frozen Pass", blurb = "Dun Morogh, Loch Modan and the ruin of Gnomeregan." },
    { key = "redridge", name = "Redridge Burning", blurb = "The Blackrock orcs march on Lakeshire, and Duskwood stirs." },
    { key = "ashen", name = "Shadows of Ashenvale", blurb = "Satyrs in the forest, naga on the shore." },
    { key = "jungle", name = "The Gurubashi Jungle", blurb = "Tigers, trolls, pirates and a blood god." },
    { key = "badlands", name = "The Badlands", blurb = "Ogres, dragonkin and the titans' vaults." },
    { key = "sands", name = "Sands of Tanaris", blurb = "Sandfury trolls and the hydra of Zul'Farrak." },
    { key = "plague", name = "The Plaguelands", blurb = "The Scourge in its own country." },
    { key = "blackrock", name = "Blackrock Mountain", blurb = "Down through the Dark Iron city to the Firelord." },
    { key = "aq", name = "Gates of Ahn'Qiraj", blurb = "The silithid swarm, an old god, and a lich in the sky." },
}

ns.LEVELS = {
    { key = "goldshire", name = "Goldshire Road", blurb = "A gentle, winding road through Elwynn. Hogger waits at the end.",
      waves = 12, ramp = 1.0, hp = 1.5, gold = 160, marks = 1, reward = 25,
      foes = { { "kobold", 1 }, { "wolf", 3 }, { "murloc", 5 }, { "brute", 8 } },
      bosses = { [12] = "hogger" } },
    { key = "westfall", name = "Westfall Fields", blurb = "The road circles the farms on its way to the farmhouse keep.",
      waves = 15, ramp = 1.15, hp = 2.2, gold = 175, marks = 1, reward = 35,
      foes = { { "kobold", 1 }, { "wolf", 1 }, { "murloc", 2 }, { "golem", 4 }, { "bat", 7 }, { "stalker", 10 } },
      bosses = { [8] = "hogger", [15] = "vancleef" } },
    { key = "duskwood", name = "Duskwood Graves", blurb = "The road coils into the graveyard. The dead don't stay down.",
      waves = 15, ramp = 1.35, hp = 1.4, gold = 190, marks = 2, reward = 45,
      foes = { { "kobold", 1 }, { "wolf", 1 }, { "ghoul", 2 }, { "bat", 4 }, { "stalker", 6 }, { "ooze", 8 }, { "mystic", 11 } },
      bosses = { [8] = "vancleef", [15] = "stitches" } },
    { key = "wetlands", name = "Wetlands Marsh", blurb = "A long road between the bogs, with little dry ground to build on.",
      waves = 18, ramp = 1.4, hp = 1.7, gold = 205, marks = 2, reward = 60,
      foes = { { "murloc", 1 }, { "raptor", 1 }, { "ooze", 3 }, { "bat", 5 }, { "brute", 7 }, { "mystic", 10 }, { "stalker", 13 } },
      bosses = { [9] = "stitches", [18] = "mutanus" } },
    { key = "needles", name = "Thousand Needles", blurb = "Long switchbacks between the spires. Harpies cut across them.",
      waves = 20, ramp = 1.5, hp = 2.1, gold = 220, marks = 3, reward = 75,
      foes = { { "wolf", 1 }, { "harpy", 1 }, { "brute", 3 }, { "raptor", 5 }, { "golem", 8 }, { "stalker", 11 }, { "mystic", 14 } },
      bosses = { [10] = "mutanus", [20] = "arikara" } },
    { key = "steppes", name = "Burning Steppes", blurb = "Blackrock's last stand, across rivers of lava. Onyxia comes at the end.",
      waves = 25, ramp = 1.6, hp = 2.4, gold = 240, marks = 3, reward = 100,
      foes = { { "ghoul", 1 }, { "whelp", 2 }, { "grunt", 3 }, { "shaman", 6 }, { "golem", 9 }, { "harpy", 11 }, { "stalker", 13 }, { "mystic", 16 } },
      bosses = { [8] = "vancleef", [16] = "arikara", [25] = "onyxia" } },
}
ns.BOSSES = { "hogger", "vancleef", "stitches", "mutanus", "arikara", "onyxia" }

-- Chapters two to ten are built from a list: each level's name and blurb, then the
-- chapter's foes in the order they turn up and its bosses (one ends each level).
local LATER = {
    { prefix = "morogh",
      foes = { "trogg", "frostmane", "leopard", "leper", "seer", "tunneler", "wendigo", "yeti", "mechano" },
      bosses = { "grikni", "icebeard", "beld", "vagash", "fallout", "thermaplugg" },
      levels = {
          { "Coldridge Valley", "Snow, troggs and a long walk to the keep." },
          { "Frostmane Hold", "The trolls come down from their caves." },
          { "Kharanos Crossing", "Thunderbrew's barrels won't defend themselves." },
          { "Gol'Bolar Quarry", "The troggs dig up from below." },
          { "Loch Modan Dam", "Wendigos and yetis along the frozen shore." },
          { "Gnomeregan", "The gnomes' city, irradiated and overrun. Mind the walking bombs." },
      } },
    { prefix = "redridge",
      foes = { "mongrel", "outrunner", "poacher", "worg", "warcaller", "webspider", "shadowcaster", "worgen", "dragonspawn" },
      bosses = { "gathilzogg", "morganth", "tharilzun", "malathrom", "stalvan", "morbent" },
      levels = {
          { "Lakeshire Bridge", "Gnolls on the bridge and orcs behind them." },
          { "Tower of Ilgalar", "Morganth stirs in his tower by the lake." },
          { "Render's Valley", "The Blackrock war camp empties onto the road." },
          { "Raven Hill Cemetery", "Duskwood's dead come back for another go." },
          { "Manor Mistmantle", "A lonely house, a lonelier ghost." },
          { "Deadwind Pass", "Morbent Fel waits in the crypts below Karazhan." },
      } },
    { prefix = "ashen",
      foes = { "furbolg", "nightsaber", "felhound", "ursa", "snapclaw", "trickster", "myrmidon", "wisp", "siren" },
      bosses = { "ursangous", "ghamoora", "sarevess", "kelris", "serrakis", "akumai" },
      levels = {
          { "Auberdine Shore", "Furbolgs out of the woods and crabs out of the sea." },
          { "Bashal'Aran", "Ruins, crabs, and one very large turtle." },
          { "Fallen Sky Lake", "The naga have come ashore." },
          { "Night Run", "Satyrs in the dark and a twilight lord behind them." },
          { "Zoram Strand", "Something big is swimming under the strand." },
          { "Blackfathom Deeps", "The flooded temple, and the thing that lives in it." },
      } },
    { prefix = "thorn",
      foes = { "axethrower", "tiger", "jraptor", "pirate", "batrider", "witchdoctor", "shadowhunter", "basilisk", "silverback" },
      bosses = { "bangalash", "moshogg", "mandokir", "grilek", "jindo", "hakkar" },
      levels = {
          { "Rebel Camp", "The jungle starts here. So do the tigers." },
          { "Nesingwary's Expedition", "Hemet wants trophies. The jungle wants Hemet." },
          { "Booty Bay Docks", "Pirates at the docks. Mind your gold." },
          { "Mosh'Ogg Mound", "Ogres, gorillas and very little shade." },
          { "Ruins of Zul'Kunda", "The Gurubashi are waking their old gods." },
          { "Zul'Gurub", "The blood god Hakkar, in his own temple." },
      } },
    { prefix = "bad",
      foes = { "coyote", "ogre", "buzzard", "ambusher", "ogremage", "scalding", "saboteur", "earthen", "stonekeeper" },
      bosses = { "revelosh", "ironaya", "sentinel", "keeper", "galgann", "archaedas" },
      levels = {
          { "Kargath Road", "Dust, coyotes and buzzards circling." },
          { "Angor Fortress", "Ogres hold the old dwarven fort." },
          { "Lethlor Ravine", "Dragonkin nest in the ravine." },
          { "Camp Boff", "The kobolds of Camp Boff have found some friends." },
          { "Hammertoe's Digsite", "Dark Irons dig where they shouldn't." },
          { "Uldaman", "The titans' vault, and the stone watcher who guards it." },
      } },
    { prefix = "tanaris",
      foes = { "sandfury", "hyena", "scorpid", "roc", "zombie", "thief", "duneworm", "sandcaster", "dustdevil" },
      bosses = { "antusul", "theka", "zumrah", "bly", "velratha", "gahzrilla" },
      levels = {
          { "Gadgetzan Gates", "Hot sand, hotter tempers." },
          { "Steamwheedle Port", "Thieves on the wharf. Watch your purse." },
          { "Noonshade Ruins", "Old stones half under the dunes." },
          { "Thistleshrub Valley", "Dust devils dance through the valley." },
          { "The Gaping Chasm", "Something tunnels under the sand." },
          { "Zul'Farrak", "Climb the stairs, ring the gong, meet the hydra." },
      } },
    { prefix = "plague",
      foes = { "plagueghoul", "skeleton", "plaguehound", "gargoyle", "acolyte", "crawler", "necromancer", "banshee", "horror" },
      bosses = { "forresten", "timmy", "ramstein", "gandling", "barthilas", "rivendare" },
      levels = {
          { "Chillwind Camp", "The last Alliance camp before the Plaguelands proper." },
          { "Andorhal", "A city of the dead, and a little boy who isn't." },
          { "Light's Hope Chapel", "Hold the chapel. Its light might hold you." },
          { "Corin's Crossing", "Necromancers raise the fallen as fast as you fell them." },
          { "Scholomance", "School's in. The headmaster is a lich." },
          { "Stratholme", "The Baron's city. The clock is ticking." },
      } },
    { prefix = "rock",
      foes = { "imp", "anvilrage", "geologist", "lavaspawn", "surger", "corehound", "firepriest", "flamewaker", "giant" },
      bosses = { "roccor", "argelmach", "angerforge", "thaurissan", "executus", "ragnaros" },
      levels = {
          { "Blackrock Stronghold", "The mountain's gate, and its fiery doorman." },
          { "Detention Block", "The Dark Irons' prison has opened its cells." },
          { "The Manufactory", "Golems roll off the line. Borrow their tricks." },
          { "Shadowforge City", "The Emperor's own streets." },
          { "Molten Bridge", "A bridge of rock over a river of fire." },
          { "Molten Core", "BY FIRE BE PURGED!" },
      } },
    { prefix = "silithus",
      foes = { "drone", "wasp", "stinger", "qiraji", "swarmguard", "geolord", "tentacle", "eradicator", "anubisath" },
      bosses = { "skeram", "huhuran", "ouro", "veklor", "cthun", "kelthuzad" },
      levels = {
          { "Cenarion Hold", "The druids hold the line. Help them." },
          { "Hive'Zora", "The hive empties out. All of it." },
          { "Bronzebeard Encampment", "Dwarves, gryphons and a lot of sand." },
          { "Scarab Wall", "Bang a gong, open the gates." },
          { "Temple of Ahn'Qiraj", "You are already dead. You just don't know it yet." },
          { "Naxxramas", "The floating necropolis, and the lich at its heart. The end of the road." },
      } },
}

-- Fine-tuning per level, from playtests: extra health on top of the formula below.
ns.TUNE = {
    morogh1 = 1.25,
    morogh2 = 1.12,
    morogh3 = 1.00,
    morogh4 = 1.25,
    morogh5 = 1.46,
    morogh6 = 1.57,
    redridge1 = 1.57,
    redridge2 = 1.00,
    redridge3 = 0.40,
    redridge4 = 1.12,
    redridge5 = 2.58,
    redridge6 = 2.58,
    ashen1 = 1.12,
    ashen2 = 1.40,
    ashen3 = 1.97,
    ashen4 = 1.00,
    ashen5 = 1.97,
    ashen6 = 0.89,
    thorn1 = 1.00,
    thorn2 = 1.25,
    thorn3 = 2.28,
    thorn4 = 1.63,
    thorn5 = 1.83,
    thorn6 = 0.88,
    bad1 = 3.53,
    bad2 = 2.28,
    bad3 = 1.83,
    bad4 = 1.63,
    bad5 = 2.12,
    bad6 = 1.64,
    tanaris1 = 3.52,
    tanaris2 = 4.50,
    tanaris3 = 4.12,
    tanaris4 = 3.2,
    tanaris5 = 4.50,
    tanaris6 = 4.12,
    plague1 = 4.50,
    plague2 = 2.76,
    plague3 = 2.37,
    plague4 = 1.89,
    plague5 = 1.30,
    plague6 = 0.9,
    rock1 = 4.50,
    rock2 = 4.50,
    rock3 = 4.50,
    rock4 = 2.22,
    rock5 = 1.32,
    rock6 = 0.8,
    silithus1 = 4.50,
    silithus2 = 4.50,
    silithus3 = 2.22,
    silithus4 = 1.5,
    silithus5 = 1.34,
    silithus6 = 1.24,
}

for c, ch in ipairs(LATER) do
    local chapter = c + 1
    local prev = LATER[c - 1]
    for i, info in ipairs(ch.levels) do
        local key = ch.prefix .. i
        local map = ns.MAPS[key]
        local waves = 14 + 2 * i + math.floor((chapter - 2) / 3)
        local lvl = {
            key = key, name = info[1], blurb = info[2], waves = waves,
            ramp = 1.05 + 0.1 * (i - 1) + 0.03 * (chapter - 2),
            hp = (1.0 + map.road / 60) * (ns.TUNE[key] or 1),
            gold = 170 + 10 * i + 10 * (chapter - 2),
            marks = 2 + (i >= 4 and 1 or 0),
            reward = 40 + 10 * i + 5 * (chapter - 2),
        }
        -- Foes the player has met before join from the first wave; one or two new ones
        -- make their debut each level. A couple of old friends from the last chapter
        -- drop by halfway.
        local foes, known = {}, i == 1 and 1 or (1 + i)
        for k = 1, math.min(#ch.foes, 3 + i) do
            local wave = 1
            if k > known then wave = k == known + 1 and 4 or (k == known + 2 and 9 or 13) end
            if i == 1 and k > 1 then wave = k == 2 and 3 or 7 end
            foes[#foes + 1] = { ch.foes[k], wave }
        end
        local guests = prev and prev.foes or { "grunt", "harpy" }
        foes[#foes + 1] = { guests[#guests - (i % 2)], math.floor(waves / 2) }
        lvl.foes = foes
        -- The chapter's boss for this level ends it; earlier ones come back along the way.
        local bosses = { [waves] = ch.bosses[i] }
        if i == 1 then
            bosses[math.floor(waves / 2)] = prev and prev.bosses[6] or "onyxia"
        elseif i < 6 then
            bosses[math.floor(waves / 2)] = ch.bosses[i - 1]
        else
            bosses[math.floor(waves / 3)] = ch.bosses[4]
            bosses[math.floor(2 * waves / 3)] = ch.bosses[5]
        end
        lvl.bosses = bosses
        lvl.endlessBosses = ch.bosses
        ns.LEVELS[#ns.LEVELS + 1] = lvl
    end
end

ns.LEVEL = {}
for i, l in ipairs(ns.LEVELS) do
    l.index = i
    l.chapter = math.floor((i - 1) / 6) + 1
    l.map = ns.MAPS[l.key]
    ns.LEVEL[l.key] = l
end
for c, ch in ipairs(ns.CHAPTERS) do
    ch.index = c
    ch.levels = {}
    for k = 1, 6 do ch.levels[k] = ns.LEVELS[(c - 1) * 6 + k] end
end
