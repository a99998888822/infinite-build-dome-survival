"""Add the native manual-cast hand and banker reply to the original recordings."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

from PIL import Image, ImageDraw, ImageFilter, ImageFont

PROJECT = Path(__file__).resolve().parents[2]
REPLY = "明智的选择"
FPS = 60
FIRST = 300
LAST = 480


def smooth(value):
    value = max(0.0, min(1.0, value))
    return value * value * (3 - 2 * value)


def panel(texture, width, height, margin=12):
    result = Image.new("RGBA", (width, height))
    xs, ys = [0, margin, texture.width - margin, texture.width], [0, margin, texture.height - margin, texture.height]
    dx, dy = [0, margin, width - margin, width], [0, margin, height - margin, height]
    for j in range(3):
        for i in range(3):
            patch = texture.crop((xs[i], ys[j], xs[i + 1], ys[j + 1]))
            patch = patch.resize((dx[i + 1] - dx[i], dy[j + 1] - dy[j]), Image.Resampling.NEAREST)
            result.alpha_composite(patch, (dx[i], dy[j]))
    return result


def alpha_gain(picture, gain):
    picture = picture.copy()
    picture.putalpha(picture.getchannel("A").point(lambda a: round(a * gain)))
    return picture


def make_overlay(frame, hand, bubble, tail, font):
    overlay = Image.new("RGBA", (1920, 1080))
    if 306 <= frame < 347:
        target = (340.0, 608.0)
        arrival = smooth((frame - 306) / 10)
        press = smooth((frame - 320) / 10) if frame <= 330 else 1 - smooth((frame - 330) / 10)
        size = round(56 * (1 - 0.18 * press))
        finger = hand.resize((size, size), Image.Resampling.NEAREST)
        # The SVG's index fingertip is at (8.5, 2.5) on its native 20px grid.
        fingertip = (target[0] + 28 * (1 - arrival), target[1] + 44 * (1 - arrival) - 9 * (1 - press))
        position = (round(fingertip[0] - size * 8.5 / 20), round(fingertip[1] - size * 2.5 / 20))
        opacity = min(smooth((frame - 306) / 5), 1 - smooth((frame - 340) / 7))
        shadow = Image.new("RGBA", (size + 4, size + 4), (10, 12, 15, 0))
        mask = Image.new("L", shadow.size)
        mask.paste(finger.getchannel("A"), (2, 2))
        shadow.putalpha(mask.filter(ImageFilter.MaxFilter(3)))
        overlay.alpha_composite(alpha_gain(shadow, opacity), (position[0] - 2, position[1] - 2))
        overlay.alpha_composite(alpha_gain(finger, opacity), position)
    if frame >= 342:
        words = min(len(REPLY), 1 + (frame - 342) // 6)
        speech = Image.new("RGBA", (180, 66))
        speech.alpha_composite(bubble)
        speech.alpha_composite(tail, (10, 51))
        ImageDraw.Draw(speech).text((14, 12), REPLY[:words], font=font, fill="#c6c7c2")
        # Reuse the location and assets of the original in-game speech bubble.
        overlay.alpha_composite(alpha_gain(speech, smooth((frame - 341) / 5)), (498, 278))
    return overlay


def audio_hash(ffmpeg, path):
    return subprocess.check_output([str(ffmpeg), "-v", "error", "-i", str(path), "-map", "0:a:0", "-c", "copy", "-f", "hash", "-hash", "sha256", "-"], encoding="utf-8").strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=PROJECT / "artifacts/previews/greed_promo_20261024")
    parser.add_argument("--output", type=Path, default=PROJECT / "artifacts/previews/greed_promo_20261024_v2")
    parser.add_argument("--ffmpeg", type=Path, default=Path("D:/soft/ffmpeg-N-116796-gb730defd52-win64-gpl-shared/bin/ffmpeg.exe"))
    args = parser.parse_args()
    root = args.output.resolve()
    root.mkdir(parents=True, exist_ok=True)
    # Godot rasterizes the exact imported SVG; no replacement hand is drawn.
    hand_source = Image.open(root / "cast_manual.png").convert("RGBA")
    hand = Image.new("RGBA", hand_source.size, "#ddbe79")
    hand.putalpha(hand_source.getchannel("A"))
    skin = PROJECT / "assets/ui/finance"
    bubble = panel(Image.open(skin / "trade_bubble.png").convert("RGBA"), 180, 56)
    tail = Image.open(skin / "trade_bubble_tail.png").convert("RGBA")
    font = ImageFont.truetype(str(PROJECT / "assets/font/ark-pixel-12px-monospaced-zh_cn.otf"), 24)
    manifest = {"reply": REPLY, "hand_asset": "assets/ui/icons/cast_manual.svg", "click_frame": 330,
                "reply_start_frame": 342, "smile": "Existing original shot from frame 330",
                "bgm_percent": 0, "sfx_percent": 100, "audio_changed": False, "files": []}
    for kind, name, expected in [("story", "02_goblin_buyout_story.mp4", 690), ("raw", "02_sell_the_best_weapon.mp4", 480)]:
        folder = root / (kind + "_overlay")
        folder.mkdir(exist_ok=True)
        for frame in range(FIRST, LAST):
            overlay = make_overlay(frame, hand, bubble, tail, font)
            if kind == "story" and frame < 372:
                overlay = overlay.crop((32, 180, 1152, 810)).resize((1920, 1080), Image.Resampling.NEAREST)
            overlay.save(folder / f"{frame - FIRST:03d}.png")
        source = args.source.resolve() / name
        destination = root / name
        source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
        graph = "[1:v]setpts=PTS-STARTPTS+5/TB[ink];[0:v][ink]overlay=eof_action=pass:repeatlast=0:format=auto,format=yuv420p[v]"
        subprocess.run([str(args.ffmpeg), "-hide_banner", "-loglevel", "error", "-y", "-i", str(source),
                        "-framerate", "60", "-i", str(folder / "%03d.png"), "-filter_complex", graph,
                        "-map", "[v]", "-map", "0:a:0", "-c:v", "libx264", "-crf", "14", "-preset", "slow",
                        "-r", "60", "-fps_mode", "cfr", "-c:a", "copy", "-movflags", "+faststart", str(destination)], check=True)
        probe = json.loads(subprocess.check_output([str(args.ffmpeg.with_name("ffprobe.exe")), "-v", "error", "-show_streams", "-of", "json", str(destination)], encoding="utf-8"))
        video = next(s for s in probe["streams"] if s["codec_type"] == "video")
        assert int(video["nb_frames"]) == expected and (video["width"], video["height"]) == (1920, 1080)
        assert video["r_frame_rate"] == "60/1"
        assert audio_hash(args.ffmpeg, source) == audio_hash(args.ffmpeg, destination)
        assert hashlib.sha256(source.read_bytes()).hexdigest() == source_hash
        manifest["files"].append({"name": name, "frames": expected, "duration": expected / 60,
                                  "source_sha256": source_hash, "audio_bitstream_identical": True})
        print("EXPORTED", destination, flush=True)
    review = root / "review"
    review.mkdir(exist_ok=True)
    contacts = Image.new("RGB", (1440, 900), "#17171c")
    text = ImageDraw.Draw(contacts)
    for i, frame in enumerate([300, 316, 324, 330, 344, 368, 400, 470, 600]):
        path = review / f"frame_{frame:03d}.png"
        subprocess.run([str(args.ffmpeg), "-v", "error", "-y", "-ss", str(frame / 60), "-i", str(root / "02_goblin_buyout_story.mp4"), "-frames:v", "1", str(path)], check=True)
        x, y = (i % 3) * 480, (i // 3) * 300
        contacts.paste(Image.open(path).resize((480, 270)), (x, y))
        text.text((x + 8, y + 277), f"{frame / 60:.2f}s / frame {frame}", fill="white")
    contacts.save(root / "revision_contact.jpg")
    (root / "revision_validation.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(manifest, ensure_ascii=True), flush=True)


if __name__ == "__main__":
    main()
