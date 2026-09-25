"""Deterministic recipes implementing the user's 2026-09-25 audio decisions."""
from pathlib import Path

import numpy as np
from scipy import signal
from scipy.io import wavfile

RATE = 48000
SOURCES = Path(__file__).parent / "audio_sources/round2"
REVISED_CUES = {"plasma_hit", "fire", "ice", "light_sword", "reaction_freeze", "reaction_reflection"}


class Sound:
    def __init__(self, seconds, seed):
        self.t = np.arange(round(seconds*RATE))/RATE
        self.x = np.zeros(len(self.t))
        self.rng = np.random.default_rng(seed)

    def noise(self, low, high):
        x = signal.sosfilt(signal.butter(2, [low, high], btype="bandpass", fs=RATE, output="sos"), self.rng.normal(size=len(self.t)))
        return x/max(np.std(x), 1e-8)

    def envelope(self, start, decay, attack=.001):
        u = np.maximum(self.t-start, 0)
        return (self.t >= start)*(1-np.exp(-u/attack))*np.exp(-u/decay)

    def impact(self, frequency, end, decay, gain, start=0):
        u = np.maximum(self.t-start, 0)
        glide = .018
        phase = 2*np.pi*(end*u+(frequency-end)*glide*(1-np.exp(-u/glide)))
        self.x += gain*np.sin(phase)*self.envelope(start,decay)

    def grit(self, low, high, start, decay, gain, attack=.001):
        self.x += gain*self.noise(low,high)*self.envelope(start,decay,attack)


def finish(x, peak_db=-5):
    x = signal.sosfilt(signal.butter(2,35,btype="highpass",fs=RATE,output="sos"),x)
    x[:24] *= np.linspace(0,1,24)
    x[-1440:] *= np.linspace(1,0,1440)**2
    return x*10**(peak_db/20)/max(np.max(abs(x)),1e-8)


def ice_friction(frozen=False):
    s = Sound(1.12 if frozen else 1.02, 251901 if frozen else 250901)
    # Two long stick/slip strokes: strained creaks and rough contact,
    # rather than a stack of bright bell partials.
    for onset, width, base, weight in [(.025,.38,520,1),(.45,.48,390,.78)]:
        u = np.clip((s.t-onset)/width,0,1)
        envelope = ((s.t>=onset)&(s.t<onset+width))*np.sin(np.pi*u)**.8
        frequency = base+260*np.sin(np.pi*u)+28*np.sin(2*np.pi*27*s.t)
        phase = 2*np.pi*np.cumsum(frequency)/RATE
        strain = np.sin(phase)+.30*np.sin(phase*2.017)+.11*np.sin(phase*3.13)
        slip = .28+.72*(.5+.5*np.sin(2*np.pi*(22*s.t+8*s.t*s.t)))**2
        contact = s.noise(190,2400)
        s.x += weight*envelope*(.24*strain*slip+.16*contact*(.5+.5*slip))
        for offset in [.04,.17,.29]:
            s.grit(320,2100,onset+offset,.012,.09*weight)
    if frozen:
        s.impact(155,80,.070,.32)
        s.grit(160,1300,0,.038,.20)
    return finish(s.x)


def synthesize(cue):
    if cue in {"ice","reaction_freeze"}:
        return ice_friction(cue=="reaction_freeze")
    if cue == "plasma_hit":
        s = Sound(.28,250301)
        s.grit(1500,6200,0,.014,.44,attack=.00025)
        s.impact(880,560,.020,.22)
        s.grit(650,2800,.009,.037,.16)
        s.impact(290,190,.035,.12)
        for onset, gain in [(.023,.18),(.051,.10),(.083,.035)]:
            s.grit(2100,6100,onset,.006,gain,attack=.0002)
        return finish(s.x)
    if cue == "fire":
        s = Sound(.94,250801)
        envelope = (1-np.exp(-s.t/.045))*np.exp(-s.t/.37)
        flutter = .60+.25*np.sin(2*np.pi*8*s.t)**2+.15*np.sin(2*np.pi*19*s.t)**2
        s.x += .34*s.noise(100,1900)*envelope*flutter
        s.x += .075*s.noise(1600,4300)*envelope*(.6+.4*np.sin(2*np.pi*31*s.t)**2)
        for onset,gain in [(.10,.032),(.24,.025),(.43,.021),(.63,.014)]:
            s.grit(1300,3600,onset,.009,gain)
        return finish(s.x,-7)
    if cue == "light_sword":
        rate, pcm = wavfile.read(SOURCES/"before_light_sword_01.wav")
        assert rate==RATE
        s = Sound(.58,251001)
        # Keep the recognizable landing signature under a larger body impact.
        original = signal.sosfilt(signal.butter(2,1050,fs=RATE,output="sos"),pcm.astype(float)/32768)
        s.x[:len(original)] += .42*original
        s.impact(175,62,.105,.63)
        s.grit(75,650,0,.077,.26,attack=.002)
        s.grit(450,1900,.005,.023,.18)
        for frequency,gain in [(330,.10),(570,.060),(910,.025)]:
            s.impact(frequency,frequency,.10,gain,start=.006)
        return finish(s.x)
    if cue == "reaction_reflection":
        return prism_shimmer()
    raise ValueError(cue)


def prism_shimmer():
    """Round three: clear, magical glints, without an approaching wind layer."""
    s = Sound(1.18,252203)
    # A consonant upper-register constellation, overlapping rather than sweeping.
    # Mild inharmonic partials and detuned tails add glass-like sparkle.
    glints = [(0,1046.5,1),(.048,1568,.52),(.11,2093,.40),
              (.18,1318.51,.48),(.26,2637.02,.25),(.35,1568,.32),
              (.45,2093,.22),(.56,3136,.11)]
    for onset, frequency, gain in glints:
        u = np.maximum(s.t-onset,0)
        envelope = s.envelope(onset,.15 if frequency>2200 else .23,.003)
        phase = 2*np.pi*frequency*u + .06*np.sin(2*np.pi*5.2*u)
        chime = (np.sin(phase)+.23*np.sin(2*np.pi*frequency*2.003*u)
                 +.09*np.sin(2*np.pi*frequency*2.76*u))
        s.x += .22*gain*chime*envelope
        s.x += .025*gain*np.sin(2*np.pi*(frequency+2.3)*u)*s.envelope(onset,.30,.025)
    # A soft octave foundation prevents the small bright glints feeling thin.
    s.x += .06*np.sin(2*np.pi*523.25*s.t)*s.envelope(0,.22,.008)
    dry = s.x.copy()
    for delay,gain in [(.073,.16),(.137,.11),(.223,.07)]:
        shift=round(delay*RATE)
        s.x[shift:] += gain*dry[:-shift]
    s.x = signal.sosfilt(signal.butter(2,6500,fs=RATE,output="sos"),s.x)
    return finish(s.x,-6)


def meteor_from_old_plasma():
    # Preserve the old plasma's heard -10 dB level on the flail's direct SFX route.
    rate, pcm = wavfile.read(SOURCES/"before_plasma_hit_01.wav")
    assert rate==RATE and pcm.dtype==np.int16
    return pcm.astype(float)/32767*10**(-10/20)
