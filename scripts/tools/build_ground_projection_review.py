"""Assemble labeled crops of the eight real GPU screenshots, without retouching."""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/previews/ground_projection_20261012"
FONT = "C:/Windows/Fonts/msyh.ttc"


def build():
    report = json.loads((OUT / "review.json").read_text(encoding="utf-8"))
    title_font = ImageFont.truetype(FONT, 27)
    card_font = ImageFont.truetype(FONT, 22)
    note_font = ImageFont.truetype(FONT, 17)
    for sheet_index, heading in enumerate(["指示器与危险预警", "落地冲击与元素扩散"]):
        sheet = Image.new("RGB", (1408, 1092), "#14201d")
        draw = ImageDraw.Draw(sheet)
        draw.text((24, 14), heading + "  /  145∶220 地面投影", font=title_font, fill="#e5eee5")
        draw.text((24, 55), "正式战斗场景关键帧裁切 · 小标记附等比放大细节 · 原始完整截图另附", font=note_font, fill="#a4bbb0")
        for index, sample in enumerate(report["samples"][sheet_index * 4:sheet_index * 4 + 4]):
            original = Image.open(OUT / sample["file"]).convert("RGB")
            # Identical 1:1 pixel crops. No perspective edits or color changes.
            scene = original.crop((304, 80, 976, 536))
            x = 24 + (index % 2) * 688
            y = 88 + (index // 2) * 500
            draw.rectangle((x, y, x + 671, y + 483), fill="#21342c")
            draw.text((x + 12, y + 3), sample["title"], font=card_font, fill="#ecf4ed")
            sheet.paste(scene, (x, y + 32))
            if sample["file"].startswith(("01_", "02_")):
                box = (494, 345, 550, 389) if sample["file"].startswith("01_") else (652, 422, 708, 466)
                inset = original.crop(box).resize((224, 176), Image.Resampling.NEAREST)
                ix, iy = x + 14, y + 70
                sheet.paste(inset, (ix, iy))
                draw.rectangle((ix - 1, iy - 1, ix + 224, iy + 176), outline="#9cae8e", width=2)
                draw.text((ix + 4, iy + 3), "局部 ×4", font=note_font, fill="#ffffff", stroke_width=2, stroke_fill="#102019")
        sheet.save(OUT / ("review_indicators.png" if sheet_index == 0 else "review_effects.png"))
    print("Saved two review sheets from 8 production GPU screenshots.")


if __name__ == "__main__":
    build()
