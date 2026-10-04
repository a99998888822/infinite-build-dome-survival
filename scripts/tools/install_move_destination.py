"""Install the supplied finished pixel strip, preserving its eight cell pivots."""
import hashlib
import json
from pathlib import Path

from PIL import Image


def main():
    source = Path("C:/Users/mi/Downloads/move_indictor.png")
    output = Path("assets/ui/combat/move_destination.png")
    image = Image.open(source).convert("RGBA")
    assert image.size == (2560, 320)
    assert image.getchannel("A").getextrema() == (0, 255)
    # Source is an exact 5x enlargement of the supplied pixel grid.
    result = image.resize((512, 64), Image.Resampling.NEAREST)
    assert result.resize(image.size, Image.Resampling.NEAREST).tobytes() == image.tobytes()
    output.parent.mkdir(parents=True, exist_ok=True)
    result.save(output)
    record = {
        "source": str(source), "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "output": str(output), "frame_size": [64, 64], "frame_count": 8,
        "processing": "Exact nearest-neighbor removal of the source 5x pixel enlargement; no repaint, recenter, or palette change.",
        "frame_bounds": [result.crop((i * 64, 0, (i + 1) * 64, 64)).getbbox() for i in range(8)],
    }
    output.with_suffix(".json").write_text(json.dumps(record, indent=2), encoding="utf-8")
    print(json.dumps(record))


if __name__ == "__main__":
    main()
