"""Encode real Godot capture frames, with a nearest-neighbor detail view."""

import argparse
import json
from pathlib import Path
import shutil
import subprocess

from PIL import Image, ImageDraw


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    output = args.directory.resolve()
    report = json.loads((output / "report.json").read_text(encoding="utf-8"))
    desktop = json.loads((output / "capture.json").read_text(encoding="utf-8"))
    assert not report["failures"], report["failures"]
    assert desktop["exit_code"] == 0 and desktop["foreground_samples"] == 0
    assert desktop["private_desktop"] == desktop["verified_desktop"]
    frames = sorted((output / "frames").glob("frame_*.png"))
    assert len(frames) == report["frames"] == 300
    ffmpeg = shutil.which("ffmpeg")
    assert ffmpeg, "ffmpeg required"
    source = [ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-framerate", str(report["fps"]),
              "-i", str(output / "frames/frame_%04d.png")]
    # 50 fps has exact GIF timing (20 ms) and preserves the short critical shake.
    graph = "fps=50,crop=820:490:260:120,scale=984:588:flags=neighbor,split[a][b];[a]palettegen=max_colors=256[p];[b][p]paletteuse=dither=none"
    subprocess.run(source + ["-filter_complex", graph, "-loop", "0", str(output / "damage_numbers.gif")], check=True)
    subprocess.run(source + ["-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(output / "battle_full.mp4")], check=True)
    with Image.open(frames[204]) as frame:
        frame.save(output / "battle_still.png")
    # A contact sheet exposes the first critical impact without modifying frames.
    contact = Image.new("RGB", (820, 160 * 6), "#182124")
    draw = ImageDraw.Draw(contact)
    for row, index in enumerate([16, 19, 22, 25, 28, 31]):
        with Image.open(frames[index]) as frame:
            contact.paste(frame.crop((260, 390, 1080, 525)), (0, row * 160 + 25))
        draw.text((10, row * 160 + 5), f"Critical hit: {(index - 15) / 60:.3f}s", fill="white")
    contact.save(output / "critical_contact_sheet.png")
    with Image.open(output / "damage_numbers.gif") as gif:
        total_ms = 0
        for index in range(gif.n_frames):
            gif.seek(index)
            total_ms += gif.info.get("duration", 0)
        summary = {"gif_frames": gif.n_frames, "duration_ms": total_ms, "size": gif.size,
                   "source": "Godot GPU viewport", "speed": "1x", "crop": [260, 120, 820, 490]}
    (output / "encoding.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary))


if __name__ == "__main__":
    main()
