"""Paint the Skywatch map backgrounds.

Reads every map's rows from Maps.lua (made by make_levels.py) and the board size from
Data.lua, and paints each map at 30 pixels a square. Hand-drawn maps (chapter one) are
scaled to the board's square size and saved in the top-left of their own 1024x512 TGA.
Generated maps are scaled to 18 pixels a square and packed four to a 1024x512 atlas
(atlas1.tga, atlas2.tga, ...), to keep the addon small. All in StryguardSkywatch/media
(WoW wants power-of-two textures). Standard library only. Pass --png DIR to also write
PNG previews, and map keys or atlas names to paint only those (a key paints its whole atlas).

Map letters: S lair, E keep, # road, . open ground, T trees (spires on Thousand
Needles, burnt stumps on the Burning Steppes), ~ water (bog, lava), G graves
(haystacks, bones), R rocks.
"""
import math
import os
import random
import re
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.join(HERE, "..", "StryguardSkywatch")
DATA = open(os.path.join(ADDON, "Data.lua"), encoding="utf-8").read()
MAPS = open(os.path.join(ADDON, "Maps.lua"), encoding="utf-8").read()
COLS, ROWS, OUT_CELL = map(int, re.search(r"ns\.COLS, ns\.ROWS, ns\.CELL = (\d+), (\d+), (\d+)", DATA).groups())
CELL = 30                                  # painted at 30 pixels a square...
W, H = COLS * CELL, ROWS * CELL
OUT_W, OUT_H = COLS * OUT_CELL, ROWS * OUT_CELL   # ...then scaled to the board
TEX_W, TEX_H = 1024, 512
SLOT_W, SLOT_H, ATLAS_CELL = 512, 256, 18        # atlas slots, and their maps' square size
AT_W, AT_H = COLS * ATLAS_CELL, ROWS * ATLAS_CELL

# tree: leafy, spire or dead. prop: what a G square holds. liquid: what ~ is.
THEMES = {
    "goldshire": dict(grass=(0.36, 0.52, 0.2), grass2=(0.46, 0.55, 0.2), road=(0.62, 0.5, 0.33), leaf=(0.2, 0.42, 0.14),
                      flowers=[(0.95, 0.85, 0.3), (0.95, 0.95, 0.9), (0.8, 0.45, 0.75)], flower_rate=0.0009, tuft=0.004,
                      tree="leafy", prop="grave", liquid="water", pads=True),
    "westfall": dict(grass=(0.55, 0.5, 0.24), grass2=(0.64, 0.56, 0.27), road=(0.58, 0.45, 0.3), leaf=(0.62, 0.4, 0.15),
                     flowers=[(0.95, 0.8, 0.3), (0.9, 0.55, 0.25)], flower_rate=0.0006, tuft=0.003,
                     tree="leafy", prop="hay", liquid="water", pads=False, furrows=True),
    "duskwood": dict(grass=(0.16, 0.24, 0.17), grass2=(0.2, 0.22, 0.25), road=(0.36, 0.33, 0.3), leaf=(0.12, 0.2, 0.15),
                     flowers=[(0.6, 0.45, 0.8), (0.75, 0.75, 0.85)], flower_rate=0.0004, tuft=0.004, mist=True,
                     tree="leafy", prop="grave", liquid="water", pads=False),
    "wetlands": dict(grass=(0.24, 0.34, 0.19), grass2=(0.3, 0.33, 0.2), road=(0.42, 0.36, 0.27), leaf=(0.17, 0.32, 0.15),
                     flowers=[(0.85, 0.85, 0.6), (0.6, 0.7, 0.4)], flower_rate=0.0004, tuft=0.007,
                     tree="leafy", prop="grave", liquid="bog", pads=True),
    "needles": dict(grass=(0.66, 0.42, 0.24), grass2=(0.74, 0.52, 0.3), road=(0.82, 0.68, 0.48), leaf=None,
                    flowers=[(0.5, 0.55, 0.3)], flower_rate=0.0003, tuft=0.0012, cracks=True,
                    tree="spire", prop="bones", liquid="water", pads=False),
    "steppes": dict(grass=(0.2, 0.16, 0.14), grass2=(0.29, 0.2, 0.16), road=(0.42, 0.35, 0.3), leaf=None,
                    flowers=[(1.0, 0.5, 0.1), (1.0, 0.75, 0.3)], flower_rate=0.0007, tuft=0.0008, cracks=True, glow=True,
                    tree="dead", prop="bones", liquid="lava", pads=False),
    "dunmorogh": dict(grass=(0.8, 0.84, 0.9), grass2=(0.7, 0.77, 0.86), road=(0.55, 0.5, 0.46), leaf=(0.14, 0.28, 0.22),
                      flowers=[(0.97, 0.98, 1.0)], flower_rate=0.0006, tuft=0.0008,
                      tree="pine", prop="bones", liquid="ice", pads=False),
    "redridge": dict(grass=(0.42, 0.43, 0.2), grass2=(0.56, 0.38, 0.22), road=(0.62, 0.42, 0.3), leaf=(0.4, 0.44, 0.17),
                     flowers=[(0.9, 0.5, 0.2), (0.95, 0.85, 0.3)], flower_rate=0.0007, tuft=0.004,
                     tree="leafy", prop="hay", liquid="water", pads=True),
    "ashenvale": dict(grass=(0.17, 0.25, 0.23), grass2=(0.23, 0.21, 0.31), road=(0.38, 0.33, 0.3), leaf=(0.18, 0.3, 0.3),
                      flowers=[(0.7, 0.5, 0.9), (0.5, 0.8, 0.9)], flower_rate=0.0006, tuft=0.005, mist=True,
                      tree="leafy", prop="grave", liquid="water", pads=True),
    "stranglethorn": dict(grass=(0.2, 0.4, 0.15), grass2=(0.28, 0.45, 0.12), road=(0.5, 0.4, 0.25), leaf=(0.1, 0.36, 0.1),
                          flowers=[(1.0, 0.3, 0.4), (1.0, 0.8, 0.2), (0.9, 0.4, 0.9)], flower_rate=0.0012, tuft=0.008,
                          tree="jungle", prop="bones", liquid="water", pads=True),
    "badlands": dict(grass=(0.62, 0.4, 0.28), grass2=(0.7, 0.5, 0.35), road=(0.78, 0.6, 0.42), leaf=None,
                     flowers=[(0.5, 0.45, 0.3)], flower_rate=0.0002, tuft=0.001, cracks=True,
                     tree="spire", spire=(0.66, 0.34, 0.22), prop="bones", liquid="water", pads=False),
    "tanaris": dict(grass=(0.86, 0.74, 0.48), grass2=(0.9, 0.8, 0.56), road=(0.74, 0.6, 0.4), leaf=None,
                    flowers=[(0.6, 0.65, 0.3)], flower_rate=0.0002, tuft=0.0006, furrows=True,
                    tree="spire", spire=(0.8, 0.64, 0.4), prop="bones", liquid="water", pads=False),
    "plaguelands": dict(grass=(0.34, 0.36, 0.22), grass2=(0.42, 0.38, 0.25), road=(0.4, 0.36, 0.3), leaf=None,
                        flowers=[(0.6, 0.7, 0.3), (0.55, 0.45, 0.6)], flower_rate=0.0004, tuft=0.003, mist=True,
                        tree="dead", prop="grave", liquid="slime", pads=False),
    "blackrock": dict(grass=(0.17, 0.14, 0.13), grass2=(0.25, 0.17, 0.14), road=(0.36, 0.3, 0.27), leaf=None,
                      flowers=[(1.0, 0.5, 0.1), (1.0, 0.75, 0.3)], flower_rate=0.0008, tuft=0.0006, cracks=True, glow=True,
                      tree="dead", prop="bones", liquid="lava", pads=False),
    "silithus": dict(grass=(0.75, 0.62, 0.4), grass2=(0.68, 0.5, 0.42), road=(0.62, 0.5, 0.38), leaf=None,
                     flowers=[(0.6, 0.4, 0.8)], flower_rate=0.0003, tuft=0.0006, cracks=True,
                     tree="spire", spire=(0.55, 0.4, 0.75), prop="bones", liquid="slime", pads=False),
}
LIQUIDS = {
    "water": dict(shallow=(0.3, 0.5, 0.58), deep=(0.1, 0.22, 0.36), foam=(0.75, 0.88, 0.95), shore=(0.7, 0.62, 0.42), rough=0.25, pads=1.0),
    "bog": dict(shallow=(0.22, 0.34, 0.3), deep=(0.07, 0.15, 0.13), foam=(0.45, 0.58, 0.5), shore=(0.3, 0.25, 0.15), rough=0.35, pads=0.35),
    "lava": dict(shallow=(1.0, 0.62, 0.15), deep=(0.78, 0.16, 0.03), foam=(1.0, 0.9, 0.5), shore=(0.12, 0.08, 0.07), rough=0.5, pads=0.0),
    "ice": dict(shallow=(0.72, 0.86, 0.94), deep=(0.5, 0.68, 0.86), foam=(1.0, 1.0, 1.0), shore=(0.9, 0.92, 0.96), rough=0.2, pads=0.0),
    "slime": dict(shallow=(0.45, 0.6, 0.2), deep=(0.24, 0.36, 0.1), foam=(0.7, 0.85, 0.4), shore=(0.3, 0.3, 0.15), rough=0.35, pads=0.0),
}
LIGHT = (-0.5, -0.6, 0.62)


def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else hi if v > hi else v


def mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def mul(a, k):
    return tuple(x * k for x in a)


class Noise:
    """Smooth value noise on a lattice, summed over a few octaves."""

    def __init__(self, seed, size=64):
        rnd = random.Random(seed)
        self.size = size
        self.v = [rnd.random() for _ in range(size * size)]

    def at(self, x, y):
        n = self.size
        xi, yi = int(math.floor(x)), int(math.floor(y))
        xf, yf = x - xi, y - yi
        u, w = xf * xf * (3 - 2 * xf), yf * yf * (3 - 2 * yf)
        x0, x1, y0, y1 = xi % n, (xi + 1) % n, yi % n, (yi + 1) % n
        v = self.v
        a = v[y0 * n + x0] + (v[y0 * n + x1] - v[y0 * n + x0]) * u
        b = v[y1 * n + x0] + (v[y1 * n + x1] - v[y1 * n + x0]) * u
        return a + (b - a) * w

    def fbm(self, x, y, octaves=3):
        total, amp, norm = 0.0, 1.0, 0.0
        for _ in range(octaves):
            total += self.at(x, y) * amp
            norm += amp
            x, y, amp = x * 2.03 + 17.1, y * 2.03 + 5.3, amp * 0.5
        return total / norm


def read_maps():
    """Each map's key, theme, picture file, atlas slot (or None) and rows, from Maps.lua."""
    maps = []
    for m in re.finditer(r"^    (\w+) = \{(.*?)rows = \{(.*?)\} \},", MAPS, re.S | re.M):
        key, head, body = m.groups()
        theme = re.search(r'theme = "(\w+)"', head)
        art = re.search(r'art = "(\w+)"', head).group(1)
        slot = re.search(r"slot = (\d+)", head)
        rows = re.findall(r'"([^"]*)"', body)
        assert len(rows) == ROWS and all(len(r) == COLS for r in rows), key
        maps.append((key, theme.group(1) if theme else key, art, int(slot.group(1)) if slot else None, rows))
    return maps


def road_points(rows):
    """Follow the road from S to E and keep only the corners, in pixels."""
    grid = {(c, r): ch for r, row in enumerate(rows) for c, ch in enumerate(row)}
    start = next(k for k, v in grid.items() if v == "S")
    goal = next(k for k, v in grid.items() if v == "E")
    cells, seen, cur = [start], {start}, start
    while cur != goal:
        for dc, dr in ((1, 0), (0, 1), (-1, 0), (0, -1)):
            nxt = (cur[0] + dc, cur[1] + dr)
            if grid.get(nxt) in ("#", "E") and nxt not in seen:
                cur = nxt
                break
        seen.add(cur)
        cells.append(cur)
    pts = [cells[0]]
    for i in range(1, len(cells) - 1):
        a, b, c = cells[i - 1], cells[i], cells[i + 1]
        if (b[0] - a[0], b[1] - a[1]) != (c[0] - b[0], c[1] - b[1]):
            pts.append(b)
    pts.append(cells[-1])
    return grid, [((c + 0.5) * CELL, (r + 0.5) * CELL) for c, r in pts]


def seg_dist(px, py, segs):
    best = 1e9
    for ax, ay, bx, by in segs:
        dx, dy = bx - ax, by - ay
        span = dx * dx + dy * dy
        t = 0.0 if span == 0 else clamp(((px - ax) * dx + (py - ay) * dy) / span)
        ex, ey = ax + dx * t - px, ay + dy * t - py
        d = ex * ex + ey * ey
        if d < best:
            best = d
    return math.sqrt(best)


class Canvas:
    def __init__(self):
        self.px = [[(0.0, 0.0, 0.0)] * W for _ in range(H)]

    def get(self, x, y):
        return self.px[y][x]

    def put(self, x, y, col, alpha=1.0):
        if 0 <= x < W and 0 <= y < H:
            if alpha >= 1:
                self.px[y][x] = col
            else:
                self.px[y][x] = mix(self.px[y][x], col, alpha)

    def shade(self, x, y, k, alpha=1.0):
        if 0 <= x < W and 0 <= y < H:
            c = self.px[y][x]
            self.px[y][x] = mix(c, mul(c, k), alpha)


def shadow(cv, cx, cy, rx, ry, strength=0.45):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if d < 1:
                cv.shade(x, y, 0.35, strength * (1 - d) ** 0.6)


def blob(cv, cx, cy, r, base, noise, rim=0.55, gloss=0.6):
    """A shaded sphere-ish blob lit from the top left, with a dark rim."""
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            dx, dy = (x + 0.5 - cx) / r, (y + 0.5 - cy) / r
            d2 = dx * dx + dy * dy
            if d2 > 1:
                continue
            dz = math.sqrt(1 - d2)
            light = clamp(dx * LIGHT[0] + dy * LIGHT[1] + dz * LIGHT[2])
            k = 0.5 + gloss * light + (noise.at(x * 0.45, y * 0.45) - 0.5) * 0.35
            if d2 > (1 - 1.4 / r) ** 2:
                k *= rim
            cv.put(x, y, mul(base, k))


def paint_tree(cv, cx, cy, leaf, noise, rnd, big=1.0):
    shadow(cv, cx + 5, cy + 8, 16 * big, 9 * big)
    for y in range(int(cy + 3), int(cy + 11)):
        for x in range(int(cx - 1), int(cx + 2)):
            cv.put(x, y, (0.3, 0.2, 0.12) if x < cx + 1 else (0.2, 0.13, 0.08))
    tint = mul(leaf, rnd.uniform(0.9, 1.1))
    parts = [(rnd.uniform(-6, 6) * big, rnd.uniform(-3, 4) * big, rnd.uniform(7.5, 9.5) * big) for _ in range(4)]
    parts.sort(key=lambda p: p[1])
    for dx, dy, r in parts:
        blob(cv, cx + dx, cy + dy - 3, r, tint, noise)
    blob(cv, cx + rnd.uniform(-2, 2), cy - 7, 7.5, mul(tint, 1.15), noise)


def paint_pine(cv, cx, cy, leaf, noise, rnd):
    """A snowy fir: stacked dark-green tiers, white on their upper edges."""
    shadow(cv, cx + 6, cy + 9, 12, 6, 0.5)
    for y in range(int(cy + 6), int(cy + 11)):
        for x in range(int(cx - 1), int(cx + 2)):
            cv.put(x, y, (0.3, 0.2, 0.12))
    height = rnd.uniform(22, 27)
    top = cy + 7 - height
    for y in range(int(top), int(cy + 8)):
        t = (y - top) / height
        tier = (t * 3) % 1
        half = 2 + 9 * t * (0.55 + 0.45 * tier)
        for x in range(int(cx - half), int(cx + half) + 1):
            u = (x + 0.5 - cx) / max(half, 1)
            k = 0.75 + 0.35 * (1 - (u + 1) / 2) + (noise.at(x * 0.5, y * 0.5) - 0.5) * 0.2
            col = mul(leaf, k)
            if tier < 0.22 and u < 0.4:
                col = mix(col, (0.95, 0.97, 1.0), 0.75)
            cv.put(x, y, col)


def paint_spire(cv, cx, cy, noise, rnd, color=(0.72, 0.42, 0.24)):
    """A sandstone needle: wide at the foot, pointed at the top, banded."""
    height, foot = rnd.uniform(24, 30), rnd.uniform(8, 10)
    shadow(cv, cx + 7, cy + 9, 13, 6, 0.5)
    base_y = cy + 10
    for y in range(int(base_y - height), int(base_y) + 1):
        t = (base_y - y) / height
        half = foot * max(0.0, 1 - t) ** 0.8 + 0.6
        for x in range(int(cx - half) - 1, int(cx + half) + 2):
            u = (x + 0.5 - cx) / half
            if abs(u) > 1:
                continue
            light = 0.95 - 0.5 * (u + 1) / 2
            band = 0.9 + 0.1 * math.sin(y * 0.9 + noise.at(x * 0.3, y * 0.3) * 4)
            k = light * band * (0.9 + noise.at(x * 0.6, y * 0.6) * 0.2)
            if abs(u) > 0.85:
                k *= 0.7
            cv.put(x, y, mul(color, k))


def paint_grave(cv, cx, cy, noise):
    shadow(cv, cx + 2, cy + 5, 6, 3, 0.5)
    stone = (0.55, 0.56, 0.6)
    for y in range(int(cy - 6), int(cy + 5)):
        for x in range(int(cx - 3), int(cx + 4)):
            top = cy - 6 + 2.5
            if y < top and (x + 0.5 - cx) ** 2 + (y - top) ** 2 > 3.6 ** 2:
                continue
            k = 1.0 if x < cx else 0.75
            k *= 0.9 + noise.at(x * 0.7, y * 0.7) * 0.2
            if x == int(cx - 3) or x == int(cx + 3):
                k *= 0.7
            cv.put(x, y, mul(stone, k))
    for x in range(int(cx - 1), int(cx + 2)):
        cv.shade(x, int(cy - 3), 0.6)


def paint_rock(cv, cx, cy, noise, rnd):
    shadow(cv, cx + 4, cy + 5, 11, 6)
    for dx, dy, r in [(-3, 1, 7), (4, 2, 5.5), (0, -2, 6)]:
        blob(cv, cx + dx, cy + dy, r, (0.5, 0.48, 0.45), noise, rim=0.6, gloss=0.7)


def paint_dead_tree(cv, cx, cy, noise, rnd):
    """A burnt stump with a few bare, charred branches."""
    shadow(cv, cx + 5, cy + 9, 11, 5, 0.6)
    bark, dark = (0.44, 0.4, 0.36), (0.22, 0.19, 0.17)

    def limb(x0, y0, ang, length, width):
        for i in range(int(length * 3)):
            t = i / 3.0
            x, y = x0 + math.cos(ang) * t, y0 - math.sin(ang) * t
            w = width * (1 - t / (length + 1))
            for dx in range(-int(w + 1), int(w + 2)):
                if abs(dx) <= w:
                    cv.put(int(x + dx), int(y), bark if dx <= 0 else dark)
    limb(cx, cy + 10, math.pi / 2, 22, 2.8)
    for k in range(4):
        y0 = cy + rnd.uniform(-9, 3)
        side = 1 if k % 2 else -1
        limb(cx, y0, math.pi / 2 - side * rnd.uniform(0.5, 1.0), rnd.uniform(7, 11), 1.2)
    for _ in range(5):
        x, y = int(cx + rnd.uniform(-2, 2)), int(cy + rnd.uniform(-10, 8))
        cv.put(x, y, (1.0, 0.45, 0.1))
        cv.put(x + 1, y, (0.9, 0.3, 0.05))


def paint_hay(cv, cx, cy, noise):
    """A round haystack, gold and lit from the top left, with a few loose strands."""
    shadow(cv, cx + 4, cy + 6, 10, 5, 0.5)
    blob(cv, cx, cy, 8.5, (0.86, 0.7, 0.32), noise, rim=0.62, gloss=0.55)
    for i in range(-6, 7, 3):
        for k in range(4):
            cv.shade(int(cx + i + k * 0.3), int(cy - 2 + k * 2), 0.8)


def paint_bones(cv, cx, cy, noise):
    """A bleached skull and a couple of scattered bones."""
    bone = (0.86, 0.82, 0.72)
    shadow(cv, cx + 2, cy + 3, 6, 3, 0.4)
    blob(cv, cx, cy, 3.6, bone, noise, rim=0.7, gloss=0.5)
    cv.put(int(cx - 1), int(cy), (0.15, 0.12, 0.1))
    cv.put(int(cx + 1), int(cy), (0.15, 0.12, 0.1))
    for x0, y0, dx, dy in ((cx + 6, cy + 4, 1, 0.35), (cx - 9, cy + 2, 1, -0.3)):
        for i in range(7):
            cv.put(int(x0 + dx * i), int(y0 + dy * i), mul(bone, 0.95 if i % 6 else 1.05))


def paint_lair(cv, cx, cy, noise, theme):
    rock = (0.32, 0.3, 0.32) if theme in ("duskwood", "plaguelands", "blackrock") else (0.42, 0.36, 0.3)
    shadow(cv, cx + 3, cy + 6, 16, 8)
    for dx, dy, r in [(-8, 2, 9), (8, 2, 9), (0, -4, 11)]:
        blob(cv, cx + dx, cy + dy, r, rock, noise, rim=0.6, gloss=0.7)
    for y in range(int(cy - 6), int(cy + 9)):
        for x in range(int(cx - 9), int(cx + 10)):
            d = ((x + 0.5 - cx) / 8) ** 2 + ((y + 0.5 - cy - 4) / 9) ** 2
            if d < 1 and y < cy + 8:
                glow = clamp(1 - d) * 0.35
                cv.put(x, y, (0.04 + glow * 0.25, 0.03 + glow * 0.08, 0.06 + glow * 0.2))


def paint_keep(cv, ox, oy):
    """Stryguard keep in one 30x30 square: a wall, two towers and a banner."""
    stone, dark, roof, red = (0.66, 0.64, 0.6), (0.4, 0.38, 0.36), (0.32, 0.2, 0.25), (0.62, 0.1, 0.1)
    shadow(cv, ox + 17, oy + 27, 15, 4, 0.55)

    def rect(x0, y0, x1, y1, col, lit=True):
        for y in range(y0, y1):
            for x in range(x0, x1):
                k = 1.0
                if lit and x == x1 - 1:
                    k = 0.72
                if lit and y == y0:
                    k = 1.12
                cv.put(ox + x, oy + y, mul(col, k))

    rect(5, 15, 25, 27, stone)
    for x in range(5, 25, 4):
        rect(x, 13, x + 2, 15, stone)
    rect(12, 20, 18, 27, (0.18, 0.12, 0.1), lit=False)
    for x0 in (2, 22):
        rect(x0, 9, x0 + 6, 27, stone)
        for x in range(x0, x0 + 6, 2):
            rect(x, 7, x + 1, 9, stone)
        rect(x0 + 2, 13, x0 + 4, 16, (0.15, 0.1, 0.1), lit=False)
    for y in range(0, 7):
        for x in range(4, 6):
            cv.put(ox + x, oy + y + 1, dark)
    for y in range(1, 5):
        for x in range(6, 6 + 7 - y // 2):
            cv.put(ox + x, oy + y, red if (x + y) % 5 else mul(red, 1.2))
    for x in range(5, 25):
        cv.shade(ox + x, oy + 26, 0.75)
    _ = roof


def paint_map(key, rows, theme_name):
    theme = THEMES[theme_name]
    rnd = random.Random(key)
    big, fine, hue, rough = Noise(zlib.crc32(key.encode()) & 0xFFFF), Noise(7), Noise(11), Noise(23)
    grid, pts = road_points(rows)
    segs = [(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1]) for i in range(len(pts) - 1)]
    water = [(c, r) for (c, r), ch in grid.items() if ch == "~"]
    cv = Canvas()

    # Ground and road.
    for y in range(H):
        for x in range(W):
            n = big.fbm(x / 70, y / 70)
            g = mix(theme["grass"], theme["grass2"], clamp(hue.fbm(x / 110 + 9, y / 110) * 1.6 - 0.4))
            g = mul(g, 0.82 + n * 0.36 + (fine.at(x * 0.9, y * 0.9) - 0.5) * 0.09)
            if theme.get("furrows") and hue.fbm(x / 90 + 3, y / 90 + 7) > 0.52:
                g = mul(g, 0.94 + 0.08 * math.sin(y * 0.75 + x * 0.04))
            if theme.get("cracks"):
                crack = abs(rough.fbm(x / 18, y / 18) - 0.5)
                if crack < (0.0025 if theme.get("glow") else 0.006):
                    g = mix(g, (0.95, 0.38, 0.08), 0.6) if theme.get("glow") else mul(g, 0.86)
            if theme.get("mist"):
                m = clamp(big.fbm(x / 60 + 40, y / 45) * 1.8 - 0.75)
                g = mix(g, (0.45, 0.5, 0.58), m * 0.35)
            d = seg_dist(x + 0.5, y + 0.5, segs)
            w = 10.5 + (rough.at(x / 9, y / 9) - 0.5) * 3.5
            if d < w:
                r = mul(theme["road"], 0.88 + rough.fbm(x / 12, y / 12) * 0.22 + (fine.at(x * 1.3, y * 1.3) - 0.5) * 0.1)
                if abs(d - 4.5) < 1.2:
                    r = mul(r, 0.9)
                if d > w - 1.6:
                    r = mul(r, 0.82)
                g = r
            elif d < w + 3.5:
                g = mul(g, 0.72 + 0.28 * (d - w) / 3.5)
            cv.px[y][x] = g

    # Water (or bog, or lava): the union of the ~ squares, rounded off, with a shore.
    liq = LIQUIDS[theme["liquid"]]
    for y in range(H):
        near = [(c, r) for c, r in water if abs(y - (r + 0.5) * CELL) < 3 * CELL]
        if not near:
            continue
        for x in range(W):
            field = 0.0
            for c, r in near:
                dx = (x - (c + 0.5) * CELL) / 17
                if -4 < dx < 4:
                    dy = (y - (r + 0.5) * CELL) / 15
                    field += math.exp(-(dx * dx + dy * dy))
            field += (rough.at(x / 7, y / 7) - 0.5) * liq["rough"] + (big.at(x / 25, y / 25) - 0.5) * liq["rough"]
            if field > 0.55:
                depth = clamp((field - 0.55) / 0.9)
                col = mix(liq["shallow"], liq["deep"], depth)
                wave = math.sin((y + fine.at(x / 9, y / 4) * 5) * 0.9)
                if wave > 0.97 and 0.15 < depth:
                    col = mix(col, liq["foam"], 0.35)
                cv.px[y][x] = col
            elif field > 0.42:
                cv.px[y][x] = mix(cv.px[y][x], liq["shore"], (field - 0.42) / 0.13)
            elif field > 0.25 and theme["liquid"] == "lava":
                cv.px[y][x] = mix(cv.px[y][x], (0.55, 0.16, 0.05), (field - 0.25) / 0.17 * 0.5)

    for c, r in (water if theme["pads"] else []):
        for _ in range(2):
            if rnd.random() > liq["pads"]:
                continue
            px, py = (c + 0.5) * CELL + rnd.uniform(-9, 9), (r + 0.5) * CELL + rnd.uniform(-8, 8)
            for y in range(int(py - 3), int(py + 4)):
                for x in range(int(px - 3), int(px + 4)):
                    dx, dy = x - px, y - py
                    if dx * dx + dy * dy < 9 and not (dx > 0 and abs(dy) < 0.8):
                        cv.put(x, y, (0.3, 0.55, 0.22) if dx < 1 else (0.22, 0.42, 0.17))

    # Grass tufts and flowers on open ground, away from the road.
    for _ in range(int(W * H * theme["tuft"])):
        x, y = rnd.randrange(W), rnd.randrange(H)
        if seg_dist(x, y, segs) < 15 or grid.get((x // CELL, y // CELL)) == "~":
            continue
        for i in range(3):
            tx = x + i - 1
            ln = rnd.randint(2, 4)
            for k in range(ln):
                cv.shade(tx + (k if i == 2 else -k if i == 0 else 0) // 3, y - k, 0.75 if k < ln - 1 else 1.25)
    for _ in range(int(W * H * theme["flower_rate"])):
        x, y = rnd.randrange(W), rnd.randrange(H)
        if seg_dist(x, y, segs) < 15 or grid.get((x // CELL, y // CELL)) == "~":
            continue
        col = rnd.choice(theme["flowers"])
        cv.put(x, y, col)
        cv.put(x + 1, y, mul(col, 0.85))
        cv.put(x, y + 1, mul(col, 0.8))

    # Pebbles on the road.
    for _ in range(int(W * H * 0.004)):
        x, y = rnd.randrange(W), rnd.randrange(H)
        if seg_dist(x, y, segs) < 8:
            cv.shade(x, y, rnd.choice((0.75, 1.2)))

    # A faint grid on open ground so squares are easy to pick.
    for (c, r), ch in grid.items():
        if ch != ".":
            continue
        for i in range(CELL):
            cv.shade(c * CELL + i, r * CELL, 0.93)
            cv.shade(c * CELL, r * CELL + i, 0.93)

    # Things that stand on the ground, drawn top to bottom so lower ones overlap.
    things = sorted(((r, c, ch) for (c, r), ch in grid.items() if ch in "TGRSE"), key=lambda t: (t[0], t[1]))
    for r, c, ch in things:
        cx, cy = (c + 0.5) * CELL + rnd.uniform(-2, 2), (r + 0.5) * CELL + rnd.uniform(-2, 2)
        if ch == "T":
            if theme["tree"] == "spire":
                paint_spire(cv, cx, cy, fine, rnd, theme.get("spire", (0.72, 0.42, 0.24)))
            elif theme["tree"] == "pine":
                paint_pine(cv, cx, cy, theme["leaf"], fine, rnd)
            elif theme["tree"] == "jungle":
                paint_tree(cv, cx, cy, theme["leaf"], fine, rnd, 1.15)
            elif theme["tree"] == "dead":
                paint_dead_tree(cv, cx, cy, fine, rnd)
            else:
                paint_tree(cv, cx, cy, theme["leaf"], fine, rnd)
        elif ch == "G":
            prop = {"grave": paint_grave, "hay": paint_hay, "bones": paint_bones}[theme["prop"]]
            prop(cv, cx - 5, cy - 2, fine)
            prop(cv, cx + 6, cy + 3, fine)
        elif ch == "R":
            paint_rock(cv, cx, cy, fine, rnd)
        elif ch == "S":
            paint_lair(cv, (c + 0.5) * CELL, (r + 0.5) * CELL, fine, theme_name)
        elif ch == "E":
            paint_keep(cv, c * CELL, r * CELL)

    # A soft vignette.
    for y in range(H):
        for x in range(W):
            dx, dy = (x - W / 2) / (W / 2), (y - H / 2) / (H / 2)
            cv.px[y][x] = mul(cv.px[y][x], 1 - 0.22 * clamp((dx * dx + dy * dy) - 0.35))
    return cv


def to_bytes(cv, out_w=OUT_W, out_h=OUT_H):
    """Scale the painting (box-filtered when shrinking a lot, bilinear otherwise) to 8-bit RGB rows."""
    px, sx, sy = cv.px, W / out_w, H / out_h
    if sx > 1.4:
        return shrink(cv, out_w, out_h)
    out = []
    for oy in range(out_h):
        fy = min(H - 1.0, max(0.0, (oy + 0.5) * sy - 0.5))
        y0 = int(fy)
        y1, ty = min(H - 1, y0 + 1), fy - y0
        row = []
        for ox in range(out_w):
            fx = min(W - 1.0, max(0.0, (ox + 0.5) * sx - 0.5))
            x0 = int(fx)
            x1, tx = min(W - 1, x0 + 1), fx - x0
            a, b, c, d = px[y0][x0], px[y0][x1], px[y1][x0], px[y1][x1]
            row.append(tuple(int(clamp((a[i] * (1 - tx) + b[i] * tx) * (1 - ty) + (c[i] * (1 - tx) + d[i] * tx) * ty) * 255 + 0.5)
                             for i in range(3)))
        out.append(row)
    return out


def shrink(cv, out_w, out_h):
    """Average each output pixel's footprint in the painting, so small atlas maps stay smooth."""
    px, sx, sy = cv.px, W / out_w, H / out_h
    out = []
    for oy in range(out_h):
        y0 = int(oy * sy)
        y1 = min(H, max(y0 + 1, int((oy + 1) * sy)))
        row = []
        for ox in range(out_w):
            x0 = int(ox * sx)
            x1 = min(W, max(x0 + 1, int((ox + 1) * sx)))
            r = g = b = 0.0
            for y in range(y0, y1):
                line = px[y]
                for x in range(x0, x1):
                    c = line[x]
                    r, g, b = r + c[0], g + c[1], b + c[2]
            n = (y1 - y0) * (x1 - x0)
            row.append(tuple(int(clamp(v / n) * 255 + 0.5) for v in (r, g, b)))
        out.append(row)
    return out


def write_atlas(path, slots):
    """Four small maps in a 1024x512 TGA, each in its 512x256 corner, edges repeated so
    the picture doesn't bleed into its neighbour when WoW filters it."""
    tex = [[(0, 0, 0)] * TEX_W for _ in range(TEX_H)]
    for slot, rgb in slots.items():
        ox, oy = (slot % 2) * SLOT_W, (slot // 2) * SLOT_H
        for y in range(SLOT_H):
            src = rgb[min(y, AT_H - 1)]
            line = tex[oy + y]
            for x in range(SLOT_W):
                line[ox + x] = src[min(x, AT_W - 1)]
    write_tga(path, tex, TEX_W, TEX_H)


def write_tga(path, rgb, out_w=OUT_W, out_h=OUT_H):
    # 32-bit uncompressed, bottom-left origin, BGRA: the format WoW reads.
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, TEX_W, TEX_H, 32, 8)
    blank = bytes(4 * TEX_W)
    with open(path, "wb") as fh:
        fh.write(header)
        for y in range(TEX_H - 1, -1, -1):
            if y >= out_h:
                fh.write(blank)
                continue
            row = bytearray()
            for r, g, b in rgb[y]:
                row += bytes((b, g, r, 255))
            row += bytes(4 * (TEX_W - out_w))
            fh.write(row)


def write_png(path, rgb):
    out_w, out_h = len(rgb[0]), len(rgb)
    raw = b"".join(b"\x00" + bytes(v for px in row for v in px) for row in rgb)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    with open(path, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", out_w, out_h, 8, 2, 0, 0, 0))
                 + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def main():
    args = sys.argv[1:]
    png_dir = None
    if "--png" in args:
        i = args.index("--png")
        png_dir = args[i + 1]
        del args[i:i + 2]
    media = os.path.join(ADDON, "media")
    os.makedirs(media, exist_ok=True)
    maps = read_maps()
    wanted = {art for key, theme, art, slot, rows in maps if slot is not None and (not args or key in args or art in args)}
    atlases = {}
    for key, theme, art, slot, rows in maps:
        if slot is None:
            if args and key not in args:
                continue
            rgb = to_bytes(paint_map(key, rows, theme))
            write_tga(os.path.join(media, key + ".tga"), rgb)
        else:
            if art not in wanted:
                continue
            rgb = to_bytes(paint_map(key, rows, theme), AT_W, AT_H)
            atlases.setdefault(art, {})[slot] = rgb
        if png_dir:
            write_png(os.path.join(png_dir, key + ".png"), rgb)
        print("painted", key, flush=True)
    for art, slots in atlases.items():
        write_atlas(os.path.join(media, art + ".tga"), slots)
        print("wrote", art, flush=True)


if __name__ == "__main__":
    main()
