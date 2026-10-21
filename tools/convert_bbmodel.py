"""Converts model_src/pitbike.bbmodel (Blockbench free/mesh model) into mod resources:
geometry JSON, animation JSON, texture atlas and an item icon.

Usage: python3 tools/convert_bbmodel.py
"""
import base64
import io
import json
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "model_src", "pitbike.bbmodel")
ASSETS = os.path.join(ROOT, "src", "main", "resources", "assets", "pitbike")

# Blockbench group uuid -> bone id used by the mod
BONE_IDS = {
    "3cd4060e-be5f-543b-82c4-274f41a76218": "root",
    "794b9dd0-367e-58c0-9951-9d3446541a37": "body",
    "b34a52c0-2fb0-52c4-94ef-8460abb8ebf0": "frame",
    "fd614b49-a250-5116-9d56-51e0a2c41365": "engine",
    "807b857d-53d2-5955-ae91-57bc12b82e3d": "seat",
    "2ba5c77e-e261-57ed-9891-e4ac293d133f": "fork",
    "fc35659d-234c-56d1-af27-5c5f41fe3073": "fork_travel",
    "0323f5cf-5e17-5271-8673-57f8759c7117": "front_wheel",
    "c09d01f7-0ec0-5a71-9c6a-4a87d37f6bd8": "front_wheel_spin",
    "11681d03-ae39-5d32-b4f5-951b0d893c17": "exhaust",
    "c1ad5ec3-e8a8-5211-9c71-3cbacb93dff2": "swingarm",
    "11ecaf9a-831e-5bb6-bdb3-a3be213290cf": "rear_wheel",
    "a4c89552-9895-5cd8-8fbd-cc54247d9d60": "rear_wheel_spin",
    "4bbea7fd-ccb2-5780-afb0-e1477c226c1a": "shock",
}

TILE = 16
ATLAS_COLS = 16


def sub(a, b):
    return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]


def cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def norm(a):
    length = math.sqrt(dot(a, a))
    return [c / length for c in a] if length > 1e-9 else [0.0, 1.0, 0.0]


def sorted_quad(verts, pos):
    """Same vertex ordering Blockbench uses for rendering mesh quads (MeshFace.getSortedVertices)."""

    def other_side(base1, base2, top, check):
        d = sub(base2, base1)
        t = dot(sub(top, base1), d) / dot(d, d)
        closest = [base1[i] + d[i] * t for i in range(3)]
        n = sub(closest, top)
        return dot(n, sub(check, base2)) > 0

    p = [pos[v] for v in verts]
    if other_side(p[1], p[2], p[0], p[3]):
        return [verts[2], verts[0], verts[1], verts[3]]
    if other_side(p[0], p[1], p[2], p[3]):
        return [verts[0], verts[2], verts[1], verts[3]]
    return list(verts)


def main():
    with open(SRC, encoding="utf-8") as f:
        model = json.load(f)

    textures = model["textures"]
    rows = math.ceil(len(textures) / ATLAS_COLS)
    atlas_w = ATLAS_COLS * TILE
    atlas_h = 1 << math.ceil(math.log2(rows * TILE))
    atlas = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))
    tile_colors = []
    for i, tex in enumerate(textures):
        data = base64.b64decode(tex["source"].split(",", 1)[1])
        img = Image.open(io.BytesIO(data)).convert("RGBA").resize((TILE, TILE))
        atlas.paste(img, ((i % ATLAS_COLS) * TILE, (i // ATLAS_COLS) * TILE))
        tile_colors.append(img.resize((1, 1), Image.BOX).getpixel((0, 0))[:3])

    uv_scale = [TILE / t["uv_width"] for t in textures]
    elements = {e["uuid"]: e for e in model["elements"]}
    flat_faces = []  # for the item icon

    def convert_element(e):
        origin = e["origin"]
        pos = {k: [origin[i] + v[i] for i in range(3)] for k, v in e["vertices"].items()}
        quads = []
        for face in e["faces"].values():
            verts = face["vertices"]
            if len(verts) == 4:
                verts = sorted_quad(verts, pos)
            elif len(verts) == 3:
                verts = verts + [verts[2]]
            else:
                continue
            tex = face["texture"]
            n = norm(cross(sub(pos[verts[1]], pos[verts[0]]), sub(pos[verts[2]], pos[verts[0]])))
            if n == [0.0, 1.0, 0.0] and len(set(verts)) == 4:
                n = norm(cross(sub(pos[verts[2]], pos[verts[0]]), sub(pos[verts[3]], pos[verts[0]])))
            col, row = tex % ATLAS_COLS, tex // ATLAS_COLS
            q = []
            for v in verts:
                u, vv = face["uv"][v]
                q += [round(c, 5) for c in pos[v]]
                q += [round((col * TILE + u * uv_scale[tex]) / atlas_w, 6),
                      round((row * TILE + vv * uv_scale[tex]) / atlas_h, 6)]
            q += [round(c, 5) for c in n]
            quads.append(q)
            flat_faces.append(([pos[v] for v in verts], n, tile_colors[tex]))
        return quads

    def convert_group(g):
        bone = {
            "name": BONE_IDS[g["uuid"]],
            "pivot": g["origin"],
            "rotation": g.get("rotation", [0, 0, 0]),
            "quads": [],
            "children": [],
        }
        for child in g["children"]:
            if isinstance(child, str):
                bone["quads"] += convert_element(elements[child])
            else:
                bone["children"].append(convert_group(child))
        return bone

    bones = [convert_group(g) for g in model["outliner"] if isinstance(g, dict)]
    geo = {"texture_width": atlas_w, "texture_height": atlas_h, "bones": bones}

    # Animations: values are stored already converted to the transform that gets applied
    # (Blockbench applies rotation as -x, -y, +z degrees and position as -x, +y, +z pixels).
    anims = {}
    for a in model["animations"]:
        out_bones = {}
        for uuid, animator in a["animators"].items():
            channels = {}
            for kf in animator["keyframes"]:
                dp = kf["data_points"][0]
                x, y, z = (float(dp[k]) for k in "xyz")
                if kf["channel"] == "rotation":
                    val = [-math.radians(x), -math.radians(y), math.radians(z)]
                elif kf["channel"] == "position":
                    val = [-x, y, z]
                else:
                    val = [x, y, z]
                channels.setdefault(kf["channel"], []).append(
                    [round(kf["time"], 5)] + [round(c, 6) for c in val] + [1 if kf["interpolation"] == "step" else 0])
            for frames in channels.values():
                frames.sort(key=lambda f: f[0])
            out_bones[BONE_IDS[uuid]] = channels
        anims[a["name"]] = {"length": a["length"], "loop": a["loop"] == "loop", "bones": out_bones}

    os.makedirs(os.path.join(ASSETS, "geo"), exist_ok=True)
    os.makedirs(os.path.join(ASSETS, "animations"), exist_ok=True)
    os.makedirs(os.path.join(ASSETS, "textures", "entity"), exist_ok=True)
    os.makedirs(os.path.join(ASSETS, "textures", "item"), exist_ok=True)
    with open(os.path.join(ASSETS, "geo", "pitbike.json"), "w", encoding="utf-8") as f:
        json.dump(geo, f, separators=(",", ":"))
    with open(os.path.join(ASSETS, "animations", "pitbike.json"), "w", encoding="utf-8") as f:
        json.dump(anims, f, separators=(",", ":"))
    atlas.save(os.path.join(ASSETS, "textures", "entity", "pitbike.png"))

    # Item icon: side view (from -X, the exhaust side) with simple painter's sort and lambert shading.
    size, scale = 32, 4
    big = Image.new("RGBA", (size * scale, size * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(big)
    pts = [p for poly, _, _ in flat_faces for p in poly]
    zmin, zmax = min(p[2] for p in pts), max(p[2] for p in pts)
    ymin, ymax = min(p[1] for p in pts), max(p[1] for p in pts)
    k = (size - 2) * scale / max(zmax - zmin, ymax - ymin)
    ox = (size * scale - (zmax - zmin) * k) / 2
    oy = (size * scale - (ymax - ymin) * k) / 2
    light = norm([-0.6, 0.8, 0.3])
    for poly, n, color in sorted(flat_faces, key=lambda f: -sum(p[0] for p in f[0]) / 4):
        if n[0] > 0.05:
            continue
        shade = 0.55 + 0.45 * max(0.0, dot(n, light))
        c = tuple(min(255, int(ch * shade)) for ch in color) + (255,)
        draw.polygon([(ox + (zmax - p[2]) * k, oy + (ymax - p[1]) * k) for p in poly], fill=c)
    big.resize((size, size), Image.LANCZOS).save(os.path.join(ASSETS, "textures", "item", "pitbike.png"))

    total = sum(1 for _ in flat_faces)
    print(f"atlas {atlas_w}x{atlas_h}, {total} quads, animations: {list(anims)}")


if __name__ == "__main__":
    main()
