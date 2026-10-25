"""Clear the two reviewed flat blue fills without changing any crystal pixels.

The original baked ice atlases contain a faint ellipse and broad crystal-base
fill. Their exact RGBA entries are distinct from the crystal strokes. This
idempotent cleanup preserves all 37 frames, dimensions, alignment and remaining
pixel values in each of the three detail tiers. No model generation is used.
"""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
FILLS = {(102, 153, 204, 15), (120, 170, 212, 36)}


def main():
    for tier in range(3):
        path = ROOT / f"assets/effects/pixel_baked/ice_d{tier}.png"
        with Image.open(path) as source:
            assert source.mode == "RGBA" and source.size == (1024, 400), path
            before = list(source.get_flattened_data())
            after = [(0, 0, 0, 0) if pixel in FILLS else pixel for pixel in before]
            removed = sum(pixel in FILLS for pixel in before)
            if removed:
                cleaned = Image.new("RGBA", source.size)
                cleaned.putdata(after)
                cleaned.save(path)
        with Image.open(path) as result:
            assert list(result.get_flattened_data()) == after
        print(f"{path.name}: cleared {removed} fill pixels; crystal pixels preserved")


if __name__ == "__main__":
    main()
