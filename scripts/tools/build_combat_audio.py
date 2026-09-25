"""Original procedural combat Foley. Requires numpy/scipy; no external samples.

python scripts/tools/build_combat_audio.py --review-dir <outside-project-folder>
Regenerates only this pack, its GDScript catalogue, and the optional offline review.
"""
from pathlib import Path
import argparse
import base64
import hashlib
import html
import json

import numpy as np
from scipy import signal
from scipy.io import wavfile
from combat_audio_revision_round2 import REVISED_CUES, synthesize as synthesize_round2

ROOT = Path(__file__).resolve().parents[2]
RATE = 48000
ASSET = ROOT / "assets/audio/sfx/combat"
APPROVED_LIGHTNING = ROOT / "scripts/tools/audio_sources/lightning_bright_approved.wav"
# key, label, category, variants, gain dB, minimum interval ms, voices, priority, pitch spread
SPECS = [
    ("wood_arrow", "木质弓箭命中", "武器", 1, -7, 65, 3, 2, .035),
    ("plasma_hit", "电浆炮接触", "武器", 1, -10, 160, 2, 2, .025),
    ("lightning", "电火花 · 噼啪电弧", "附魔", 1, -10, 75, 3, 1, .035),
    ("spark_charge", "落雷 · 蓄能", "附魔", 1, -19, 350, 1, 0, 0),
    ("electric_spark", "落雷 · 雷击轰鸣", "附魔", 1, -14, 260, 3, 2, .015),
    ("fire", "火焰 · 燃烧", "附魔", 1, -16, 260, 2, 1, .035),
    ("explosion", "爆炸 · 短冲击", "附魔", 1, -10, 230, 2, 2, .035),
    ("water", "水流 · 泼溅", "附魔", 1, -11, 180, 2, 1, .035),
    ("ice", "寒冰 · 冰块摩擦", "附魔", 1, -12, 240, 2, 1, .025),
    ("wind", "风刃 · 切风", "附魔", 1, -12, 180, 2, 1, .035),
    ("light_sword", "光辉剑 · 落地", "附魔", 1, -10, 260, 2, 2, .015),
    ("black_hole", "黑洞 · 空腔吸入", "附魔", 1, -13, 550, 1, 1, .02),
    ("reaction_steam", "水火 · 蒸汽", "联动", 1, -13, 330, 1, 2, .025),
    ("reaction_freeze", "水冰 · 冻结", "联动", 1, -11, 300, 1, 2, .02),
    ("reaction_thaw", "解冻 · 碎冰滴落", "联动", 1, -17, 400, 1, 0, .025),
    ("reaction_holy", "光火 · 神圣火焰", "联动", 1, -14, 450, 1, 2, .015),
    ("reaction_dark_flame", "暗火 · 暗焰", "联动", 1, -14, 500, 1, 2, .02),
    ("reaction_cancel", "光暗 · 湮灭", "联动", 1, -12, 350, 1, 2, .02),
    ("reaction_conduct", "电火花 × 水 · 导电爆裂", "联动", 1, -10, 160, 2, 2, .035),
    ("reaction_thunder_fire", "电火花 × 火 · 雷火引爆", "联动", 1, -8, 300, 2, 2, .025),
    ("reaction_conduct_strike", "落雷 × 水 · 导电雷鸣", "联动", 1, -14, 260, 3, 2, .015),
    ("reaction_thunder_fire_strike", "落雷 × 火 · 雷火轰鸣", "联动", 1, -14, 260, 3, 2, .015),
    ("reaction_wet_spread", "风水 · 扩散", "联动", 1, -16, 350, 1, 0, .03),
    ("reaction_ice_expand", "风冰 · 霜线推进", "联动", 1, -12, 350, 1, 1, .02),
    ("reaction_reflection", "光冰 · 棱镜反射", "联动", 1, -12, 450, 1, 2, .015),
]
# All landing variants share one cooldown and voice budget, including reactions.
THUNDER_CUES = {"electric_spark", "reaction_conduct_strike", "reaction_thunder_fire_strike"}
# User decision: ice enchantment / ice weapon and freezing have no audio.
# Keep source WAVs for archived comparisons, but reject every runtime entry point.
DISABLED_CUES = {"ice", "reaction_freeze"}


class Synth:
    def __init__(self, duration, seed):
        self.rng = np.random.default_rng(seed)
        self.t = np.arange(round(duration * RATE)) / RATE
        self.x = np.zeros(len(self.t))

    def env(self, decay, start=0, attack=.0015):
        u = np.maximum(0, self.t - start)
        return (self.t >= start) * (1 - np.exp(-u / attack)) * np.exp(-u / decay)

    def noise(self, low, high):
        n = self.rng.normal(0, 1, len(self.t))
        sos = signal.butter(2, [low, high], btype="bandpass", fs=RATE, output="sos")
        n = signal.sosfilt(sos, n)
        return n / max(np.std(n), 1e-6)

    def tone(self, freq, decay, gain, start=0, end=None, glide=.04):
        u = np.maximum(self.t - start, 0)
        end = freq if end is None else end
        phase = 2*np.pi*(end*u + (freq-end)*glide*(1-np.exp(-u/glide)))
        self.x += gain * np.sin(phase) * self.env(decay, start)

    def grit(self, low, high, decay, gain, start=0, attack=.0015):
        self.x += gain * self.noise(low, high) * self.env(decay, start, attack)

    def arc(self, scale=1):
        self.grit(1100, 6400, .014, .4*scale)
        self.tone(1500, .06, .12*scale, end=320, glide=.025)
        for start, gain in [(.028,.23),(.071,.13),(.115,.06)]:
            self.grit(650, 4500, .01, gain*scale, start)

    def crackle(self, scale=1, start=0):
        # Irregular groups of dry electrical snaps, not a pitched laser glide.
        for onset, weight in [(0, 1), (.041, .85), (.093, .9), (.156, .65), (.218, .5), (.279, .3)]:
            at = start + onset
            self.grit(750, 7200, .005, .48*weight*scale, at, attack=.0002)
            self.grit(340, 1900, .010, .16*weight*scale, at, attack=.0004)
            for _ in range(3):
                self.grit(1800, 9200, self.rng.uniform(.0008, .0032),
                          self.rng.uniform(.12, .28)*weight*scale,
                          at+self.rng.uniform(.002, .023), attack=.00015)
        # Quiet electrical grain bridges the snaps without becoming white hiss.
        gate = (.5+.5*np.sin(2*np.pi*83*self.t))**5
        self.x += .045*scale*self.noise(1400, 6100)*gate*self.env(.13, start)

    def chain_crackle(self, scale=1):
        # Sustained jagged discharges with irregular restrikes. Keep energy in
        # the midrange, with short bright edges rather than isolated soft ticks.
        for onset, weight in [(0, 1), (.021, .82), (.049, .95), (.082, .90),
                              (.116, .86), (.151, .74), (.190, .64),
                              (.232, .48), (.274, .30)]:
            at = onset + self.rng.uniform(0, .002)
            self.grit(950, 7200, .0075, .62*weight*scale, at, attack=.00012)
            self.grit(400, 2600, .015, .27*weight*scale, at, attack=.00025)
            u = np.maximum(self.t-at, 0)
            # Nonstationary pulse train gives the tearing, arcing texture.
            phase = 2*np.pi*(185*u + 1250*u*u)
            teeth = np.tanh(3.6*(np.sin(phase)+.38*np.sin(phase*2.73)))
            texture = .72*self.noise(750, 5100)+.28*teeth
            gate = .20+.80*(.5+.5*np.sin(phase))**2
            self.x += .24*weight*scale*texture*gate*self.env(.018, at, .00025)
            for _ in range(3):
                self.grit(1600, 7800, self.rng.uniform(.0012, .0035),
                          self.rng.uniform(.14, .26)*weight*scale,
                          at+self.rng.uniform(.003, .018), attack=.00010)

    def thunder(self):
        # Close lightning crack -> chest-weight pressure -> rolling thunder.
        # The body is mostly turbulent noise: a falling sine alone sounds like a kick.
        self.grit(1400, 8500, .011, .52, attack=.0003)
        self.grit(400, 3400, .058, .48, start=.005, attack=.001)
        self.grit(70, 520, .20, .72, attack=.004)
        self.grit(38, 150, .34, .65, start=.014, attack=.009)
        self.tone(66, .17, .18, start=.008, end=52, glide=.09)
        self.grit(120, 1400, .19, .26, start=.035, attack=.017)
        # Overlapping, increasingly distant rolls give a long but receding tail.
        for at, weight, high in [(.10, .24, 680), (.24, .20, 430), (.43, .14, 290), (.68, .09, 190)]:
            roll = self.noise(40, high)
            wobble = .65+.35*np.sin(2*np.pi*(5.3*self.t+.8*self.t*self.t))**2
            self.x += weight*roll*wobble*self.env(.27, at, attack=.035)
        # Diffuse early reflections, then dark reverberation; no obvious repeat.
        dry = self.x.copy()
        wet = np.zeros_like(dry)
        for delay, gain in [(.031, .15), (.053, -.12), (.087, .10), (.139, .08), (.211, -.055)]:
            offset = round(delay*RATE)
            wet[offset:] += gain*dry[:-offset]
        ir_t = np.arange(round(.78*RATE))/RATE
        impulse = self.rng.normal(size=len(ir_t))*np.exp(-ir_t/.17)*(1-np.exp(-ir_t/.028))
        impulse = signal.sosfilt(signal.butter(2, 1250, fs=RATE, output="sos"), impulse)
        impulse /= max(np.linalg.norm(impulse), 1e-9)
        wet += .11*signal.fftconvolve(dry, impulse)[:len(dry)]
        self.x += wet

    def crystal(self, scale=1, spread=1):
        for i, freq in enumerate([1050, 1713, 2497, 3431]):
            self.tone(freq*spread, .06+i*.022, scale*.18/(1+i*.5), i*.013)
        self.grit(1700, 5800, .025, .13*scale)

    def splash(self, scale=1):
        self.grit(320, 3400, .095, .3*scale, attack=.006)
        for i in range(9):
            self.tone(self.rng.uniform(450,1500), .014, .045*scale,
                      self.rng.uniform(.015,.22), end=self.rng.uniform(230,600), glide=.009)


def approved_lightning():
    rate, pcm = wavfile.read(APPROVED_LIGHTNING)
    if rate != RATE or pcm.dtype != np.int16 or pcm.ndim != 1:
        raise ValueError("Approved lightning must be 48 kHz mono PCM16")
    # Match write_wav's PCM scaling so rebuilding preserves every sample.
    return pcm.astype(np.float64) / 32767.0


def synthesize(key, variant):
    if key == "lightning":
        return approved_lightning()
    if key == "reaction_holy":
        return synthesize("reaction_dark_flame", variant)
    if key == "reaction_ice_expand":
        return synthesize("wind", variant)
    if key in REVISED_CUES:
        return synthesize_round2(key)
    seed = int.from_bytes(hashlib.sha256(f"{key}:{variant}:v1".encode()).digest()[:4], "little")
    duration = {"wood_arrow":.19, "spark_charge":.48,
                "electric_spark":1.72, "reaction_conduct_strike":1.72,
                "reaction_thunder_fire_strike":1.88, "reaction_thunder_fire":.65,
                "reaction_conduct":.39, "black_hole":.76, "light_sword":.48,
                "reaction_dark_flame":.62, "reaction_reflection":.53,
                "reaction_cancel":.43}.get(key, .39)
    s = Synth(duration, seed)
    v = s.rng.uniform(.94,1.06)
    if key == "wood_arrow":
        # Dry shaft/body impact: low wooden modes, fibre crunch, no metallic ring.
        s.tone(190*v,.030,.48,end=125*v,glide=.012)
        s.tone(465*v,.020,.20)
        s.tone(1130*v,.013,.075,start=.006)
        s.grit(180,1900,.018,.25)
        s.grit(1800,4600,.006,.13,start=.003)
    elif key == "plasma_hit":
        s.tone(190,.10,.38,end=70,glide=.08)
        s.grit(260,2600,.072,.22)
        s.x += .12*np.sin(2*np.pi*530*s.t + 2*np.sin(2*np.pi*73*s.t))*s.env(.09)
    elif key == "spark_charge":
        progress = np.clip(s.t/.48, 0, 1)
        ramp = progress**1.5*(1-np.exp(-s.t/.025))
        ramp *= np.clip((.48-s.t)/.025, 0, 1)
        s.x += (.20*s.noise(180, 1300)*(1-progress)+.10*s.noise(1600, 5500)*progress)*ramp
        s.x += .04*s.noise(700, 3200)*ramp*(.5+.5*np.sin(2*np.pi*47*s.t))**3
    elif key in THUNDER_CUES:
        s.thunder()
        if key == "reaction_conduct_strike":
            s.crackle(.40, start=.035)
            s.grit(1800, 6000, .08, .10, start=.09)
        elif key == "reaction_thunder_fire_strike":
            s.grit(90, 1600, .24, .27, start=.06, attack=.018)
            s.crackle(.25, start=.11)
    elif key == "reaction_thunder_fire":
        s.grit(70, 800, .14, .48, start=.012, attack=.004)
        s.grit(180, 2300, .10, .25, start=.043)
    elif key == "explosion":
        s.tone(150*v,.095,.60,end=49,glide=.024)
        s.grit(65,900,.10,.35)
        s.grit(1000,5000,.020,.18)
    elif key in ("fire", "reaction_dark_flame"):
        s.grit(80,1500,.13,.36,attack=.009)
        for start in [.01,.066,.14,.21]: s.grit(1200,4300,.007,.09,start)
        if key == "reaction_dark_flame":
            s.tone(108,.18,.16,end=62,glide=.15)
            s.x += .08*s.noise(340,1100)*s.env(.24)*np.sin(2*np.pi*19*s.t)
    elif key in ("water", "reaction_wet_spread", "reaction_thaw"):
        s.splash(.8)
        if key == "reaction_wet_spread": s.grit(450,3600,.12,.14,attack=.055)
        if key == "reaction_thaw": s.crystal(.28,1.24)
    elif key in ("ice", "reaction_freeze", "reaction_ice_expand"):
        s.crystal(.7,v)
        s.grit(600,3800,.032,.16)
        if key == "reaction_freeze":
            s.tone(290,.033,.25)
            for start in [.037,.089,.15]: s.grit(900,4800,.014,.20,start)
        if key == "reaction_ice_expand":
            for i in range(5): s.tone(850+i*280,.035,.13,i*.041)
    elif key == "wind":
        s.grit(700,4900,.034,.48,start=.015,attack=.034)
        s.grit(210,900,.053,.18,attack=.026)
    elif key in ("light_sword", "reaction_holy", "reaction_reflection"):
        if key == "light_sword":
            s.tone(230,.04,.38,end=100)
            s.grit(900,4300,.016,.24)
        elif key == "reaction_holy": s.grit(220,1900,.08,.18)
        else: s.grit(1300,5400,.085,.12,attack=.03)
        for i,f in enumerate([740,1110,1480,2220]):
            s.tone(f,.15-i*.023,.15/(1+i), i*.029 if key != "light_sword" else 0)
    elif key == "black_hole":
        s.tone(140,.22,.29,end=45,glide=.20)
        s.x += .12*s.noise(200,820)*s.env(.20,attack=.023)*(1+.3*np.sin(2*np.pi*13*s.t))
        s.tone(310,.15,.07,end=90,glide=.20)
    elif key == "reaction_steam":
        s.grit(1700,6700,.092,.38,attack=.012)
        s.grit(350,1600,.07,.12)
    elif key == "reaction_cancel":
        s.grit(280,2400,.062,.18,attack=.03)
        s.tone(720,.065,.26,end=65,glide=.06)
        s.grit(1400,4500,.012,.15,start=.088)
    elif key == "reaction_conduct":
        s.grit(450, 2400, .055, .12, start=.025)
    else:
        raise ValueError(key)
    # DC rejection, soft transient saturation, bounded peak and click-free endpoints.
    x = signal.sosfilt(signal.butter(2, 45, "highpass", fs=RATE, output="sos"), s.x)
    x = np.tanh(x*1.3)
    x[:24] *= np.linspace(0,1,24)
    fade = min(960,len(x)//4)
    x[-fade:] *= np.linspace(1,0,fade)**2
    if key in {"reaction_conduct", "reaction_thunder_fire"}:
        # Keep the approved arc's texture intact: process the element layer
        # first, then combine linearly without another saturation stage.
        arc = approved_lightning()
        x *= .65 if key == "reaction_thunder_fire" else 1.0
        x[:len(arc)] += arc * (.85 if key == "reaction_thunder_fire" else 1.0)
    x *= (10**(-5/20))/max(np.max(np.abs(x)),1e-6)
    return x


def write_wav(path, x):
    path.parent.mkdir(parents=True,exist_ok=True)
    assert np.isfinite(x).all() and np.max(np.abs(x)) < .999
    wavfile.write(path, RATE, np.round(x*32767).astype(np.int16))


def data_uri(path):
    return "data:audio/wav;base64,"+base64.b64encode(path.read_bytes()).decode("ascii")


def build_review(folder, profiles, audio):
    folder.mkdir(parents=True,exist_ok=True)
    items = []
    for key, label, category, *_ in SPECS:
        if key in DISABLED_CUES:
            continue
        paths = [ASSET / Path(p).name for p in profiles[key]["paths"]]
        controls = "".join(f'<audio controls preload="none" src="{data_uri(p)}"></audio>' for p in paths)
        items.append(f'<article data-kind="{category}"><small>{category}</small><h3>{label}</h3><p>正式音效 · {len(audio[key][0])/RATE:.2f} 秒 · 实战增益 {profiles[key]["gain_db"]} dB</p>{controls}</article>')
    old = []
    for name in ["lighting_1.wav","lighting_2.wav","thunder_1.wav"]:
        p = ROOT / "assets/audio/sfx/effects" / name
        old.append(f'<article><h3>原版 {html.escape(name)}</h3><audio controls preload="none" src="{data_uri(p)}"></audio></article>')
    # Illustrative sequence (not a game recording). Uses the same per-cue gains.
    mix = np.zeros(RATE*13)
    events = [(i*.48,"wood_arrow",0) for i in range(22)]
    events += [(1.02,"lightning",0),(1.15,"lightning",0),(2.1,"spark_charge",0),(2.6,"electric_spark",0),
               (3.3,"water",0),(3.75,"ice",0),(3.78,"reaction_freeze",0),(4.6,"fire",0),
               (4.85,"reaction_steam",0),(5.8,"light_sword",0),(6.3,"black_hole",0),
               (7.1,"wind",0),(7.25,"reaction_wet_spread",0),(8.1,"reaction_thunder_fire",0),
               (9.0,"plasma_hit",0),(9.24,"plasma_hit",0),(10.1,"reaction_reflection",0)]
    for start,key,v in events:
        if key in DISABLED_CUES:
            continue
        x=audio[key][v]*10**(profiles[key]["gain_db"]/20)
        at=round(start*RATE); mix[at:at+len(x)] += x
    write_wav(folder/"combat_sequence.wav",mix)
    spark = np.zeros(round(RATE*(.6+len(audio["electric_spark"][0])/RATE+.25)))
    for start,key in [(0.1,"spark_charge"),(.6,"electric_spark")]:
        x=audio[key][0]*10**(profiles[key]["gain_db"]/20)
        at=round(start*RATE); spark[at:at+len(x)] += x
    write_wav(folder/"spark_charge_and_strike.wav",spark)
    page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>战斗音效 · 当前试听</title>
<style>body{margin:0;background:#171b1c;color:#e5dbc9;font:16px/1.65 system-ui}main{max-width:1140px;margin:auto;padding:36px 28px}h1{font-size:30px}h2{margin-top:38px}p{color:#b6b5a8}section{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:16px}article{padding:18px;background:#292822;border:1px solid #4f4a3e;border-radius:9px}h3{margin:3px 0 8px;font-size:18px}small{color:#9cc0ad}audio{width:100%;height:38px;margin:4px 0}button{padding:9px 16px;margin:4px;border:1px solid #72694c;border-radius:5px;background:#35372d;color:#eee;cursor:pointer}header{border-bottom:1px solid #504b3d;padding-bottom:20px}</style>
<main><header><small>ORIGINAL PROCEDURAL SFX · 48 kHz / 16-bit PCM / MONO</small><h1>战斗音效 · 当前试听</h1>
<p>短促的材质撞击与元素音色，少量空腔、颤动用于黑洞和暗焰。全部由程序合成，无外部采样。此页可离线使用。</p>
<p>共 @@CUE_COUNT@@ 类正式音效，每类一个播放器。电火花为密集噼啪电弧；落雷为近处雷击与低沉滚雷，蓄能和雷击分开播放。水、火联动各有保留落雷轰鸣的组合音。</p>
<p>单项展示素材原始音量；游戏还会按表中增益降低音量、限制重复与并发。原版电音保持原始音量，仅供音色对照，不是等响度测评。</p></header>
<h2>组合试听</h2><section><article><h3>落雷：蓄能 → 0.5 秒后落雷</h3><audio controls src="@@SPARK@@"></audio></article><article><h3>连续交战 · 合成示意</h3><p>按游戏增益拼接，非实机录音；不含背景音乐。</p><audio controls src="@@MIX@@"></audio></article></section>
<h2>新音效</h2><nav><button onclick="filter('')">全部</button><button onclick="filter('武器')">武器</button><button onclick="filter('附魔')">附魔</button><button onclick="filter('联动')">联动</button></nav><section id="sounds">@@CARDS@@</section>
<h2>原版电音</h2><section>@@OLD@@</section><p>审阅重点：木箭是否够实、不像敲水鼓；电火花和落雷是否好区分；冰与光是否刺耳；连续播放是否疲劳。</p></main>
<script>function filter(k){document.querySelectorAll('#sounds article').forEach(e=>e.hidden=!!k&&e.dataset.kind!==k)}document.addEventListener('play',e=>{if(e.target.tagName==='AUDIO')document.querySelectorAll('audio').forEach(a=>{if(a!==e.target)a.pause()})},true)</script></html>'''
    page=page.replace("@@SPARK@@",data_uri(folder/"spark_charge_and_strike.wav")).replace("@@MIX@@",data_uri(folder/"combat_sequence.wav")).replace("@@CARDS@@","".join(items)).replace("@@OLD@@","".join(old))
    page=page.replace("@@CUE_COUNT@@",str(len(SPECS)-len(DISABLED_CUES)))
    (folder/"combat_audio_review.html").write_text(page,encoding="utf-8")


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--review-dir",type=Path)
    args=parser.parse_args()
    profiles={}; audio={}; report=[]
    for key,label,category,count,gain,cooldown,voices,priority,pitch in SPECS:
        paths=[]; audio[key]=[]
        for v in range(count):
            x=synthesize(key,v); path=ASSET/f"{key}_{v+1:02}.wav"
            write_wav(path,x); audio[key].append(x)
            paths.append("res://"+path.relative_to(ROOT).as_posix())
            report.append({"file":path.name,"seconds":len(x)/RATE,"peak_db":round(20*np.log10(max(abs(x))),2),
                           "rms_db":round(20*np.log10(np.sqrt(np.mean(x*x))),2),"end_sample":float(x[-1])})
        profiles[key]={"paths":paths,"gain_db":gain,"cooldown_ms":cooldown,"max_voices":voices,"priority":priority,"pitch_spread":pitch}
        if key in THUNDER_CUES:
            profiles[key]["voice_group"] = "thunder_landing"
    # Preloads also make every WAV an explicit export dependency.
    catalogue="extends RefCounted\n\n# Generated by scripts/tools/build_combat_audio.py. Tune profiles there.\nconst PROFILES: Dictionary = {\n"
    for key,profile in profiles.items():
        fields={k:v for k,v in profile.items() if k!="paths"}
        stream_text=", ".join('preload('+json.dumps(p)+')' for p in profile["paths"])
        catalogue+='\t'+json.dumps(key)+': {"streams": ['+stream_text+'], '+json.dumps(fields)[1:] + ",\n"
    catalogue+="}\n"
    catalogue += "\nconst DISABLED_CUES: Dictionary = " + json.dumps({key: True for key in sorted(DISABLED_CUES)}) + "\n"
    catalogue += "const DISABLED_PATHS: Dictionary = " + json.dumps({path: True for key in sorted(DISABLED_CUES) for path in profiles[key]["paths"]}) + "\n"
    target=ROOT/"scripts/audio/combat_sound_library.gd"
    target.parent.mkdir(parents=True,exist_ok=True)
    newline = "\r\n" if target.exists() and b"\r\n" in target.read_bytes() else "\n"
    with target.open("w", encoding="utf-8", newline="") as output:
        output.write(catalogue.replace("\n", newline))
    if args.review_dir:
        build_review(args.review_dir,profiles,audio)
        (args.review_dir/"audio_metrics.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
    print(json.dumps({"cue_types":len(profiles),"wav_files":len(report),"total_bytes":sum(p.stat().st_size for p in ASSET.glob('*.wav')),"review":str(args.review_dir)},ensure_ascii=True))


if __name__ == "__main__":
    main()
