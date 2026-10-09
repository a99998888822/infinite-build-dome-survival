"""Original pixel artwork authored by the current coding model; no image API.

Draw on a 64px grid, export a 128px RGBA master and a 48px combat sprite.
Layered geometry and individually placed wear marks are the editable source.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "artifacts/previews/vault_redraw"
ASSETS = ROOT / "assets/ui/finance"
P = {
    "ink": "#17151d", "deep": "#23252b", "shadow": "#303238",
    "iron_dark": "#35423f", "iron": "#495750", "iron_mid": "#58665d",
    "iron_light": "#718274", "iron_edge": "#929b82", "patina": "#506b5d",
    "patina_light": "#789585", "purple": "#443c49", "wear": "#6b6766",
    "brass_dark": "#534536", "brass_shadow": "#71604a", "brass": "#96805a",
    "brass_light": "#b6a078", "brass_edge": "#d2bd92", "brass_glint": "#e0d0ab",
    "rust": "#684b40", "rust_dark": "#433731", "steel": "#88877c",
    "steel_light": "#b4b3a0",
}
im = Image.new("RGBA", (64, 64))
d = ImageDraw.Draw(im)


def poly(points, color):
    d.polygon(points, fill=P[color])


def rect(box, color):
    d.rectangle(box, fill=P[color])


def line(points, color, width=1):
    d.line(points, fill=P[color], width=width)


def rivet(x, y, bright=False):
    rect((x, y, x + 2, y + 2), "ink")
    rect((x, y, x + 1, y + 1), "brass_light" if bright else "steel")
    rect((x + 1, y + 1, x + 1, y + 1), "brass_shadow" if bright else "iron_dark")


# Two heavy feet, joined visually to the base; no decorative ground shadow.
poly([(10, 49), (18, 50), (18, 58), (15, 60), (9, 59), (8, 56)], "ink")
poly([(10, 54), (16, 55), (16, 58), (10, 57)], "iron_dark")
line([(10, 54), (15, 54)], "iron_light")
poly([(40, 53), (49, 49), (51, 50), (50, 56), (45, 60), (40, 60)], "ink")
poly([(43, 54), (48, 52), (48, 55), (44, 58), (42, 58)], "shadow")
line([(43, 54), (48, 51)], "wear")

# The irregular outline is deliberately stepped instead of antialiased.
poly([(8, 14), (20, 6), (23, 5), (53, 8), (57, 11), (57, 46),
      (55, 50), (45, 58), (40, 59), (9, 55), (6, 52), (6, 18)], "ink")
poly([(9, 15), (22, 7), (52, 10), (54, 12), (43, 20)], "iron_light")
poly([(13, 15), (23, 9), (48, 12), (41, 17)], "iron_mid")
poly([(17, 14), (24, 10), (42, 12), (36, 14)], "iron")
line([(10, 15), (23, 7), (51, 10)], "iron_edge")
line([(24, 8), (48, 10)], "patina_light")
poly([(44, 20), (55, 12), (55, 47), (44, 56)], "iron_dark")
poly([(48, 22), (53, 18), (53, 43), (48, 47)], "shadow")
poly([(50, 22), (53, 20), (53, 37), (51, 38)], "iron")
line([(55, 14), (55, 46), (45, 55)], "deep")
line([(46, 24), (46, 49)], "iron_mid")
line([(53, 25), (53, 32)], "patina")
line([(49, 43), (51, 41), (53, 41)], "purple")

# Front slab with a heavy black door recess and broad tonal planes.
poly([(9, 17), (42, 20), (42, 56), (9, 52), (8, 49), (8, 20)], "iron")
poly([(10, 18), (40, 21), (40, 25), (13, 23), (13, 49), (10, 49)], "iron_mid")
line([(9, 18), (9, 49), (12, 52), (40, 55)], "iron_light")
line([(12, 19), (39, 22)], "iron_edge")
poly([(15, 23), (37, 25), (39, 27), (39, 49), (36, 52), (15, 50),
      (12, 47), (12, 26)], "ink")
poly([(16, 25), (36, 27), (37, 29), (37, 48), (35, 50), (16, 48),
      (14, 46), (14, 28)], "brass_dark")
poly([(17, 26), (34, 28), (35, 30), (35, 47), (17, 46), (16, 44), (16, 29)], "iron_dark")
poly([(17, 27), (33, 29), (33, 34), (28, 34), (23, 40), (17, 39)], "iron")
poly([(17, 41), (22, 41), (29, 47), (17, 46)], "shadow")
line([(16, 26), (35, 28), (36, 30)], "brass")
line([(15, 29), (15, 43)], "brass_shadow")
line([(18, 48), (34, 50), (37, 47)], "deep")

# Four battered brass brackets bind the frame, rather than a uniform gold rim.
poly([(7, 17), (9, 14), (18, 15), (18, 20), (13, 20), (13, 25),
      (7, 24)], "ink")
poly([(8, 17), (10, 15), (17, 16), (17, 18), (11, 18), (11, 23), (8, 22)], "brass")
line([(10, 15), (16, 16)], "brass_edge")
line([(8, 18), (8, 21)], "brass_light")
rect((12, 18, 15, 18), "brass_shadow")
rivet(9, 18, True)

poly([(35, 17), (44, 18), (49, 14), (51, 17), (46, 22), (46, 28),
      (40, 29), (40, 23), (35, 22)], "ink")
poly([(36, 18), (43, 19), (48, 16), (49, 17), (44, 22), (44, 27),
      (41, 27), (41, 22), (36, 21)], "brass_shadow")
line([(36, 18), (43, 19), (48, 16)], "brass_light")
rect((36, 19, 40, 20), "brass")
line([(41, 22), (41, 25)], "brass_light")
rivet(41, 20, True)

poly([(7, 45), (13, 45), (13, 50), (20, 50), (20, 55), (10, 54), (7, 51)], "ink")
poly([(8, 46), (11, 46), (11, 51), (18, 52), (18, 54), (10, 53), (8, 51)], "brass_shadow")
line([(8, 46), (10, 46), (10, 51), (16, 52)], "brass_light")
rivet(9, 49, True)
poly([(36, 49), (41, 49), (41, 46), (46, 45), (46, 52), (42, 56), (36, 55)], "ink")
poly([(38, 51), (42, 51), (42, 47), (44, 47), (44, 52), (41, 54), (38, 54)], "brass_shadow")
line([(38, 51), (41, 51), (41, 48)], "brass")
rivet(41, 51, True)

# Side reinforcing strap and small lock bolts.
poly([(47, 31), (55, 25), (55, 29), (47, 35)], "ink")
line([(48, 31), (54, 27)], "brass_shadow", 2)
line([(49, 30), (54, 26)], "brass")
rivet(51, 28)
line([(48, 18), (51, 16)], "patina_light")

# Hinge blocks project over the left door seam.
for y in (27, 42):
    poly([(7, y), (17, y + 1), (19, y + 3), (17, y + 6), (7, y + 5), (5, y + 3)], "ink")
    poly([(7, y + 1), (16, y + 2), (17, y + 3), (16, y + 4), (7, y + 4)], "wear")
    line([(7, y + 1), (15, y + 2)], "steel")
    rect((7, y + 2, 9, y + 3), "shadow")
    rect((14, y + 2, 15, y + 4), "brass_dark")
    rect((13, y + 2, 13, y + 3), "steel_light")

# Large machined circular lock, pixel octagons with a weathered segmented rim.
poly([(25, 27), (30, 27), (35, 30), (38, 35), (38, 40), (35, 45),
      (30, 48), (25, 47), (20, 44), (18, 40), (18, 34), (21, 30)], "ink")
poly([(25, 29), (30, 29), (34, 32), (36, 35), (36, 40), (33, 44),
      (29, 46), (25, 45), (21, 42), (20, 38), (20, 35), (22, 31)], "brass_shadow")
line([(20, 37), (21, 34), (24, 30), (29, 29), (33, 31)], "brass_light", 2)
line([(22, 32), (25, 30), (28, 30)], "brass_edge")
line([(35, 34), (36, 36), (36, 39), (33, 43), (29, 45), (26, 44)], "brass_dark", 2)
line([(23, 43), (26, 45), (29, 45)], "brass")
poly([(25, 32), (29, 32), (32, 34), (34, 37), (33, 41), (30, 43),
      (26, 42), (23, 40), (22, 37), (23, 34)], "ink")
poly([(25, 33), (29, 33), (31, 35), (32, 37), (31, 40), (29, 41),
      (26, 40), (24, 38), (24, 35)], "iron_light")
poly([(26, 35), (29, 34), (31, 36), (31, 39), (29, 40), (26, 39)], "iron_dark")

# Three short spokes and hub; the wheel reads even after reduction to 48px.
line([(27, 37), (27, 32)], "ink", 3)
line([(27, 37), (23, 39)], "ink", 3)
line([(27, 37), (32, 40)], "ink", 3)
line([(27, 35), (27, 32)], "steel_light")
line([(27, 36), (27, 33)], "steel")
line([(25, 38), (23, 39)], "steel_light")
line([(29, 38), (32, 40)], "steel", 2)
rect((26, 35, 29, 38), "ink")
rect((26, 35, 28, 37), "brass_light")
rect((27, 36, 28, 37), "brass_shadow")
rect((26, 35, 26, 35), "brass_glint")

# Sparse purposeful corrosion and chips follow material edges, never the alpha.
line([(21, 11), (24, 11), (24, 12), (28, 12)], "patina_light")
line([(34, 13), (37, 13), (38, 12)], "iron_dark")
rect((45, 12, 48, 12), "wear")
line([(18, 22), (22, 22), (22, 23)], "rust_dark")
rect((19, 22, 20, 22), "rust")
line([(30, 24), (33, 24)], "patina_light")
rect((36, 26, 37, 26), "rust")
line([(10, 35), (10, 38)], "patina")
rect((11, 37, 11, 39), "patina_light")
rect((16, 35, 16, 37), "iron_edge")
line([(39, 32), (39, 34)], "iron_light")
line([(38, 44), (38, 46)], "rust")
line([(23, 52), (25, 53), (28, 53)], "patina")
line([(26, 51), (30, 51)], "iron_light")
rect((33, 53, 34, 53), "rust_dark")
line([(49, 39), (49, 41)], "rust")
line([(52, 34), (52, 37)], "iron_mid")
rect((52, 35, 52, 35), "patina_light")
rect((21, 41, 21, 41), "brass_light")
rect((33, 32, 33, 32), "brass_glint")
rect((32, 44, 32, 44), "rust")

OUT.mkdir(parents=True, exist_ok=True)
ASSETS.mkdir(parents=True, exist_ok=True)
im.save(OUT / "vault_grid_64.png")
master = im.resize((128, 128), Image.Resampling.NEAREST)
master.save(OUT / "challenge_vault_painted.png")
master.save(ASSETS / "challenge_vault_painted.png")
# Re-center the opaque area in an explicit 48px canvas, preserving its ratio.
body = im.crop(im.getbbox())
body.thumbnail((42, 44), Image.Resampling.NEAREST)
combat = Image.new("RGBA", (48, 48))
combat.alpha_composite(body, ((48 - body.width) // 2, (48 - body.height) // 2))
combat.save(OUT / "challenge_vault_world.png")
combat.save(ASSETS / "challenge_vault_world.png")

# Review against a plain project-colored surface; this is art, not a screenshot.
preview = Image.new("RGB", (512, 512), "#27272f")
preview.paste(master.resize((512, 512), Image.Resampling.NEAREST), (0, 0),
              master.resize((512, 512), Image.Resampling.NEAREST))
preview.save(OUT / "vault_art_preview.png")
manifest = {
    "provenance": "Original artwork directly authored by the current coding model through local pixel drawing; no external image model or API.",
    "editable_source": "scripts/tools/source_art/challenge_vault.py", "grid": [64, 64], "palette": P,
    "references": ["assets/ui/icons/relics/relic_steel_vault.png",
                   "assets/ui/icons/relics/relic_coin_heart.png",
                   "assets/ui/main_menu/bg_main_menu.png",
                   "assets/ui/character_select/background.png",
                   "assets/ui/finance/finance_background.png"],
    "assets": {},
}
for name in ("challenge_vault_painted.png", "challenge_vault_world.png"):
    p = ASSETS / name
    a = Image.open(p).convert("RGBA")
    manifest["assets"][name] = {
        "path": str(p.relative_to(ROOT)).replace("\\", "/"),
        "size": list(a.size), "bbox": list(a.getbbox()),
        "colors": len({pixel[:3] for pixel in a.getdata() if pixel[3]}),
        "alpha": sorted(set(a.getchannel("A").getdata())),
        "sha256": hashlib.sha256(p.read_bytes()).hexdigest(),
    }
(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
print(json.dumps(manifest["assets"], indent=2))
