"""Refine option C: preserve its interrupted rhythm, remove gritty distortion.

Generate a review only. Original C remains available as the listening reference.
"""
from pathlib import Path
import json

import numpy as np
from scipy import signal
from scipy.io import wavfile

from build_electric_spark_options import COUNT, GAIN, RATE, TIME, sequence, uri, weighted_energy, write

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/electric_spark_c_clean_20260925"
REFERENCE = ROOT / "scripts/tools/audio_sources/electric_spark_reference/option_C_source.wav"


def clean_discharge():
    rng = np.random.default_rng(252604)
    x = np.zeros(COUNT)
    # Keep C's five interruption windows. Replace held noise and tanh clipping
    # with short, smooth, higher-frequency resonances for each individual snap.
    for start, width, strength in [(0, .027, 1), (.034, .049, .96),
                                  (.098, .033, .92), (.139, .061, .79),
                                  (.215, .036, .46)]:
        at = start
        while at < start + width - .004:
            length = min(round(.012*RATE), COUNT-round(at*RATE))
            u = np.arange(length)/RATE
            # A few clean, nonharmonic modes give a bright electric crack,
            # with no square edges, bit-crushing, saturation or pitch sweep.
            scale = rng.uniform(.965, 1.035)
            snap = (np.sin(2*np.pi*4300*scale*u)*np.exp(-u/.0018)
                    + .42*np.sin(2*np.pi*6150*scale*u)*np.exp(-u/.00085)
                    + .23*np.sin(2*np.pi*3250*scale*u)*np.exp(-u/.0027))
            snap *= (1-np.exp(-u/.00010))
            snap[-48:] *= np.linspace(1, 0, 48)**2
            # Small differences and tiny secondary sparks keep the sound
            # irregular; the former continuous rasp/noise bed is absent.
            weight = strength*rng.uniform(.72, 1)
            weight *= .80+.20*np.sin(2*np.pi*125*at)**2
            index = round(at*RATE)
            x[index:index+length] += weight*snap
            at += rng.uniform(.0048, .0082)
    # Linear filtering and gain only: do not reintroduce distortion while
    # brightening the sound. Roll off ultrasonic edges to limit sharp hiss.
    x = signal.sosfilt(signal.butter(2, [2300, 7600], btype="bandpass", fs=RATE, output="sos"), x)
    x[:12] *= np.linspace(0, 1, 12)
    x[-960:] *= np.linspace(1, 0, 960)**2
    return x


def metrics(x):
    frequency, power = signal.welch(x, RATE, nperseg=2048)
    return {
        "peak_dbfs": float(20*np.log10(max(abs(x)))),
        "weighted_energy_db": float(10*np.log10(weighted_energy(x))),
        "spectral_centroid_hz": float(np.sum(frequency*power)/np.sum(power)),
        "energy_below_1500_hz": float(np.sum(power[frequency < 1500])/np.sum(power)),
        "energy_above_3000_hz": float(np.sum(power[frequency > 3000])/np.sum(power)),
    }


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rate, original_pcm = wavfile.read(REFERENCE)
    assert rate == RATE and len(original_pcm) == COUNT
    original = original_pcm.astype(float)/32768
    clean = clean_discharge()
    # Equal K-weighted energy, retaining at least 5 dB peak headroom. A common
    # attenuation, if needed, keeps comparison levels honest for both versions.
    clean *= np.sqrt(weighted_energy(original)/weighted_energy(clean))
    attenuation = min(1.0, 10**(-5/20)/max(max(abs(original)), max(abs(clean))))
    original *= attenuation
    clean *= attenuation
    comparison = np.zeros(round(10.4*RATE))
    cards = []
    report = {"comparison_attenuation_db": float(20*np.log10(attenuation)), "versions": {}}
    for i, (key, title, description, x) in enumerate([
        ("original", "原版 C · 粗粝撕裂", "作为参照：原有的粗糙电流与失真颗粒。", original),
        ("clean", "C2 · 清亮噼啪", "保留断续节奏，提高噼啪音高，去掉砂砾底噪与饱和失真。", clean),
    ]):
        source = OUT/f"{key}_source.wav"
        preview = OUT/f"{key}_preview.wav"
        solo = OUT/f"{key}_single.wav"
        write(source, x)
        demo = sequence(x)
        write(preview, demo)
        single = np.zeros(round(.9*RATE))
        single[4800:4800+COUNT] = x*GAIN
        write(solo, single)
        at = round((.3+i*5.1)*RATE)
        comparison[at:at+len(demo)] = demo
        report["versions"][key] = metrics(x)
        cards.append(f'<article class="{key}"><h2>{title}</h2><p>{description}</p><div class="players"><div><label>单次放电</label><audio controls preload="metadata" src="{uri(solo)}"></audio></div><div><label>单次 × 2 → 三段连锁 × 2</label><audio controls preload="metadata" src="{uri(preview)}"></audio></div></div></article>')
    write(OUT/"C_to_C2_comparison.wav", comparison)
    (OUT/"metrics.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    page = '''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>电火花 C2 · 更高、更清亮</title>
<style>*{box-sizing:border-box}body{margin:0;background:#101922;color:#edf5fa;font:16px/1.7 system-ui,"Microsoft YaHei",sans-serif}main{max-width:1000px;margin:auto;padding:44px 26px 60px}.eyebrow{font-size:12px;letter-spacing:2px;color:#84c8df}h1{font-size:34px;line-height:1.3;margin:12px 0 18px}p{color:#b1c4d2}.compare,article{padding:23px;border:1px solid #344d5e;border-radius:12px;margin:22px 0;background:#192735}article.clean{border-color:#679ab0;background:#203744}h2{margin:0 0 8px;font-size:23px}.players{display:grid;grid-template-columns:1fr 1fr;gap:20px}label{display:block;font-size:13px;color:#a0bbc9;margin-bottom:10px}audio{display:block;width:100%;height:40px}footer{font-size:13px;color:#8ea8b8;margin-top:25px}@media(max-width:650px){main{padding:28px 16px}.players{grid-template-columns:1fr}h1{font-size:28px}}</style></head><body><main><header><div class="eyebrow">ELECTRIC SPARK / C → C2</div><h1>保留 C 的节奏，让噼啪更高、更清亮</h1><p>减少粗糙和失真，把电火花集中为短促、清晰的高音爆裂。两版已做近似等响处理，请保持系统音量一致。</p></header>
<div class="compare"><label>连续比较：原版 C → 新版 C2</label><audio controls preload="metadata" src="@@COMPARE@@"></audio></div>@@CARDS@@
<footer>每次放电仍为 0.28 秒，连锁间隔为 0.10 秒。试听使用统一 −10 dB 增益，不含背景音乐或游戏压缩器。此轮为音色精修审阅。</footer></main><script>document.addEventListener('play',e=>{if(e.target.tagName==='AUDIO')document.querySelectorAll('audio').forEach(a=>{if(a!==e.target)a.pause()})},true)</script></body></html>'''
    page = page.replace("@@CARDS@@", "".join(cards)).replace("@@COMPARE@@", uri(OUT/"C_to_C2_comparison.wav"))
    (OUT/"review.html").write_text(page, encoding="utf-8")
    print(json.dumps(report, indent=2))
    print(OUT/"review.html")


if __name__ == "__main__":
    main()
