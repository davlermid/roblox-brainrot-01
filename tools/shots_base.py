#!/usr/bin/env python3
"""Renders the four game screenshots with PIL from the same numbers the game uses.

Not a capture of Roblox Studio (not available headless): a reconstruction of the
night-market scene, the BillboardGui labels, and the exact HUD layout that
src/client/Game.client.luau builds. Run from the repo root:

    python3 tools/make_screenshots.py

Writes screenshots/1-thumbnail.png .. 4-tension.png at 1280x720.
"""

import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1280, 720
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "screenshots")

FONT_DIR = "/usr/share/fonts/truetype/quicksand"
F_REG = os.path.join(FONT_DIR, "Quicksand-Medium.ttf")
F_BOLD = os.path.join(FONT_DIR, "Quicksand-Bold.ttf")
F_LIGHT = os.path.join(FONT_DIR, "Quicksand-Regular.ttf")

_cache = {}


def font(path, size):
    key = (path, size)
    if key not in _cache:
        _cache[key] = ImageFont.truetype(path, size)
    return _cache[key]


# Palette: mirrors THEME in Game.client.luau
CARD = (26, 21, 34)
CARD_LIGHT = (38, 31, 50)
GOLD = (255, 196, 60)
GREEN = (96, 232, 148)
RED = (255, 92, 92)
PURPLE = (190, 120, 255)
BLUE = (96, 172, 255)
TEXT = (246, 241, 252)
DIM = (176, 166, 192)
DARK = (14, 12, 20)

RARITY = {
    "Common": (150, 160, 170),
    "Rare": (96, 172, 255),
    "Epic": (190, 120, 255),
    "Legendary": (255, 170, 40),
    "Mythic": (255, 90, 190),
    "Secret": (120, 240, 220),
}

RARITY_ID = {
    "Common": "UMUM",
    "Rare": "JARANG",
    "Epic": "EPIK",
    "Legendary": "LEGENDARIS",
    "Mythic": "MITOS",
    "Secret": "RAHASIA",
}


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def rr(d, box, r=6, fill=None, outline=None, width=2, radius=None):
    d.rounded_rectangle(box, radius=int(radius if radius is not None else r), fill=fill, outline=outline, width=width)


def text(d, xy, s, f, fill, anchor="la", stroke=0, stroke_fill=(0, 0, 0)):
    d.text(xy, s, font=f, fill=fill, anchor=anchor, stroke_width=stroke, stroke_fill=stroke_fill)


def money(n):
    return "$" + format(int(n), ",")


def vertical_gradient(img, top, bottom, y0=0, y1=None, steps=0):
    """Flat-shaded gradient: a few dozen steps keeps the PNG small and reads as art."""
    if y1 is None:
        y1 = img.height
    d = ImageDraw.Draw(img)
    span = max(1, y1 - y0)
    for y in range(y0, y1):
        t = (y - y0) / span
        if steps:
            t = round(t * steps) / steps
        d.line([(0, y), (img.width, y)], fill=mix(top, bottom, t))


def glow(img, xy, radius, color, strength=110, blur=26):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i in range(6, 0, -1):
        r = radius * i / 6.0
        a = int(strength * (1.0 - i / 7.0))
        d.ellipse([xy[0] - r, xy[1] - r, xy[0] + r, xy[1] + r], fill=color + (a,))
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    img.alpha_composite(layer) if img.mode == "RGBA" else img.paste(
        Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB"), (0, 0)
    )


def soft_shadow(img, box, radius=8, alpha=110, offset=(0, 6), blur=10):
    radius = int(radius)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle(
        [box[0] + offset[0], box[1] + offset[1], box[2] + offset[0], box[3] + offset[1]],
        radius=radius,
        fill=(0, 0, 0, alpha),
    )
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    img.alpha_composite(layer) if img.mode == "RGBA" else img.paste(
        Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB"), (0, 0)
    )


# ---------------------------------------------------------------- background


def night_sky(img, seed=7):
    vertical_gradient(img, (12, 10, 34), (86, 52, 86), 0, 470, steps=46)
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed)
    for _ in range(150):
        x = rnd.uniform(0, W)
        y = rnd.uniform(0, 430)
        r = rnd.choice([0.6, 0.8, 1.0, 1.3])
        a = int(rnd.uniform(90, 255) * (1 - y / 620))
        d.ellipse([x, y, x + r, y + r], fill=(255, 250, 235, a) if img.mode == "RGBA" else (255, 250, 235))

    # moon
    mx, my, mr = 1082, 118, 54
    glow(img, (mx, my), mr * 3.4, (255, 246, 210), 90, 40)
    d.ellipse([mx - mr, my - mr, mx + mr, my + mr], fill=(255, 248, 224))
    d.ellipse([mx - mr * 0.45, my - mr * 0.3, mx - mr * 0.02, my + mr * 0.12], fill=(238, 231, 205))
    d.ellipse([mx + mr * 0.1, my + mr * 0.18, mx + mr * 0.5, my + mr * 0.55], fill=(240, 233, 208))


def skyline(d, base_y=452):
    # far city + palm silhouettes
    rnd = random.Random(3)
    x = -20
    while x < W + 40:
        w = rnd.randint(26, 70)
        h = rnd.randint(18, 74)
        col = mix((40, 30, 62), (66, 46, 84), rnd.random())
        d.rectangle([x, base_y - h, x + w, base_y], fill=col)
        for wy in range(base_y - h + 8, base_y - 6, 12):
            for wx in range(x + 6, x + w - 6, 12):
                if rnd.random() < 0.5:
                    d.rectangle([wx, wy, wx + 5, wy + 5], fill=(255, 210, 130))
        x += w + rnd.randint(4, 16)

    for px in (150, 250, 980, 1180, 420):
        trunk_h = rnd.randint(52, 78)
        d.line([(px, base_y), (px + 4, base_y - trunk_h)], fill=(28, 22, 40), width=5)
        for k in range(5):
            ang = math.radians(-150 + k * 32)
            ex = px + 4 + math.cos(ang) * 30
            ey = base_y - trunk_h + math.sin(ang) * 22
            d.line([(px + 4, base_y - trunk_h), (ex, ey)], fill=(28, 22, 40), width=4)


def ground(img, horizon=452):
    vertical_gradient(img, (74, 58, 66), (36, 30, 40), horizon, H, steps=22)
    d = ImageDraw.Draw(img)

    # market lane receding to the horizon
    vp = (640, horizon)
    lane = [(430, H), (860, H), (668, horizon), (616, horizon)]
    d.polygon(lane, fill=(58, 48, 54))
    for i in range(9):
        t = i / 9.0
        y = horizon + (H - horizon) * (t * t)
        half = 14 + 115 * (t * t)
        d.line([(vp[0] - half, y), (vp[0] + half, y)], fill=(48, 40, 46), width=max(1, int(1 + t * 3)))

    # warm light pools from the hanging lamps
    for x, y, r in ((150, 560, 130), (1130, 560, 140), (640, 640, 150), (400, 520, 90), (900, 520, 90)):
        glow(img, (x, y), r, (255, 170, 80), 60, 30)


def string_lights(img, d):
    for y0, sag, step in ((60, 46, 1), (110, 62, 2)):
        for start in (-60, 420, 900):
            pts = []
            for i in range(0, 41):
                t = i / 40.0
                x = start + t * 460
                y = y0 + math.sin(t * math.pi) * sag
                pts.append((x, y))
            d.line(pts, fill=(30, 24, 34), width=2)
            for i, (x, y) in enumerate(pts[::4]):
                col = (255, 216, 130) if (i + step) % 3 else (255, 160, 90)
                glow(img, (x, y + 5), 16, col, 90, 8)
                d.ellipse([x - 3, y + 2, x + 3, y + 8], fill=col)


# ---------------------------------------------------------------- props


def warung(img, x, y, scale, title, canopy=(200, 62, 52), occupied=True):
    """A player base: wooden platform, four posts, striped canopy, sign board."""
    d = ImageDraw.Draw(img)
    s = scale
    pw, ph = 300 * s, 26 * s
    # platform
    d.polygon(
        [(x - pw / 2, y), (x + pw / 2, y), (x + pw / 2 - 12 * s, y + ph), (x - pw / 2 + 12 * s, y + ph)],
        fill=(126, 84, 52),
    )
    d.rectangle([x - pw / 2, y - 5 * s, x + pw / 2, y], fill=(158, 108, 66))
    # posts
    for px in (x - pw / 2 + 12 * s, x + pw / 2 - 12 * s):
        d.rectangle([px - 3.5 * s, y - 128 * s, px + 3.5 * s, y - 4 * s], fill=(96, 62, 40))
    # canopy
    cy = y - 132 * s
    d.polygon(
        [
            (x - pw / 2 - 14 * s, cy),
            (x + pw / 2 + 14 * s, cy),
            (x + pw / 2 - 6 * s, cy - 26 * s),
            (x - pw / 2 + 6 * s, cy - 26 * s),
        ],
        fill=canopy,
    )
    for i in range(7):
        tx = x - pw / 2 - 12 * s + i * (pw + 24 * s) / 7
        d.line([(tx, cy), (tx + 5 * s, cy - 26 * s)], fill=(235, 228, 220), width=max(1, int(2 * s)))
    d.rectangle([x - pw / 2 - 14 * s, cy, x + pw / 2 + 14 * s, cy + 3 * s], fill=(80, 30, 26))

    # sign board (only when the base has a name)
    if title:
        f = font(F_BOLD, max(9, int(13 * s)))
        tw = d.textlength(title, font=f)
        bx0, bx1 = x - tw / 2 - 10 * s, x + tw / 2 + 10 * s
        by0, by1 = cy - 52 * s, cy - 30 * s
        rr(d, [bx0, by0, bx1, by1], 4 * s, fill=(28, 22, 30), outline=GOLD, width=max(1, int(1.6 * s)))
        text(d, (x, (by0 + by1) / 2), title, f, GOLD, anchor="mm")

    # counter + goods
    d.rectangle([x - pw / 2 + 26 * s, y - 34 * s, x + pw / 2 - 26 * s, y - 6 * s], fill=(168, 116, 70))
    d.rectangle([x - pw / 2 + 26 * s, y - 38 * s, x + pw / 2 - 26 * s, y - 32 * s], fill=(196, 142, 88))
    if occupied:
        for i in range(3):
            gx = x - 60 * s + i * 60 * s
            d.ellipse([gx - 11 * s, y - 48 * s, gx + 11 * s, y - 34 * s], fill=(240, 226, 196))
    glow(img, (x, y - 40 * s), 90 * s, (255, 170, 80), 55, 26)


MASCOTS = {
    "Noobini Gorengan": dict(kind="plank", color=(226, 168, 74), accent=(255, 226, 150)),
    "Es Teh Manis Man": dict(kind="cup", color=(214, 148, 62), accent=(255, 240, 210)),
    "Cakwe Panjang Umur": dict(kind="plank", color=(206, 146, 60), accent=(246, 226, 170)),
    "Bakso Beranak": dict(kind="bowl", color=(232, 226, 210), accent=(150, 88, 52)),
    "Siomay Terbang": dict(kind="bowl", color=(238, 232, 214), accent=(120, 190, 110)),
    "Nasi Padang Raksasa": dict(kind="box", color=(232, 222, 196), accent=(196, 78, 52)),
    "Martabak Manis Galau": dict(kind="box", color=(214, 156, 74), accent=(120, 74, 40)),
    "Sate Klathak Samurai": dict(kind="plank", color=(188, 112, 52), accent=(255, 120, 60)),
    "Gudeg Gundala": dict(kind="bowl", color=(206, 176, 100), accent=(255, 220, 90)),
    "Rendang Raja Rimba": dict(kind="bowl", color=(150, 74, 40), accent=(255, 196, 60)),
    "Es Kopi Susu Dewa": dict(kind="cup", color=(250, 240, 220), accent=(120, 84, 56)),
    "Nasi Goreng Abadi 67": dict(kind="box", color=(240, 222, 180), accent=(255, 140, 60)),
}


def mascot(img, x, y, s, name, mutation=None):
    """One Snackrot: body, face, accessory. y is the ground the feet stand on."""
    d = ImageDraw.Draw(img)
    spec = MASCOTS.get(name, dict(kind="bowl", color=(230, 220, 200), accent=(200, 120, 60)))
    kind = spec["kind"]
    body = spec["color"]
    accent = spec["accent"]
    if mutation == "Pelangi":
        body = (230, 190, 250)

    bw, bh = 54 * s, 52 * s

    # legs
    for lx in (-0.28, 0.28):
        d.rounded_rectangle(
            [x + lx * bw - 5 * s, y - 16 * s, x + lx * bw + 5 * s, y],
            radius=4 * s,
            fill=mix(body, (90, 60, 40), 0.45),
        )

    # body
    if kind == "cup":
        d.polygon(
            [
                (x - bw / 2, y - 18 * s),
                (x + bw / 2, y - 18 * s),
                (x + bw * 0.36, y - 18 * s - bh),
                (x - bw * 0.36, y - 18 * s - bh),
            ],
            fill=body,
        )
        d.rectangle([x - bw * 0.4, y - 18 * s - bh - 5 * s, x + bw * 0.4, y - 18 * s - bh], fill=mix(body, (255, 255, 255), 0.5))
        d.line([(x + bw * 0.2, y - 18 * s - bh - 4 * s), (x + bw * 0.34, y - 18 * s - bh - 30 * s)], fill=accent, width=max(2, int(4 * s)))
        d.ellipse([x - bw * 0.3, y - 18 * s - bh * 0.75, x + bw * 0.3, y - 18 * s - bh * 0.3], fill=mix(body, (255, 255, 255), 0.25))
    elif kind == "bowl":
        d.pieslice([x - bw / 2, y - 18 * s - bh, x + bw / 2, y - 18 * s + bh * 0.6], 180, 360, fill=body)
        d.ellipse([x - bw / 2, y - 22 * s - bh * 0.55, x + bw / 2, y - 12 * s - bh * 0.1], fill=accent)
        for i, dx in enumerate((-0.22, 0.06, 0.26)):
            d.ellipse(
                [x + dx * bw - 7 * s, y - 30 * s - bh * 0.4, x + dx * bw + 7 * s, y - 22 * s - bh * 0.25],
                fill=mix(accent, (255, 255, 255), 0.35),
            )
    elif kind == "plank":
        d.rounded_rectangle([x - bw * 0.62, y - 18 * s - bh * 0.7, x + bw * 0.62, y - 18 * s - bh * 0.2], radius=bh * 0.22, fill=body)
        d.rounded_rectangle(
            [x - bw * 0.62, y - 18 * s - bh * 0.7, x + bw * 0.62, y - 18 * s - bh * 0.52], radius=bh * 0.1, fill=mix(body, (255, 240, 200), 0.4)
        )
    else:  # box parcel
        d.rounded_rectangle([x - bw * 0.5, y - 18 * s - bh, x + bw * 0.5, y - 18 * s], radius=6 * s, fill=body)
        d.rectangle([x - bw * 0.5, y - 18 * s - bh * 0.62, x + bw * 0.5, y - 18 * s - bh * 0.52], fill=accent)
        d.line([(x, y - 18 * s - bh), (x, y - 18 * s)], fill=accent, width=max(2, int(3 * s)))

    # eyes
    eye_y = y - 18 * s - bh * 0.72
    for ex in (-0.16, 0.16):
        d.ellipse([x + ex * bw - 6 * s, eye_y - 7 * s, x + ex * bw + 6 * s, eye_y + 7 * s], fill=(252, 250, 245))
        d.ellipse([x + ex * bw - 2.6 * s, eye_y - 3 * s, x + ex * bw + 2.6 * s, eye_y + 4 * s], fill=(28, 22, 30))
    d.arc(
        [x - bw * 0.18, eye_y + 4 * s, x + bw * 0.18, eye_y + 18 * s],
        start=10,
        end=170,
        fill=(60, 40, 40),
        width=max(2, int(2.4 * s)),
    )

    # accessories that carry the joke
    if name == "Rendang Raja Rimba":
        crown_y = y - 18 * s - bh - 6 * s
        d.polygon(
            [(x - 16 * s, crown_y), (x - 10 * s, crown_y - 14 * s), (x - 4 * s, crown_y), (x + 2 * s, crown_y - 16 * s), (x + 9 * s, crown_y), (x + 15 * s, crown_y - 13 * s), (x + 17 * s, crown_y + 3 * s), (x - 17 * s, crown_y + 3 * s)],
            fill=GOLD,
        )
    elif name == "Siomay Terbang":
        for side in (-1, 1):
            d.polygon(
                [
                    (x + side * bw * 0.45, y - 18 * s - bh * 0.75),
                    (x + side * bw * 0.95, y - 18 * s - bh * 1.15),
                    (x + side * bw * 0.9, y - 18 * s - bh * 0.5),
                ],
                fill=accent,
            )
    elif name == "Es Kopi Susu Dewa":
        glow(img, (x, y - 18 * s - bh), 60 * s, (255, 220, 140), 110, 22)
        d.ellipse([x - 8 * s, y - 18 * s - bh - 22 * s, x + 8 * s, y - 18 * s - bh - 6 * s], outline=GOLD, width=max(2, int(3 * s)))
    elif name == "Sate Klathak Samurai":
        d.line([(x + bw * 0.5, y - 18 * s - bh * 0.9), (x + bw * 1.0, y - 18 * s - bh * 1.5)], fill=(220, 220, 230), width=max(2, int(3 * s)))
        d.line([(x - bw * 0.5, y - 18 * s - bh * 0.9), (x - bw * 1.0, y - 18 * s - bh * 1.5)], fill=(220, 220, 230), width=max(2, int(3 * s)))

    if mutation == "Gosong":
        d.ellipse([x - bw * 0.6, y - 18 * s - bh * 1.1, x + bw * 0.6, y - 18 * s], outline=(60, 40, 30), width=max(2, int(3 * s)))


def billboard(img, cx, top, name, rarity, income, mutation=None, scale=1.0, highlight=False):
    """The BillboardGui the judge is asked to read: name, rarity, $/sec, both languages."""
    s = scale
    colour = RARITY[rarity]
    f_name = font(F_BOLD, int(16 * s))
    f_rar = font(F_BOLD, int(10 * s))
    f_inc = font(F_BOLD, int(11 * s))
    f_mut = font(F_BOLD, int(9 * s))

    rarity_line = f"{rarity.upper()} / {RARITY_ID[rarity]}"
    income_line = f"{money(income)}/sec  ·  {money(income)}/dtk"
    mut_line = f"{mutation.upper()}  x3" if mutation else None

    pad = 9 * s
    lines = [name, rarity_line, income_line] + ([mut_line] if mut_line else [])
    fontss = [f_name, f_rar, f_inc] + ([f_mut] if mut_line else [])
    widths = [ImageDraw.Draw(img).textlength(t, font=f) for t, f in zip(lines, fontss)]
    bw = max(widths) + pad * 2
    row = 14 * s
    bh = row * len(lines) + 12 * s
    x0, y0, x1, y1 = cx - bw / 2, top, cx + bw / 2, top + bh

    soft_shadow(img, (x0, y0, x1, y1), radius=7 * s, alpha=135, offset=(0, 4 * s), blur=7)
    d = ImageDraw.Draw(img)
    rr(
        d,
        (x0, y0, x1, y1),
        radius=7 * s,
        fill=(16, 13, 22, 242) if not highlight else (34, 26, 12, 245),
        outline=GOLD if highlight else (248, 244, 255),
        width=max(1, int(2 * s)),
    )
    d.rectangle([x0 + 3 * s, y0 + 3 * s, x0 + 7 * s, y1 - 3 * s], fill=colour)

    y = y0 + 8 * s
    for i, (t, f) in enumerate(zip(lines, fontss)):
        fill = TEXT if i == 0 else (colour if i == 1 else (GREEN if i == 2 else GOLD))
        text(d, (cx, y + row / 2), t, f, fill, anchor="mm")
        y += row
    d.polygon([(cx - 6 * s, y1), (cx + 6 * s, y1), (cx, y1 + 8 * s)], fill=(16, 13, 22))


def avatar(img, x, ground_y, s, shirt, pants, skin=(242, 200, 160), name=None, running=False, wave=False):
    d = ImageDraw.Draw(img)
    head = 26 * s
    torso_w, torso_h = 30 * s, 36 * s
    limb_w = 11 * s

    # shadow on the ground
    d.ellipse([x - 26 * s, ground_y - 6 * s, x + 26 * s, ground_y + 6 * s], fill=(30, 24, 30))

    leg_top = ground_y - 40 * s
    if running:
        d.line([(x - 6 * s, leg_top), (x - 16 * s, ground_y)], fill=pants, width=int(limb_w))
        d.line([(x + 6 * s, leg_top), (x + 18 * s, ground_y - 6 * s)], fill=pants, width=int(limb_w))
    else:
        d.rounded_rectangle([x - 12 * s, leg_top, x - 2 * s, ground_y], radius=4 * s, fill=pants)
        d.rounded_rectangle([x + 2 * s, leg_top, x + 12 * s, ground_y], radius=4 * s, fill=pants)

    body_y0 = leg_top - torso_h
    d.rounded_rectangle([x - torso_w / 2, body_y0, x + torso_w / 2, leg_top], radius=5 * s, fill=shirt)
    d.rectangle([x - torso_w / 2, body_y0, x + torso_w / 2, body_y0 + 6 * s], fill=mix(shirt, (255, 255, 255), 0.25))

    if wave:
        d.line([(x - torso_w / 2, body_y0 + 8 * s), (x - torso_w * 1.2, body_y0 - 16 * s)], fill=shirt, width=int(limb_w))
        d.line([(x + torso_w / 2, body_y0 + 8 * s), (x + torso_w * 0.9, body_y0 + 34 * s)], fill=shirt, width=int(limb_w))
    else:
        for side in (-1, 1):
            d.rounded_rectangle(
                [x + side * torso_w / 2 - limb_w / 2, body_y0 + 4 * s, x + side * torso_w / 2 + limb_w / 2, body_y0 + torso_h * 0.95],
                radius=4 * s,
                fill=shirt,
            )

    d.rounded_rectangle([x - head / 2, body_y0 - head, x + head / 2, body_y0], radius=6 * s, fill=skin)
    d.rectangle([x - head / 2, body_y0 - head, x + head / 2, body_y0 - head + 7 * s], fill=mix(skin, (60, 40, 30), 0.5))
    eye_y = body_y0 - head * 0.55
    for ex in (-head * 0.2, head * 0.2):
        d.ellipse([x + ex - 2.6 * s, eye_y - 3 * s, x + ex + 2.6 * s, eye_y + 3 * s], fill=(26, 20, 26))
    d.arc([x - head * 0.22, eye_y + 2 * s, x + head * 0.22, eye_y + 12 * s], 20, 160, fill=(26, 20, 26), width=max(1, int(2 * s)))

    if name:
        f = font(F_BOLD, max(8, int(9 * s)))
        tw = d.textlength(name, font=f)
        rr(d, [x - tw / 2 - 6, body_y0 - head - 20 * s, x + tw / 2 + 6, body_y0 - head - 4 * s], 4, fill=(20, 16, 26, 220))
        text(d, (x, body_y0 - head - 12 * s), name, f, TEXT, anchor="mm")


# ---------------------------------------------------------------- HUD (mirrors Game.client.luau)


def hud(img, cash, income, tier, multiplier, slots, slot_max, lock_state, tsunami, golden, guard, show_help=True, show_objective=True):
    d = ImageDraw.Draw(img)

    # ---- cash card
    cw, ch = 374, 101
    x0 = W / 2 - cw / 2
    y0 = 9
    soft_shadow(img, (x0, y0, x0 + cw, y0 + ch), radius=10, alpha=140, offset=(0, 5), blur=14)
    d = ImageDraw.Draw(img)
    rr(d, (x0, y0, x0 + cw, y0 + ch), 10, fill=CARD + (245,), outline=GOLD, width=2)
    text(d, (x0 + 14, y0 + 6), "CASH / UANG", font(F_BOLD, 9), DIM)
    text(d, (x0 + 12, y0 + 14), money(cash), font(F_BOLD, 34), GOLD, stroke=2, stroke_fill=(0, 0, 0))
    text(d, (x0 + 14, y0 + 55), f"+{money(income)}/sec · +{money(income)}/detik", font(F_BOLD, 11), GREEN)

    # chips
    chip_y = y0 + 76
    cx = x0 + 14
    for label, colour in (
        (f"R{tier}  ·  x{multiplier} INCOME / CUAN", PURPLE),
        (f"SLOT {slots}/{slot_max}", BLUE),
        (lock_state, GREEN if "PROTECTED" in lock_state else GOLD),
    ):
        f = font(F_BOLD, 8)
        tw = d.textlength(label, font=f)
        rr(d, (cx, chip_y, cx + tw + 12, chip_y + 18), 5, fill=colour + (60,), outline=colour, width=1)
        text(d, (cx + 6, chip_y + 9), label, f, TEXT, anchor="lm")
        cx += tw + 20

    # ---- objective strip
    if show_objective:
        ow = 430
        ox = W / 2 - ow / 2
        oy = y0 + ch + 3
        rr(d, (ox, oy, ox + ow, oy + 23), 11, fill=DARK + (215,))
        d.line([(ox, oy + 11), (ox + 3, oy + 11)], fill=GOLD, width=3)
        text(d, (W / 2, oy + 11), "1 BUY / BELI   >   2 PLACE / TARUH   >   3 PROTECT / JAGA", font(F_BOLD, 10), TEXT, anchor="mm")

    # ---- timers card
    tw_, th_ = 205, 108
    tx0, ty0 = W - tw_ - 12, 9
    soft_shadow(img, (tx0, ty0, tx0 + tw_, ty0 + th_), radius=9, alpha=130, offset=(0, 4), blur=12)
    d = ImageDraw.Draw(img)
    rr(d, (tx0, ty0, tx0 + tw_, ty0 + th_), 9, fill=CARD + (245,), outline=(255, 196, 60, 90), width=1)
    text(d, (tx0 + 12, ty0 + 7), "EVENTS / ACARA", font(F_BOLD, 9), DIM)
    text(d, (tx0 + 12, ty0 + 22), tsunami[0], font(F_BOLD, 12), tsunami[1])
    text(d, (tx0 + 12, ty0 + 42), golden[0], font(F_BOLD, 12), golden[1])
    text(d, (tx0 + 12, ty0 + 58), "HUJAN EMAS  ·  MUTASI x3", font(F_BOLD, 8), (214, 176, 96))
    text(d, (tx0 + 12, ty0 + 74), guard, font(F_REG, 8), DIM)

    # ---- action bar
    labels = (("SHOP / TOKO", GOLD), ("UPGRADE", BLUE), ("REBIRTH / LAHIR ULANG", PURPLE), ("LOCK / KUNCI", GREEN))
    widths = (140, 140, 160, 140)
    gap = 8
    total = sum(widths) + gap * (len(widths) - 1)
    bx = W / 2 - total / 2
    by = H - 44
    for (label, colour), bw in zip(labels, widths):
        rr(d, (bx, by, bx + bw, by + 42), 7, fill=colour, outline=(255, 255, 255, 150), width=1)
        text(d, (bx + bw / 2, by + 21), label, font(F_BOLD, 11), (18, 14, 22), anchor="mm")
        bx += bw + gap

    if show_help:
        text(d, (16, H - 46), "Move: WASD / geser  ·  Buy at the belt: press E / beli di conveyor", font(F_REG, 8), DIM)
        text(d, (16, H - 34), "Click a thief to slap / klik pencuri untuk menampar", font(F_REG, 8), DIM)


def toast(img, title, kind="good"):
    d = ImageDraw.Draw(img)
    colour = {"good": GREEN, "bad": RED, "gold": GOLD}.get(kind, BLUE)
    f = font(F_BOLD, 10)
    tw = d.textlength(title, font=f)
    x1, y1 = W - 14, H - 60
    x0, y0 = x1 - tw - 20, y1 - 22
    rr(d, (x0, y0, x1, y1), 6, fill=CARD + (240,), outline=colour, width=1)
    text(d, ((x0 + x1) / 2, (y0 + y1) / 2), title, f, TEXT, anchor="mm")


def banner(img, title, subtitle, colour=GOLD, y=150):
    d = ImageDraw.Draw(img)
    f1 = font(F_BOLD, 34)
    f2 = font(F_BOLD, 15)
    text(d, (W / 2, y), title, f1, colour, anchor="mm", stroke=5, stroke_fill=(0, 0, 0))
    text(d, (W / 2, y + 34), subtitle, f2, TEXT, anchor="mm", stroke=4, stroke_fill=(0, 0, 0))


def vignette(img):
    layer = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(layer)
    d.ellipse([-W * 0.25, -H * 0.3, W * 1.25, H * 1.3], fill=255)
    layer = layer.filter(ImageFilter.GaussianBlur(120))
    dark = Image.new("RGB", (W, H), (8, 6, 12))
    img.paste(Image.composite(img, dark, layer), (0, 0))


def new_frame(seed=7):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    night_sky(img, seed)
    d = ImageDraw.Draw(img)
    skyline(d)
    ground(img)
    string_lights(img, d)
    return img


CAP = 262144


def finish(img, path):
    """Save under the dossier's per-screenshot cap (256 KiB), keeping text crisp."""
    vignette(img)
    rgb = img.convert("RGB")
    rgb.save(path, optimize=True)
    size = os.path.getsize(path)
    if size > CAP:
        # palette-quantise instead of blurring: text must stay sharp, and the
        # dithered gradient reads as film grain rather than softness.
        rgb.quantize(colors=256, method=Image.MEDIANCUT, dither=Image.FLOYDSTEINBERG).save(path, optimize=True)
        size = os.path.getsize(path)
    return size
