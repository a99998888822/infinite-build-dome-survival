"""Draw pixel UI assets and a quiet mechanical typewriter for the trade review."""
from pathlib import Path
import math
import random
import struct
import wave
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/ui/finance"
AUDIO = ROOT / "assets/audio/sfx/ui"
INK = "#141c19"
DARK = "#292d23"
EDGE = "#756744"
GOLD = "#ba985c"
LIGHT = "#e5c88b"


def panel(name, size, speech=False):
    w, h = size
    im = Image.new("RGBA", size)
    d = ImageDraw.Draw(im)
    outline = [(4, 0), (w - 5, 0), (w - 1, 4), (w - 1, h - 5),
               (w - 5, h - 1), (4, h - 1), (0, h - 5), (0, 4)]
    d.polygon(outline, fill=INK)
    d.rectangle((3, 3, w - 4, h - 4), fill=GOLD if speech else EDGE)
    d.rectangle((5, 5, w - 6, h - 6), fill="#303426" if speech else DARK)
    d.line((6, 6, w - 7, 6), fill="#535039")
    d.line((6, h - 7, w - 7, h - 7), fill="#1c241c")
    # Restrict wear to the frame so nine-patch stretching never muddies the text.
    rng = random.Random(260926)
    for x in range(12, w - 12, 7):
        if rng.random() < .6:
            d.line((x, 3, x + 2, 3), fill=LIGHT)
        d.point((x + 1, h - 4), fill="#4c4730")
    for x, y, sx, sy in [(6, 6, 1, 1), (w - 7, 6, -1, 1),
                         (6, h - 7, 1, -1), (w - 7, h - 7, -1, -1)]:
        d.line((x, y, x + sx * 8, y), fill=GOLD, width=2)
        d.line((x, y, x, y + sy * 8), fill=GOLD, width=2)
        d.point((x, y), fill=LIGHT)
        d.point((x + sx * 3, y + sy * 3), fill=EDGE)
    im.save(OUT / name)


def seal():
    im = Image.new("RGBA", (32, 32))
    d = ImageDraw.Draw(im)
    d.polygon([(10, 19), (8, 31), (14, 28), (18, 31), (19, 20)], fill="#65512f")
    points = [(10, 2), (22, 2), (22, 4), (27, 4), (27, 9), (29, 9),
              (29, 21), (26, 21), (26, 26), (21, 26), (21, 28),
              (10, 28), (10, 26), (5, 26), (5, 21), (3, 21),
              (3, 9), (5, 9), (5, 4), (10, 4)]
    d.polygon(points, fill=INK)
    d.ellipse((5, 3, 26, 26), fill=GOLD)
    d.ellipse((7, 5, 24, 24), fill="#665234", outline=LIGHT)
    d.ellipse((9, 7, 22, 22), fill="#343b29", outline="#a88950")
    # A slitted eye on a coin: an offer that is watching the player's wallet.
    d.polygon([(10, 14), (15, 10), (21, 14), (16, 18)], fill=LIGHT)
    d.rectangle((15, 11, 16, 17), fill=INK)
    d.point((8, 8), fill="#fff0b3")
    im.save(OUT / "trade_seal.png")


def accents():
    im = Image.new("RGBA", (18, 12))
    d = ImageDraw.Draw(im)
    d.polygon([(0, 0), (17, 0), (3, 11)], fill=INK)
    d.polygon([(2, 0), (14, 0), (4, 8)], fill=GOLD)
    d.polygon([(4, 0), (11, 0), (5, 5)], fill="#303426")
    im.save(OUT / "trade_bubble_tail.png")
    im = Image.new("RGBA", (128, 16))
    d = ImageDraw.Draw(im)
    for frame in range(8):
        radius = [1, 2, 4, 6, 4, 3, 2, 1][frame]
        x, y = frame * 16 + 8, 8
        d.line((x - radius, y, x + radius, y), fill=GOLD)
        d.line((x, y - radius, x, y + radius), fill=GOLD)
        d.rectangle((x - 1, y - 1, x + 1, y + 1), fill=LIGHT)
        d.point((x, y), fill="#fff2cc")
    im.save(OUT / "trade_glints.png")


def audio():
    AUDIO.mkdir(parents=True, exist_ok=True)
    rate = 24000
    for variant in range(3):
        rng = random.Random(105 + variant)
        samples = []
        for index in range(int(rate * .072)):
            t = index / rate
            # Two short, damped impacts; no sustained, high-pitched beep.
            attack = min(1., t / .001)
            body = math.sin(math.tau * (960 + variant * 100) * t) * math.exp(-t * 180)
            click = rng.uniform(-1, 1) * math.exp(-t * 330)
            release = 0 if t < .025 else math.sin(math.tau * 580 * t) * math.exp(-(t - .025) * 380) * .17
            sample = (body * .2 + click * .33 + release) * attack * .6
            samples.append(struct.pack("<h", int(max(-1, min(1, sample)) * 32767)))
        with wave.open(str(AUDIO / f"trade_type_{variant + 1:02d}.wav"), "wb") as stream:
            stream.setnchannels(1)
            stream.setsampwidth(2)
            stream.setframerate(rate)
            stream.writeframes(b"".join(samples))


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    panel("trade_panel.png", (112, 80))
    panel("trade_bubble.png", (96, 48), True)
    seal()
    accents()
    audio()
    print("Drawn 5 pixel UI textures and 3 typewriter samples.")
