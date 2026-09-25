"""Assemble actual Godot viewport frames; only crop/label, never redraw combat."""
from pathlib import Path
import argparse
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/meteor_flail_implementation"
LABELS = {
    "base": "原版：距离与节奏",
    "split": "分裂：追加两次弱化挥击",
    "split_lightning": "分裂 + 闪电链",
    "split_fire": "分裂 + 火焰",
}
FONT = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 19)
SMALL = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 14)


def make(variants, destination):
    reports = [json.loads((OUT / name / "capture.json").read_text(encoding="utf-8")) for name in variants]
    assert all(report["valid"] and report["production"] for report in reports)
    rendered = []
    # 15 fps with the original eight-second timing. Crop follows the fixed screen
    # center (the production camera follows the player), retaining full flail reach.
    for index in range(0, 240, 2):
        canvas = Image.new("RGB", (512 * len(variants), 456), "#111c20")
        draw = ImageDraw.Draw(canvas)
        for column, variant in enumerate(variants):
            with Image.open(OUT / variant / f"frame_{index:04d}.png") as source:
                crop = source.convert("RGB").crop((384, 192, 896, 592))
            canvas.paste(crop, (column * 512, 40))
            draw.text((column * 512 + 14, 9), LABELS[variant], font=FONT, fill="#d5e8e8")
            draw.line((column * 512, 39, (column + 1) * 512, 39), fill="#55746f")
        draw.text((14, 439), "正式游戏实录 · 演示敌人血量 240 · 真实碰撞与附魔", font=SMALL, fill="#94aba7")
        rendered.append(canvas)
    # A shared palette avoids per-frame color shimmer and keeps sharp square pixels.
    atlas = Image.new("RGB", (rendered[0].width, rendered[0].height * 12))
    for row, frame in enumerate(rendered[::10]):
        atlas.paste(frame, (0, row * frame.height))
    palette = atlas.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    frames = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in rendered]
    durations = [70 if i % 3 != 2 else 60 for i in range(len(frames))]
    frames[0].save(destination, save_all=True, append_images=frames[1:], duration=durations,
                   loop=0, optimize=False, disposal=1)
    rendered[9].save(destination.with_suffix(".png"))
    print(json.dumps({"artifact": str(destination), "frames": len(frames), "duration_ms": sum(durations),
                      "bytes": destination.stat().st_size}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--pair", choices=["mechanics", "elements", "all"], default="all")
    args = parser.parse_args()
    if args.pair in ("mechanics", "all"):
        make(["base", "split"], OUT / "meteor_flail_mechanics.gif")
    if args.pair in ("elements", "all"):
        make(["split_lightning", "split_fire"], OUT / "meteor_flail_enchantments.gif")
