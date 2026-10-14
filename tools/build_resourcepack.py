#!/usr/bin/env python3
"""Генерирует пиксель-арт текстуры ShadowSMP и собирает ресурспак (1.21.11).
Запуск: python3 tools/build_resourcepack.py  -> resourcepack/ (исходники) + resourcepack/ShadowSMP-pack.zip
"""
import hashlib, json, os, shutil, zipfile
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACK = os.path.join(ROOT, "resourcepack", "pack")
ZIP = os.path.join(ROOT, "resourcepack", "ShadowSMP-pack.zip")
NS = os.path.join(PACK, "assets", "shadowsmp")

# метки слоёв
O, B, L, D, G, H, P, E = range(1, 9)
KEYS = {"o": O, "b": B, "l": L, "d": D, "g": G, "h": H, "p": P, "e": E}


def hexc(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def outline(grid):
    n = len(grid)
    out = [row[:] for row in grid]
    for y in range(n):
        for x in range(n):
            if grid[y][x]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < n and 0 <= ny < n and grid[ny][nx] and grid[ny][nx] != O:
                    out[y][x] = O
                    break
    return out


def render(grid, pal, size=16):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    for y in range(size):
        for x in range(size):
            v = grid[y][x]
            if v and v in pal:
                img.putpixel((x, y), hexc(pal[v]))
    return img


def from_ascii(rows):
    return [[KEYS.get(c, 0) for c in r] for r in rows]


def canvas():
    return Image.new("L", (16, 16), 0)


def to_grid(im):
    return [[im.getpixel((x, y)) for x in range(16)] for y in range(16)]


# ---------- талисман (силуэт тотема) ----------
TOTEM = [
    "................",
    ".....oooooo.....",
    "....obbllbbo....",
    "....oblllbbo....",
    "....obeebeeo....",
    "....obbbbbbo....",
    "....odbbbbdo....",
    ".oo..oddddo..oo.",
    "oblo.obggbo.olbo",
    "obbboobggboobbbo",
    ".obbbbbbbbbbbbo.",
    "..oodbbbbbbdoo..",
    "....odbggbdo....",
    "....obdbbdbo....",
    "....ooddddoo....",
    ".....oooooo.....",
]

TALISMANS = {
    "demon":  dict(b="#8B1A1A", l="#D23C3C", d="#4A0A0A", o="#1A0505", e="#FFB000", g="#FF5A1F", h="#2B2B2B"),
    "ice":    dict(b="#5EC8E8", l="#D4F6FF", d="#2A7FA8", o="#0E3A52", e="#FFFFFF", g="#9EE7FF"),
    "storm":  dict(b="#E8C547", l="#FFF29A", d="#9C7A1C", o="#3A2E08", e="#5AB4FF", g="#FFFFFF"),
    "shadow": dict(b="#4B2A7A", l="#8150C8", d="#22113D", o="#0B0614", e="#E04BFF", g="#B266FF"),
    "life":   dict(b="#4CAF50", l="#A4E8A6", d="#2E6B30", o="#0F2A10", e="#FF6FA8", g="#FFD1E3"),
    "ocean":  dict(b="#2A9D8F", l="#86E3D6", d="#1B5E57", o="#07241F", e="#A8F0FF", g="#3FA9F5"),
}


def talisman(name, c):
    grid = from_ascii(TOTEM)
    if name == "demon":  # рога
        for x, y in ((3, 0), (4, 0), (4, 1), (12, 0), (11, 0), (11, 1)):
            grid[y][x] = H
    if name == "storm":  # молния на груди
        for x, y in ((8, 10), (7, 11), (8, 11), (8, 12)):
            grid[y][x] = E
    if name == "ice":  # кристаллы на плечах
        for x, y in ((1, 7), (14, 7)):
            grid[y][x] = L
    pal = {O: c["o"], B: c["b"], L: c["l"], D: c["d"], G: c["g"], E: c["e"], H: c.get("h", c["o"])}
    return render(grid, pal)


# ---------- оружие / инструменты ----------
def sword(pal):
    im = canvas()
    d = ImageDraw.Draw(im)
    d.line([(13, 2), (6, 9)], fill=B, width=3)
    d.line([(13, 1), (6, 8)], fill=L, width=1)
    d.line([(14, 2), (7, 9)], fill=D, width=1)
    d.point((14, 1), fill=L)
    d.line([(3, 8), (8, 13)], fill=G, width=2)
    d.line([(5, 10), (2, 13)], fill=H, width=1)
    d.point([(1, 14), (2, 14), (1, 13)], fill=P)
    return render(outline(to_grid(im)), pal)


def axe(pal):
    im = canvas()
    d = ImageDraw.Draw(im)
    d.polygon([(8, 1), (11, 4), (8, 7), (5, 9), (2, 7), (2, 3), (5, 1)], fill=B)
    d.line([(2, 3), (2, 7)], fill=L)
    d.line([(3, 2), (5, 1)], fill=L)
    d.line([(9, 3), (6, 7)], fill=D)
    d.line([(2, 14), (12, 4)], fill=H, width=1)
    d.point([(12, 4), (11, 5)], fill=G)
    return render(outline(to_grid(im)), pal)


def pickaxe(pal):
    im = canvas()
    d = ImageDraw.Draw(im)
    d.line([(2, 4), (5, 2), (9, 2), (12, 4), (13, 7), (13, 11)], fill=B, width=2)
    d.line([(3, 3), (5, 1), (9, 1), (13, 3)], fill=L, width=1)
    d.point([(2, 4), (3, 4), (13, 11), (12, 11)], fill=D)
    d.line([(2, 14), (10, 6)], fill=H, width=1)
    d.point([(10, 5), (11, 5)], fill=G)
    return render(outline(to_grid(im)), pal)


def shard(pal):
    im = canvas()
    d = ImageDraw.Draw(im)
    d.polygon([(8, 1), (12, 6), (9, 14), (5, 8)], fill=B)
    d.line([(8, 2), (6, 8)], fill=L)
    d.line([(11, 6), (9, 12)], fill=D)
    d.point([(8, 6), (9, 8)], fill=E)
    return render(outline(to_grid(im)), pal)


def heart(pal):
    im = canvas()
    d = ImageDraw.Draw(im)
    d.ellipse((2, 3, 8, 9), fill=B)
    d.ellipse((8, 3, 14, 9), fill=B)
    d.polygon([(2, 7), (14, 7), (8, 14)], fill=B)
    d.point([(4, 5), (5, 4), (4, 6)], fill=L)
    d.line([(9, 11), (11, 9)], fill=D)
    d.line([(8, 6), (8, 10)], fill=E)
    return render(outline(to_grid(im)), pal)


def coin(pal, star=False):
    im = canvas()
    d = ImageDraw.Draw(im)
    d.ellipse((2, 2, 13, 13), fill=B)
    d.ellipse((4, 4, 11, 11), outline=D)
    d.arc((2, 2, 13, 13), 160, 280, fill=L)
    if star:
        d.line([(7, 5), (7, 10)], fill=E)
        d.line([(5, 7), (10, 7)], fill=E)
        d.point([(8, 5), (8, 10), (5, 8), (10, 8), (8, 7), (7, 8), (8, 8)], fill=E)
    else:
        d.line([(7, 5), (7, 10)], fill=E)
        d.line([(8, 5), (8, 10)], fill=E)
    return render(outline(to_grid(im)), pal)


def book(pal):
    im = canvas()
    d = ImageDraw.Draw(im)
    d.rectangle((3, 2, 12, 13), fill=B)
    d.rectangle((3, 2, 4, 13), fill=D)
    d.line([(12, 3), (12, 12)], fill=L)
    d.rectangle((7, 6, 9, 8), fill=E)
    d.point([(8, 5), (8, 9), (6, 7), (10, 7)], fill=G)
    return render(outline(to_grid(im)), pal)


def P_(o, b, l, d, g="#000000", h="#000000", p="#000000", e="#FFFFFF"):
    return {O: o, B: b, L: l, D: d, G: g, H: h, P: p, E: e}


ITEMS = {
    "shadow_blade": (sword, P_("#120818", "#6A2FB0", "#C08CFF", "#2E0F5C", "#3B1A5E", "#2B1B10", "#F107A3"), True),
    "frostbite":    (sword, P_("#0E2A3B", "#7FD8F5", "#E8FBFF", "#3592C4", "#CFE9F5", "#4A6B82", "#FFFFFF"), True),
    "inferno_axe":  (axe, P_("#1E0A04", "#D2451E", "#FFB347", "#7A1E0C", "#FFD27A", "#3E2312"), True),
    "void_pickaxe": (pickaxe, P_("#08030F", "#4A1C7A", "#9E5CF0", "#1E0838", "#F107A3", "#1A1A2E"), True),
    "shadow_shard": (shard, P_("#0B0614", "#6B35B5", "#C69CFF", "#2D1252", e="#FF7BEF"), False),
    "demon_heart":  (heart, P_("#1A0505", "#B3161B", "#FF6B6B", "#5C0A0D", e="#FFB000"), False),
    "coin":         (lambda p: coin(p), P_("#3A2A05", "#E8B923", "#FFE57A", "#A67C12", e="#A67C12"), False),
    "shadowcoin":   (lambda p: coin(p, True), P_("#14061F", "#7B2FF7", "#C59BFF", "#3F128A", e="#F107A3"), False),
    "enchant_book": (book, P_("#14061F", "#5B2A9E", "#F0E6FF", "#2C0F57", "#FFD700", e="#F107A3"), False),
}


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def add_item(name, img, handheld):
    os.makedirs(os.path.join(NS, "textures", "item"), exist_ok=True)
    img.save(os.path.join(NS, "textures", "item", name + ".png"))
    write_json(os.path.join(NS, "models", "item", name + ".json"),
               {"parent": "minecraft:item/handheld" if handheld else "minecraft:item/generated",
                "textures": {"layer0": "shadowsmp:item/" + name}})
    write_json(os.path.join(NS, "items", name + ".json"),
               {"model": {"type": "minecraft:model", "model": "shadowsmp:item/" + name}})


# Базовый ванильный предмет для каждой текстуры (плагин ставит custom_model_data = "shadowsmp:<имя>")
BASE = {"shadow_blade": "netherite_sword", "frostbite": "diamond_sword", "inferno_axe": "netherite_axe",
        "void_pickaxe": "netherite_pickaxe", "enchant_book": "enchanted_book"}


def base_of(name):
    if name.startswith("talisman_"):
        return "totem_of_undying"
    return BASE.get(name, "paper")


def write_vanilla_overrides(names):
    by_base = {}
    for n in names:
        by_base.setdefault(base_of(n), []).append(n)
    for base, ns in by_base.items():
        write_json(os.path.join(PACK, "assets", "minecraft", "items", base + ".json"), {"model": {
            "type": "minecraft:select",
            "property": "minecraft:custom_model_data",
            "index": 0,
            "cases": [{"when": "shadowsmp:" + n, "model": {"type": "minecraft:model", "model": "shadowsmp:item/" + n}} for n in ns],
            "fallback": {"type": "minecraft:model", "model": "minecraft:item/" + base}}})


def main():
    if os.path.exists(PACK):
        shutil.rmtree(PACK)
    os.makedirs(NS)
    write_json(os.path.join(PACK, "pack.mcmeta"), {"pack": {
        "description": "§5§lShadowSMP §7— кастомные предметы",
        "pack_format": 75, "min_format": 75, "max_format": 75}})
    for name, c in TALISMANS.items():
        add_item("talisman_" + name, talisman(name, c), False)
    for name, (fn, pal, hand) in ITEMS.items():
        add_item(name, fn(pal), hand)
    write_vanilla_overrides(["talisman_" + n for n in TALISMANS] + list(ITEMS))
    # иконка пака и сервера
    icon = talisman("shadow", TALISMANS["shadow"]).resize((128, 128), Image.NEAREST)
    bg = Image.new("RGBA", (128, 128))
    for y in range(128):
        for x in range(128):
            t = (x + y) / 254
            bg.putpixel((x, y), (int(0x2A + (0x7B - 0x2A) * t), int(0x08 + (0x10 - 0x08) * t), int(0x45 + (0xA3 - 0x45) * t), 255))
    bg.alpha_composite(icon)
    bg.save(os.path.join(PACK, "pack.png"))
    server_dir = os.path.join(ROOT, "server")
    os.makedirs(server_dir, exist_ok=True)
    bg.resize((64, 64), Image.NEAREST).save(os.path.join(server_dir, "server-icon.png"))
    # превью всех текстур (для README)
    files = sorted(f for f in os.listdir(os.path.join(NS, "textures", "item")))
    prev = Image.new("RGBA", (len(files) * 72, 72), (24, 16, 36, 255))
    for i, f in enumerate(files):
        im = Image.open(os.path.join(NS, "textures", "item", f)).resize((64, 64), Image.NEAREST)
        prev.alpha_composite(im, (i * 72 + 4, 4))
    prev.save(os.path.join(ROOT, "resourcepack", "preview.png"))
    # zip (детерминированный)
    if os.path.exists(ZIP):
        os.remove(ZIP)
    with zipfile.ZipFile(ZIP, "w", zipfile.ZIP_DEFLATED) as z:
        for base, _, fs in sorted(os.walk(PACK)):
            for f in sorted(fs):
                full = os.path.join(base, f)
                info = zipfile.ZipInfo(os.path.relpath(full, PACK).replace(os.sep, "/"), (2025, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                with open(full, "rb") as fh:
                    z.writestr(info, fh.read())
    sha1 = hashlib.sha1(open(ZIP, "rb").read()).hexdigest()
    print("Ресурспак:", ZIP)
    print("SHA-1:", sha1)


if __name__ == "__main__":
    main()
