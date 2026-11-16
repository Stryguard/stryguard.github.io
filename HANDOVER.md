# Stryguard roster: handover

Written on 14 November 2026 (Oslo time) at the end of a claude.ai session, for a Claude Code session started in `C:\Projects\wow_guild_project`.

## The project

- **Guild:** Stryguard, World of Warcraft: Forever, EU region, Roleplay PvP ruleset, Alliance. Guild id 102159, slug `stryguard`. 28 characters.
- **The user** runs the guild and is on Windows. Use `py`, not `python`.
- **Goal:** a guild tracker the whole guild can enjoy. The user has said plainly that they want **fun, whimsical stats, not meta stuff**. That rules out item level, character stats, talents and min-max raid planning unless they ask for it.

## What exists

### 1. The live tracker (claude.ai artifact)

- **URL:** https://claude.ai/artifact/FQ18ZiPqd8LbK3beTHcyUL, titled "Stryguard roster". It's private to the user for now.
- **Source:** `stryguard-roster.html` in this folder, copied from the published version at handover time.
- **Runtime:** one self-contained HTML file. It reaches the artifact runtime through `await window.claude.use("db")` and `use("user")`. Declared capabilities are `{db: {}, user: {}}`, and a republish has to keep them.
- **Data:**
  - `members` collection, one document per character. Fields: `first, last, title, race, cls, level, role, rank, alt, prof1, skill1, prof2, skill2, hks, notes, updatedAt`.
  - `guild/info` document: `{motto, updatedAt}`.
- **State at handover:** all 28 characters are loaded from the first script run. Roles, titles and notes are empty. Everyone except Sigmund Ashvane (Guild Master) has rank "Member".
- **Sections:**
  - Hero with a banner tinted by faction.
  - Raid readiness: Barrow Deeps 10, Hyjal Summit 20, Onyxia's Lair 40. Raids open on 9 December 2026, and only mains at level 60 count.
  - Class, role and level makeup.
  - Honorable kills board and best crafter per profession.
  - Sortable, filterable roster.
  - Member edit dialog.
  - "Paste a roster" box. It's a line parser that matches existing members by full name (case-insensitive) and updates them. It reads race, class, level, role, rank, two professions with skill, and "N HK".
- **Design:**
  - Fonts: Grenze Gotisch for display, Alegreya Sans for body text.
  - Faction tokens: `--banner` and `--trim` (Alliance is #1E3A7B / #C9A227).
  - Light and dark themes.
  - Data values are always set with `textContent`.
- **Hard limits:**
  - The page can't make network calls, so it can't call Blizzard or show images from render.worldofwarcraft.com.
  - The only external resource allowed is Google Fonts.
  - Don't use browser storage for data.
- **Publishing changes:** this needs artifact tools, meaning the Artifact tool or the claude-artifacts MCP. If this session doesn't have them, edit the local HTML, then ask the user to open a claude.ai chat and republish the file to the same URL. Writing database documents directly also needs those tools.

### 2. `fetch_roster.py`

- **Requirements:** Python 3.8 or newer, standard library only. Keep it that way.
- **Auth:** OAuth client credentials. `CLIENT_ID` is hard-coded, which is fine because it isn't secret. The secret comes from the `BLIZZARD_CLIENT_SECRET` environment variable, or from a hidden prompt.
- **Region:** read from `WOW_REGION`, otherwise the script asks. The guild is on `eu`.
- **API:**
  - Namespace `profile-forever-eu`, locale `en_GB`.
  - Roster: `/data/wow/guild/stryguard/roster`.
  - Character: `/profile/wow/character/{first}-{last}` in lowercase. Roster entries carry `slug`.
- **Outputs, written to the current folder:**
  - `stryguard-paste.txt`: lines for the paste box.
  - `stryguard-roster.json`: structured data, including all professions. The secondary ones (Cooking, Fishing, First Aid) are here too, though the tracker only stores two.
  - `--debug` → `stryguard-debug.json`.
  - `--probe "Name"` → `stryguard-probe.json`, a trimmed report covering 20 character endpoints for one character.
- **Fun data (added 14 Nov 2026, Claude Code):** each member in `stryguard-roster.json` now also has `id`, `slug`, `last_login` (ms) and a `fun` object: `stats` (flat `{name: quantity}`, ~104 distinct names across the guild incl. hugs, LOLs, facepalms, deaths from falling/drowning/fire/fatigue), `stat_details` (the "what" for "…most" stats), `bosses` `[{boss, dungeon, kills}]`, `deeds` (completed achievements, newest first), `recent_deeds`, `pets`, `mounts`, `reputations`, `looks` (named customizations), `gear` (slot/name/quality only), `titles`, `active_title`, `portrait` (render URLs). 12 requests per member, full run ~40 s. Flags: `--no-fun`, `--out FOLDER`.
- **Ranks:** `RANK_NAMES` only maps rank 0. The roster has rank 0 ×1 (Sigmund Ashvane), rank 1 ×2 (Fam Ily, Aulë Ill), rank 3 ×19 and rank 4 ×6. Rank 2 is unused. Ask the user what ranks 1, 3 and 4 are called.

## The secret

- Never read, print, echo, log or save `BLIZZARD_CLIENT_SECRET`. Keep it out of files, commits and tool output. To check that it's set, test for presence only, for example `py -c "import os; print(bool(os.environ.get('BLIZZARD_CLIENT_SECRET')))"`.
- An earlier secret was pasted into a chat, and the user was advised to regenerate it. If you're unsure whether they did, remind them once.

## Probe findings (Old Iron, 14 November 2026)

All 20 endpoints answered in `profile-forever-eu`:

- profile, titles, reputations
- collections, collections/mounts, collections/pets
- achievements, achievements/statistics, statistics
- appearance
- encounters, encounters/dungeons, encounters/raids
- quests, quests/completed
- character-media, equipment, specializations, pvp-summary, professions

What's useful for the fun direction:

- **`/achievements/statistics`** is the best source.
  - The shape is categories → sub_categories → statistics, each `{id, name, quantity, description?, last_updated_timestamp}`.
  - Quantities are floats (62.0).
  - Some entries keep the "what" in `description`. For example, "Bandage used most" → "Linen Bandage", and probably "Creature type killed the most" works the same way.
  - Old Iron's numbers: deaths from falling 3, deaths from drowning 1, total deaths 59, deaths from the opposite faction 18, food eaten 117, beverages 5, health potions 62, elixirs 6, critters killed 92, creatures killed 4,856, times camped 121, hearthstone uses 36, flight paths taken 78, waves 24, cheers 13, need rolls 63 vs greed rolls 103, quests completed 327, quests abandoned 9, duels lost 1, 5-player dungeons entered 17.
  - Boss kills are named, for example "Edwin VanCleef Kills (Deadmines)". The probe only kept names, not ids, so match by name or save full answers to find the ids.
- **`/collections/pets`:** `pets[{species.name, level, quality, is_favorite}]`. Old Iron has a Cockatiel and a Prairie Chicken (favourite).
- **`/collections/mounts`:** empty for him, since nobody has a mount at level 34 yet.
- **`/titles`:** no titles earned. The probe's `all_titles: ["Old"]` comes from the probe itself picking up the character's name, not a real title.
- **`/reputations`:** 14 factions, each with `standing.name` (Neutral, Friendly, Honored…), `tier`, `value` and `max`. Darkmoon Faire is in there.
- **`/achievements`:**
  - `recent_events[{achievement.name, timestamp}]`, for example "Explore Dun Morogh" and "Novice Spelunker". Good for a guild news feed.
  - `achievements[]` with `completed_timestamp`.
  - Points are always 0 in Forever.
- **`/quests/completed`:** 361 named quests.
- **`/appearance`:** some customizations have a named choice, for example Hair Style "Triple Knots". Nice RP flavour.
- **`/equipment`:** item names, some of them funny ("Grubbis Paws", "Quilboar Blaster").
- **`/character-media`:** `avatar` (jpg), `main-raw` and `main-sd-raw` (png) on render.worldofwarcraft.com. The page can't link to these directly. They would have to be uploaded as artifact assets or embedded as data URLs.
- **Profile:** `last_login_timestamp` (ms) is good for a playful "last seen in Azeroth". It also has `ruleset {name: "Roleplay PvP", id: 15}`.
- **`/specializations`:** active spec and spent points. That's meta, so leave it alone unless the user asks, for example to fill in roles automatically.

## What the user wants next

They said "fun stuff, not meta things, more of a whimsy vibe". Nothing below has been built or agreed in detail yet:

- A guild book of records with superlative awards: most falls, drownings, meals, potions, critters slain, times camped, hearthstones, flight paths, waves and cheers, greediest roller, most quests abandoned, most deaths at the hands of the Horde.
- Favourite pet on each member card, and mounts once people have them.
- Reputation fun, like who is best loved in each city, plus Darkmoon Faire standing.
- A "recent deeds" feed built from achievement `recent_events`.
- Boss kill counts, hiscore style: a table per boss and a boss log per character (replaced the trophy wall, 16 Nov 2026).
- Silly gear names and named hairstyles on member cards.
- Head chef and best angler awards from the secondary professions. Silas Moonwhisper has Cooking 300 and Fishing 226.
- Portraits, which need the extra asset work described above.

## Suggested plan

1. **Extend `fetch_roster.py`** so it also fetches these per member: `/achievements/statistics`, `/collections/pets`, `/collections/mounts`, `/reputations`, `/achievements` (recent events only), `/appearance` and `/equipment`. Save a small, curated `fun` object per member in `stryguard-roster.json`. At about 8 extra requests × 28 members, a run is roughly 250 requests, far below Blizzard's limits (36,000 an hour, 100 a second).
2. **Get the data into the tracker.** The line-based paste box can't carry nested data. The best option is a "Load roster file" button on the page that reads `stryguard-roster.json` locally with FileReader (no network). It would merge into `members` by full name and write the `fun` fields. Keep the paste box for manual use.
3. **Add a whimsical section** (book of records or "Hall of oddities") and a richer member dialog. Keep the existing design language.
4. **Fill in rank names** in `RANK_NAMES` once the user tells you what they are.
5. **Later, self-hosting:** a GitHub Actions job runs the script with the secret stored as a repository secret, and GitHub Pages serves the page. The Blizzard client's Service URL is `http://localhost` for now. Update it when a site goes live.

## Gotchas

- The Forever API is undocumented, so field names can change. If something breaks, run `py fetch_roster.py --probe "Old Iron"` again.
- Names with special characters (Aulë, Bjørnson) work, because the script URL-encodes slugs.
- The `alt` flag is manual. Raid readiness only counts non-alts at level 60.
- The script writes its files to whatever folder you run it from.

## Files in this folder

- `HANDOVER.md`: this file.
- `CLAUDE.md`: short rules that Claude Code loads automatically.
- `fetch_roster.py`: the sync script.
- `stryguard-roster.html`: source of the live tracker.
- `stryguard-paste.txt`: output of the latest run (28 lines).
- `stryguard-roster.json`: output of the latest run.
- `stryguard-probe.json`: probe report for Old Iron.
