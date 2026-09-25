"""Conservative processing of the exact option_C_preview.wav requested.

No resynthesis: each direction is obtained by filtering/pitch-shifting that
existing recording, then matching its approximate perceptual level.
"""
from pathlib import Path
import base64
import hashlib
import json
import shutil
import subprocess

import numpy as np
from scipy import signal
from scipy.io import wavfile

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "scripts/tools/audio_sources/electric_spark_reference/option_C_preview.wav"
OUT = ROOT / "artifacts/electric_spark_c_directions_20260925"
RATE = 48000
OPTIONS = [
    ("1", "原味提亮", "保留原音高和颗粒，只把噼啪的亮度往上推一点。", "treble=g=3:f=2800:w=0.5,equalizer=f=650:t=q:w=0.8:g=-1"),
    ("2", "小幅升调", "整体提高两个半音，保留原有撕裂结构和放电节奏。", "rubberband=tempo=1:pitch=1.122462048309373:transients=crisp:detector=percussive:window=short:pitchq=quality"),
    ("3", "轻收毛边", "保留粗粝颗粒，轻压尖锐毛刺，让中高频噼啪更集中。", "equalizer=f=6500:t=q:w=0.8:g=-3,equalizer=f=3100:t=q:w=0.8:g=2,equalizer=f=700:t=q:w=1:g=-1"),
]


def weighted_energy(x):
    x = signal.lfilter([1.53512485958697, -2.69169618940638, 1.19839281085285],
                      [1, -1.69065929318241, .73248077421585], x)
    x = signal.lfilter([1, -2, 1], [1, -1.99004745483398, .99007225036621], x)
    return float(np.mean(x*x))


def rms_envelope(x):
    frames = x[:len(x)//240*240].reshape(-1, 240)
    return np.sqrt(np.mean(frames*frames, axis=1))


def describe(x, original):
    frequency, power = signal.welch(x, RATE, nperseg=2048)
    return {
        "seconds": len(x)/RATE,
        "peak_dbfs": float(20*np.log10(max(abs(x)))),
        "weighted_energy_db": float(10*np.log10(weighted_energy(x))),
        "centroid_hz": float(np.sum(frequency*power)/np.sum(power)),
        "envelope_correlation_with_original": float(np.corrcoef(rms_envelope(x), rms_envelope(original))[0, 1]),
    }


def write(path, x):
    assert np.isfinite(x).all() and np.max(abs(x)) < .98
    wavfile.write(path, RATE, np.round(x*32768).astype(np.int16))


def uri(path):
    return "data:audio/wav;base64,"+base64.b64encode(path.read_bytes()).decode("ascii")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    rate, pcm = wavfile.read(SOURCE)
    assert rate == RATE and pcm.dtype == np.int16 and pcm.ndim == 1
    original = pcm.astype(float)/32768
    # Keep the listening reference byte-for-byte identical to the selected file.
    reference = OUT/"original_C_preview.wav"
    shutil.copyfile(SOURCE, reference)
    audios = [("original", "原版 C", "你指定的原文件，作为对照。", reference, original)]
    metrics = {"source": str(SOURCE.relative_to(ROOT)), "source_sha256": source_hash, "options": {}}
    target = weighted_energy(original)
    for key, title, description, effects in OPTIONS:
        command = ["ffmpeg", "-v", "error", "-i", str(SOURCE), "-af", effects,
                   "-ar", str(RATE), "-ac", "1", "-f", "f32le", "pipe:1"]
        result = subprocess.run(command, check=True, capture_output=True)
        audio = np.frombuffer(result.stdout, dtype="<f4").astype(float)
        raw_frames = len(audio)
        assert abs(len(audio)-len(original)) < RATE*.15
        audio = np.pad(audio, (0, max(0, len(original)-len(audio))))[:len(original)]
        # Only trim/pad within the final silence. No new envelope, hits or
        # rescheduled events are created, including for the pitch-only option.
        assert np.max(abs(audio[-2400:])) < .0005
        audio *= np.sqrt(target/weighted_energy(audio))
        audio[:24] *= np.linspace(0, 1, 24)
        audio[-240:] *= np.linspace(1, 0, 240)
        path = OUT/f"direction_{key}_preview.wav"
        write(path, audio)
        measurements = describe(audio, original)
        measurements["filter"] = effects
        measurements["raw_frames"] = raw_frames
        assert measurements["envelope_correlation_with_original"] > .90
        metrics["options"][key] = measurements
        audios.append((key, title, description, path, audio))
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == source_hash
    assert reference.read_bytes() == SOURCE.read_bytes()
    comparison = np.zeros(round(20.4*RATE))
    cards = []
    for index, (key, title, description, path, audio) in enumerate(audios):
        at = round((.25+index*5.1)*RATE)
        comparison[at:at+len(audio)] = audio
        cards.append(f'<article><div class="number">{"C" if key == "original" else key}</div><div><h2>{title}</h2><p>{description}</p><audio controls preload="metadata" src="{uri(path)}"></audio></div></article>')
    write(OUT/"C_and_three_directions.wav", comparison)
    metrics["reference"] = describe(original, original)
    (OUT/"metrics.json").write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    page = '''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>保留原版 C · 三个小幅修改方向</title><style>
*{box-sizing:border-box}body{margin:0;background:#121a20;color:#eef1f5;font:16px/1.7 system-ui,"Microsoft YaHei",sans-serif}main{max-width:880px;margin:auto;padding:42px 24px 60px}h1{font-size:31px;line-height:1.3;margin:12px 0 18px}.eyebrow{color:#93b9cb;font-size:12px;letter-spacing:2px}p{color:#b9c5ce}.sequence{padding:20px;background:#22303b;border:1px solid #405767;border-radius:10px;margin:26px 0}label{display:block;font-size:13px;color:#bdcfd9;margin-bottom:12px}article{display:grid;grid-template-columns:43px 1fr;gap:18px;padding:27px 0;border-bottom:1px solid #32434e}.number{font-size:25px;color:#a6d1e2}h2{font-size:23px;margin:0}article p{margin:8px 0 17px}audio{width:100%;height:40px;display:block}footer{font-size:13px;color:#8fabbc;margin-top:25px}@media(max-width:600px){main{padding:27px 16px}h1{font-size:26px}article{gap:9px;grid-template-columns:32px 1fr}}</style></head><body><main><header><div class="eyebrow">ORIGINAL C / SUBTLE DIRECTIONS</div><h1>保留原版 C，比较三个小幅修改方向</h1><p>直接处理你指定的 option_C_preview.wav，保留它的撕裂质感和节奏。原版作为第一项，修改版已匹配近似响度。</p><p>建议先听 1：只提亮，变化最保守。2 主要比较音高，3 主要比较毛刺与清晰度。</p></header>
<div class="sequence"><label>依次播放：原版 C → 1 提亮 → 2 升调 → 3 收毛边</label><audio controls preload="metadata" src="@@SEQUENCE@@"></audio></div>@@CARDS@@
<footer>各段均为 4.3 秒，保留原单次与连锁排列。原版对照文件逐字节一致。此轮为音色方向审阅，未替换游戏资源。</footer></main><script>document.addEventListener('play',e=>{if(e.target.tagName==='AUDIO')document.querySelectorAll('audio').forEach(a=>{if(a!==e.target)a.pause()})},true)</script></body></html>'''
    page = page.replace("@@CARDS@@", "".join(cards)).replace("@@SEQUENCE@@", uri(OUT/"C_and_three_directions.wav"))
    (OUT/"review.html").write_text(page, encoding="utf-8")
    print(json.dumps(metrics, indent=2))
    print(OUT/"review.html")


if __name__ == "__main__":
    main()
