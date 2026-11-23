"""Lay out the Skywatch maps and write StryguardSkywatch/Maps.lua.

The first chapter's six maps are drawn by hand (HANDMADE below). Every other map is
generated from its key, so running this again gives the same maps. A generated road is a
random self-avoiding walk on a lattice of every other square, which keeps road squares
from touching except where the road really goes (Game.lua follows the road square by
square, so two stretches side by side would confuse it). Then trees, water, rocks and
props are scattered by the chapter's theme, keeping enough open ground by the road.

Each map also gets its picture's place: hand-drawn maps have their own texture in media/,
generated ones share atlas textures, four to a 1024x512 picture (see make_maps.py).

Standard library only. Run from the addon folder: py tools/make_levels.py
Pass --show to print every map.
"""
import os
import random
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "StryguardSkywatch", "Maps.lua")
COLS, ROWS = 22, 13
PER_ATLAS = 4

HANDMADE = {
    "goldshire": [
        "TT....T.....TT.....TTT",
        "S########...~~~.......",
        "....T...#...~~~...###E",
        "T.......#.R.......#..T",
        "..#######.........#...",
        "T.#..T..........T.#..T",
        "..#...........#####.TT",
        "..#.....T.....#.R.....",
        "T.######..T...#......T",
        "TT..R..#......#.......",
        "T......#..T...#..T..TT",
        "TT.....########......T",
        "TTT..T...TT...T..T.TTT",
    ],
    "westfall": [
        "TT..G....T....G...TTTT",
        "T.......G.......T...TT",
        "..################.G.T",
        "..#..............#....",
        "..#......G.......#..T.",
        "..#..##########..#..GT",
        "S##..#........#..#T.T.",
        "TT...#..E######..#....",
        "..T..#....R......#G..T",
        "T.G..#...........#....",
        "TT...#############..GT",
        "T..G....T.....G....TTT",
        "TT...T.....T....T..TTT",
    ],
    "duskwood": [
        "TTT...T....T.....TTTTT",
        "S################T.TTT",
        "TG....G.........#G..TT",
        "T.............G.#..G.T",
        "T..##########...#T....",
        "T..#........#...#.G..T",
        "TG.#...G....#...#.T..T",
        "T..#........#...#...GT",
        "TT.#..E######...#T....",
        "T..#.......G....#.G..T",
        "TG.#............#T..TT",
        "T..##############.G.TT",
        "TTT...T..G...T..TTTTTT",
    ],
    "wetlands": [
        "TT...T....~~~....T.TTT",
        "S#################T.TT",
        "TT.....~~~~~.....#.T.T",
        "T.......~~~~.....#....",
        "....##############T..T",
        "T..T#.....~~~~........",
        "TT..#....~~~~~......TT",
        "~...##############.T..",
        "~~........T......#...T",
        "~~~.~~~..........#....",
        "~~~~~~~..T.......####E",
        "T~~~~~......T....~~~TT",
        "TT~~...T.....T..~~~~TT",
    ],
    "needles": [
        "T..R...T...R....T..T.T",
        "...........T..........",
        "S##..####..####..####E",
        "..#..#..#..#..#..#.R.T",
        "T.#..#..#..#..#..#....",
        "..#..#..#..#..#..#..T.",
        ".T#..#..#..#..#..#...T",
        "..#..#..#..#..#..#.R..",
        "T.#..#..#..#..#..#...T",
        "..#..#..#..#..#..#...T",
        "R.####..####..####..T.",
        "...T.....R.....T......",
        "T.R..T..T...R....T.TTT",
    ],
    "steppes": [
        "TT.R...T..~~~..R...TTT",
        "TT.#######~~~~...T.##E",
        "R..#.~~~.#.......R.#T.",
        "...#.~~~~#..####...#R.",
        "T..#.....#~.#..#...#..",
        "...#..####..#..#...#..",
        "T..#..#.....#..#...#.T",
        ".R.#..#..~~.#..#...#..",
        "T..#..#.~~~.#..#...#~T",
        "..G#..#######..#...#..",
        "T..#........R..#...#.T",
        "S###~~.......R.#####~T",
        "TT..~~~..T......R..TTT",
    ],
}

# How each chapter's ground is dressed. trees/rocks/props are chances per open square
# (trees come in clumps), water is how many pools, keep is how often the keep sits inside
# the board rather than on its right edge.
THEMES = {
    "dunmorogh": dict(trees=0.20, water=2, rocks=0.05, props=0.0, keep=0.3),
    "redridge": dict(trees=0.16, water=2, rocks=0.07, props=0.02, keep=0.4),
    "ashenvale": dict(trees=0.30, water=2, rocks=0.02, props=0.02, keep=0.3),
    "stranglethorn": dict(trees=0.34, water=3, rocks=0.03, props=0.02, keep=0.4),
    "badlands": dict(trees=0.08, water=1, rocks=0.12, props=0.03, keep=0.5),
    "tanaris": dict(trees=0.05, water=1, rocks=0.06, props=0.04, keep=0.4),
    "plaguelands": dict(trees=0.14, water=2, rocks=0.04, props=0.06, keep=0.5),
    "blackrock": dict(trees=0.07, water=3, rocks=0.10, props=0.03, keep=0.5),
    "silithus": dict(trees=0.09, water=1, rocks=0.08, props=0.04, keep=0.6),
}

# Chapter key prefix, theme, and the road length (squares) of its first and last map.
CHAPTERS = [
    ("morogh", "dunmorogh", 50, 84),
    ("redridge", "redridge", 54, 88),
    ("ashen", "ashenvale", 56, 92),
    ("thorn", "stranglethorn", 58, 96),
    ("bad", "badlands", 60, 98),
    ("tanaris", "tanaris", 62, 100),
    ("plague", "plaguelands", 64, 104),
    ("rock", "blackrock", 66, 108),
    ("silithus", "silithus", 68, 112),
]

NODE_C = list(range(1, 20, 2))   # 1, 3, ... 19
NODE_R = list(range(1, 12, 2))   # 1, 3, ... 11


def walk(rnd, want_len, edge_end):
    """A self-avoiding walk on the node lattice, from the left column, `want_len` road
    squares long (give or take), ending on the right column when edge_end."""
    nc, nr = len(NODE_C), len(NODE_R)
    target_nodes = (want_len + 1) // 2
    best = None
    for _attempt in range(400):
        start = (0, rnd.randrange(nr))
        path, seen = [start], {start}
        straight = rnd.uniform(0.35, 0.8)
        last_dir = (1, 0)
        stuck = False
        while len(path) < target_nodes + 6:
            i, j = path[-1]
            opts = []
            for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (i + d[0], j + d[1])
                if 0 <= n[0] < nc and 0 <= n[1] < nr and n not in seen:
                    # Look one step further to avoid walking into a dead end.
                    free = sum(1 for e in ((1, 0), (-1, 0), (0, 1), (0, -1))
                               if 0 <= n[0] + e[0] < nc and 0 <= n[1] + e[1] < nr and (n[0] + e[0], n[1] + e[1]) not in seen)
                    w = 1.0 + (straight * 4 if d == last_dir else 0) + (0.6 if d[0] == 1 else 0) + free * 0.3
                    if free == 0 and not (edge_end and n[0] == nc - 1):
                        w *= 0.05
                    opts.append((w, d, n))
            if not opts:
                stuck = True
                break
            tot = sum(o[0] for o in opts)
            pick = rnd.uniform(0, tot)
            for w, d, n in opts:
                pick -= w
                if pick <= 0:
                    break
            path.append(n)
            seen.add(n)
            last_dir = d
            if len(path) >= target_nodes - 3:
                if edge_end and n[0] == nc - 1:
                    break
                if not edge_end and n[0] >= 4 and len(path) >= target_nodes:
                    break
        ok_end = (path[-1][0] == nc - 1) if edge_end else path[-1][0] >= 4
        if not ok_end or len(path) < target_nodes - 4:
            continue
        # Prefer a walk that spreads across the board.
        js = {p[1] for p in path}
        is_ = {p[0] for p in path}
        score = -abs(len(path) - target_nodes) + 0.5 * len(js) + 0.3 * len(is_)
        if best is None or score > best[0]:
            best = (score, path)
        if score > target_nodes * 0 + 7 and len(js) >= 5:
            break
        _ = stuck
    return best[1] if best else None


def blank():
    return [["." for _ in range(COLS)] for _ in range(ROWS)]


def lay_road(grid, path, edge_end):
    cells = []
    sc, sr = 0, NODE_R[path[0][1]]
    grid[sr][sc] = "S"
    cells.append((sc, sr))
    prev = None
    for i, j in path:
        c, r = NODE_C[i], NODE_R[j]
        if prev:
            mc, mr = (prev[0] + c) // 2, (prev[1] + r) // 2
            grid[mr][mc] = "#"
            cells.append((mc, mr))
        grid[r][c] = "#"
        cells.append((c, r))
        prev = (c, r)
    if edge_end:
        grid[prev[1]][20] = "#"
        grid[prev[1]][21] = "E"
        cells += [(20, prev[1]), (21, prev[1])]
    else:
        grid[prev[1]][prev[0]] = "E"
    return cells


def near_road(grid, c, r, reach):
    for dr in range(-reach, reach + 1):
        for dc in range(-reach, reach + 1):
            rr, cc = r + dr, c + dc
            if 0 <= rr < ROWS and 0 <= cc < COLS and grid[rr][cc] in "#SE":
                return True
    return False


def dress(grid, rnd, theme):
    t = THEMES[theme]
    # Pools of water: small blobs on open ground, one square clear of the road.
    for _ in range(t["water"]):
        for _try in range(30):
            c, r = rnd.randrange(COLS), rnd.randrange(ROWS)
            if grid[r][c] != "." or near_road(grid, c, r, 1):
                continue
            size = rnd.randint(3, 7)
            pool = [(c, r)]
            while len(pool) < size:
                pc, pr = rnd.choice(pool)
                dc, dr = rnd.choice(((1, 0), (-1, 0), (0, 1), (0, -1)))
                nc, nr = pc + dc, pr + dr
                if 0 <= nc < COLS and 0 <= nr < ROWS and grid[nr][nc] == "." and not near_road(grid, nc, nr, 0) \
                        and (nc, nr) not in pool:
                    pool.append((nc, nr))
                elif rnd.random() < 0.2:
                    break
            for pc, pr in pool:
                grid[pr][pc] = "~"
            break
    # Trees in clumps, thicker at the edges of the board.
    seeds = [(rnd.randrange(COLS), rnd.randrange(ROWS)) for _ in range(int(t["trees"] * 40))]
    for r in range(ROWS):
        for c in range(COLS):
            if grid[r][c] != ".":
                continue
            edge = min(c, COLS - 1 - c, r, ROWS - 1 - r)
            chance = t["trees"] * (2.2 if edge == 0 else 1.2 if edge == 1 else 0.6)
            for sc, sr in seeds:
                if abs(sc - c) + abs(sr - r) <= 1:
                    chance += 0.35
            if near_road(grid, c, r, 0):
                chance *= 0.25
            if rnd.random() < chance:
                grid[r][c] = "T"
    for r in range(ROWS):
        for c in range(COLS):
            if grid[r][c] != ".":
                continue
            x = rnd.random()
            if x < t["rocks"]:
                grid[r][c] = "R"
            elif x < t["rocks"] + t["props"]:
                grid[r][c] = "G"


def check(grid):
    """Problems with a map, or an empty list."""
    probs = []
    flat = "".join("".join(row) for row in grid)
    if flat.count("S") != 1 or flat.count("E") != 1:
        probs.append("needs one S and one E")
    road = [(c, r) for r in range(ROWS) for c in range(COLS) if grid[r][c] in "#SE"]
    # Every road square except the ends has exactly two road neighbours.
    for c, r in road:
        n = sum(1 for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1))
                if 0 <= c + dc < COLS and 0 <= r + dr < ROWS and grid[r + dr][c + dc] in "#SE")
        want = 1 if grid[r][c] in "SE" else 2
        if n != want:
            probs.append(f"road square {c},{r} has {n} neighbours")
            break
    build = sum(1 for r in range(ROWS) for c in range(COLS) if grid[r][c] == "." and near_road(grid, c, r, 1))
    if build < 45:
        probs.append(f"only {build} open squares by the road")
    rocks = sum(1 for r in range(ROWS) for c in range(COLS) if grid[r][c] == "R" and near_road(grid, c, r, 2))
    water = sum(1 for r in range(ROWS) for c in range(COLS) if grid[r][c] == "~" and near_road(grid, c, r, 2))
    if rocks < 3:
        probs.append(f"only {rocks} rocks by the road")
    if water < 3:
        probs.append(f"only {water} water squares by the road")
    return probs, len(road)


def generate(key, theme, want_len):
    base = zlib.crc32(key.encode())
    for n in range(500):
        rnd = random.Random(base + n * 7919)
        edge_end = rnd.random() > THEMES[theme]["keep"]
        path = walk(rnd, want_len, edge_end)
        if not path:
            continue
        grid = blank()
        lay_road(grid, path, edge_end)
        dress(grid, rnd, theme)
        probs, length = check(grid)
        if abs(length - want_len) > 12:
            continue
        if not probs:
            return ["".join(row) for row in grid], length
    raise SystemExit(f"couldn't lay out {key}")


def main():
    show = "--show" in sys.argv
    entries = []
    for key, rows in HANDMADE.items():
        assert len(rows) == ROWS and all(len(r) == COLS for r in rows), key
        probs, length = check([list(r) for r in rows])
        entries.append((key, None, rows, length))
    for prefix, theme, first, last in CHAPTERS:
        for i in range(6):
            key = f"{prefix}{i + 1}"
            want = round(first + (last - first) * i / 5)
            rows, length = generate(key, theme, want)
            entries.append((key, theme, rows, length))
    out = ["local _, ns = ...", "",
           "-- Every level's map. Generated by tools/make_levels.py: change it there and run it again.",
           "-- art is the picture's file in media/; slot is its place in a shared atlas (0-3), if any.",
           "ns.MAPS = {"]
    atlas_i = 0
    for key, theme, rows, length in entries:
        if theme is None:
            head = f'    {key} = {{ art = "{key}", road = {length}, rows = {{'
        else:
            art, slot = f"atlas{atlas_i // PER_ATLAS + 1}", atlas_i % PER_ATLAS
            atlas_i += 1
            head = f'    {key} = {{ theme = "{theme}", art = "{art}", slot = {slot}, road = {length}, rows = {{'
        out.append(head)
        for row in rows:
            out.append(f'        "{row}",')
        out.append("    } },")
        if show:
            print(key, theme or "", length)
            print("\n".join(rows))
            print()
    out.append("}")
    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out) + "\n")
    print(f"wrote {len(entries)} maps to Maps.lua")


if __name__ == "__main__":
    main()
