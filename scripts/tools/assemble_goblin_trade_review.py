"""Assemble Godot viewport captures and the matching typewriter sound track."""
from pathlib import Path
import argparse
import json
import shutil
import struct
import subprocess
import wave
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/reviews/ui/goblin_trade"


def sound_track(path, small):
    rate = 24000
    sound = [0.0] * (rate * 8)
    samples = []
    for variant in range(1, 4):
        with wave.open(str(ROOT / f"assets/audio/sfx/ui/trade_type_{variant:02d}.wav"), "rb") as stream:
            samples.append(struct.unpack("<" + "h" * stream.getnframes(), stream.readframes(stream.getnframes())))
    speech = "再存一点，\n我给你看看真正的好东西。"
    body = "存入 200 本金\n强力刷新 ×1" if small else "存入 200 本金\n获得 1 次强力刷新"
    last_tick = -1
    for frame in range(160):
        seconds = frame / 20
        speech_chars = max(0, min(len(speech), int((seconds - .35) * 13)))
        body_chars = max(0, min(len(body), int((seconds - 1.35) * 13)))
        tick = (speech_chars + body_chars) // 2
        if tick > last_tick and tick > 0 and seconds < 3.8:
            start = round(seconds * rate)
            for offset, value in enumerate(samples[tick % 3]):
                sound[start + offset] += value * .355
        last_tick = tick
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(rate)
        stream.writeframes(b"".join(struct.pack("<h", int(max(-32768, min(32767, n)))) for n in sound))


def assemble(source, name, small, cancelled=False):
    paths = sorted(source.glob("frame_*.png"))
    assert len(paths) == 160, len(paths)
    frames = [Image.open(p).convert("RGB") for p in paths]
    # Desktop GIF crops only the financial window; the MP4 preserves the full viewport.
    if not small:
        frames = [im.crop((16, 72, 816, 712)) for im in frames]
    atlas = Image.new("RGB", (frames[0].width, frames[0].height * 8))
    for row, frame in enumerate(frames[::20]):
        atlas.paste(frame, (0, row * frame.height))
    palette = atlas.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    paletted = [im.quantize(palette=palette, dither=Image.Dither.NONE) for im in frames]
    gif = OUT / f"{name}.gif"
    paletted[0].save(gif, save_all=True, append_images=paletted[1:],
                     duration=50, loop=0, optimize=False, disposal=1)
    frames[60].save(OUT / f"{name}_speaking.png")
    frames[130].save(OUT / f"{name}_{'closed' if cancelled else 'ready'}.png")
    audio = OUT / f"{name}_typing.wav"
    sound_track(audio, small)
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg:
        subprocess.run([shutil.which("ffmpeg"), "-hide_banner", "-loglevel", "error", "-y",
                        "-framerate", "20", "-i", str(source / "frame_%04d.png"), "-i", str(audio),
                        "-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p", "-c:a", "aac",
                        "-movflags", "+faststart", "-shortest", str(OUT / f"{name}.mp4")], check=True)
    print(json.dumps({"gif": str(gif), "frames": 160, "duration_seconds": 8, "bytes": gif.stat().st_size}))


def sheet():
    canvas = Image.new("RGB", (800, 380), "#1a211c")
    d = ImageDraw.Draw(canvas)
    font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 18)
    d.text((24, 16), "交易 · 像素素材审阅", font=font, fill="#e5c88b")
    for name, label, position, scale in [
        ("trade_panel.png", "交易框 / 九宫格拉伸", (24, 64), 3),
        ("trade_bubble.png", "对话气泡 / 九宫格拉伸", (398, 64), 3),
        ("trade_seal.png", "金币眼纹徽记", (408, 246), 2),
        ("trade_glints.png", "边缘闪光 / 8 帧", (524, 246), 2),
    ]:
        im = Image.open(ROOT / "assets/ui/finance" / name)
        im = im.resize((im.width * scale, im.height * scale), Image.Resampling.NEAREST)
        canvas.paste(im, position, im)
        d.text((position[0], position[1] + im.height + 10), label, font=font, fill="#b4b69a")
    canvas.save(OUT / "asset_sheet.png")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("capture_root", type=Path)
    parser.add_argument("--reject-demo", action="store_true")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    for name in ("desktop", "small"):
        assemble(args.capture_root / name, name + ("_cancel" if args.reject_demo else ""), name == "small", args.reject_demo)
    sheet()
