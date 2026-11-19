#!/usr/bin/env python3
"""The four scenes. Imports the shared drawing kit in shots_base.py."""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image, ImageDraw, ImageFilter

import shots_base as B
from shots_base import (
    BLUE,
    CARD,
    DARK,
    DIM,
    GOLD,
    GREEN,
    H,
    PURPLE,
    RARITY,
    RED,
    TEXT,
    W,
    avatar,
    banner,
    billboard,
    finish,
    font,
    glow,
    hud,
    mascot,
    money,
    new_frame,
    rr,
    text,
    toast,
    warung,
)

F_BOLD = B.F_BOLD
F_REG = B.F_REG
F_LIGHT = B.F_LIGHT


def conveyor(img, x0, y0, length, s, items):
    """The belt: dark tread, yellow arrows, snacks riding it with price tags."""
    d = ImageDraw.Draw(img)
    h = 20 * s
    y1 = y0 + h
    d.polygon(
        [(x0, y0), (x0 + length, y0), (x0 + length - 8 * s, y1), (x0 + 8 * s, y1)],
        fill=(58, 54, 66),
    )
    d.rectangle([x0 + 4 * s, y0 - 3 * s, x0 + length - 4 * s, y0 + 3 * s], fill=(96, 92, 106))
    for i in range(int(length // (26 * s))):
        ax = x0 + 10 * s + i * 26 * s
        d.polygon(
            [(ax, y1 - 4 * s), (ax + 8 * s, y1 - 9 * s), (ax + 8 * s, y1 - 3 * s)],
            fill=(214, 176, 60),
        )
    for i, cost in enumerate(items):
        item_x = x0 + length * (0.22 + 0.26 * i)
        mascot(img, item_x, y0 - 4 * s, 0.62 * s, cost[0])
        price_tag(img, item_x, y0 - 74 * s, cost[1], 0.68 * s)


def price_tag(img, cx, cy, cost, s=1.0):
    d = ImageDraw.Draw(img)
    s = max(0.55, s)
    f1 = font(F_BOLD, int(13 * s))
    f2 = font(F_BOLD, int(9 * s))
    top = money(cost)
    bot = "BUY / BELI"
    bw = max(d.textlength(top, font=f1), d.textlength(bot, font=f2)) + 14 * s
    B.soft_shadow(img, (cx - bw / 2, cy - 22 * s, cx + bw / 2, cy + 12 * s), radius=5, alpha=120, offset=(0, 3), blur=6)
    d = ImageDraw.Draw(img)
    rr(d, (cx - bw / 2, cy - 22 * s, cx + bw / 2, cy + 12 * s), 5, fill=(18, 15, 24, 240), outline=GOLD, width=2)
    text(d, (cx, cy - 12 * s), top, f1, GOLD, anchor="mm")
    text(d, (cx, cy + 3 * s), bot, f2, TEXT, anchor="mm")
    d.polygon([(cx - 5 * s, cy + 12 * s), (cx + 5 * s, cy + 12 * s), (cx, cy + 18 * s)], fill=(18, 15, 24))


def prompt(img, cx, cy, s=1.0):
    """ProximityPrompt bubble: E to buy."""
    d = ImageDraw.Draw(img)
    f = font(F_BOLD, int(10 * s))
    label = "BUY / BELI"
    tw = d.textlength(label, font=f)
    rr(d, (cx - tw / 2 - 26 * s, cy - 12 * s, cx + tw / 2 + 6 * s, cy + 12 * s), 6, fill=(10, 8, 14, 235), outline=(250, 246, 255), width=2)
    rr(d, (cx - tw / 2 - 22 * s, cy - 9 * s, cx - tw / 2 - 4 * s, cy + 9 * s), 3, fill=TEXT)
    text(d, (cx - tw / 2 - 13 * s, cy), "E", font(F_BOLD, int(11 * s)), (20, 16, 24), anchor="mm")
    text(d, (cx - tw / 2 + 5 * s, cy), label, f, TEXT, anchor="lm")


def coins(img, x, y, n=7, seed=1, radius=90):
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed)
    for _ in range(n):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(radius * 0.25, radius)
        cx, cy = x + math.cos(a) * r, y + math.sin(a) * r * 0.6
        rr_ = rnd.uniform(4, 7)
        d.ellipse([cx - rr_, cy - rr_, cx + rr_, cy + rr_], fill=(255, 206, 84), outline=(190, 130, 20), width=1)
        text(d, (cx, cy), "$", font(F_BOLD, int(rr_ * 1.5)), (150, 100, 10), anchor="mm")


def popup(img, x, y, label, colour=GREEN, size=17):
    d = ImageDraw.Draw(img)
    text(d, (x, y), label, font(F_BOLD, size), colour, anchor="mm", stroke=3, stroke_fill=(0, 0, 0))


def sparkle(img, x, y, r, colour=(255, 244, 200)):
    d = ImageDraw.Draw(img)
    d.polygon([(x, y - r), (x + r * 0.22, y - r * 0.22), (x + r, y), (x + r * 0.22, y + r * 0.22), (x, y + r), (x - r * 0.22, y + r * 0.22), (x - r, y), (x - r * 0.22, y - r * 0.22)], fill=colour)


# ------------------------------------------------------------------ scenes


def golden_rain(img, seed=5, count=190, top=0):
    """Falling gold: streaks, sparks, and a warm wash over the market."""
    """Falling gold: streaks, sparks, and a warm wash over the market."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    rnd = random.Random(seed)
    for _ in range(count):
        x = rnd.uniform(-40, W + 40)
        y = rnd.uniform(top, H)
        ln = rnd.uniform(10, 34)
        slant = rnd.uniform(3, 9)
        a = rnd.randint(80, 190)
        d.line([(x, y), (x + slant, y + ln)], fill=(255, 214, 110, a), width=rnd.choice([1, 2, 2]))
    for _ in range(26):
        x = rnd.uniform(0, W)
        y = rnd.uniform(top, H)
        r = rnd.uniform(3, 8)
        d.polygon(
            [(x, y - r), (x + r * 0.25, y - r * 0.25), (x + r, y), (x + r * 0.25, y + r * 0.25), (x, y + r), (x - r * 0.25, y + r * 0.25), (x - r, y), (x - r * 0.25, y - r * 0.25)],
            fill=(255, 240, 190, rnd.randint(120, 220)),
        )
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(0.4)))


def hero_base(img, cx, y, width=620):
    """A wooden stall platform with a low rail and a warm lamp: the player's warung."""
    d = ImageDraw.Draw(img)
    x0, x1 = cx - width / 2, cx + width / 2
    B.soft_shadow(img, (x0, y + 6, x1, y + 54), radius=10, alpha=120, offset=(0, 8), blur=16)
    rr(d, (x0, y, x1, y + 34), 8, fill=(126, 82, 48), outline=(88, 56, 34), width=3)
    step = (x1 - x0) / 9
    for i in range(1, 9):
        px = x0 + i * step
        d.line([(px, y + 3), (px, y + 31)], fill=(108, 70, 42), width=3)
    rr(d, (x0, y + 34, x1, y + 42), 4, fill=(96, 62, 38))
    for rx in (x0 + 18, x1 - 18):
        rr(d, (rx - 6, y + 42, rx + 6, y + 50), 3, fill=(70, 46, 30))
    for px in (x0 + 26, x1 - 26):
        rr(d, (px - 5, y - 46, px + 5, y + 2), 3, fill=(150, 104, 62), outline=(96, 64, 40), width=2)
        B.glow(img, (px, y - 52), 64, (255, 176, 96), 90, 30)
        d.ellipse([px - 8, y - 60, px + 8, y - 44], fill=(255, 226, 168))
    rr(d, (x0 + 8, y - 34, x0 + 128, y - 8), 5, fill=(28, 22, 30, 240), outline=GOLD, width=2)
    text(d, (x0 + 68, y - 21), "BASE KAMU / YOUR BASE", font(F_BOLD, 10), GOLD, anchor="mm")


def scene_cover():
    img = new_frame(11)

    warung(img, 1074, 508, 0.52, "WARUNG PAK JOKO", canopy=(64, 116, 92))
    warung(img, 208, 500, 0.5, "WARUNG BU SITI", canopy=(70, 96, 180))

    hero_base(img, 610, 690, 660)
    on_base = [
        (418, "Bakso Beranak", "Common", 18, None, 514),
        (610, "Rendang Raja Rimba", "Legendary", 410, "Keju Lumer", 490),
        (802, "Es Kopi Susu Dewa", "Mythic", 940, "Pelangi", 514),
    ]
    for bx, name, rarity, income, mutation, _ in on_base:
        mascot(img, bx, 688, 1.42, name, mutation)
    for bx, name, rarity, income, mutation, ty in on_base:
        billboard(img, bx, ty, name, rarity, income, mutation, scale=1.12, highlight=(name == "Rendang Raja Rimba"))

    golden_rain(img, 7)

    conveyor(img, 8, 716, 300, 0.95, [("Noobini Gorengan", 45), ("Cakwe Panjang Umur", 120)])
    prompt(img, 188, 618, 0.95)

    avatar(img, 1010, 720, 1.4, shirt=(58, 132, 200), pants=(38, 44, 62), name="kamu", wave=True)
    avatar(img, 1176, 566, 0.62, shirt=(196, 74, 128), pants=(40, 34, 52), name="Dewi")
    coins(img, 610, 588, 6, seed=4, radius=76)
    popup(img, 900, 604, "+$1,230", GREEN, 19)

    hud(
        img,
        cash=1284500,
        income=8450,
        tier=2,
        multiplier=3,
        slots=5,
        slot_max=12,
        lock_state="PROTECTED 32s / AMAN",
        tsunami=("TSUNAMI  1:42", GOLD),
        golden=("GOLDEN RAIN  0:38", GOLD),
        guard="GUARD DOG / ANJING PENJAGA: ON",
        show_objective=False,
        show_help=False,
    )
    banner(img, "GOLDEN RAIN! / HUJAN EMAS!", "x3 mutation drops right now  ·  Mutasi x3 jatuh sekarang", GOLD, 178)
    return finish(img, os.path.join(B.OUT, "1-thumbnail.png"))


def scene_start():
    img = new_frame(21)

    # a neighbour's base in the middle distance, so the sky is not empty
    warung(img, 208, 486, 0.66, "WARUNG PAK JOKO", canopy=(70, 96, 180))
    warung(img, 1074, 540, 0.72, "WARUNG KOSONG", canopy=(120, 74, 60), occupied=False)

    conveyor(img, 96, 612, 640, 1.32, [("Noobini Gorengan", 45), ("Es Teh Manis Man", 60), ("Bakso Beranak", 120)])
    # the item the tutorial points at
    ring = Image.new("RGBA", img.size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    rd.ellipse([96 + 640 * 0.22 - 62, 596, 96 + 640 * 0.22 + 62, 628], outline=(255, 214, 110, 220), width=5)
    img.alpha_composite(ring.filter(ImageFilter.GaussianBlur(2)))
    glow(img, (96 + 640 * 0.22, 560), 70, (255, 206, 96), 95, 26)

    prompt(img, 96 + 640 * 0.22, 476, 1.05)
    avatar(img, 900, 700, 1.24, shirt=(58, 132, 200), pants=(38, 44, 62), name="kamu")

    popup(img, 96 + 640 * 0.22, 442, "STEP 1  /  LANGKAH 1", GOLD, 17)
    sparkle(img, 700, 520, 8)
    sparkle(img, 760, 556, 6)

    hud(
        img,
        cash=250,
        income=2,
        tier=0,
        multiplier=1,
        slots=0,
        slot_max=8,
        lock_state="OPEN / TERBUKA",
        tsunami=("TSUNAMI  2:10", TEXT),
        golden=("GOLDEN RAIN  1:35", GOLD),
        guard="GUARD DOG / ANJING PENJAGA: OFF",
    )
    toast(img, "Press E at the belt / Tekan E di conveyor", "gold")
    return finish(img, os.path.join(B.OUT, "2-start.png"))


def shop_panel(img):
    """The shop the client builds: 12 snacks, rarity, income, price, BUY button."""
    d = ImageDraw.Draw(img)
    px1, py1 = W - 12, 610
    px0, py0 = px1 - 430, 118
    B.soft_shadow(img, (px0, py0, px1, py1), radius=12, alpha=170, offset=(0, 8), blur=18)
    d = ImageDraw.Draw(img)
    rr(d, (px0, py0, px1, py1), 12, fill=(20, 16, 28, 250), outline=(255, 196, 60, 180), width=2)
    rr(d, (px0, py0, px1, py0 + 40), 12, fill=(30, 24, 40, 255))
    text(d, (px0 + 16, py0 + 20), "SHOP / TOKO", font(F_BOLD, 17), GOLD, anchor="lm")
    text(d, (px1 - 16, py0 + 20), "12 SNACKROT", font(F_BOLD, 10), DIM, anchor="rm")

    rows = [
        ("Noobini Gorengan", "Common", 45, 2),
        ("Es Teh Manis Man", "Common", 60, 3),
        ("Bakso Beranak", "Common", 120, 6),
        ("Siomay Terbang", "Rare", 340, 18),
        ("Nasi Padang Raksasa", "Rare", 780, 40),
        ("Rendang Raja Rimba", "Legendary", 12500, 410),
    ]
    y = py0 + 50
    for name, rarity, cost, income in rows:
        colour = RARITY[rarity]
        rr(d, (px0 + 12, y, px1 - 12, y + 72), 8, fill=(34, 27, 46, 255), outline=colour + (150,), width=1)
        d.rectangle([px0 + 12, y + 6, px0 + 16, y + 66], fill=colour)
        text(d, (px0 + 26, y + 12), name, font(F_BOLD, 13), TEXT)
        text(d, (px0 + 26, y + 30), f"{rarity.upper()} / {B.RARITY_ID[rarity]}", font(F_BOLD, 9), colour)
        text(d, (px0 + 26, y + 46), f"{money(income)}/sec · {money(income)}/dtk", font(F_BOLD, 9), GREEN)
        bw = 118
        bx0 = px1 - 20 - bw
        rr(d, (bx0, y + 18, bx0 + bw, y + 54), 7, fill=GOLD if cost < 5000 else (150, 120, 60))
        text(d, (bx0 + bw / 2, y + 30), money(cost), font(F_BOLD, 12), (22, 16, 12), anchor="mm")
        text(d, (bx0 + bw / 2, y + 44), "BUY / BELI", font(F_BOLD, 9), (60, 40, 10), anchor="mm")
        y += 78
    d.rectangle([px1 - 18, py0 + 50, px1 - 14, py1 - 12], fill=(70, 60, 86))


def scene_play():
    img = new_frame(31)

    warung(img, 396, 640, 1.55, "")
    on_base = [
        (226, "Noobini Gorengan", "Common", 24, None, 448),
        (342, "Siomay Terbang", "Rare", 54, "Gosong", 424),
        (458, "Nasi Padang Raksasa", "Rare", 120, None, 448),
        (574, "Sate Klathak Samurai", "Epic", 384, "Keju Lumer", 424),
    ]
    for bx, name, rarity, income, mutation, _ in on_base:
        mascot(img, bx, 628, 0.8, name, mutation)
    for bx, name, rarity, income, mutation, ty in on_base:
        billboard(img, bx, ty, name, rarity, income, mutation, scale=0.7)

    avatar(img, 120, 676, 1.02, shirt=(58, 132, 200), pants=(38, 44, 62), name="kamu")
    coins(img, 574, 500, 5, seed=9, radius=46)
    popup(img, 660, 470, "+$384", GREEN, 16)

    shop_panel(img)

    hud(
        img,
        cash=89400,
        income=384,
        tier=1,
        multiplier=2,
        slots=4,
        slot_max=10,
        lock_state="OPEN / TERBUKA",
        tsunami=("TSUNAMI  0:24", RED),
        golden=("GOLDEN RAIN  1:02", GOLD),
        guard="GUARD DOG / ANJING PENJAGA: ON",
    )
    toast(img, "Placed Sate Klathak / Menaruh Sate", "good")
    return finish(img, os.path.join(B.OUT, "3-play.png"))


def tsunami_wave(img, crest_x, base_y, height=330):
    """A curling wall of water: a bezier crest, a lighter inner face, foam and spray."""
    W, H = img.size
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    def crest(t, sx=0.0, sy=0.0):
        # cubic bezier from the waterline up into a hook
        p0 = (crest_x + 30 + sx, base_y + sy)
        p1 = (crest_x - 10 + sx, base_y - height * 0.55 + sy)
        p2 = (crest_x - 120 + sx, base_y - height * 1.02 + sy)
        p3 = (crest_x - 258 + sx, base_y - height * 0.70 + sy)
        u = 1 - t
        x = u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0]
        y = u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1]
        return x, y

    body = [crest(k / 48) for k in range(49)]
    body += [(crest_x - 300, base_y + 26), (crest_x + 40, base_y + 26)]
    d.polygon(body, fill=(26, 78, 104, 255))

    face = [crest(k / 48, 26, 20) for k in range(49)]
    face += [(crest_x - 250, base_y + 24), (crest_x + 6, base_y + 24)]
    d.polygon(face, fill=(38, 118, 150, 255))

    inner = [crest(k / 48, 58, 46) for k in range(30, 49)]
    inner += [(crest_x - 170, base_y + 20), (crest_x - 40, base_y + 20)]
    d.polygon(inner, fill=(68, 162, 180, 235))

    # motion streaks inside the face
    rnd = random.Random(7)
    for _ in range(26):
        t = rnd.uniform(0.05, 0.85)
        x, y = crest(t, rnd.uniform(0, 40), rnd.uniform(10, 40))
        d.line([(x, y), (x + rnd.uniform(-16, -6), y + rnd.uniform(26, 54))], fill=(180, 226, 236, rnd.randint(40, 90)), width=2)

    # foam along the crest
    for _ in range(150):
        t = rnd.uniform(0.30, 1.0)
        x, y = crest(t)
        r = rnd.uniform(5, 15) * (0.7 + t * 0.6)
        d.ellipse([x - r, y - r * 0.8, x + r, y + r * 0.8], fill=(238, 250, 252, rnd.randint(150, 240)))
    for _ in range(120):
        t = rnd.random()
        x, y = crest(t, rnd.uniform(-6, 6), rnd.uniform(-4, 8))
        r = rnd.uniform(3, 8)
        d.ellipse([x - r, y - r * 0.8, x + r, y + r * 0.8], fill=(246, 252, 253, rnd.randint(180, 245)))

    # spray thrown ahead of the hook
    for _ in range(120):
        t = rnd.uniform(0.6, 1.0)
        x, y = crest(t)
        x += rnd.uniform(20, 130)
        y -= rnd.uniform(0, height * 0.42)
        r = rnd.uniform(1.5, 5.5)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(240, 252, 254, rnd.randint(60, 170)))

    # the waterline: the flood already at the player's feet
    d.rectangle([0, base_y - 8, crest_x - 240, base_y + 30], fill=(30, 96, 124, 150))
    for _ in range(40):
        x = rnd.uniform(0, crest_x - 240)
        r = rnd.uniform(4, 16)
        d.ellipse([x - r, base_y - 10, x + r, base_y + 2], fill=(236, 250, 252, rnd.randint(120, 210)))

    layer = layer.filter(ImageFilter.GaussianBlur(0.5))
    img.alpha_composite(layer)


def speed_lines(img, x, y, direction=-1, n=5, colour=(255, 255, 255)):
    d = ImageDraw.Draw(img)
    rnd = random.Random(int(x))
    for i in range(n):
        ly = y - 60 + i * 22 + rnd.randint(-4, 4)
        ln = rnd.randint(26, 54)
        d.line([(x + direction * (24 + rnd.randint(0, 8)), ly), (x + direction * (24 + ln), ly)], fill=colour + (150,), width=random.Random(i).choice([2, 3]))


def alarm_vignette(img, colour=(255, 40, 40), peak=110):
    """Red edge glow: the room lights are screaming."""
    W, H = img.size
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i in range(26):
        inset = i * 9
        a = int(peak * (1 - i / 26) ** 2.1) + 4
        d.rectangle([inset, inset, W - inset, H - inset], outline=colour + (a,), width=12)
    layer = layer.filter(ImageFilter.GaussianBlur(9))
    img.alpha_composite(layer)


def scene_tension():
    img = new_frame(41)

    tsunami_wave(img, 610, 720, 372)

    # the base that is being robbed
    warung(img, 1042, 640, 1.14, "BASE KAMU / YOUR BASE")
    left_behind = [
        (972, "Bakso Beranak", "Common", 18, None, 448),
        (1114, "Es Kopi Susu Dewa", "Mythic", 940, None, 430),
    ]
    for bx, name, rarity, income, mut, _ in left_behind:
        mascot(img, bx, 628, 0.78, name, mut)
    for bx, name, rarity, income, mut, ty in left_behind:
        billboard(img, bx, ty, name, rarity, income, mut, scale=0.62)

    # safe zone, where the player is heading
    ring = Image.new("RGBA", img.size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    rd.ellipse([1042 - 132, 644 - 26, 1042 + 132, 644 + 26], outline=(90, 240, 150, 200), width=5)
    rd.ellipse([1042 - 132, 644 - 26, 1042 + 132, 644 + 26], fill=(90, 240, 150, 36))
    img.alpha_composite(ring.filter(ImageFilter.GaussianBlur(2)))
    d = ImageDraw.Draw(img)
    text(d, (1042, 682), "SAFE ZONE / ZONA AMAN", font(F_BOLD, 10), GREEN, anchor="mm", stroke=3, stroke_fill=(0, 0, 0))

    # the thief: running left with the Rendang under one arm, label gone from the base
    thief_x, thief_y = 748, 706
    avatar(img, thief_x, thief_y, 1.16, shirt=(44, 40, 54), pants=(26, 24, 34), name="", running=True)
    mascot(img, thief_x - 6, thief_y - 18, 0.78, "Rendang Raja Rimba")
    speed_lines(img, thief_x, thief_y - 52, 1, 5, (255, 220, 200))
    d = ImageDraw.Draw(img)
    rr(d, (thief_x - 92, thief_y - 196, thief_x + 92, thief_y - 140), 7, fill=(190, 32, 40, 250), outline=(255, 226, 226), width=2)
    text(d, (thief_x, thief_y - 178), "STOLEN! / DICURI!", font(F_BOLD, 15), (255, 246, 246), anchor="mm")
    text(d, (thief_x, thief_y - 156), "Rendang Raja Rimba", font(F_BOLD, 11), (255, 224, 196), anchor="mm")
    d.polygon([(thief_x - 8, thief_y - 140), (thief_x + 8, thief_y - 140), (thief_x, thief_y - 128)], fill=(190, 32, 40))

    # the player, sprinting for the safe zone
    player_x = 1108
    avatar(img, player_x, 742, 1.24, shirt=(58, 132, 200), pants=(38, 44, 62), name="kamu", running=True)
    speed_lines(img, player_x, 700, -1, 4, (210, 230, 255))

    hud(
        img,
        cash=51200,
        income=1368,
        tier=1,
        multiplier=2,
        slots=2,
        slot_max=10,
        lock_state="OPEN / TERBUKA",
        tsunami=("TSUNAMI NOW! / SEKARANG!", RED),
        golden=("GOLDEN RAIN  0:12", GOLD),
        guard="GUARD DOG / ANJING PENJAGA: OFF",
        show_help=False,
    )
    banner(img, "TSUNAMI! / SEMUA LARI!", "Get to the safe zone  ·  Lari ke zona aman", RED, 172)
    toast(img, "Rendang Raja Rimba stolen / dicuri!", "bad")
    alarm_vignette(img)
    return finish(img, os.path.join(B.OUT, "4-tension.png"))


if __name__ == "__main__":
    os.makedirs(B.OUT, exist_ok=True)
    want = sys.argv[1:] or ["cover", "start", "play", "tension"]
    table = {"cover": scene_cover, "start": scene_start, "play": scene_play, "tension": scene_tension}
    for key in want:
        size = table[key]()
        print(key, size, "bytes")
