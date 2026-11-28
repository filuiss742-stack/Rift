#!/usr/bin/env python3
"""Генератор временных пиксельных спрайтов. Запуск из корня проекта: python tools/make_sprites.py
Лист персонажа = 4 кадра в ряд: 0 стоит, 1 шаг A, 2 шаг B, 3 атака. Персонаж смотрит ВПРАВО."""
import os, random
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
OUTLINE = (24, 16, 32, 255)

def outline(img):
    w, h = img.size
    src = img.load()
    res = img.copy()
    dst = res.load()
    for x in range(w):
        for y in range(h):
            if src[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] > 0:
                        dst[x, y] = OUTLINE
                        break
    return res

def save(name, img):
    img.save(os.path.join(OUT, name + ".png"))

def human(name, hair, cloth, accent, eyes, weapon=None, long_hair=True, skin=(244, 205, 180)):
    sheet = Image.new("RGBA", (32 * 4, 48), (0, 0, 0, 0))
    for f in range(4):
        im = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        bob = 1 if f in (1, 2) else 0
        lean = 2 if f == 3 else 0
        # ноги
        la, lb = {0: (0, 0), 1: (-3, 3), 2: (3, -3), 3: (-3, 3)}[f]
        d.rectangle([12 + la, 36, 14 + la, 45], fill=(60, 48, 70))
        d.rectangle([17 + lb, 36, 19 + lb, 45], fill=(75, 60, 88))
        d.rectangle([12 + la, 44, 16 + la, 46], fill=(40, 28, 38))
        d.rectangle([17 + lb, 44, 21 + lb, 46], fill=(40, 28, 38))
        x, y = lean, bob
        if long_hair:
            d.polygon([(9 + x, 14 + y), (13 + x, 10 + y), (13 + x, 33 + y), (7 + x, 35 + y)], fill=hair)
        # тело и плащ
        d.polygon([(12 + x, 23 + y), (20 + x, 23 + y), (23 + x, 38 + y), (9 + x, 38 + y)], fill=cloth)
        d.rectangle([12 + x, 30 + y, 20 + x, 31 + y], fill=accent)
        d.line([(16 + x, 23 + y), (16 + x, 29 + y)], fill=accent)
        # голова
        d.ellipse([9 + x, 6 + y, 23 + x, 22 + y], fill=skin)
        d.pieslice([8 + x, 4 + y, 24 + x, 20 + y], 180, 360, fill=hair)
        d.rectangle([8 + x, 11 + y, 12 + x, 19 + y], fill=hair)
        d.polygon([(12 + x, 11 + y), (19 + x, 11 + y), (14 + x, 14 + y)], fill=hair)
        d.rectangle([16 + x, 14 + y, 17 + x, 16 + y], fill=eyes)
        d.rectangle([20 + x, 14 + y, 21 + x, 16 + y], fill=eyes)
        # руки и оружие
        if f == 3:
            d.rectangle([19 + x, 25 + y, 25 + x, 27 + y], fill=skin)
            hx, hy, tx, ty = 25 + x, 26 + y, 31, 24
        else:
            d.rectangle([20 + x, 25 + y, 22 + x, 32 + y], fill=skin)
            hx, hy, tx, ty = 22 + x, 31 + y, 29, 40
        if weapon == "sword":
            d.line([(hx, hy), (tx, ty)], fill=(225, 230, 245), width=2)
            d.line([(hx, hy - 2), (hx, hy + 2)], fill=accent, width=1)
        elif weapon == "bow":
            d.arc([hx - 4, hy - 9, hx + 5, hy + 9], 270, 90, fill=(165, 110, 60), width=2)
            d.line([(hx, hy - 9), (hx, hy + 9)], fill=(220, 220, 220))
        elif weapon == "staff":
            d.line([(hx + 2, hy - 14), (hx + 2, hy + 10)], fill=(130, 90, 55), width=2)
            d.ellipse([hx, hy - 18, hx + 5, hy - 13], fill=accent)
        elif weapon == "pick":
            d.line([(hx, hy), (hx + 5, hy - 7)], fill=(130, 90, 55), width=2)
            d.line([(hx + 1, hy - 9), (hx + 8, hy - 4)], fill=(170, 175, 190), width=2)
        sheet.paste(outline(im), (32 * f, 0))
    save(name, sheet)

def monster(name, body, glow, w=32, h=48, horns=False, big=False):
    sheet = Image.new("RGBA", (w * 4, h), (0, 0, 0, 0))
    for f in range(4):
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        sx, sy = w / 32.0, h / 48.0
        def P(x, y):
            return (int(x * sx), int(y * sy))
        def R(a, b, c, e):
            return [*P(a, b), *P(c, e)]
        la, lb = {0: (0, 0), 1: (-3, 3), 2: (3, -3), 3: (-2, 2)}[f]
        lean = 3 if f == 3 else 0
        d.polygon([P(11, 32), P(15, 32), P(13 + la, 46), P(8 + la, 46)], fill=body)
        d.polygon([P(18, 32), P(22, 32), P(24 + lb, 46), P(19 + lb, 46)], fill=body)
        wide = 3 if big else 0
        d.polygon([P(10 - wide + lean, 18), P(23 + wide + lean, 18), P(21, 35), P(12, 35)], fill=body)
        d.ellipse(R(11 + lean, 7, 25 + lean, 21), fill=body)
        if horns:
            d.polygon([P(12 + lean, 11), P(7 + lean, 1), P(16 + lean, 8)], fill=(220, 210, 205))
            d.polygon([P(21 + lean, 9), P(28 + lean, 1), P(24 + lean, 12)], fill=(220, 210, 205))
        d.rectangle(R(18 + lean, 12, 19 + lean, 14), fill=glow)
        d.rectangle(R(22 + lean, 12, 23 + lean, 14), fill=glow)
        d.line([P(14 + lean, 20), P(18 + lean, 25), P(15, 30), P(19, 34)], fill=glow, width=max(1, int(sx)))
        if f == 3:
            d.polygon([P(20, 22), P(31, 20), P(31, 27), P(21, 27)], fill=body)
            d.line([P(28, 20), P(31, 16)], fill=glow, width=2)
            d.line([P(29, 27), P(31, 31)], fill=glow, width=2)
        else:
            d.polygon([P(22, 21), P(26, 22), P(28, 38), P(24, 37)], fill=body)
            d.line([P(25, 37), P(29, 41)], fill=glow, width=max(1, int(sx)))
        sheet.paste(outline(im), (w * f, 0))
    save(name, sheet)

def prop(name, w, h, painter):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    painter(ImageDraw.Draw(im))
    save(name, outline(im))

def tree_dead(d):
    d.rectangle([21, 30, 27, 63], fill=(72, 50, 52))
    for a, b in (((24, 38), (8, 20)), ((24, 32), (40, 12)), ((24, 30), (22, 4)), ((12, 24), (4, 22)), ((35, 18), (45, 18))):
        d.line([a, b], fill=(72, 50, 52), width=3)

def tree_red(d):
    d.rectangle([21, 38, 27, 63], fill=(70, 42, 48))
    for box, c in (([4, 14, 32, 40], (110, 28, 52)), ([18, 8, 46, 38], (148, 36, 58)), ([12, 2, 36, 26], (176, 52, 70))):
        d.ellipse(box, fill=c)

def rock(d):
    d.polygon([(2, 23), (6, 9), (16, 3), (27, 11), (30, 23)], fill=(105, 100, 118))
    d.polygon([(8, 11), (16, 5), (20, 14), (12, 17)], fill=(135, 130, 150))

def crystal(d):
    d.polygon([(10, 39), (6, 16), (12, 4), (18, 18), (15, 39)], fill=(86, 200, 235))
    d.polygon([(16, 39), (19, 20), (25, 12), (29, 24), (24, 39)], fill=(150, 230, 250))
    d.polygon([(2, 39), (3, 26), (7, 22), (10, 39)], fill=(60, 150, 210))

def campfire(d):
    d.line([(4, 27), (27, 21)], fill=(110, 70, 40), width=3)
    d.line([(4, 21), (27, 27)], fill=(90, 56, 34), width=3)
    d.polygon([(9, 23), (15, 3), (18, 12), (22, 8), (23, 23)], fill=(240, 120, 40))
    d.polygon([(12, 23), (16, 12), (20, 23)], fill=(255, 220, 90))

def bed(d):
    d.rectangle([2, 14, 45, 26], fill=(116, 82, 62))
    d.rectangle([4, 10, 43, 20], fill=(92, 112, 180))
    d.rectangle([32, 8, 43, 15], fill=(232, 232, 240))
    d.rectangle([3, 26, 6, 30], fill=(80, 54, 40))
    d.rectangle([40, 26, 43, 30], fill=(80, 54, 40))

def diary(d):
    d.rectangle([4, 8, 20, 21], fill=(150, 48, 66))
    d.rectangle([7, 9, 19, 19], fill=(238, 228, 205))
    for y in (12, 14, 16):
        d.line([(9, y), (17, y)], fill=(90, 80, 90))

def lantern(d):
    d.rectangle([7, 12, 9, 39], fill=(62, 56, 70))
    d.rectangle([3, 3, 13, 13], fill=(255, 218, 120))

def crack(d):
    pts = [(20, 2), (14, 16), (22, 24), (12, 38), (19, 46), (15, 62)]
    d.line(pts, fill=(200, 24, 60), width=9)
    d.line(pts, fill=(255, 245, 250), width=3)

def echo(d):
    d.ellipse([9, 6, 23, 22], fill=(255, 120, 150, 220))
    d.polygon([(12, 22), (20, 22), (25, 44), (7, 44)], fill=(220, 60, 110, 190))
    d.rectangle([16, 14, 17, 16], fill=(255, 255, 255))
    d.rectangle([20, 14, 21, 16], fill=(255, 255, 255))

def bones(d):
    d.line([(3, 13), (20, 5)], fill=(214, 206, 188), width=2)
    d.line([(5, 6), (19, 13)], fill=(214, 206, 188), width=2)
    d.ellipse([13, 6, 22, 14], fill=(224, 216, 198))

def grass(d):
    for x in range(3, 22, 3):
        d.line([(x, 15), (x + random.randint(-3, 3), random.randint(3, 9))], fill=(128, 102, 112), width=1)

def potion(d):
    d.rectangle([9, 3, 14, 9], fill=(180, 180, 200))
    d.ellipse([4, 8, 19, 22], fill=(224, 52, 82))
    d.rectangle([8, 11, 10, 13], fill=(255, 190, 200))

def main():
    os.makedirs(OUT, exist_ok=True)
    random.seed(7)
    human("mira", (214, 216, 232), (48, 44, 78), (214, 38, 72), (200, 30, 60), "sword")
    human("liza", (110, 70, 50), (82, 110, 150), (240, 220, 160), (50, 80, 60))
    human("ren", (60, 44, 40), (70, 90, 66), (190, 150, 90), (40, 40, 40), "bow", long_hair=False)
    human("iveta", (180, 180, 186), (108, 66, 98), (210, 190, 120), (60, 50, 90), "staff")
    human("worker", (130, 90, 50), (140, 112, 76), (90, 66, 44), (40, 30, 20), "pick", long_hair=False)
    human("swordsman", (90, 70, 50), (66, 96, 160), (220, 190, 90), (30, 30, 50), "sword", long_hair=False)
    human("archer", (196, 150, 70), (66, 130, 90), (200, 170, 100), (30, 60, 30), "bow")
    human("guardian", (170, 176, 190), (112, 124, 150), (240, 200, 90), (240, 240, 255), "staff", long_hair=False, skin=(150, 160, 178))
    monster("husk", (86, 74, 96), (255, 70, 90))
    monster("spitter", (92, 58, 106), (255, 130, 210))
    monster("brute", (110, 52, 62), (255, 150, 60), horns=True, big=True)
    monster("hunter", (50, 36, 58), (255, 40, 70), 48, 64, horns=True)
    monster("warden", (34, 22, 42), (255, 235, 240), 64, 88, horns=True, big=True)
    prop("tree_dead", 48, 64, tree_dead)
    prop("tree_red", 48, 64, tree_red)
    prop("rock", 32, 24, rock)
    prop("crystal", 32, 40, crystal)
    prop("campfire", 32, 30, campfire)
    prop("bed", 48, 32, bed)
    prop("diary", 24, 24, diary)
    prop("lantern", 16, 40, lantern)
    prop("crack", 32, 64, crack)
    prop("echo", 32, 48, echo)
    prop("bones", 24, 16, bones)
    prop("grass", 24, 16, grass)
    prop("potion", 24, 24, potion)
    icon = Image.new("RGBA", (128, 128), (22, 12, 30, 255))
    d = ImageDraw.Draw(icon)
    pts = [(74, 8), (52, 48), (78, 64), (48, 94), (62, 120)]
    d.line(pts, fill=(204, 24, 60), width=18)
    d.line(pts, fill=(255, 246, 250), width=5)
    icon.save(os.path.join(OUT, "..", "..", "icon.png"))
    print("Готово:", len(os.listdir(OUT)), "файлов")

if __name__ == "__main__":
    main()
