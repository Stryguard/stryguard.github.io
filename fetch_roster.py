#!/usr/bin/env python3
"""
Stryguard roster sync for World of Warcraft: Forever.

Reads the guild roster and each member's profile from Blizzard's API, then
prints one line per character for the tracker's "Paste a roster" box.

It also saves two files next to where you run it:
  stryguard-paste.txt    the same lines, ready to copy
  stryguard-roster.json  the data as JSON, for a hosted site later

The JSON also carries a "fun" object per member: deaths by falling and
drowning, meals eaten, critters slain, greed vs need rolls, bosses defeated,
pets, mounts, reputations, recent achievements, named hairstyles, gear names
and portrait links.

Run it with:   python fetch_roster.py        (on Windows: py fetch_roster.py)
Add --debug to also save the raw API answers for the first member to
stryguard-debug.json. That file holds public game data only, never your secret.
Add --no-fun to skip the fun data (much faster).
Add --out FOLDER to write the files somewhere other than the current folder.

Scouting mode:  python fetch_roster.py --probe "Old Iron"
asks Blizzard for every kind of data about one character (titles, mounts,
reputations, statistics and so on) and saves a short report to
stryguard-probe.json, without fetching the rest of the guild.

Needs only Python 3.8 or newer. Nothing to install.

Settings can come from environment variables (handy for GitHub Actions later):
  BLIZZARD_CLIENT_ID, BLIZZARD_CLIENT_SECRET, WOW_REGION (eu or us), WOW_GUILD
Anything not set is asked for when the script starts. The secret is typed
hidden and is never printed or saved.

Note: Blizzard hasn't documented the Forever endpoints yet. This follows what
players have found works, so field names may change without notice.
"""
import base64
import getpass
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor

CLIENT_ID = os.environ.get("BLIZZARD_CLIENT_ID", "bed0cc2e6cc049d88e4c1e520bcc3b32")
GUILD = os.environ.get("WOW_GUILD", "Stryguard")

# The API gives rank numbers, not rank names. 0 is always the guild master.
# Add your own, e.g. {0: "Guild Master", 1: "Officer", 2: "Veteran", 3: "Member", 4: "Recruit"}
RANK_NAMES = {0: "Guild Master", 1: "Officer", 3: "Member", 4: "Recruit"}

# Set to False to read only the roster: much faster, but no professions or kills.
FETCH_DETAILS = True
# Set to False to skip the fun data (statistics, pets, reputations, gear names...): about 9 fewer requests each.
FETCH_FUN = "--no-fun" not in sys.argv

CLASS_BY_ID = {1: "Warrior", 2: "Paladin", 3: "Hunter", 4: "Rogue", 5: "Priest",
               7: "Shaman", 8: "Mage", 9: "Warlock", 11: "Druid"}
RACE_BY_ID = {1: "Human", 2: "Orc", 3: "Dwarf", 4: "Night Elf", 5: "Undead",
              6: "Tauren", 7: "Gnome", 8: "Troll"}

DEBUG = "--debug" in sys.argv


def out_dir():
    """--out FOLDER writes the files there instead of the current folder."""
    if "--out" in sys.argv:
        i = sys.argv.index("--out")
        if i + 1 < len(sys.argv) and not sys.argv[i + 1].startswith("--"):
            os.makedirs(sys.argv[i + 1], exist_ok=True)
            return sys.argv[i + 1]
        sys.exit("--out needs a folder name, e.g. --out site/data")
    return "."


OUT = out_dir()


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def ask_region():
    region = os.environ.get("WOW_REGION", "").strip().lower()
    if region not in ("eu", "us") and not sys.stdin.isatty():
        sys.exit("Set WOW_REGION to eu or us.")
    while region not in ("eu", "us"):
        region = input("Which region is the guild on, eu or us? ").strip().lower()
    return region


def get_token(client_id, secret):
    body = urllib.parse.urlencode({"grant_type": "client_credentials"}).encode()
    req = urllib.request.Request("https://oauth.battle.net/token", data=body, method="POST")
    req.add_header("Authorization", "Basic " + base64.b64encode(f"{client_id}:{secret}".encode()).decode())
    req.add_header("Content-Type", "application/x-www-form-urlencoded")
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.load(r)["access_token"]
    except urllib.error.HTTPError as e:
        if e.code in (400, 401):
            sys.exit("Blizzard rejected the client ID or secret. Check both on the developer portal and try again.")
        raise


class Api:
    def __init__(self, region, token):
        self.region = region
        self.token = token
        self.locale = "en_GB" if region == "eu" else "en_US"

    def get(self, path, namespace="profile", strict=True):
        query = urllib.parse.urlencode({"namespace": f"{namespace}-forever-{self.region}", "locale": self.locale})
        url = f"https://{self.region}.api.blizzard.com{path}?{query}"
        req = urllib.request.Request(url, headers={"Authorization": "Bearer " + self.token})
        self.last_status = None
        for attempt in range(4):
            try:
                with urllib.request.urlopen(req, timeout=30) as r:
                    time.sleep(0.05)  # stay far below Blizzard's rate limit
                    self.last_status = 200
                    return json.load(r)
            except urllib.error.HTTPError as e:
                self.last_status = e.code
                if e.code == 404:
                    return None
                if e.code == 429 or e.code >= 500:
                    time.sleep(1.5 * (attempt + 1))
                    continue
                if not strict:
                    return None
                if e.code in (401, 403):
                    sys.exit(f"Blizzard refused {path} (HTTP {e.code}). The token may have expired; run the script again.")
                raise
            except urllib.error.URLError as e:
                if attempt == 3:
                    sys.exit(f"Couldn't reach Blizzard's API: {e.reason}")
                time.sleep(1.5 * (attempt + 1))
        return None


def text(v):
    """Names arrive as plain strings, as {"name": ...}, or as a dict of locales."""
    if isinstance(v, str):
        return v
    if isinstance(v, dict):
        if "name" in v:
            return text(v["name"])
        for val in v.values():
            if isinstance(val, str):
                return val
    return ""


def find_key(data, key):
    """Find the first value stored under `key` anywhere in a nested answer."""
    if isinstance(data, dict):
        if key in data and isinstance(data[key], (int, float)):
            return int(data[key])
        for val in data.values():
            found = find_key(val, key)
            if found is not None:
                return found
    elif isinstance(data, list):
        for val in data:
            found = find_key(val, key)
            if found is not None:
                return found
    return None


def race_name(raw, faction):
    low = raw.strip().lower()
    if "windshaper" in low:
        return "Windshaper Skyborne"
    if "high order" in low:
        return "High Order Skyborne"
    if "skyborne" in low:
        return {"ALLIANCE": "High Order Skyborne", "HORDE": "Windshaper Skyborne"}.get(faction, "")
    if low in ("forsaken", "scourge"):
        return "Undead"
    return raw.strip()


def professions(data):
    out = []
    if not isinstance(data, dict):
        return out
    for group in ("primaries", "secondaries"):
        for entry in data.get(group) or []:
            name = text(entry.get("profession"))
            skill = entry.get("skill_points")
            if skill is None:
                tiers = [t.get("skill_points") for t in entry.get("tiers") or [] if isinstance(t.get("skill_points"), int)]
                skill = max(tiers) if tiers else None
            if name:
                out.append((name, skill))
    return out


def slugify(*parts):
    return "-".join(p.strip().lower().replace(" ", "-").replace("'", "") for p in parts if p and p.strip())


# ---------- Fun data: the whimsical bits for the guild's book of records ----------
# Each entry is (key in the "fun" object, path under the character).
FUN_PATHS = [("statistics", "/achievements/statistics"), ("achievements", "/achievements"),
             ("pets", "/collections/pets"), ("mounts", "/collections/mounts"),
             ("reputations", "/reputations"), ("appearance", "/appearance"),
             ("equipment", "/equipment"), ("titles", "/titles"), ("media", "/character-media")]


def number(q):
    """Statistics arrive as floats (62.0). Keep whole numbers as ints."""
    if isinstance(q, float) and q.is_integer():
        return int(q)
    return q


def boss_kill(name):
    """'Edwin VanCleef Kills (Deadmines)' -> ('Edwin VanCleef', 'Deadmines'); anything else -> None."""
    low = name.lower()
    i = low.rfind(" kills (")
    if i < 0 or not name.endswith(")"):
        return None
    return name[:i].strip(), name[i + len(" kills ("):-1].strip()


def fun_statistics(data):
    """Flatten categories -> sub_categories -> statistics into {name: quantity}.
    Stats that name a 'what' (e.g. 'Bandage used most' -> 'Linen Bandage') also land in details.
    Boss kills come out separately so the stats stay a tidy list."""
    stats, details, bosses = {}, {}, []

    def take(entries, in_boss_group):
        for s in entries or []:
            name, qty = text(s.get("name")), number(s.get("quantity"))
            if not name or not isinstance(qty, (int, float)):
                continue
            boss = boss_kill(name) if in_boss_group else None
            if boss:
                bosses.append({"boss": boss[0], "dungeon": boss[1], "kills": qty})
                continue
            stats[name] = max(qty, stats.get(name, qty))
            if s.get("description"):
                details[name] = text(s.get("description"))

    def walk(cats):
        for cat in cats or []:
            group = text(cat.get("name")).lower()
            take(cat.get("statistics"), "boss" in group)
            walk(cat.get("sub_categories"))

    if isinstance(data, dict):
        walk(data.get("categories"))
    return stats, details, bosses


def fun_data(answers):
    """Boil the raw answers for one character down to a small 'fun' object."""
    fun = {}
    stats, details, bosses = fun_statistics(answers.get("statistics"))
    fun["stats"], fun["stat_details"], fun["bosses"] = stats, details, bosses

    ach = answers.get("achievements") or {}
    fun["deeds"] = sorted(({"name": text(a.get("achievement")), "at": a.get("completed_timestamp")}
                           for a in ach.get("achievements") or []
                           if isinstance(a, dict) and a.get("completed_timestamp")),
                          key=lambda d: d["at"], reverse=True)
    fun["recent_deeds"] = [{"name": text(e.get("achievement")), "at": e.get("timestamp")}
                           for e in ach.get("recent_events") or [] if isinstance(e, dict)]

    pets = (answers.get("pets") or {}).get("pets") or []
    fun["pets"] = [{"name": text(p.get("name")) or text(p.get("species")), "species": text(p.get("species")),
                    "level": p.get("level"), "quality": text(p.get("quality")),
                    "favorite": bool(p.get("is_favorite"))} for p in pets if isinstance(p, dict)]

    mounts = (answers.get("mounts") or {}).get("mounts") or []
    fun["mounts"] = [{"name": text(m.get("mount")), "favorite": bool(m.get("is_favorite"))}
                     for m in mounts if isinstance(m, dict)]

    reps = (answers.get("reputations") or {}).get("reputations") or []
    fun["reputations"] = [{"faction": text(r.get("faction")), "standing": text(r.get("standing")),
                           "tier": (r.get("standing") or {}).get("tier"),
                           "value": (r.get("standing") or {}).get("value"),
                           "max": (r.get("standing") or {}).get("max")} for r in reps if isinstance(r, dict)]

    # Only customizations with a named choice are worth showing ("Hair Style": "Triple Knots").
    looks = (answers.get("appearance") or {}).get("customizations") or []
    fun["looks"] = {text(c.get("option")): text(c.get("choice")) for c in looks
                    if isinstance(c, dict) and text(c.get("option")) and text(c.get("choice"))}

    # Gear for its names, not its numbers.
    gear = (answers.get("equipment") or {}).get("equipped_items") or []
    fun["gear"] = [{"slot": text(g.get("slot")), "name": text(g.get("name")), "quality": text(g.get("quality"))}
                   for g in gear if isinstance(g, dict) and text(g.get("name"))]

    titles = answers.get("titles") or {}
    fun["titles"] = [text(t) for t in titles.get("titles") or [] if text(t)]
    fun["active_title"] = text(titles.get("active_title")) or None

    # Portrait links for a hosted site (the claude.ai page can't load them).
    assets = (answers.get("media") or {}).get("assets") or []
    fun["portrait"] = {a.get("key"): a.get("value") for a in assets
                       if isinstance(a, dict) and a.get("key") in ("avatar", "inset", "main-raw")}
    return fun


# ---------- Probe mode: see what Forever's character endpoints actually return ----------
PROBE_PATHS = ["", "/titles", "/reputations", "/collections", "/collections/mounts", "/collections/pets",
               "/achievements", "/achievements/statistics", "/statistics", "/appearance",
               "/encounters", "/encounters/dungeons", "/encounters/raids", "/quests", "/quests/completed",
               "/character-media", "/equipment", "/specializations", "/pvp-summary", "/professions"]


def trim(v, depth=0):
    """Shorten an answer so the report stays small: first 3 items of each list, short strings."""
    if isinstance(v, dict):
        if depth > 6:
            return "{...}"
        return {k: trim(x, depth + 1) for k, x in v.items() if k not in ("_links", "href")}
    if isinstance(v, list):
        out = [trim(x, depth + 1) for x in v[:3]]
        if len(v) > 3:
            out.append(f"... {len(v) - 3} more")
        return out
    if isinstance(v, str) and len(v) > 100:
        return v[:100] + "..."
    return v


def collect(data, test, fmt, limit=600):
    """Walk a whole answer and list every entry that passes `test`, formatted by `fmt`."""
    found = []

    def walk(node):
        if len(found) >= limit:
            return
        if isinstance(node, dict):
            if test(node):
                found.append(fmt(node))
            for val in node.values():
                walk(val)
        elif isinstance(node, list):
            for val in node:
                walk(val)

    walk(data)
    return found


def probe(api, member):
    c = member.get("character") or {}
    first, last = text(c.get("name")), text(c.get("surname") or c.get("last_name"))
    slug = c.get("slug") or slugify(first, last)
    base = f"/profile/wow/character/{urllib.parse.quote(slug.lower())}"
    report = {"character": f"{first} {last}".strip(), "roster_entry": trim(member), "endpoints": {}}
    for path in PROBE_PATHS:
        log(f"  asking for {path or 'the profile'}...")
        data = api.get(base + path, strict=False)
        status = api.last_status
        entry = {"status": "ok" if data is not None else (f"HTTP {status}" if status else "no answer")}
        if data is not None:
            entry["top_level_fields"] = [k for k in data.keys() if k != "_links"] if isinstance(data, dict) else type(data).__name__
            entry["sample"] = trim(data)
            # Full lists for the parts most likely to hold fun stuff
            named_counts = collect(data, lambda d: "name" in d and isinstance(d.get("quantity"), (int, float)),
                                   lambda d: f"{text(d.get('name'))}: {d.get('quantity')}")
            if named_counts:
                entry["all_named_counts"] = named_counts
            if path == "/reputations":
                entry["all_reputations"] = collect(data, lambda d: "faction" in d and "standing" in d,
                                                   lambda d: f"{text(d.get('faction'))}: {text(d.get('standing'))}")
            if path == "/titles":
                entry["all_titles"] = list(dict.fromkeys(collect(data, lambda d: "name" in d and "id" in d,
                                                                 lambda d: text(d.get("name")))))
            if path in ("/collections/mounts", "/collections/pets", "/achievements", "/quests/completed"):
                for key in ("mounts", "pets", "achievements", "quests"):
                    if isinstance(data.get(key), list):
                        entry[f"{key}_count"] = len(data[key])
                        entry[f"{key}_names"] = [text(x.get("mount") or x.get("species") or x.get("achievement") or x)
                                                 for x in data[key][:40] if isinstance(x, dict)]
        report["endpoints"][path or "/ (profile)"] = entry
    with open(os.path.join(OUT, "stryguard-probe.json"), "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    ok = [p for p, e in report["endpoints"].items() if e["status"] == "ok"]
    log(f"\nSaved stryguard-probe.json for {report['character']}. {len(ok)} of {len(PROBE_PATHS)} kinds of data answered:")
    for p, e in report["endpoints"].items():
        log(f"  {p:<28} {e['status']}")
    log("\nAttach stryguard-probe.json in the chat with Claude.")


def main():
    region = ask_region()
    secret = os.environ.get("BLIZZARD_CLIENT_SECRET")
    if not secret and not sys.stdin.isatty():
        sys.exit("No client secret: set BLIZZARD_CLIENT_SECRET (on GitHub, as a repository secret).")
    secret = secret or getpass.getpass("Client secret (typing is hidden): ").strip()
    if not secret:
        sys.exit("No client secret given.")

    log("Getting an access token...")
    api = Api(region, get_token(CLIENT_ID, secret))

    guild_slug = slugify(GUILD)
    log(f"Reading the {GUILD} roster ({region.upper()})...")
    roster = api.get(f"/data/wow/guild/{urllib.parse.quote(guild_slug)}/roster")
    if not roster or not roster.get("members"):
        sys.exit(f"No guild called {GUILD!r} was found on {region.upper()}. Check the region and spelling, "
                 "or try again later if the guild was created very recently.")

    if "--probe" in sys.argv:
        i = sys.argv.index("--probe")
        wanted = sys.argv[i + 1].strip().lower() if i + 1 < len(sys.argv) and not sys.argv[i + 1].startswith("--") else ""

        def label(m):
            c = m.get("character") or {}
            return f"{text(c.get('name'))} {text(c.get('surname') or c.get('last_name'))}".strip().lower()

        pick = next((m for m in roster["members"] if wanted and label(m) == wanted), None)
        if wanted and not pick:
            pick = next((m for m in roster["members"] if label(m).startswith(wanted)), None)
        if wanted and not pick:
            sys.exit(f"Nobody called {wanted!r} is on the roster. Check the spelling, or leave the name out to use the first member.")
        log(f"Scouting {label(pick or roster['members'][0]).title()}...")
        probe(api, pick or roster["members"][0])
        return

    debug = {"roster_first_member": roster["members"][0]} if DEBUG else None
    members = []
    total = len(roster["members"])
    for n, m in enumerate(roster["members"], 1):
        c = m.get("character") or {}
        first = text(c.get("name"))
        last = text(c.get("surname") or c.get("last_name") or c.get("family_name"))
        slug = c.get("slug") or slugify(first, last)
        faction = text((c.get("faction") or {}).get("type")) or ""
        rec = {
            "first": first, "last": last,
            "race": RACE_BY_ID.get((c.get("playable_race") or {}).get("id"), ""),
            "class": CLASS_BY_ID.get((c.get("playable_class") or {}).get("id"), ""),
            "level": c.get("level"),
            "rank": RANK_NAMES.get(m.get("rank"), ""),
            "rank_number": m.get("rank"),
            "professions": [], "honorable_kills": None,
            "id": c.get("id"), "slug": slug, "last_login": None,
        }
        if FETCH_DETAILS and slug:
            log(f"  {n}/{total}  {first} {last}".rstrip())
            base = f"/profile/wow/character/{urllib.parse.quote(slug.lower())}"
            profile = api.get(base)
            if profile:
                rec["level"] = profile.get("level", rec["level"])
                rec["class"] = text(profile.get("character_class")) or rec["class"]
                faction = text((profile.get("faction") or {}).get("type")) or faction
                rec["race"] = text(profile.get("race")) or rec["race"]
                rec["last"] = rec["last"] or text(profile.get("surname"))
                rec["id"] = profile.get("id", rec["id"])
                rec["last_login"] = profile.get("last_login_timestamp")
            prof_data = api.get(base + "/professions")
            pvp = api.get(base + "/pvp-summary")
            rec["professions"] = professions(prof_data)
            rec["honorable_kills"] = find_key(pvp, "honorable_kills")
            if FETCH_FUN:
                # A missing fun answer shouldn't stop the whole run, so these aren't strict.
                with ThreadPoolExecutor(max_workers=4) as pool:
                    answers = dict(zip([k for k, _ in FUN_PATHS],
                                       pool.map(lambda kp: api.get(base + kp[1], strict=False), FUN_PATHS)))
                rec["fun"] = fun_data(answers)
            if debug is not None and n == 1:
                debug.update({"profile": profile, "professions": prof_data, "pvp_summary": pvp})
                if FETCH_FUN:
                    debug.update({f"fun_{k}": v for k, v in answers.items()})
        rec["race"] = race_name(rec["race"], faction)
        members.append(rec)

    lines = []
    for r in members:
        fields = [f"{r['first']} {r['last']}".strip(), r["race"], r["class"],
                  str(r["level"]) if isinstance(r["level"], int) and 1 <= r["level"] <= 60 else "", r["rank"]]
        fields += [f"{name} {skill}" if isinstance(skill, int) else name for name, skill in r["professions"][:2]]
        if r["honorable_kills"]:
            fields.append(f"{r['honorable_kills']} HK")
        lines.append(", ".join(f for f in fields if f))

    with open(os.path.join(OUT, "stryguard-paste.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    with open(os.path.join(OUT, "stryguard-roster.json"), "w", encoding="utf-8") as f:
        json.dump({"guild": GUILD, "region": region, "fetched_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                   "members": members}, f, ensure_ascii=False, indent=2)
    if debug is not None:
        with open(os.path.join(OUT, "stryguard-debug.json"), "w", encoding="utf-8") as f:
            json.dump(debug, f, ensure_ascii=False, indent=2)
        log("Saved stryguard-debug.json")

    print("\n".join(lines))
    log(f"\nDone: {len(lines)} characters. Copy the lines above, or open stryguard-paste.txt, "
        "and paste them into “Paste a roster” on the tracker.")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit("\nStopped.")
