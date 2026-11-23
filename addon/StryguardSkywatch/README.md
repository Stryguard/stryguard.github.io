# Stryguard Skywatch

A tower defence campaign for long flights on World of Warcraft: Forever. Foes march from the lair to Stryguard keep; build towers along the road to stop them.

## Install

Copy this `StryguardSkywatch` folder into
`C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\`
and restart the game. A `/reload` is enough for code changes, but new map pictures only load on a full restart.

## Play

- `/skywatch` (or `/td`) opens and closes the window. It also opens by itself when you take a flight, and pauses when you land.
- Pick a chapter and a level, pick a tower on the right, then click a square. Shift-click keeps building; right-click cancels.
- Click a tower to upgrade it, change who it shoots, or sell it. At level 3 you choose one of two specialisations.
- Every fourth wave you pick a blessing for the rest of the run. Hold every wave to win the level.
- Your run is saved between waves, so it carries over to your next flight.

Other commands: `/skywatch scale 0.8`, `/skywatch reset`, `/skywatch flights off`.

## The campaign

Ten chapters of six levels, sixty in all, each locked until you win the one before. Every level ends with its own boss, and many unlock a new tower. After a win you can keep going in endless mode, where the waves keep getting harder and a boss comes every tenth wave.

| Chapter | Where | Last boss | New towers |
|---|---|---|---|
| 1. The Road to Stryguard | Elwynn to the Burning Steppes | Onyxia | Holy Beacon, Goblin Mint, Storm Totem, Serpent Ward, Arcane Obelisk |
| 2. The Frozen Pass | Dun Morogh, Gnomeregan | Mekgineer Thermaplugg | Dwarven Cannon, Ballista |
| 3. Redridge Burning | Redridge, Duskwood | Morbent Fel | War Drums, Shadow Spire |
| 4. Shadows of Ashenvale | Ashenvale, Blackfathom Deeps | Aku'mai | Earthbind Totem, Mage Tower |
| 5. The Gurubashi Jungle | Stranglethorn, Zul'Gurub | Hakkar | Harbor Battery, Entangling Briars |
| 6. The Badlands | Badlands, Uldaman | Archaedas | Mining Camp, Rifleman's Nest |
| 7. Sands of Tanaris | Tanaris, Zul'Farrak | Gahz'rilla | Rocket Battery, Earthshaker Totem |
| 8. The Plaguelands | Plaguelands, Stratholme | Baron Rivendare | Chapel of Light |
| 9. Blackrock Mountain | Blackrock Depths, Molten Core | Ragnaros | Tesla Coil |
| 10. Gates of Ahn'Qiraj | Silithus, Ahn'Qiraj, Naxxramas | Kel'Thuzad | Wildhammer Roost |

Stars: three for losing no lives, two for losing fewer than ten, one for a win.

**Heroic:** any level you've won can be played on Heroic (the switch above the level cards): tougher foes, an affix every other wave and half the lives, for half as much reward again and skulls instead of stars.

## The armoury

There are 24 towers but only nine slots, so before a run you choose which nine to bring (the Armoury button on the level screen). A new tower joins your loadout by itself while there's room. Some towers need special ground: Spike Traps and Entangling Briars go on the road, Mining Camps on rocks, Harbor Batteries on water or lava.

## Foes

Over 100 kinds of foe and 60 bosses. Besides armour, flying and stealth, foes can heal or shield their friends, ward them or urge them on, get back up, split, burrow out of reach, blink forward, leave spawn behind them, frenzy when friends die, steal your gold, shrug off magic or physical damage, and silence your towers. Bosses call for help, dive out of reach, and some can't be slowed or stunned. Each foe is introduced the first time it shows up.

Sixteen affixes can change a wave, from Hasted and Shielded to Sabotage, Undying and Elite.

## Marks, the shop and deeds

Marks carry over between runs, even lost ones. You earn them for every wave held, every boss slain, every win (the first win of a level pays the most), every new star, and deeds. Spend them with the Quartermaster (the Shop button) on upgrades that last for every run: 19 general upgrades, plus a mastery for every tower.

Deeds are nearly a hundred feats that pay marks once: clearing chapters (and flawless or on Heroic), mastering each tower, slaying foes and bosses, holding endless waves, and odd challenges like winning with only Archer Towers.

## Blessings

Over a hundred, offered three at a time every fourth wave. Most help everyone; some only turn up when a tower they favour is in your loadout.

## Towers

| Tower | Good for | Level 4 choices |
|---|---|---|
| Archer | Cheap, steady, hits flyers | Marksman / Volley |
| Frost | Slowing; fire hits chilled foes 50% harder | Blizzard / Deep Freeze |
| Fire | Splash; no flyers | Inferno / Ignite |
| Spike Trap | On the road; stabs every ground foe on it | Tar Pit / Goblin Mine |
| Holy | Reveals stealth, boosts towers it touches | Crusader Aura / Consecration |
| Mint | Gold every wave | Bank / Bounty Office |
| Storm | Chain lightning for swarms | Thunderstorm / Overload |
| Serpent Ward | Stacking poison that ignores armour | Plague / Viper Sting |
| Arcane Obelisk | A beam that builds up on one target | Focus / Prism |
| Dwarven Cannon | Heavy ground splash | Siege Cannon / Mortar |
| Ballista | Bolts that skewer a whole line | Bolt Thrower / Harpoon |
| War Drums | Towers it touches attack faster | Bloodlust Drums / Drums of Battle |
| Shadow Spire | Curses: cursed foes take more from everything | Shadow Word: Pain / Mind Flay |
| Earthbind Totem | Slows everything near it | Earthgrab / Grounding |
| Mage Tower | Arcane missiles; polymorphs foes into sheep | Polymorph Master / Arcane Barrage |
| Harbor Battery | On water; long-range cannon | Broadside / Chain Shot |
| Entangling Briars | On the road; roots foes in place | Thornweave / Wild Growth |
| Mining Camp | On rocks; gold every wave | Thorium Vein / Gem Cutter |
| Rifleman's Nest | Huge range, heavy shots | Headshot / Big Game Hunter |
| Rocket Battery | Flyers only, very hard | Flak Cannons / Homing Rockets |
| Earthshaker Totem | Throws ground foes back down the road | Earthquake / Tremor |
| Chapel of Light | Mends the keep | Cathedral / Light's Hope |
| Tesla Coil | Discharges into everything nearby, flyers too | Overcharger / Arc Field |
| Wildhammer Roost | Double damage to flyers | Stormhammer / Sky Marshal |

## Files

- `Maps.lua`: every level's map. Made by `../tools/make_levels.py`; don't edit by hand.
- `Data.lua`: towers, affixes, blessings, the shop, and how waves are built.
- `Foes.lua`: every foe and boss, and what the game says when one first appears.
- `Levels.lua`: the chapters and levels. `ns.TUNE` holds per-level health tweaks from bot playtests.
- `Deeds.lua`: the deeds.
- `Meta.lua`: marks, the shop, the loadout, campaign progress, tallies and deeds, which carry over between runs.
- `Game.lua`: the simulation, with no UI code.
- `UI.lua`: the window.
- `Core.lua`: saved settings, slash commands and the flight hooks.
- `media/`: the painted map backgrounds, made by `../tools/make_maps.py` from `Maps.lua`. Chapter one's maps each have their own picture; the rest share `atlas1` to `atlas14`, four maps to a picture.

To change a map: edit `HANDMADE` (chapter one) or the chapter settings in `tools/make_levels.py`, run `py tools/make_levels.py`, then `py tools/make_maps.py <key>` from the `addon` folder.
