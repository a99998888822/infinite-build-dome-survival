"""Compose an attack review from the approved PNG frames; no gameplay edits."""

from __future__ import annotations

import base64
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/elite_rusher_assets_20260923"
ASSETS = ROOT / "assets/sprites/enemies/combat/elite_rusher"
MANIFEST = ROOT / "assets/sprites/enemies/elite_rusher/asset_manifest.json"
META = json.loads(MANIFEST.read_text(encoding="utf-8"))
SCALE = 2
TICK = 20
IDLE_IN = 600
WINDUP = sum(META["actions"]["windup"]["durations"])
DASH = 400
RECOVER = sum(META["actions"]["recover"]["durations"])
ATTACK_START = IDLE_IN + WINDUP
RECOVER_START = ATTACK_START + DASH
END = RECOVER_START + RECOVER
TOTAL = END + 700
START_X = 160
GROUND_Y = 245
DISTANCE = META["telegraph"]["center_travel_px"]
LABELS = {"idle": "准备", "windup": "蓄力预警", "dash": "冲刺攻击", "recover": "收招", "rest": "恢复待机"}


def font(size):
    return ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", size)


def images():
    result = {}
    for action in ("idle", "windup", "dash", "recover"):
        with Image.open(ASSETS / f"enemy_rift_rusher_{action}.png") as sheet:
            result[action] = [sheet.convert("RGBA").crop((i*128, 0, (i+1)*128, 128))
                              for i in range(META["actions"][action]["count"])]
    return result


def state_at(time_ms):
    if time_ms < IDLE_IN:
        return "idle", time_ms, 0.0
    if time_ms < ATTACK_START:
        return "windup", time_ms-IDLE_IN, 0.0
    if time_ms < RECOVER_START:
        return "dash", time_ms-ATTACK_START, (time_ms-ATTACK_START)/DASH
    if time_ms < END:
        return "recover", time_ms-RECOVER_START, 1.0
    return "rest", time_ms-END, 1.0


def index_at(action, elapsed):
    action = "idle" if action == "rest" else action
    spec = META["actions"][action]
    if spec["loop"]:
        elapsed %= sum(spec["durations"])
    for index, duration in enumerate(spec["durations"]):
        if elapsed < duration:
            return action, index
        elapsed -= duration
    return action, spec["count"]-1


def backdrop():
    canvas = Image.new("RGB", (900, 480), "#182326")
    d = ImageDraw.Draw(canvas)
    d.text((26, 18), "裂甲奔袭者 · 攻击动作确认", font=font(25), fill="#EEE2BC")
    d.text((28, 57), "蓄力 0.8 秒  →  冲刺 0.4 秒  →  收招 0.5 秒", font=font(17), fill="#AEBBAD")
    d.rectangle((18, 96, 882, 345), fill="#253536")
    for x in range(22, 882, 32):
        d.line((x, 96, x, 345), fill="#2C3C3D")
    for y in range(105, 345, 32):
        d.line((18, y, 882, y), fill="#2C3C3D")
    for x, label in ((START_X, "起点"), (START_X+DISTANCE*SCALE, "终点")):
        d.line((x, GROUND_Y-8, x, GROUND_Y+8), fill="#657674")
        d.line((x-8, GROUND_Y, x+8, GROUND_Y), fill="#657674")
        d.text((x-16, 309), label, font=font(14), fill="#94A4A1")
    d.text((28, 431), "素材动作预览 · 矩形预警透明度 30% · 尚未接入战斗判定", font=font(16), fill="#9AAEA7")
    return canvas


def render(time_ms, frames, path, base):
    result = base.copy()
    action, elapsed, progress = state_at(time_ms)
    if action == "windup":
        # Existing alpha is applied exactly once. The path remains stationary.
        result.paste(path, (START_X-32*SCALE, GROUND_Y-32*SCALE), path)
    frame_action, frame_index = index_at(action, elapsed)
    sprite = frames[frame_action][frame_index].resize((256, 256), Image.Resampling.NEAREST)
    x = START_X + round(DISTANCE*SCALE*progress)
    result.paste(sprite, (x-64*SCALE, GROUND_Y-84*SCALE), sprite)
    d = ImageDraw.Draw(result)
    color = "#F29178" if action == "windup" else "#F2D38E" if action == "dash" else "#B9CEAE"
    d.text((28, 359), LABELS[action], font=font(20), fill=color)
    note = {"idle": "即将开始预警", "windup": "压低身体，锁定前方路径",
            "dash": "沿固定方向向前冲刺", "recover": "前肢刹停，身体回弹",
            "rest": "回到待机，随后重新演示"}[action]
    d.text((185, 363), note, font=font(16), fill="#B8C2B5")
    d.text((728, 363), f"{time_ms/1000:0.2f} / {TOTAL/1000:.2f}s", font=font(14), fill="#AEBBAD")
    d.rounded_rectangle((28, 401, 872, 407), radius=3, fill="#364644")
    if time_ms:
        d.rounded_rectangle((28, 401, 28+round(844*time_ms/TOTAL), 407), radius=3, fill="#C5B784")
    return result


def save_html():
    encoded = {}
    for action in ("idle", "windup", "dash", "recover"):
        encoded[action] = "data:image/png;base64,"+base64.b64encode((ASSETS/f"enemy_rift_rusher_{action}.png").read_bytes()).decode("ascii")
    encoded["path"] = "data:image/png;base64,"+base64.b64encode((ROOT/META["telegraph"]["path"]).read_bytes()).decode("ascii")
    payload = json.dumps({"images": encoded, "actions": META["actions"], "total": TOTAL}, ensure_ascii=False)
    html = r'''<!doctype html>
<html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>裂甲奔袭者 · 攻击动作确认</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#152022;color:#d5dfd0;font-family:system-ui,"Microsoft YaHei",sans-serif}
main{max-width:1000px;margin:30px auto;padding:24px}h1{font-size:25px;color:#eee2bc;margin:0 0 12px}p{color:#aebbad;line-height:1.8}
canvas{width:100%;height:auto;border:1px solid #40524d;background:#253536;image-rendering:pixelated;border-radius:8px}
.toolbar{display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin:18px 0}button,select{font:inherit;color:#e9dfbd;background:#30423e;border:1px solid #586750;border-radius:6px;padding:9px 14px;cursor:pointer}button:hover{background:#455c4e}button:focus-visible,input:focus-visible,select:focus-visible{outline:2px solid #f2d38e;outline-offset:3px}
input[type=range]{width:100%;accent-color:#b9be86}.status{display:flex;justify-content:space-between;margin:14px 0;color:#e9dfbd}.stages{display:flex;gap:8px;flex-wrap:wrap}small{display:block;color:#96aaa2;margin-top:18px;line-height:1.7}
</style><main>
<h1>裂甲奔袭者 · 攻击动作确认</h1>
<p>蓄力 0.8 秒 → 冲刺 0.4 秒 → 收招 0.5 秒。红色路径在蓄力开始时锁定；下面可暂停、慢放或拖动查看每个阶段。</p>
<canvas id="view" width="900" height="340" aria-label="精英怪蓄力、冲刺和收招动画预览"></canvas>
<div class="status"><strong id="stage">加载中</strong><span id="clock"></span></div>
<input id="timeline" type="range" min="0" max="3000" step="20" value="0" aria-label="攻击动画时间轴">
<div class="toolbar"><button id="play">暂停</button><button id="restart">重播</button>
<label>速度 <select id="speed"><option value="1">正常速度</option><option value="0.5">半速慢放</option><option value="0.25">四分之一速度</option></select></label>
<button id="flip">朝向：右</button></div>
<div class="stages"><button data-time="600">查看蓄力</button><button data-time="1400">查看出手</button><button data-time="1600">查看冲刺中段</button><button data-time="1800">查看收招</button></div>
<small>本页组合已绘制的透明 PNG 和冲刺路径素材，用于确认动作、节奏与朝向；尚未接入游戏战斗逻辑，不代表碰撞或伤害判定已完成。</small>
</main><script>
const DATA=__PAYLOAD__;
const canvas=document.getElementById('view'),ctx=canvas.getContext('2d'),slider=document.getElementById('timeline');
const stage=document.getElementById('stage'),clock=document.getElementById('clock'),play=document.getElementById('play');
let time=0,playing=true,rate=1,flip=false,last=null; const imgs={}; slider.max=DATA.total-20;
function stateAt(t){if(t<600)return ['idle',t,0];if(t<1400)return ['windup',t-600,0];if(t<1800)return ['dash',t-1400,(t-1400)/400];if(t<2300)return ['recover',t-1800,1];return ['rest',t-2300,1]}
function frameAt(a,t){if(a==='rest')a='idle';const s=DATA.actions[a];if(s.loop)t%=s.durations.reduce((x,y)=>x+y,0);for(let i=0;i<s.count;i++){if(t<s.durations[i])return [a,i];t-=s.durations[i]}return [a,s.count-1]}
function draw(){ctx.imageSmoothingEnabled=false;ctx.fillStyle='#253536';ctx.fillRect(0,0,900,340);ctx.strokeStyle='#2d3e3e';ctx.beginPath();for(let x=4;x<900;x+=32){ctx.moveTo(x,0);ctx.lineTo(x,340)}for(let y=5;y<340;y+=32){ctx.moveTo(0,y);ctx.lineTo(900,y)}ctx.stroke();
const [a,elapsed,progress]=stateAt(time),[name,index]=frameAt(a,elapsed);ctx.save();if(flip){ctx.translate(900,0);ctx.scale(-1,1)}
if(a==='windup')ctx.drawImage(imgs.path,96,156,608,128);
ctx.drawImage(imgs[name],index*128,0,128,128,160+Math.round(480*progress)-128,52,256,256);ctx.restore();
stage.textContent=({idle:'准备',windup:'蓄力预警 · 无箭头矩形 · 30% 透明度',dash:'冲刺攻击 · 方向已锁定',recover:'收招 · 刹停并回弹',rest:'恢复待机'})[a];clock.textContent=(time/1000).toFixed(2)+' / '+(DATA.total/1000).toFixed(2)+' 秒';slider.value=time;}
function tick(now){if(last!==null&&playing)time=(time+(now-last)*rate)%DATA.total;last=now;draw();requestAnimationFrame(tick)}
function pause(){playing=false;play.textContent='播放'}
play.onclick=()=>{playing=!playing;play.textContent=playing?'暂停':'播放'};document.getElementById('restart').onclick=()=>{time=0;playing=true;play.textContent='暂停'};
slider.oninput=()=>{pause();time=Number(slider.value);draw()};document.getElementById('speed').onchange=e=>rate=Number(e.target.value);
document.getElementById('flip').onclick=e=>{flip=!flip;e.target.textContent='朝向：'+(flip?'左':'右');draw()};
document.querySelectorAll('[data-time]').forEach(b=>b.onclick=()=>{pause();time=Number(b.dataset.time);draw()});
Promise.all(Object.entries(DATA.images).map(([name,src])=>new Promise((resolve,reject)=>{const im=new Image();im.onload=()=>{imgs[name]=im;resolve()};im.onerror=reject;im.src=src}))).then(()=>requestAnimationFrame(tick)).catch(()=>stage.textContent='素材加载失败');
</script></html>'''
    (OUT/"elite_rusher_attack_review.html").write_text(html.replace("__PAYLOAD__", payload), encoding="utf-8")


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    frames = images()
    with Image.open(ROOT/META["telegraph"]["path"]) as source:
        path = source.convert("RGBA").resize((608,128),Image.Resampling.NEAREST)
    base = backdrop()
    sequence = [render(t,frames,path,base) for t in range(0,TOTAL,TICK)]
    # A single palette prevents color flicker between frames; no dithering.
    training = Image.new("RGB",(900,480*4))
    for i,t in enumerate((0,800,1600,1840)):
        training.paste(sequence[t//TICK],(0,480*i))
    palette=training.quantize(colors=128,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE)
    encoded=[im.quantize(palette=palette,dither=Image.Dither.NONE) for im in sequence]
    for name,factor in (("elite_rusher_attack.gif",1),("elite_rusher_attack_slow.gif",2)):
        encoded[0].save(OUT/name,save_all=True,append_images=encoded[1:],duration=TICK*factor,
                        loop=0,disposal=2,optimize=False)
    stages=[(600,"01  锁定路径"),(1000,"02  压低蓄力"),(1400,"03  开始冲刺"),
            (1600,"04  冲刺中段"),(1800,"05  到达并刹停"),(2180,"06  恢复姿态")]
    board=Image.new("RGB",(1080,930),"#182326")
    d=ImageDraw.Draw(board)
    d.text((24,18),"裂甲奔袭者 · 完整攻击分镜",font=font(27),fill="#EEE2BC")
    d.text((24,58),"先固定红色提示路径，再沿该方向冲刺，最后收招。",font=font(17),fill="#AEBBAD")
    for i,(t,label) in enumerate(stages):
        x=20+(i%2)*530;y=103+(i//2)*269
        scene=sequence[t//TICK].crop((18,96,882,346)).resize((518,150),Image.Resampling.NEAREST)
        board.paste(scene,(x,y+40))
        d.text((x+4,y+5),label,font=font(19),fill="#EEE2BC")
        action,elapsed,progress=state_at(t)
        d.text((x+4,y+205),f"{t/1000:.2f} 秒 · {LABELS[action]}",font=font(16),fill="#AEBBAD")
    board.save(OUT/"elite_rusher_attack_keyframes.png")
    save_html()
    for name,factor in (("elite_rusher_attack.gif",1),("elite_rusher_attack_slow.gif",2)):
        with Image.open(OUT/name) as im:
            duration=0
            for i in range(im.n_frames):
                im.seek(i);duration+=im.info['duration']
            assert duration==TOTAL*factor,(name,duration)
    report={"type":"asset choreography preview; not gameplay capture", "windup_ms":WINDUP,
            "dash_ms":DASH,"recover_ms":RECOVER,"loop_ms":TOTAL,"tick_ms":TICK,
            "travel_world_pixels":DISTANCE,"display_scale":SCALE,
            "path_fixed_during_windup":True,"path_source_alpha":META["telegraph"]["alpha_byte"],
            "path_shape":"rectangle","path_arrows":False,
            "source":"existing approved PNG sprite sheets", "gameplay_modified":False}
    (OUT/"attack_preview_manifest.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(report))


if __name__=="__main__":
    main()
