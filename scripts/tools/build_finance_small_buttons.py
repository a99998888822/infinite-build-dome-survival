"""Draw single-line pixel button skins using the approved iron/bronze palette."""
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]


def build() -> None:
    for name, fill, edge in [
        ("neutral_iron", "#24262b", "#555b5e"),
        ("smoke_bronze", "#342d26", "#95764f"),
    ]:
        image = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)
        draw.rectangle((1, 1, 14, 14), fill=fill)
        for segment in [(1, 0, 14, 0), (1, 15, 14, 15), (0, 1, 0, 14), (15, 1, 15, 14)]:
            draw.line(segment, fill=edge, width=1)
        target = ROOT / "assets/ui/hud" / name / "button_small.png"
        target.parent.mkdir(parents=True, exist_ok=True)
        image.save(target)
        print(target.relative_to(ROOT))


if __name__ == "__main__":
    build()
