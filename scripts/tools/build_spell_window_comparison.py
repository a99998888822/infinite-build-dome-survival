"""Build nearest-neighbor detail crops from actual GPU screenshots."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/reports/spell_window_resolution"
FONT = "C:/Windows/Fonts/msyh.ttc"
title = ImageFont.truetype(FONT, 26)
small = ImageFont.truetype(FONT, 17)
rows = [
    ("\u5149\u8f89\u5251\uff1aPNG\u5251\u5203\u4e0e\u62a4\u624b", (360, 684)),
    ("\u7ed3\u971c\uff1aPNG\u7ec6\u5c0f\u96ea\u6676", (1498, 446)),
    ("\u6c34\u6d41\uff1a\u7a0b\u5e8f3px\u8272\u5757", (310, 423)),
]
sheet = Image.new("RGB", (1080, 1090), "#121919")
d = ImageDraw.Draw(sheet)
d.text((24, 14), "\u5b9e\u673a\u5c40\u90e8\u5bf9\u6bd4\uff1a\u6bcf\u4e2a\u622a\u56fe\u50cf\u7d20\u653e\u59273\u500d", font=title, fill="#d9f4e5")
d.text((24, 52), "\u540c\u4e00\u903b\u8f91\u533a\u57df\uff1b\u4e0d\u540c\u7a97\u53e3\u7684\u5b9e\u9645\u50cf\u7d20\u6570\u4e0d\u540c", font=small, fill="#9fb6aa")
for row, (label, (x, y)) in enumerate(rows):
    top = 90 + row * 330
    d.text((24, top), label, font=small, fill="#b8daca")
    for col, (w, h) in enumerate([(1280,720), (1920,1080), (2560,1440)]):
        scale = w / 1920
        box = tuple(round(v * scale) for v in (x, y, x+64, y+64))
        with Image.open(OUT / f"window_{w}x{h}.png") as source:
            crop = source.convert("RGB").crop(box)
        crop = crop.resize((crop.width*3, crop.height*3), Image.Resampling.NEAREST)
        d.text((col*360+24, top+30), f"{w} x {h}", font=small, fill="#e3e8e6")
        sheet.paste(crop, (col*360+(360-crop.width)//2, top+66+(258-crop.height)//2))
sheet.save(OUT / "pixel_details.png")
print(OUT / "pixel_details.png")
