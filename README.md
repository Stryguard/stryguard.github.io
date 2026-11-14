# Stryguard

A self-updating website for **Stryguard**, an Alliance guild on World of Warcraft: Forever (EU, RP-PvP).
Live at **<https://stryguard.github.io>**.

It shows the roster and a hall of oddities: who fell to their doom the most, who eats the most,
who the Horde loves to kill, which bosses we have humbled, and more.

## How it works

```
GitHub Actions (every hour)          GitHub Pages
  fetch_roster.py  ──► site/data/  ──► site/index.html loads the data when you open it
  (Blizzard API, secret stays on GitHub)
```

- `.github/workflows/update.yml` runs every hour, on every push to `main`, and on demand
  (Actions tab → *Update site* → *Run workflow*). It fetches the guild from Blizzard and publishes `site/`.
- `site/index.html` is the whole website: one self-contained page.
- `site/guild.json` holds what the API doesn't know. **Edit it on GitHub** (open the file, pencil icon, commit)
  and the site rebuilds in a minute or two:
  - `motto`: the guild motto under the banner
  - `ranks`: guild rank names by rank number (0 is the Guild Master)
  - `members`: per character, `role` (Tank, Healer or Damage), `alt` (true or false; alts get a tag and can be hidden in the roster), an in-character `title`, and `notes`.
    New characters appear on the site automatically; add them here only to set these fields.
- `site/milestones.json` lists the odd milestones (first to die 100 times, first to 10 hugs, ...). Add your own;
  each needs a unique `id`.
- `site/firsts.json` is the ledger of who claimed each milestone first. The hourly job updates and commits it
  whenever someone crosses a line; don't edit it by hand unless you're correcting a mistake.
  Achievement firsts (levels, crafts, exploration, dungeons) need no ledger: the Armory dates them exactly.
- `site/history.json` keeps one snapshot of everyone a day (the last 15 days). It feeds the levelling race,
  stolen crowns and the Town Crier, which comes out every Sunday from 22 November 2026. The hourly job adds
  the day's snapshot on its first run after midnight (UTC) and commits it.
- `fetch_roster.py` is the data script. Python 3.8+, standard library only.

## One-time setup

1. **Secret:** repository *Settings → Secrets and variables → Actions → New repository secret*.
   Name `BLIZZARD_CLIENT_SECRET`, value = the client secret from <https://develop.battle.net/access/clients>.
2. **Pages:** *Settings → Pages → Build and deployment → Source: GitHub Actions*.
3. Run the workflow once from the Actions tab. The site appears at <https://stryguard.github.io>.

## Running it locally

```sh
py fetch_roster.py --out site/data      # asks for the secret unless BLIZZARD_CLIENT_SECRET is set
py -m http.server 8000 -d site          # then open http://localhost:8000
```

Other flags: `--no-fun` (skip the fun stats, faster), `--debug` (save raw answers for the first member),
`--probe "Name"` (report every endpoint for one character).

## Notes

- Blizzard hasn't documented the Forever API; field names may change. If something breaks, run a probe.
- GitHub pauses scheduled workflows in repositories with no activity for 60 days. Any commit (even a
  `guild.json` edit) resets that; GitHub emails a warning first.
- `stryguard-roster.html` is the older claude.ai artifact version of the tracker, kept for reference.
