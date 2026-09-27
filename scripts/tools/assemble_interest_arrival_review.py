"""Assemble real Godot viewport frames at their recorded 24 fps timing."""
from pathlib import Path
import sys

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "artifacts/reviews/ui/interest_arrival"


def assemble(name):
    frames = [Image.open(p).convert("RGB").crop((12, 68, 820, 714)) for p in sorted((OUT / name).glob("*.png"))]
    if not frames:
        raise RuntimeError("No captured frames: " + name)
    samples = frames[::8]
    palette_sheet = Image.new("RGB", (202 * 4, 162 * ((len(samples) + 3) // 4)))
    for i, frame in enumerate(samples):
        palette_sheet.paste(frame.resize((202, 162)), ((i % 4) * 202, (i // 4) * 162))
    palette = palette_sheet.quantize(colors=256)
    indexed = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
    durations = [round((i + 1) * 100 / 24) * 10 - round(i * 100 / 24) * 10 for i in range(len(frames))]
    durations[-1] += 600
    indexed[0].save(OUT / f"{name}.gif", save_all=True, append_images=indexed[1:], duration=durations, loop=0, disposal=2, optimize=False)
    frames[min(31, len(frames) - 1)].save(OUT / f"{name}_receipt.png")
    print(name, "frames=", len(frames), "duration_ms=", sum(durations), "bytes=", (OUT / f"{name}.gif").stat().st_size)


if __name__ == "__main__":
    for scene in ["bonus", "sanity_loss"]:
        assemble(scene)
