"""Run the production weapon benchmark on a private desktop and publish evidence."""
import html
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/previews/new_weapon_art_20261025/production"
GODOT = "D:/soft/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"

def run():
    OUT.mkdir(parents=True, exist_ok=True)
    cmd = [sys.executable, str(ROOT / "scripts/tools/run_godot_background.py"),
           "--godot", GODOT, "--log", str(OUT / "capture.log"), "--timeout", "240", "--",
           "--path", str(ROOT), "--scene", "res://scenes/tests/furnace_saber_performance.tscn",
           "--resolution", "1920x1080", "--", "--transient-session", f"--capture-dir={OUT.as_posix()}"]
    subprocess.run(cmd, cwd=ROOT, check=True, timeout=260)
    log = (OUT / "capture.log").read_text(encoding="utf-8")
    bad = [line for line in log.splitlines() if any(p in line for p in ["SCRIPT ERROR", "SHADER ERROR", "Parse Error", "ERROR:"])]
    if bad or "FURNACE_SABER_PERFORMANCE_COMPLETE" not in log:
        raise RuntimeError("\n".join(bad) or "Benchmark did not complete")
    evidence = json.loads((OUT / "capture.json").read_text(encoding="utf-8"))
    assert evidence["foreground_samples"] == 0 and evidence["private_desktop"] == evidence["verified_desktop"] and evidence["exit_code"] == 0
    data = json.loads((OUT / "performance.json").read_text(encoding="utf-8"))
    assert data["runtimes_after_cleanup"] == 0 and len(data["cases"]) == 4
    publish(data)

def publish(data):
    labels = {"baseline":"空载基线", "furnace_single":"刚焰炉 · 单圈", "saber_single":"斩马刀 · 单刀", "five_rings_split_five_cuts":"五圈＋分裂＋五刀"}
    rows = []
    cards = []
    for case in data["cases"]:
        cpu = case["cpu_ms"]
        frames = case["frame_ms"]
        rows.append(f'<tr><td>{labels[case["id"]]}</td><td>{cpu["mean"]:.3f}</td><td>{cpu["p95"]:.3f}</td><td>{frames["mean"]:.2f}</td><td>{frames["p95"]:.2f}</td><td>{case["peak_weapon_visuals"]}</td></tr>')
        cards.append(f'<figure><img src="{case["id"]}.png?v=1"><figcaption>{labels[case["id"]]}</figcaption></figure>')
    page = '''<!doctype html><meta charset="utf-8"><title>新武器 · 正式接入与性能</title>
<style>:root{color-scheme:dark}body{margin:32px auto;padding:0 28px;max-width:1300px;background:#101716;color:#e0e8df;font:16px/1.7 "Segoe UI","Microsoft YaHei",sans-serif}h1{font-size:28px}p{color:#b2c2b6}table{width:100%;border-collapse:collapse}th,td{text-align:left;padding:12px;border-bottom:1px solid #35423e}th{color:#ffd778}section{display:grid;grid-template-columns:1fr 1fr;gap:16px}figure{margin:24px 0 0}img{width:100%;image-rendering:pixelated}a{color:#ffd778}small{color:#9dab9d}@media(max-width:800px){section{grid-template-columns:1fr}table{font-size:12px}}</style>
<h1>刚焰炉 & 斩马刀 · 正式接入</h1><p>受击触发、闪现斩击、五级升级、附魔与商店入口已接入。以下为正式武器运行时的后台实测。</p>
<p>300 个静止敌人，同一真实战场，1920 × 1080；每项 360 帧，跳过预热帧。CPU 列计入玩家、武器判定和燃烧更新；帧耗时包含整场渲染。测试关闭敌人 AI 并定时重置冷却以保持各组负载一致。</p>
<table><tr><th>场景</th><th>CPU 均值 ms</th><th>CPU P95 ms</th><th>帧均值 ms</th><th>帧 P95 ms</th><th>特效节点峰值</th></tr>''' + "".join(rows) + '</table><p>显卡：' + html.escape(data["rendering"]) + '。结束后两把武器的运行时残留为 0。</p><section>' + "".join(cards) + '</section><p><a href="performance.json">原始测量数据</a> · <a href="capture.json">后台运行证据</a> · <a href="../?v=4">此前的美术审阅</a></p><small>这是固定负载测试，不等同于所有敌人 AI 与附魔组合下的整场帧率保证。</small>'
    (OUT / "index.html").write_text(page, encoding="utf-8")
    print(json.dumps(data, ensure_ascii=True, indent=2))

if __name__ == "__main__":
    run()
