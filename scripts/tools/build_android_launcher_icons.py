"""Derive Android adaptive launcher layers from the approved root icon.png."""

from pathlib import Path

from PIL import Image, ImageOps


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    output = root / "assets/ui/app_icon"
    output.mkdir(parents=True, exist_ok=True)
    logo = Image.open(root / "icon.png").convert("RGBA")
    # Android can mask and animate the 108 dp layers. Keep the artwork within
    # the central 66 dp area so the hat and hands survive circular masks.
    layer_size = 432
    artwork_size = 264
    inset = (layer_size - artwork_size) // 2
    artwork = logo.resize((artwork_size, artwork_size), Image.Resampling.LANCZOS)
    foreground = Image.new("RGBA", (layer_size, layer_size))
    foreground.alpha_composite(artwork, (inset, inset))
    foreground.save(output / "android_foreground.png")
    background = Image.new("RGB", (layer_size, layer_size), logo.getpixel((0, 0))[:3])
    background.save(output / "android_background.png")
    # Themed icons use alpha only. Preserve the logo's illuminated details
    # while making its dark purple background transparent.
    alpha = ImageOps.grayscale(artwork).point(lambda value: max(0, min(255, (value - 42) * 8)))
    alpha = Image.composite(alpha, Image.new("L", alpha.size), artwork.getchannel("A"))
    monochrome = Image.new("RGBA", (layer_size, layer_size))
    ink = Image.new("RGBA", artwork.size, "white")
    ink.putalpha(alpha)
    monochrome.alpha_composite(ink, (inset, inset))
    monochrome.save(output / "android_monochrome.png")


if __name__ == "__main__":
    main()
