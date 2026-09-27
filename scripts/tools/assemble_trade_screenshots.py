"""Crop and group actual Godot captures; never paint over the game UI."""
from pathlib import Path
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "artifacts/reviews/ui/goblin_trade/all_five"
FONT = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 19)
ENTRIES = [
    ("01_deposit_offer", "1  存款获得强力刷新"),
    ("11_principal_offer", "2  增加本金，直接开战"),
    ("04_cash_offer", "3  获得金币，关闭银行"),
    ("08_interest_offer", "4  提高利率，持续扣除理智"),
    ("06_spending_offer", "5  获得金币，本次不可存款"),
    ("04_small_cash_offer", "6  小窗口实际效果（640×360）"),
]


def main():
    width, height, gap, header = 480, 432, 16, 38
    sheet = Image.new("RGB", (width * 2 + gap * 3, (height + header) * 3 + gap * 4), "#151a17")
    draw = ImageDraw.Draw(sheet)
    for index, (name, title) in enumerate(ENTRIES):
        source = Image.open(OUT / f"{name}.png").convert("RGB")
        if index < 5:
            cropped = source.crop((16, 72, 496, 504))
            source.crop((12, 68, 820, 714)).save(OUT / f"{name}_finance.png")
        else:
            cropped = Image.new("RGB", (width, height), "#151a17")
            small = source.resize((480, 270), Image.Resampling.LANCZOS)
            cropped.paste(small, (0, 70))
        x = gap + (index % 2) * (width + gap)
        y = gap + (index // 2) * (height + header + gap)
        draw.text((x + 3, y + 4), title, font=FONT, fill="#e4d7aa")
        sheet.paste(cropped, (x, y + header))
    sheet.save(OUT / "five_trades_overview.png")

    frames = []
    for path in sorted((OUT / "refresh_frames").glob("*.png")):
        # Include the actual refresh and next-wave buttons with their surroundings.
        frames.append(Image.open(path).convert("RGB").crop((636, 602, 812, 704)).resize((352, 204), Image.Resampling.NEAREST))
    if frames:
        frames[0].save(OUT / "strong_refresh_button.gif", save_all=True, append_images=frames[1:], duration=110, loop=0)
    print(f"ASSEMBLED {len(ENTRIES)} screenshot tiles and {len(frames)} animation frames")


if __name__ == "__main__":
    main()
