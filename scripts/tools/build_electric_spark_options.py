"""Three independent electrical SFX prototypes, synthesized from silence.

No audio files or existing game synthesizer are read or imported. The only
inputs are deterministic random seeds and the equations below. All outputs
are review artifacts; this script never changes runtime assets or profiles.
"""
from pathlib import Path
import base64
import json

import numpy as np
from scipy import signal
from scipy.io import wavfile

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/electric_spark_options_20260925"
RATE = 48000
DURATION = .28
COUNT = round(RATE * DURATION)
TIME = np.arange(COUNT) / RATE
GAIN = 10 ** (-10 / 20)


def band(x, low, high):
    return signal.sosfilt(signal.butter(3, [low, high], btype="bandpass", fs=RATE, output="sos"), x)


def unit_noise(rng, low, high):
    x = band(rng.normal(size=COUNT), low, high)
    return x / np.sqrt(np.mean(x*x))


def smooth(x):
    # Remove DC/sub-bass and ultrasonic fizz. Tiny endpoint ramps prevent
    # edit clicks while leaving intentional in-sound electrical transients.
    x = band(x, 200, 9500)
    x[:12] *= np.linspace(0, 1, 12)
    x[-960:] *= np.linspace(1, 0, 960)**2
    return x


def high_voltage_arc():
    """Relaxation discharges: a serrated electrical buzz that keeps breaking."""
    rng = np.random.default_rng(252601)
    voltage = 0.0
    impulses = np.zeros(COUNT)
    # A capacitor repeatedly charges, flashes over and discharges. Its
    # nonuniform threshold prevents a musical note or evenly timed rattle.
    threshold = 1.0
    for i, t in enumerate(TIME):
        speed = 155 + 145*np.sin(2*np.pi*8.2*t)**2 + 170*np.exp(-t/.075)
        voltage += speed/RATE
        if voltage >= threshold:
            voltage = 0.0
            impulses[i] = rng.uniform(.55, 1.0)*rng.choice([-1, 1])
            threshold = rng.uniform(.55, 1.25)
    ir_t = np.arange(round(.009 * RATE))/RATE
    response = (np.exp(-ir_t/.0012)*np.sin(2*np.pi*3700*ir_t)
                + .60*np.exp(-ir_t/.003)*np.sin(2*np.pi*1450*ir_t))
    discharge = signal.fftconvolve(impulses, response)[:COUNT]
    crackling_plasma = unit_noise(rng, 1400, 7800)
    activity = signal.lfilter([1], [1, -np.exp(-1/(RATE*.0017))], abs(impulses))
    activity = np.minimum(activity, 1.4)
    # Four torn packets, rather than a long hiss or a descending laser pitch.
    envelope = np.zeros(COUNT)
    for start, length, weight in [(0, .050, 1), (.060, .046, .95),
                                  (.121, .055, .84), (.193, .052, .56)]:
        u = TIME-start
        gate = (u >= 0) & (u < length)
        shape = np.clip(u/.0003, 0, 1)*np.clip((length-u)/.005, 0, 1)
        envelope += gate*shape*weight
    x = (discharge + .45*crackling_plasma*activity)*envelope
    return smooth(np.tanh(x*1.25))


def branching_snaps():
    """Dry dielectric breakdowns: sharp cracks with audible smaller branches."""
    rng = np.random.default_rng(252602)
    x = np.zeros(COUNT)
    # Each discharge has its own wideband impulse response and tiny branch
    # echoes. A short noisy pressure front makes this fuller than small ticks.
    for at, weight in [(0, 1), (.038, .93), (.092, .88), (.153, .74), (.213, .54)]:
        count = round(.045*RATE)
        u = np.arange(count)/RATE
        pressure = rng.normal(size=count)
        pressure = signal.sosfilt(signal.butter(2, [420, 6400], btype="bandpass", fs=RATE, output="sos"), pressure)
        pressure /= np.sqrt(np.mean(pressure*pressure))
        front = pressure*np.exp(-u/.0065)
        # Very short asymmetrical air-gap pulse, not a low drum/rolling boom.
        front += .65*np.sin(2*np.pi*820*u)*np.exp(-u/.0022)
        front *= np.minimum(u/.00012, 1)
        for offset, level in [(0, 1), (.0025, -.37), (.0068, .22)]:
            start = round((at+offset)*RATE)
            length = min(count, COUNT-start)
            x[start:start+length] += weight*level*front[:length]
        for _ in range(4):
            start = round((at+rng.uniform(.008, .028))*RATE)
            length = min(round(.006*RATE), COUNT-start)
            u2 = np.arange(length)/RATE
            branch = rng.normal(size=length)*np.exp(-u2/.0009)
            branch = signal.lfilter([1, -.84], [1], branch)
            x[start:start+length] += .18*weight*branch
    return smooth(np.tanh(x*1.65))


def tearing_discharge():
    """Hard fragmented discharge: bit-edge tearing with a gritty body."""
    rng = np.random.default_rng(252603)
    # Stochastic sample-and-hold creates actual jagged discontinuities. Their
    # dwell time changes chaotically, avoiding a clean pitched sci-fi glide.
    held = np.zeros(COUNT)
    index = 0
    while index < COUNT:
        count = int(rng.integers(4, 26))
        held[index:min(index+count, COUNT)] = rng.uniform(-1, 1)
        index += count
    rasp = band(held, 550, 6800)
    rasp /= np.sqrt(np.mean(rasp*rasp))
    rasp = np.tanh(rasp*2.3)
    grain = unit_noise(rng, 2100, 8200)
    env = np.zeros(COUNT)
    for at, width, strength in [(0, .027, 1), (.034, .049, .96),
                                (.098, .033, .92), (.139, .061, .79),
                                (.215, .036, .46)]:
        u = TIME-at
        env += ((u >= 0) & (u < width))*np.clip(u/.0002, 0, 1)*np.clip((width-u)/.003, 0, 1)*strength
    # A rough modulation breaks the rasp into grains that read as electrical
    # arcing rather than smooth air/noise. No reverberation smears the gaps.
    gate = .18+.82*(.5+.5*np.sin(2*np.pi*(125*TIME+90*TIME*TIME)))**1.7
    x = (.78*rasp+.22*grain)*gate*env
    edges = np.concatenate(([0], np.diff(env)))
    edge_t = np.arange(360)/RATE
    edge_response = np.sin(2*np.pi*2800*edge_t)*np.exp(-edge_t/.0013)
    x += .9*signal.fftconvolve(edges, edge_response)[:COUNT]
    return smooth(x)


def weighted_energy(x):
    # BS.1770 K-weighting at 48 kHz. Match integrated weighted energy across
    # equal-duration one-shots; this is approximate perceptual matching, not
    # a claim of gated LUFS compliance for a sub-400 ms sound.
    x = signal.lfilter([1.53512485958697, -2.69169618940638, 1.19839281085285],
                      [1, -1.69065929318241, .73248077421585], x)
    x = signal.lfilter([1, -2, 1], [1, -1.99004745483398, .99007225036621], x)
    return np.mean(x*x)


def write(path, x):
    assert np.isfinite(x).all() and np.max(abs(x)) < .98
    wavfile.write(path, RATE, np.round(x*32767).astype(np.int16))


def sequence(x):
    output = np.zeros(round(4.3*RATE))
    for at in [.25, 1.10, 2.0, 2.1, 2.2, 3.2, 3.3, 3.4]:
        start = round(at*RATE)
        output[start:start+len(x)] += x*GAIN
    return output


def uri(path):
    return "data:audio/wav;base64,"+base64.b64encode(path.read_bytes()).decode("ascii")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    options = [
        ("A", "高压断续电弧", "连续滋裂，电流反复击穿；偏高压电弧。", high_voltage_arc()),
        ("B", "干脆爆裂连锁", "清晰的啪、嚓、噼啪；偏短促、有力度的连锁击中。", branching_snaps()),
        ("C", "粗粝撕裂放电", "断断续续的粗糙电流，持续感更强；偏猛烈放电。", tearing_discharge()),
    ]
    # Start with -5 dBFS maximum peak; choose the common energy that preserves
    # that headroom for all candidates, instead of making any one louder.
    normalized = [x*(10**(-5/20))/max(abs(x)) for _, _, _, x in options]
    target = min(weighted_energy(x) for x in normalized)
    cards = []
    metrics = {}
    combined = np.zeros(round(15.6*RATE))
    for i, (key, title, description, _) in enumerate(options):
        x = normalized[i]*np.sqrt(target/weighted_energy(normalized[i]))
        source = OUT/f"option_{key}_source.wav"
        preview = OUT/f"option_{key}_preview.wav"
        solo = OUT/f"option_{key}_single.wav"
        write(source, x)
        demo = sequence(x)
        write(preview, demo)
        one = np.zeros(round(.9*RATE))
        one[4800:4800+COUNT] = x*GAIN
        write(solo, one)
        at = round((.3+i*5.1)*RATE)
        combined[at:at+len(demo)] = demo
        metrics[key] = {
            "source_seconds": len(x)/RATE,
            "source_peak_dbfs": float(20*np.log10(max(abs(x)))),
            "source_rms_dbfs": float(20*np.log10(np.sqrt(np.mean(x*x)))),
            "weighted_energy_db": float(10*np.log10(weighted_energy(x))),
            "preview_gain_db": -10,
            "preview_peak_dbfs": float(20*np.log10(max(abs(demo)))),
        }
        cards.append(f'''<article><div class="badge">{key}</div><div class="content"><h2>{title}</h2><p>{description}</p>
<div class="players"><div><label>单次放电</label><audio controls preload="metadata" src="{uri(solo)}"></audio></div><div><label>单次 × 2 → 三段连锁 × 2</label><audio controls preload="metadata" src="{uri(preview)}"></audio></div></div></div></article>''')
    write(OUT/"ABC_comparison.wav", combined)
    (OUT/"metrics.json").write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    page = '''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>电火花 · 三个全新方向</title>
<style>*{box-sizing:border-box}body{margin:0;background:#101820;color:#eef4f8;font:16px/1.7 system-ui,"Microsoft YaHei",sans-serif}main{max-width:1040px;margin:auto;padding:44px 26px 60px}.eyebrow{font-size:12px;letter-spacing:2px;color:#80c2de}h1{font-size:35px;line-height:1.25;margin:12px 0 20px}header p{max-width:800px;color:#b5c4d2}.tip{border-left:3px solid #77b4ca;padding:8px 16px;background:#192a35;margin:25px 0}.compare{padding:20px;background:#192630;border:1px solid #304957;border-radius:10px;margin:28px 0}.compare label{margin-bottom:12px}article{display:grid;grid-template-columns:50px 1fr;gap:18px;padding:30px 0;border-bottom:1px solid #314452}.badge{border:1px solid #486b82;color:#a4d9ee;border-radius:10px;text-align:center;height:47px;font-size:24px;line-height:45px}.content h2{font-size:24px;margin:0 0 8px}.content p{margin:0 0 20px;color:#b1c3d1}.players{display:grid;grid-template-columns:1fr 1fr;gap:18px}label{display:block;font-size:13px;color:#8eabbf;margin-bottom:9px}audio{display:block;width:100%;height:40px}footer{padding-top:27px;color:#95a9b8;font-size:13px}@media(max-width:650px){main{padding:28px 16px}.players{grid-template-columns:1fr}h1{font-size:29px}article{grid-template-columns:36px 1fr;gap:12px}.badge{height:36px;line-height:34px}}
</style></head><body><main><header><div class="eyebrow">ELECTRIC SPARK / NEW DIRECTIONS</div><h1>电火花 · 三个全新方向</h1><p>全部从零合成，不使用之前的音频，也不沿用之前的音效生成配方。先听三种质感，再选希望继续打磨的方向。</p><div class="tip">每款提供单次和连续跳跃。三款已做近似等响处理，试听时保持系统音量一致。连锁间隔均为 0.10 秒。</div></header>
<div class="compare"><label>连续比较：A → B → C（每款约 4 秒，中间留空）</label><audio controls preload="metadata" src="@@COMPARISON@@"></audio></div>
@@CARDS@@<footer>这些是待选音色，尚未替换游戏当前资源。试听为离线组合，使用统一 −10 dB 增益；不含背景音乐和游戏总线压缩。音量不是最终实战混音。选定音色后再完成接入及水／火联动。</footer></main><script>document.addEventListener('play',e=>{if(e.target.tagName==='AUDIO')document.querySelectorAll('audio').forEach(a=>{if(a!==e.target)a.pause()})},true)</script></body></html>'''
    page = page.replace("@@CARDS@@", "".join(cards)).replace("@@COMPARISON@@", uri(OUT/"ABC_comparison.wav"))
    (OUT/"review.html").write_text(page, encoding="utf-8")
    print(json.dumps(metrics, indent=2))
    print(OUT/"review.html")


if __name__ == "__main__":
    main()
