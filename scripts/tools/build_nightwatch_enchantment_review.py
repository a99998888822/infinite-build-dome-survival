"""Package actual Godot captures into labeled pixel-preserving review GIFs."""
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/nightwatch_spear_enchantments"
TEMP = Path("C:/Users/mi/AppData/Local/Temp")
FFMPEG = Path("D:/soft/ffmpeg-N-116796-gb730defd52-win64-gpl-shared/bin/ffmpeg.exe")
TITLES = {"split": "分裂：命中后分出短矛", "fire": "火焰：燃烧与火焰池",
          "ice": "冰霜：结霜减速与冰域", "lightning": "电火花：连锁与麻痹",
          "split_fire": "分裂 + 火焰：短矛也能点燃", "split_lightning": "分裂 + 电火花：短矛继续引雷"}
COLORS = {"split": "#bed0c7", "fire": "#ffad60", "ice": "#82d9f0",
          "lightning": "#c6b9ff", "split_fire": "#ffad60", "split_lightning": "#c6b9ff"}
CROP = (495, 176, 1047, 464)
TILE = (552, 324)


def tile(variant: str, frame: int) -> Image.Image:
    source = TEMP / f"codex-spear-enchant-{variant}" / f"frame_{frame:04d}.png"
    result = Image.new("RGB", TILE, "#111b20")
    result.paste(Image.open(source).crop(CROP), (0, 36))
    draw = ImageDraw.Draw(result)
    draw.text((12, 6), TITLES[variant], font=ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 18), fill=COLORS[variant])
    draw.line((0, 35, 551, 35), fill="#395052")
    return result


def export(name: str, variants: list[str], columns: int) -> None:
    frame_dir = TEMP / f"codex-spear-review-export-{name}"
    frame_dir.mkdir(parents=True, exist_ok=True)
    rows = (len(variants) + columns - 1) // columns
    for index in range(108):
        board = Image.new("RGB", (TILE[0] * columns, TILE[1] * rows), "#111b20")
        for position, variant in enumerate(variants):
            board.paste(tile(variant, index), ((position % columns) * TILE[0], (position // columns) * TILE[1]))
        board.save(frame_dir / f"frame_{index:04d}.png")
        if index in [0, 18, 21, 27, 35, 51]:
            board.save(OUT / f"{name}_frame_{index:02d}.png")
    filters = "fps=20,split[a][b];[a]palettegen=max_colors=192:stats_mode=full[p];[b][p]paletteuse=dither=none"
    subprocess.run([str(FFMPEG), "-hide_banner", "-loglevel", "warning", "-framerate", "30",
                    "-i", str(frame_dir / "frame_%04d.png"), "-filter_complex", filters,
                    "-loop", "0", "-final_delay", "5", "-y", str(OUT / f"{name}.gif")], check=True)
    print(f"EXPORTED {name}", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["singles", "comparisons", "all"], default="all")
    parser.add_argument("--variants", nargs="*", default=list(TITLES))
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    if args.mode in ["all", "singles"]:
        for variant in args.variants:
            capture = TEMP / f"codex-spear-enchant-{variant}" / "capture.json"
            data = json.loads(capture.read_text(encoding="utf-8"))
            assert data["failures"] == 0, variant
            (OUT / f"{variant}_capture.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            export(variant, [variant], 1)
    if args.mode in ["all", "comparisons"]:
        export("fire_comparison", ["fire", "split_fire"], 2)
        export("lightning_comparison", ["lightning", "split_lightning"], 2)
        export("overview", ["split", "ice", "fire", "split_fire", "lightning", "split_lightning"], 2)
    validation = {}
    for path in OUT.glob("*.gif"):
        with Image.open(path) as im:
            duration = sum(im.seek(index) or im.info.get("duration", 0) for index in range(im.n_frames))
            assert im.n_frames == 72 and duration == 3600, path
            validation[path.name] = {"frames": im.n_frames, "duration_ms": duration, "size": list(im.size), "bytes": path.stat().st_size}
    (OUT / "media_validation.json").write_text(json.dumps(validation, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
