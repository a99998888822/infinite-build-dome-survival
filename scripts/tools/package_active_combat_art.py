"""Package genuine Godot captures and transparent indicator exports for review."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import zipfile

from PIL import Image, ImageDraw, ImageFont


def font(size):
    return ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", size)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("capture", type=Path)
    args = parser.parse_args()
    root = Path.cwd()
    capture = args.capture.resolve()
    report = json.loads((capture / "review_report.json").read_text(encoding="utf-8"))
    assert not report["failures"], report["failures"]
    background = json.loads((capture / "runtime.json").read_text(encoding="utf-8"))
    assert background["foreground_samples"] == 0
    assert background["private_desktop"] == background["verified_desktop"]
    data = json.loads((root / "data_config/weapons.json").read_text(encoding="utf-8"))
    records = {item["id"]: item for item in data}
    ids = report["weapon_ids"]
    width, cell_w, cell_h = 1320, 440, 340
    gallery = Image.new("RGB", (width, 92 + math.ceil(len(ids) / 3) * cell_h), "#0c171d")
    draw = ImageDraw.Draw(gallery)
    draw.text((28, 15), "武器攻击指示器 · 11 把逐一绘制", font=font(27), fill="#d8f2ff")
    draw.text((28, 55), "来自 Godot 同一绘制节点的透明导出；各图适配格子显示，实际射程由游戏属性决定", font=font(16), fill="#8fb4c4")
    manifest = {"method": "Godot geometric art, no image-generation model", "assets": [],
                "capture": report, "background_validation": background}
    raw_dir = capture / "raw_viewport_exports"
    raw_dir.mkdir(exist_ok=True)
    for index, item_id in enumerate(ids):
        path = capture / "indicators" / (item_id + ".png")
        raw_path = raw_dir / path.name
        if not raw_path.exists():
            raw_path.write_bytes(path.read_bytes())
        raw_image = Image.open(raw_path).convert("RGBA")
        # Transparent Godot viewports contain premultiplied RGB. PNG consumers
        # expect straight alpha; retaining the raw export makes this idempotent.
        pixels = bytearray(raw_image.tobytes())
        for offset in range(0, len(pixels), 4):
            alpha = pixels[offset + 3]
            if 0 < alpha < 255:
                for channel in range(3):
                    pixels[offset + channel] = min(255, (pixels[offset + channel] * 255 + alpha // 2) // alpha)
        image = Image.frombytes("RGBA", raw_image.size, bytes(pixels))
        image.save(path)
        assert image.size == (768, 768)
        assert image.getchannel("A").getextrema()[0] == 0
        bbox = image.getbbox()
        assert bbox is not None
        assert bbox[0] > 0 and bbox[1] > 0 and bbox[2] < 768 and bbox[3] < 768, (item_id, bbox)
        x, y = (index % 3) * cell_w, 92 + (index // 3) * cell_h
        draw.rounded_rectangle((x + 12, y + 8, x + cell_w - 12, y + cell_h - 8), 5,
                               fill="#14272b", outline="#29424b", width=1)
        draw.text((x + 25, y + 19), f"{index + 1:02d}  {records[item_id]['display_name']}", font=font(20), fill="#deeff7")
        padded = (max(0, bbox[0] - 16), max(0, bbox[1] - 16), min(768, bbox[2] + 16), min(768, bbox[3] + 16))
        art = image.crop(padded)
        art.thumbnail((385, 255), Image.Resampling.NEAREST)
        gallery.paste(art, (x + (cell_w - art.width) // 2, y + 65 + (255 - art.height) // 2), art)
        manifest["assets"].append({"id": item_id, "path": str(path.relative_to(capture)),
                                    "size": image.size, "alpha_bbox": bbox,
                                    "alpha_processing": "Premultiplied viewport RGB converted to straight-alpha PNG",
                                    "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    gallery.save(capture / "weapon_indicator_gallery.png")

    # These are chronological GPU captures; no synthetic poses or interpolated frames.
    frames = []
    paths = sorted((capture / "frames").glob("frame_*.png"))
    ticks = report.get("sequence_physics_ticks", [])
    durations = []
    for index, path in enumerate(paths):
        image = Image.open(path).convert("RGB").resize((960, 540), Image.Resampling.NEAREST)
        frames.append(image.quantize(colors=160, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
        gap = ticks[index + 1] - ticks[index] if index + 1 < len(ticks) else 60
        durations.append(max(60, min(1200, round(gap / 60 * 1000))))
    frames[0].save(capture / "runtime_preview.gif", save_all=True, append_images=frames[1:],
                   duration=durations, loop=0, optimize=False, disposal=2)

    movement_paths = sorted(capture.glob("movement_*.png"))
    movement = [Image.open(p).convert("RGB").resize((960, 540), Image.Resampling.NEAREST).quantize(colors=160, dither=Image.Dither.NONE)
                for p in movement_paths]
    movement[0].save(capture / "movement_runtime.gif", save_all=True, append_images=movement[1:],
                     duration=110, loop=0, disposal=2, optimize=False)

    # A compact sheet of actual battle screenshots gives context for the individual assets.
    screen_sheet = Image.new("RGB", (1280, 3 * 386), "#0c171d")
    draw = ImageDraw.Draw(screen_sheet)
    for index, number in enumerate([1, 3, 4, 8, 9, 11]):
        screenshot = Image.open(capture / f"aim_{number:02d}.png").convert("RGB")
        x, y = (index % 2) * 640, (index // 2) * 386
        screenshot = screenshot.resize((640, 360), Image.Resampling.NEAREST)
        screen_sheet.paste(screenshot, (x, y + 26))
        draw.text((x + 10, y + 3), records[ids[number - 1]]["display_name"], font=font(16), fill="#d8f2ff")
    screen_sheet.save(capture / "battle_screenshots.png")
    (capture / "art_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    with zipfile.ZipFile(capture / "active_combat_art_assets.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for item_id in ids:
            archive.write(capture / "indicators" / (item_id + ".png"), "indicators/" + item_id + ".png")
        archive.write(root / "assets/ui/combat/move_destination.png", "move_destination.png")
        archive.write(root / "assets/ui/combat/move_destination.json", "move_destination.json")
        archive.write(capture / "art_manifest.json", "art_manifest.json")
        for source in ["scripts/battle/weapon_attack_indicator.gd", "scripts/battle/attack_footprint.gd",
                       "shaders/ui/attack_indicator_clearance.gdshader"]:
            archive.write(root / source, "source/" + source)
    print(json.dumps({"assets": len(ids), "frames": len(frames), "capture": str(capture),
                      "checks": report["assertions"], "failures": report["failures"]}))


if __name__ == "__main__":
    main()
