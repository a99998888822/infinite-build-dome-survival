"""Assemble real GPU frames using their capture timestamps, preserving pacing."""
from pathlib import Path
import json
from PIL import Image, ImageOps

root = Path(__file__).resolve().parents[2] / "artifacts/previews/final_kill"
for label in ("normal", "boss"):
    directory = root / label
    sources = sorted(directory.glob("frame_*.png"))
    frames = [Image.open(path).convert("RGB").resize((960, 540), Image.Resampling.NEAREST) for path in sources]
    timestamps = json.loads((directory / "timing.json").read_text(encoding="utf-8"))
    durations = [max(20, round((b - a) / 10) * 10) for a, b in zip(timestamps, timestamps[1:])] + [500]
    sheet = Image.new("RGB", (320 * 6, 180 * 4))
    for index in range(24):
        frame = frames[min(len(frames) - 1, index * len(frames) // 24)]
        sheet.paste(frame.resize((320, 180), Image.Resampling.NEAREST), (index % 6 * 320, index // 6 * 180))
    palette = sheet.quantize(colors=256)
    quantized = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
    target = root / (label + ".gif")
    quantized[0].save(target, save_all=True, append_images=quantized[1:], duration=durations, loop=0, optimize=False, disposal=2)
    ImageOps.contain(Image.open(sources[min(22, len(sources)-1)]), (1280, 720)).save(root / (label + "_still.png"))
    print(f"{target}: {len(frames)} frames, {sum(durations)} ms, {target.stat().st_size} bytes")
