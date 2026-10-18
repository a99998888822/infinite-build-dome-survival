"""Rebuild the accepted talent UI backgrounds and arrow into an explicit directory.

Requires Pillow. Example: python export_ui.py --output <review-directory>
"""

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = Path(__file__).resolve().parent
    args.output.mkdir(parents=True, exist_ok=True)
    for entry in json.loads((source / "manifest.json").read_text(encoding="utf-8")):
        original = source / "reference" / entry["file"]
        if hashlib.sha256(original.read_bytes()).hexdigest() != entry["source_sha256"]:
            raise ValueError(f"Source hash mismatch: {original.name}")
        with Image.open(original) as image:
            image.convert("RGBA").crop(entry["crop"]).save(args.output / entry["file"])

    arrow = Image.new("RGBA", (16, 17))
    draw = ImageDraw.Draw(arrow)
    for offset in (0, 8):
        draw.polygon([(0, offset + 8), (7, offset), (8, offset), (15, offset + 8),
                      (8, offset + 5), (7, offset + 5)], fill="#b4945d")
        draw.line([(1, offset + 7), (7, offset + 1), (8, offset + 1),
                   (14, offset + 7)], fill="#c6aa73", width=1)
    arrow.save(args.output / "upgrade_arrow.png")
    print(f"Exported 4 UI images to {args.output.resolve()}")


if __name__ == "__main__":
    main()
