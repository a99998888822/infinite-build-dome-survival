"""Deterministic coin ticks, dividend chime and payout flourish (44.1 kHz PCM)."""
from pathlib import Path
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/audio/sfx/finance"
RATE = 44100


def bell(length, frequency, decay):
    t = np.arange(round(length * RATE)) / RATE
    attack = np.minimum(t / 0.003, 1)
    return attack * np.exp(-t / decay) * (
        np.sin(2 * np.pi * frequency * t)
        + 0.32 * np.sin(2 * np.pi * frequency * 2.73 * t)
        + 0.12 * np.sin(2 * np.pi * frequency * 4.11 * t)
    )


def render(name, duration, notes, peak):
    signal = np.zeros(round(duration * RATE))
    for start, frequency, gain, decay in notes:
        offset = round(start * RATE)
        tone = bell(duration - start, frequency, decay)
        signal[offset:offset + len(tone)] += tone * gain
    signal *= np.minimum((len(signal) - np.arange(len(signal))) / (RATE * 0.015), 1)
    signal *= peak / max(np.max(np.abs(signal)), 1e-8)
    with wave.open(str(OUT / name), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes((signal * 32767).astype("<i2").tobytes())


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    render("interest_tick.wav", 0.09, [(0, 1750, 1, 0.016), (0.012, 2580, 0.25, 0.013)], 0.55)
    render("interest_bonus.wav", 0.30, [(0, 1046.5, 1, 0.09), (0.045, 1568, 0.65, 0.10)], 0.65)
    render("interest_arrive.wav", 0.58, [(0, 784, 0.7, 0.14), (0.035, 1046.5, 1, 0.17), (0.07, 1318.5, 0.7, 0.18), (0.11, 1568, 0.6, 0.18), (0.16, 2093, 0.3, 0.12)], 0.70)
    print("BUILT 3 interest arrival cues")
