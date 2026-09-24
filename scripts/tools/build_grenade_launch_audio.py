"""Build the short cast-iron launcher report; offline deterministic synthesis."""
import math
import random
import struct
import wave
from pathlib import Path

path = Path(__file__).resolve().parents[2] / "assets/audio/sfx/combat/grenade_launch_01.wav"
rng = random.Random(1800)
rate = 44100
noise = 0.0
samples = bytearray()
for index in range(round(rate * 0.22)):
    t = index / rate
    noise = 0.85 * noise + 0.15 * rng.uniform(-1, 1)
    attack = min(1, t / 0.003)
    thump = math.sin(math.tau * (105 * t - 105 * t * t)) * math.exp(-t * 25)
    metallic = math.sin(math.tau * 760 * t) * math.exp(-t * 65)
    sample = attack * (0.21 * thump + 0.24 * noise * math.exp(-t * 32) + 0.035 * metallic)
    samples.extend(struct.pack("<h", round(max(-1, min(1, sample)) * 32767)))
with wave.open(str(path), "wb") as output:
    output.setnchannels(1)
    output.setsampwidth(2)
    output.setframerate(rate)
    output.writeframes(samples)
print(path.name)
