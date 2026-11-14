# Stryguard roster

Read `HANDOVER.md` before doing anything. It has the full context: the live tracker, the sync script, what the Blizzard API returns for WoW: Forever, and what's next.

Rules for this project:

- **The secret:** never read, print, echo, log or save the `BLIZZARD_CLIENT_SECRET` environment variable. To check that it's set, test for presence only.
- **Windows:** the user is on Windows, so run Python with `py`.
- **Fun first:** the user wants fun, whimsical stats for the guild, not meta stuff like item level, stats or talents, unless they ask for it.
- **The script:** keep `fetch_roster.py` standard-library only.
- **The website (main product now):** `site/index.html` + `site/guild.json`, deployed hourly to GitHub Pages by `.github/workflows/update.yml` (repo github.com/Stryguard/stryguard.github.io, live at https://stryguard.github.io). One self-contained page that fetches only its own `data/stryguard-roster.json` and `guild.json`; data values via `textContent`. See README.md.
- **The old claude.ai page:**
  - `stryguard-roster.html` is the source of a live claude.ai artifact. Keep it one self-contained file.
  - The page makes no network calls. Data values are set with `textContent`, never `innerHTML`.
  - Keep the `db` and `user` capabilities whenever it's republished.
