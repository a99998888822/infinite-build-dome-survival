"""Build the production nightwatch spear icon and sprite from authored pixel geometry."""
from __future__ import annotations

import json
import math
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
ICON = ROOT / "assets/ui/icons/weapons/weapon_nightwatch_spear.png"
WORLD = ROOT / "assets/sprites/weapons/weapon_nightwatch_spear.png"
P = {"ink": "#10191d", "wood": "#3d4546", "wood_hi": "#7a8176",
     "steel_lo": "#304a55", "steel": "#637f86", "silver": "#a9bfba", "edge": "#e1e8d3",
     "brass_lo": "#554834", "brass": "#9c8652", "brass_hi": "#c8b677",
     "cloth": "#243e43", "cloth_hi": "#47716b", "rune": "#729587"}


def draw_spear(canvas, transform):
    d = ImageDraw.Draw(canvas)
    def poly(points, color, outline=None):
        d.polygon([transform(u, v) for u, v in points], fill=color, outline=outline)
    def line(points, color, width=1):
        d.line([transform(u, v) for u, v in points], fill=color, width=width)

    # Ash-black pole and steel butt spike.
    poly([(-37,-2),(19,-2),(19,2),(-37,2)], P["ink"])
    line([(-35,-1),(18,-1)], P["wood_hi"])
    line([(-35,0),(18,0)], P["wood"])
    line([(-35,1),(18,1)], "#242e32")
    poly([(-40,0),(-36,-3),(-32,-2),(-32,2),(-36,3)], P["steel_lo"], P["ink"])
    line([(-38,0),(-35,-2),(-33,-1)], P["silver"])
    # Worn blue-green cloth grip.
    poly([(-28,-3),(-10,-3),(-9,3),(-28,3)], P["cloth"], P["ink"])
    for u in range(-26,-9,4):
        line([(u,-2),(u+2,2)], P["cloth_hi"])
    for u in [-29,-10,9]:
        poly([(u,-3),(u+2,-3),(u+2,3),(u,3)], P["brass_lo"], P["ink"])
        line([(u,-2),(u+1,-2)], P["brass_hi"])
        line([(u+1,-1),(u+1,2)], P["brass"])
    # Short ceremonial binding; silhouette remains a spear, not a flag.
    poly([(12,2),(11,6),(4,9),(6,5),(2,6),(7,2)], P["cloth"], P["ink"])
    line([(12,3),(9,6),(5,8)], P["cloth_hi"])
    # Small backward-facing wings and a long leaf-shaped blade.
    poly([(15,-2),(12,-7),(16,-5),(20,-2),(20,2),(16,5),(12,7),(15,2)], P["steel_lo"], P["ink"])
    line([(13,-6),(16,-4),(19,-2)], P["silver"])
    poly([(16,0),(21,-6),(28,-5),(39,0),(28,5),(21,6)], P["steel"], P["ink"])
    poly([(18,0),(22,-4),(28,-4),(37,0),(24,0)], P["silver"])
    poly([(19,1),(27,1),(36,0),(28,4),(22,4)], P["steel_lo"])
    line([(21,-5),(28,-4),(37,-1),(39,0)], P["edge"])
    line([(19,0),(37,0)], P["edge"])
    line([(23,4),(28,4),(34,2)], P["steel"])
    # Restrained eldritch eye engraved in the collar, no glow halo.
    poly([(18,-1),(20,-3),(23,-1),(20,1)], P["brass_lo"])
    line([(19,-1),(20,-2),(22,-1),(20,0),(19,-1)], P["rune"])
    d.point(transform(20,-1), fill=P["ink"])



def main():
    icon = Image.new("RGBA", (64, 64))
    angle = math.radians(-45)
    draw_spear(icon, lambda u, v: (round(32 + u * math.cos(angle) - v * math.sin(angle)), round(32 + u * math.sin(angle) + v * math.cos(angle))))
    world = Image.new("RGBA", (248, 28))
    draw_spear(world, lambda u, v: (round(4 + (u + 40) * 3.0), round(13 + v)))
    for image, path in ((icon, ICON), (world, WORLD)):
        assert set(image.getchannel("A").tobytes()) == {0, 255}
        assert len({pixel[:3] for _, pixel in image.getcolors(image.width * image.height) if pixel[3]}) <= 16
        path.parent.mkdir(parents=True, exist_ok=True)
        image.save(path)
    print(json.dumps({"icon": str(ICON), "sprite": str(WORLD), "method": "existing authored pixel geometry", "sizes": [icon.size, world.size]}))


if __name__ == "__main__":
    main()
