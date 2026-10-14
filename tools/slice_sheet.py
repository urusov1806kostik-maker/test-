#!/usr/bin/env python3
"""Режет лист иконок 5x3 (resourcepack/art/icons-sheet.webp) на текстуры 32x32 с прозрачным фоном.
Порядок ячеек — слева направо, сверху вниз (см. NAMES)."""
import os
from collections import deque
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEET = os.path.join(ROOT, "resourcepack", "art", "icons-sheet.webp")
OUT = os.path.join(ROOT, "resourcepack", "art", "icons")
NAMES = ["coin", "demon_heart", "enchant_book", "frostbite", "inferno_axe",
         "shadow_blade", "shadow_shard", "shadowcoin", "talisman_demon", "talisman_ice",
         "talisman_life", "talisman_ocean", "talisman_shadow", "talisman_storm", "void_pickaxe"]
SIZE = 32


BG = [(15, 15, 28), (30, 22, 52), (13, 16, 26)]  # фон ячейки и рамка


def is_bg(c, bg, tol=22):
    return any(max(abs(c[0] - b[0]), abs(c[1] - b[1]), abs(c[2] - b[2])) <= tol for b in BG + [bg])


def cut(cell):
    w, h = cell.size
    px = cell.load()
    bg = px[w // 2, 6]
    seen = [[False] * h for _ in range(w)]
    q = deque((x, y) for x in range(w) for y in (0, h - 1)) + deque((x, y) for y in range(h) for x in (0, w - 1))
    alpha = Image.new("L", (w, h), 255)
    ap = alpha.load()
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or seen[x][y]:
            continue
        seen[x][y] = True
        if not is_bg(px[x, y], bg):
            continue
        ap[x, y] = 0
        q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    rgba = cell.convert("RGBA")
    rgba.putalpha(alpha)
    bbox = alpha.getbbox()
    rgba = rgba.crop(bbox)
    side = max(rgba.size)
    pad = int(side * 0.06)
    sq = Image.new("RGBA", (side + 2 * pad, side + 2 * pad), (0, 0, 0, 0))
    sq.alpha_composite(rgba, ((sq.width - rgba.width) // 2, (sq.height - rgba.height) // 2))
    small = sq.convert("RGBa").resize((SIZE, SIZE), Image.BOX).convert("RGBA")
    # жёсткая альфа, как в пиксель-арте
    a = small.getchannel("A").point(lambda v: 255 if v >= 110 else 0)
    small.putalpha(a)
    return small


def main():
    sheet = Image.open(SHEET).convert("RGB")
    W, H = sheet.size
    cw, ch = W / 5, H / 3
    os.makedirs(OUT, exist_ok=True)
    for i, name in enumerate(NAMES):
        c, r = i % 5, i // 5
        m = 18  # отступ от рамки ячейки
        box = (int(c * cw) + m, int(r * ch) + m, int((c + 1) * cw) - m, int((r + 1) * ch) - m)
        cut(sheet.crop(box)).save(os.path.join(OUT, name + ".png"))
    print("Готово:", OUT)


if __name__ == "__main__":
    main()
