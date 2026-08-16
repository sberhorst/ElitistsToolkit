"""
Generate the Elitist's Toolkit project icon.

    python art/make_icon.py

Writes art/icon-400.png (CurseForge project avatar) plus 256/128/64 variants.

Design notes -- the constraint that drives everything here is that CurseForge
renders project avatars at roughly 64px in list views. Anything with fine
detail, thin strokes, or text turns to mush at that size. So the mark is a
single silhouette (a crest) carrying a single high-contrast focal point (an
epic-purple gem), which is what the addon is actually about: gear quality,
gems and enchants. No lettering, no numbers, no thin lines.

Everything is drawn at 4x and downsampled with LANCZOS, because Pillow's
draw primitives are not anti-aliased -- drawing straight at 400px gives
visibly jagged diagonals on the crest edges.
"""

import os
import math
from PIL import Image, ImageDraw, ImageFilter

OUT_DIR = os.path.dirname(os.path.abspath(__file__))
SIZE = 400
SS = 4                      # supersample factor
S = SIZE * SS

# Palette. Purple is Blizzard's own epic-quality colour (a335ee) so the mark
# reads as "gear quality" to anyone who plays the game.
BG_TOP      = (26, 22, 36)
BG_BOTTOM   = (11, 9, 16)
GOLD_LIGHT  = (240, 208, 122)
GOLD        = (201, 162, 62)
GOLD_DARK   = (138, 105, 34)
CREST_FILL  = (32, 25, 45)
EPIC        = (163, 53, 238)
EPIC_LIGHT  = (216, 166, 255)
EPIC_DARK   = (96, 26, 150)


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def quad_bezier(p0, p1, p2, steps=120):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        pts.append((
            u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
            u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1],
        ))
    return pts


def crest_polygon(cx, cy, w, h):
    """A heater-shield crest: flat shouldered top, curved flanks, point at
    the bottom. Built as an explicit polygon so it scales cleanly."""
    half = w / 2
    top = cy - h / 2
    bot = cy + h / 2
    shoulder = top + h * 0.10

    pts = [(cx - half, shoulder)]
    # top edge with a slight arch so it doesn't read as a plain box
    pts += quad_bezier((cx - half, shoulder), (cx, top - h * 0.03),
                       (cx + half, shoulder), 60)
    # right flank sweeping to the point
    pts += quad_bezier((cx + half, shoulder), (cx + half * 0.98, cy + h * 0.18),
                       (cx, bot), 80)
    # left flank back up
    pts += quad_bezier((cx, bot), (cx - half * 0.98, cy + h * 0.18),
                       (cx - half, shoulder), 80)
    return pts


def gem_polygon(cx, cy, r, sides=6, rotate=-math.pi / 2):
    """Hexagon, slightly taller than wide. rotate=-pi/2 puts vertex 0 at the
    TOP -- screen y grows downward, so +pi/2 would put it at the bottom and
    silently invert every facet's shading relative to the highlight."""
    return [
        (cx + r * math.cos(rotate + i * 2 * math.pi / sides),
         cy + r * math.sin(rotate + i * 2 * math.pi / sides) * 1.12)
        for i in range(sides)
    ]


def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1],
                                        radius=radius, fill=255)
    return m


def build():
    img = Image.new("RGB", (S, S), BG_BOTTOM)
    d = ImageDraw.Draw(img)

    # --- background: vertical gradient, drawn scanline by scanline ---
    for y in range(S):
        d.line([(0, y), (S, y)], fill=lerp(BG_TOP, BG_BOTTOM, y / S))

    # --- soft purple glow behind the crest, so the gem reads even at 64px ---
    glow = Image.new("RGB", (S, S), (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([S * 0.24, S * 0.20, S * 0.76, S * 0.80], fill=(70, 22, 110))
    glow = glow.filter(ImageFilter.GaussianBlur(S * 0.10))
    img = Image.blend(img, Image.blend(img, glow, 0.55), 0.75)
    d = ImageDraw.Draw(img)

    cx, cy = S / 2, S * 0.505
    crest_w, crest_h = S * 0.60, S * 0.68

    # --- crest: gold rim drawn as successive insets, giving a bevel ---
    for i, (inset, col) in enumerate((
        (0.000, GOLD_DARK),
        (0.018, GOLD),
        (0.034, GOLD_LIGHT),
        (0.052, GOLD),
        (0.075, CREST_FILL),
    )):
        d.polygon(
            crest_polygon(cx, cy, crest_w * (1 - inset * 2.6),
                          crest_h * (1 - inset * 2.2)),
            fill=col,
        )

    # --- gem ---
    gr = S * 0.146
    gy = cy - S * 0.022
    d.polygon(gem_polygon(cx, gy, gr * 1.15), fill=EPIC_DARK)   # rim
    d.polygon(gem_polygon(cx, gy, gr), fill=EPIC)

    # Six facets, lit consistently from the upper left so the specular
    # highlight below sits on the brightest face rather than fighting it.
    hexa = gem_polygon(cx, gy, gr)
    top_v, ur, lr, bot_v, ll, ul = hexa
    ctr = (cx, gy)
    for tri, col in (
        ((top_v, ul, ctr), EPIC_LIGHT),
        ((top_v, ur, ctr), lerp(EPIC, EPIC_LIGHT, 0.50)),
        ((ul, ll, ctr),    lerp(EPIC, EPIC_LIGHT, 0.18)),
        ((ur, lr, ctr),    lerp(EPIC, EPIC_DARK, 0.30)),
        ((ll, bot_v, ctr), lerp(EPIC, EPIC_DARK, 0.50)),
        ((lr, bot_v, ctr), EPIC_DARK),
    ):
        d.polygon(list(tri), fill=col)

    # specular highlight
    d.polygon([
        (cx - gr * 0.34, gy - gr * 0.52),
        (cx - gr * 0.05, gy - gr * 0.80),
        (cx - gr * 0.12, gy - gr * 0.34),
        (cx - gr * 0.40, gy - gr * 0.16),
    ], fill=(240, 220, 255))

    # --- outer frame ---
    pad = S * 0.035
    d.rounded_rectangle([pad, pad, S - pad, S - pad],
                        radius=S * 0.115, outline=GOLD, width=int(S * 0.014))
    d.rounded_rectangle([pad * 1.7, pad * 1.7, S - pad * 1.7, S - pad * 1.7],
                        radius=S * 0.095, outline=(72, 58, 30),
                        width=int(S * 0.005))

    # --- downsample, then round the corners ---
    icon = img.resize((SIZE, SIZE), Image.LANCZOS)
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.paste(icon, (0, 0), rounded_mask(SIZE, int(SIZE * 0.16)))
    return out


def main():
    icon = build()
    paths = []
    for px in (400, 256, 128, 64):
        p = os.path.join(OUT_DIR, f"icon-{px}.png")
        (icon if px == SIZE else icon.resize((px, px), Image.LANCZOS)).save(p)
        paths.append(p)
        print(f"  {os.path.basename(p)}  {px}x{px}")
    print(f"\nWrote {len(paths)} file(s) to {OUT_DIR}")
    print("CurseForge project avatar: icon-400.png")


if __name__ == "__main__":
    main()
