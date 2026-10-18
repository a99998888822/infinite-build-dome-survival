"""Cut native MovieWriter recordings and build the supplied-audio review page."""
from pathlib import Path
import argparse
import html
import json
import shutil
import subprocess
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
CAPTURE = ROOT / "temp/audio-review/capture"
OUT = ROOT / "temp/audio-review/user-audio"
ROWS = [
    ("人物移动", ["walk"], "player/player_walk.wav", "实际步行时循环，站定即停；暂停和技能位移不播放脚步。"),
    ("炮械发射", ["grenade", "hand_cannon"], "combat/grenade_launch_01.wav", "铸铁榴弹炮、巨型手持火炮共用发射声；录像保留各自命中与爆炸声。"),
    ("异化触手命中", ["tentacle"], "combat/mutant_tentacle_hit.wav", "已与摆锤、战锤的音效分开。"),
    ("摆锤／战锤命中", ["meteor", "hammer"], "combat/meteor_flail_hit.wav", "流星摆锤和裂地战锤共用重击声。"),
    ("赤铜炉灯持续喷火", ["lamp"], "combat/copper_lamp_loop.wav", "释放期间循环播放同一段喷火音，结束即停；伤害 tick 不再播放电浆声。"),
    ("坤舆秘仪书命中", ["ritual"], "combat/ritual_mark_r02_01.wav", "每次点名伤害时播放。"),
    ("爆炸", ["explosion"], "combat/explosion_01.wav", "爆炸附魔与榴弹炮引爆共用。"),
    ("光辉剑落地", ["light_sword"], "combat/light_sword_01.wav", "剑体实际落地时播放。"),
    ("水流泼溅", ["water"], "combat/water_01.wav", "按 TXT 指定的 Wind_spreads_water_i_#4 文件接入。"),
    ("光冰棱镜反射", ["reflection"], "combat/reaction_reflection_01.wav", "演示目标预设光与湿润状态，再由真实冰附魔命中触发反射。"),
    ("风冰霜线推进", ["ice_expand"], "combat/reaction_ice_expand_01.wav", "先施加寒冰，再以风刃推进冰霜区域。"),
    ("水火蒸汽", ["steam"], "combat/reaction_steam_01.wav", "先施加水流，再以火焰触发蒸汽。"),
    ("冻结解除／冰块碎裂", ["thaw"], "combat/reaction_thaw_01.wav", "水冰冻结本身保持无声；冻结解除时播放碎裂声。"),
    ("风水湿润扩散", ["wet_spread"], "combat/reaction_wet_spread_01.wav", "风刃接触湿润目标，触发湿润扩散。"),
    ("火池燃烧 · 已停用", ["fire", "holy", "dark_flame"], None, "普通火池、神圣火焰和暗焰的燃烧音频已完全停用。火池持续燃烧、扩散和消失均无声；录像保留弓箭等其他实际声音。"),
    ("风刃切风", ["wind"], "combat/wind_01.wav", "风刃生成、切过目标时播放。"),
    ("电浆球命中", ["plasma_hit"], "combat/plasma_hit_01.wav", "接触伤害时播放，多个目标共享同一批反馈。"),
    ("光暗相互湮灭 · 无音频", ["cancel"], None, "已取消湮灭自身声音；录像仍保留先前光辉剑与弓箭等实际声音。状态、伤害及特效保留。"),
]
LABELS = {"walk": "人物移动", "grenade": "铸铁榴弹炮", "hand_cannon": "巨型手持火炮", "tentacle": "异化触手", "meteor": "流星摆锤", "hammer": "裂地战锤", "lamp": "赤铜炉灯", "ritual": "坤舆秘仪书", "holy": "神圣火焰", "dark_flame": "暗焰", "fire": "普通火池"}
for title, cases, _, _ in ROWS:
    for case in cases:
        LABELS.setdefault(case, title)


def run(args):
    subprocess.run(args, cwd=ROOT, check=True, stdout=subprocess.DEVNULL)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", default=shutil.which("ffmpeg"))
    parser.add_argument("--page-only", action="store_true")
    args = parser.parse_args()
    media = OUT / "media"
    media.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((ROOT / "scripts/tools/audio_sources/user_audio_manifest.json").read_text(encoding="utf-8"))
    sounds = {s["asset"].removeprefix("assets/audio/sfx/"): s for s in manifest["sounds"]}
    evidence = []
    cards = []
    ordered_clips = []
    for index, (title, cases, asset, note) in enumerate(ROWS, 1):
        videos = []
        for case in cases:
            row = json.loads((CAPTURE / (case + ".json")).read_text(encoding="utf-8"))
            # A re-recorded case has its own movie; its frame numbers refer to that file.
            movie = CAPTURE / row.get("movie", "gameplay.avi")
            start = row["start_frame"] / row["fps"]
            seconds = (row["end_frame"] - row["start_frame"]) / row["fps"]
            destination = media / (case + ".mp4")
            ordered_clips.append(destination)
            onsets = [float(e["time"]) for e in row["sounds"] if asset and e["path"].endswith(asset)]
            if asset and case not in ["walk", "lamp", "tentacle", "meteor", "hammer", "grenade", "hand_cannon"]:
                assert onsets, f"Requested sound was not triggered: {case}"
            if not onsets:
                onsets = [float(e["time"]) for e in row["loops"] if e["playing"]]
            poster_time = min(seconds-.2, onsets[0]+.15 if onsets else {"tentacle":.65,"meteor":.67,"hammer":1.16,"hand_cannon":.6,"cancel":1.65}.get(case,1.0))
            if not args.page_only and (not destination.exists() or destination.stat().st_mtime < max(movie.stat().st_mtime, (CAPTURE / (case + ".json")).stat().st_mtime)):
                # Native recording is 1920x1080. Crop to the encounter, preserving pixels.
                subtitle = media / (case + ".ass")
                subtitle.write_text("[Script Info]\nScriptType: v4.00+\nPlayResX: 960\nPlayResY: 640\n[V4+ Styles]\nFormat: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\nStyle: Default,Microsoft YaHei,24,&H00FFFFFF,&H00FFFFFF,&H00121116,&H80121116,0,0,0,0,100,100,0,0,3,8,0,7,20,20,18,1\n[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\nDialogue: 0,0:00:00.00,0:00:20.00,Default,,0,0,0,," + f"{index:02d}  {LABELS[case]} · 实机原声" + "\n", encoding="utf-8")
                filters = "crop=1200:800:420:180,scale=960:640:flags=lanczos,subtitles=" + subtitle.relative_to(ROOT).as_posix()
                run([args.ffmpeg, "-v", "error", "-y", "-ss", str(start), "-i", str(movie), "-t", str(seconds), "-vf", filters, "-c:v", "libx264", "-preset", "fast", "-crf", "20", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", str(destination)])
                run([args.ffmpeg, "-v", "error", "-y", "-ss", str(poster_time), "-i", str(destination), "-frames:v", "1", str(media / (case + ".jpg"))])
                run([args.ffmpeg, "-v", "error", "-y", "-ss", str(start), "-i", str(movie), "-t", str(seconds), "-vn", "-c:a", "pcm_s16le", str(media / (case + "-live.wav"))])
            with wave.open(str(media / (case + "-live.wav")), "rb") as stream:
                pcm = np.frombuffer(stream.readframes(stream.getnframes()), np.int16).astype(float) / 32768
                row["audio_seconds"] = stream.getnframes() / stream.getframerate()
            row["peak_dbfs"] = float(20*np.log10(max(np.max(np.abs(pcm)), 1e-10)))
            row["rms_dbfs"] = float(20*np.log10(max(np.sqrt(np.mean(pcm*pcm)), 1e-10)))
            assert row["peak_dbfs"] > -70, f"Unexpected silent live recording: {case}"
            assert all(c["success"] for c in row["casts"]), f"Failed cast: {case}"
            evidence.append(row)
            version = int(destination.stat().st_mtime)
            videos.append(f'<div class="clip" data-case="{case}"><strong>{html.escape(LABELS[case])}</strong><video controls playsinline preload="none" poster="media/{case}.jpg?v={version}" src="media/{case}.mp4?v={version}"></video><a href="media/{case}.mp4?v={version}" download>下载片段</a></div>')
        source = ""
        if asset:
            item = sounds[asset]
            filename = Path(item["source"]).name
            solo = "source-" + Path(asset).name
            shutil.copy2(ROOT / item["asset"], media / solo)
            source = f'<details><summary>单独试听素材 · {item["seconds"]:.3f} 秒</summary><audio controls preload="none" src="media/{solo}?v={item["asset_sha256"][:12]}"></audio><p>素材原始音量；上方视频使用游戏混音。</p><code>{html.escape(filename)}</code></details>'
        key = asset or ("combat/fire_01.wav" if cases[0] == "fire" else "cancel")
        cards.append(f'<article id="s{index:02d}" data-key="{key}"><div class="heading"><span>{index:02d}</span><h2>{title}</h2></div><p>{note}</p><div class="clips">{"".join(videos)}</div>{source}<div class="feedback"><label>审阅结论 <select><option value="">待审阅</option><option>通过</option><option>需要调整</option></select></label><input placeholder="备注：音量、时机、循环感、其他…" aria-label="{title}备注"></div></article>')
    if not args.page_only:
        playlist = media / "concat.txt"
        playlist.write_text("\n".join("file '"+p.name+"'" for p in ordered_clips), encoding="utf-8")
        run([args.ffmpeg, "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(playlist), "-c", "copy", "-movflags", "+faststart", str(media / "overview.mp4")])
    page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>新音效 · 实机审阅</title>
<style>*{box-sizing:border-box}body{margin:0;background:#101616;color:#e9e8de;font:16px/1.6 system-ui,"Microsoft YaHei"}main{max-width:1160px;padding:32px 24px;margin:auto}header{border-bottom:1px solid #46534e;padding-bottom:24px}h1{font-size:34px;margin:6px 0}h2{font-size:22px;margin:0}p{color:#bac4bd}a{color:#94dbb8}button,select,input{font:inherit;background:#202e29;color:#f1f4ef;border:1px solid #567766;border-radius:6px;padding:9px 12px}button{cursor:pointer}.bar{position:sticky;top:0;z-index:2;padding:14px;background:#101616ee;display:flex;gap:16px;align-items:center;backdrop-filter:blur(10px)}article{background:#19221f;border:1px solid #354a40;border-radius:12px;padding:24px;margin:22px 0;scroll-margin-top:80px}.heading{display:flex;gap:14px;align-items:center}.heading span{color:#99dbb5;font-size:22px;font-weight:bold}.clips{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:18px}video{display:block;width:100%;background:#050909;border-radius:6px;margin:8px 0}.clip>a{font-size:13px}details{margin-top:20px;background:#111b17;border-radius:7px;padding:12px}summary{cursor:pointer}audio{width:100%;margin-top:10px}code{font-size:12px;word-break:break-all}details p{font-size:13px}.feedback{display:flex;gap:18px;margin-top:18px;align-items:center}.feedback input{flex:1;min-width:0}.overview{max-width:850px}nav{display:flex;flex-wrap:wrap;gap:8px}nav a{text-decoration:none;background:#22332b;padding:5px 11px;border-radius:5px;font-size:14px}@media(max-width:650px){main{padding:20px 12px}.feedback{display:block}.feedback input{margin-top:10px;width:100%}.clips{grid-template-columns:1fr}article{padding:16px}}</style>
<main><header><small>AUDIO.RAR · 2026.10.18</small><h1>新音效 · 实机审阅</h1><p>17 段指定音频中现有 16 段在用，火池燃烧与光暗湮灭音效已停用。下方 22 个场景均从游戏运行中录制，包含游戏实际混音，可直接播放有声视频。</p><p>为方便逐项听清，演示关闭背景音乐，以固定耐久目标触发真实武器、附魔与反应。单项素材另附试听；反馈自动保存在此浏览器。</p><details><summary>连续观看全部场景（约 1 分 40 秒）</summary><video class="overview" controls playsinline preload="none" src="media/overview.mp4"></video><a href="media/overview.mp4" download>下载合集</a></details></header><div class="bar"><b id="progress">0 / 18 已审阅</b><button id="export">导出审阅意见</button><label><input id="pending" type="checkbox">只看待审阅</label></div><nav>@@NAV@@</nav>@@CARDS@@<p>音画由 Godot 原生录制同步生成，视频未后配音。电火花／落雷的导电复用关系保持生效；普通火池、暗焰和神圣火焰的燃烧音频已完全停用。</p></main>
<script>const storage='dome-user-audio-20261018-v1',cards=[...document.querySelectorAll('article')];let saved={};try{saved=JSON.parse(localStorage.getItem(storage)||'{}')}catch{}function update(){document.querySelector('#progress').textContent=cards.filter(c=>c.querySelector('select').value).length+' / 18 已审阅';for(const c of cards)c.hidden=document.querySelector('#pending').checked&&!!c.querySelector('select').value}for(const c of cards){let v=saved[c.dataset.key]||{};c.querySelector('select').value=v.decision||'';c.querySelector('input').value=v.note||'';c.addEventListener('input',()=>{saved[c.dataset.key]={name:c.querySelector('h2').textContent,decision:c.querySelector('select').value,note:c.querySelector('input').value};localStorage.setItem(storage,JSON.stringify(saved));update()})}document.querySelector('#pending').onchange=update;document.querySelector('#export').onclick=()=>{const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([JSON.stringify(saved,null,2)],{type:'application/json'}));a.download='新音效审阅意见.json';a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000)};document.addEventListener('play',e=>{if(['AUDIO','VIDEO'].includes(e.target.tagName))document.querySelectorAll('audio,video').forEach(m=>{if(m!==e.target)m.pause()})},true);update();</script></html>'''
    page = page.replace("@@CARDS@@", "\n".join(cards)).replace("@@NAV@@", "".join(f'<a href="#s{i:02d}">{i:02d} {r[0]}</a>' for i,r in enumerate(ROWS,1)))
    page = page.replace("media/overview.mp4", "media/overview.mp4?v=" + str(int((media / "overview.mp4").stat().st_mtime)))
    (OUT / "review.html").write_text(page, encoding="utf-8")
    (OUT / "evidence.json").write_text(json.dumps({"source_manifest": manifest, "recordings": evidence}, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"page": str(OUT / "review.html"), "videos": len(evidence), "audio_files":sum(bool(row[2]) for row in ROWS)}, ensure_ascii=True))


if __name__ == "__main__":
    main()
