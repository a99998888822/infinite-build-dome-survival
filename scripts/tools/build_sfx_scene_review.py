"""Build a source-audited SFX review with optional production scene captures.

Read-only with respect to game/audio assets. Outputs a dated review under artifacts.
python scripts/tools/build_sfx_scene_review.py
"""
from pathlib import Path
from datetime import datetime
from collections import Counter
import argparse
import html
import json
import re
import shutil
import subprocess

import build_all_sfx_review as base

ROOT = base.ROOT
DEFAULT_OUT = ROOT / "temp/audio-review"
EXTRAS = {
    "combat/ritual_mark_r02_01.wav": ("秘仪书 · 逐个点名", "武器", -13, "坤舆秘仪书的每次点名伤害。旧寒冰命中入口已停用，当前仍会播放独立点名声。"),
    "combat/grenade_launch_01.wav": ("炮械 · 发射", "武器", 0, "铸铁榴弹炮、巨型手持火炮发射时共用；命中声另列。"),
    "combat/meteor_flail_hit.wav": ("摆锤／战锤 · 重击", "武器", 0, "流星摆锤和裂地战锤共用；已替换为 audio.rar 指定音频。"),
    "combat/mutant_tentacle_hit.wav": ("异化触手 · 命中", "武器", 0, "触手独立命中声，使用 audio.rar 指定音频。"),
    "combat/copper_lamp_loop.wav": ("赤铜炉灯 · 持续喷火", "武器", -16, "释放期间循环；结束、取消或暂停时停止，不再播放电浆接触声。"),
    "player/player_walk.wav": ("人物移动 · 脚步", "其他", 6, "实际步行时循环；站定、受阻、技能位移、暂停或死亡时停止。原素材电平较低，播放增益 +6 dB。"),
    "finance/interest_tick.wav": ("利息到账 · 逐项计数", "利息到账", -15, "利息收据逐行出现时播放，后续行会逐步升高音调。"),
    "finance/interest_bonus.wav": ("利息到账 · 红利翻倍", "利息到账", -10, "出现红利翻倍条目时播放，与该行计数声同时触发。"),
    "finance/interest_arrive.wav": ("利息到账 · 金额落定", "利息到账", -10, "到账总额落定且大于零时播放。"),
}
for i in range(1, 4):
    EXTRAS[f"ui/trade_type_{i:02d}.wav"] = (f"哥布林对白 · 打字音 {i}", "界面与银行", -9,
        "交易／挑战对白按字符交替播放三个变体；贷款对白也共用（交易 -9 dB，贷款 -18 dB）。")
for i, stage in enumerate(["击杀数", "获得金币", "存活波次", "获得利息", "营地币总额"], 1):
    EXTRAS[f"settlement/stage_{i}.wav"] = (f"局末结算 · {stage}", "局末结算", -6,
        f"局末结算第 {i} 阶段：{stage}开始计数时播放。")

TRIGGERS = {
    "wood_arrow": "木质弓箭、食利钱袋、营地短刀、守夜长枪、折返匕刃、短管手炮等武器命中共用。",
    "plasma_hit": "电浆球接触命中声；赤铜炉灯已使用独立喷火循环。",
    "lightning": "电火花／连锁电弧实际击中目标时触发。导电爆裂已复用本音效，共用音量和重复播放限制。",
    "spark_charge": "落雷预警开始时蓄能；真正雷击约半秒后另行触发。",
    "electric_spark": "落雷预警结束、雷击实际命中时触发。导电雷鸣已复用本音效，蓄能仍单独播放。",
    "fire": "火池燃烧音频已完全停用，普通、神圣及暗焰火池均无声。",
    "explosion": "爆炸附魔或榴弹炮引爆时触发。",
    "water": "水流效果生成时触发。",
    "wind": "风刃生成、切过目标时触发。",
    "light_sword": "光辉剑实际落地时触发。",
    "black_hole": "黑洞开始吸附时触发。",
    "reaction_steam": "水与火接触，触发蒸汽反应。",
    "reaction_thaw": "冻结结束，碎冰并重新施加湿润时触发。",
    "reaction_holy": "光与火触发神圣火焰。",
    "reaction_dark_flame": "暗与火触发暗焰。",
    "reaction_cancel": "光与暗相遇，触发湮灭。",
    "reaction_conduct": "电火花命中湿润目标，使用导电组合声。",
    "reaction_thunder_fire": "电火花命中燃烧目标，使用雷火组合声。",
    "reaction_conduct_strike": "落雷命中湿润目标，使用保留雷鸣主体的导电声。",
    "reaction_thunder_fire_strike": "落雷命中燃烧目标，使用雷火轰鸣。",
    "reaction_wet_spread": "风与水接触，扩散湿润。",
    "reaction_ice_expand": "风与冰接触，推进冰霜区域。",
    "reaction_reflection": "光击中冻结目标，触发棱镜反射。",
}
CATEGORY_ORDER = ["武器", "附魔", "元素联动", "界面与银行", "利息到账", "局末结算", "其他", "旧版备用", "待补音效"]
PREFERRED = {"spark_charge": "electric_spark", "ritual_mark_r02": "ritual", "grenade_launch_01": "grenade",
             "meteor_flail_hit": "meteor", "stats_chain_open": "drawer", "stats_chain_close": "drawer"}
PREFERRED.update({f"trade_type_{i:02d}": "trade" for i in range(1, 4)})
PREFERRED.update({f"interest_{s}": "interest" for s in ["tick", "bonus", "arrive"]})
PREFERRED.update({f"stage_{i}": "settlement" for i in range(1, 6)})


def collect(previous_numbers=None):
    entries = base.inventory()
    library = (ROOT/"scripts/audio/combat_sound_library.gd").read_text(encoding="utf-8")
    reuse_match = re.search(r"const SOUND_REUSE: Dictionary = (.+)", library)
    reuse = json.loads(reuse_match.group(1)) if reuse_match else {}
    retired = {f"assets/audio/sfx/combat/{cue}_01.wav": source for cue, source in reuse.items()}
    labels = {"reaction_conduct": "导电爆裂", "reaction_conduct_strike": "导电雷鸣",
              "reaction_holy": "神圣火焰", "reaction_dark_flame": "暗焰"}
    source_labels = {"lightning": "电火花", "electric_spark": "落雷", "fire": "火池燃烧"}
    disabled_paths = set(re.findall(r'"res://([^"]+)"', library.split("const DISABLED_PATHS:", 1)[1]))
    disabled = []
    for path in sorted(disabled_paths):
        name = {"ice_01.wav": "寒冰", "reaction_freeze_01.wav": "水冰冻结", "reaction_cancel_01.wav": "光暗湮灭", "fire_01.wav": "火池燃烧", "reaction_holy_01.wav": "神圣火焰", "reaction_dark_flame_01.wav": "暗焰"}[Path(path).name]
        disabled.append({"path": path, "title": name + " · 已停用"})
    entries = [e for e in entries if e["path"] not in disabled_paths]
    for e in entries:
        key = e["path"].removeprefix("assets/audio/sfx/")
        if key in EXTRAS:
            e["title"], e["category"], e["gain_db"], e["description"] = EXTRAS[key]
            e["status"] = "active"
        elif e.get("cue"):
            e["description"] = TRIGGERS.get(e["cue"], e["description"])
        if e["path"] in retired:
            cue = Path(e["path"]).stem.removesuffix("_01")
            e.update(title=labels[cue] + " · 旧版留档", category="旧版备用", status="legacy",
                     description=f"已改为复用{source_labels[retired[e['path']]]}。本文件保留对照，当前游戏不再引用。")
        e["uses"].extend(labels[c] + " · 共用此音效" for c in e.get("cue_ids", []) if c in reuse)
        if key.startswith("settlement/"):
            e["references"] = ["scripts/ui/run_settlement_panel.gd", "data_config/run_settlement.json"]
        if key in ["ui/bank_deposit.wav", "ui/bank_withdraw.wav"]:
            e["references"] = ["scripts/ui/bank_counter_portrait.gd", "scripts/ui/finance_popup.gd"]
        if key.startswith("ui/trade_type_"):
            e["references"].append("scripts/ui/goblin_loan_presentation.gd")
        if e.get("cue") == "ritual_mark_r02":
            e["uses"] = ["坤舆秘仪书 · 逐个点名"]
            e["references"].append("scripts/weapons/ritual_domain.gd")
        e["references"] = sorted(set(e["references"]))
        if e["status"] == "missing":
            e["description"] = "代码已配置该声音入口，但当前文件不存在；触发时不会播放此声音。"
    entries.sort(key=lambda e: (CATEGORY_ORDER.index(e["category"]), e["path"]))
    previous_numbers = previous_numbers or {}
    next_number = max([int(n[1:]) for n in previous_numbers.values()] or [0]) + 1
    for e in entries:
        if e["path"] in previous_numbers:
            e["number"] = previous_numbers[e["path"]]
        else:
            e["number"] = f"S{next_number:02d}"
            next_number += 1
    return entries, disabled


def assemble_media(out):
    media = out/"media"
    media.mkdir(exist_ok=True)
    clips = {}
    ffmpeg = shutil.which("ffmpeg")
    for result in sorted((out/"captures").glob("*/result.json")):
        row = json.loads(result.read_text(encoding="utf-8"))
        stamps = row["frames"]
        if not stamps: continue
        destination = media/(row["id"]+".mp4")
        if not destination.exists() or destination.stat().st_mtime < result.stat().st_mtime:
            lines = []
            for i, stamp in enumerate(stamps):
                lines += [f"file '{i:04d}.png'", f"duration {stamps[i+1]-stamp if i+1<len(stamps) else 1/16:.6f}"]
            lines.append(f"file '{len(stamps)-1:04d}.png'")
            concat = result.parent/"frames.txt"
            concat.write_text("\n".join(lines), encoding="utf-8")
            subprocess.run([ffmpeg,"-hide_banner","-loglevel","error","-y","-f","concat","-safe","0","-i",str(concat),
                            "-vf","fps=16","-an","-c:v","libx264","-preset","fast","-crf","25","-pix_fmt","yuv420p","-movflags","+faststart",str(destination)],check=True)
        poster = media/(row["id"]+".jpg")
        if not poster.exists() or poster.stat().st_mtime < result.stat().st_mtime:
            from PIL import Image
            Image.open(result.parent/f"{min(16,len(stamps)-1):04d}.png").convert("RGB").save(poster,quality=86)
        row["src"] = "media/"+destination.name
        row["poster"] = "media/"+poster.name
        clips[row["id"]] = row
    return clips


def attach_clips(entries, clips):
    for e in entries:
        if e["status"] != "active": continue
        matches = []
        cue = e.get("cue", "")
        preferred = PREFERRED.get(cue, cue.removeprefix("reaction_")) or PREFERRED.get(Path(e["path"]).stem, "")
        for clip in clips.values():
            events = [s for s in clip["sounds"] if s["path"].removeprefix("res://") == e["path"]]
            if events:
                matches.append((clip,events))
        matches.sort(key=lambda pair: (pair[0]["id"] != preferred, len(pair[0]["sounds"])))
        if matches:
            clip, events = matches[0]
            e["scene"] = {"src":clip["src"],"poster":clip["poster"],"id":clip["id"],
                          "trigger":max(0,events[0]["time"]-clip["frames"][0]),"events":events,
                          "evidence":"captures/"+clip["id"]+"/result.json"}
            e["scenes"] = [{**e["scene"], "label": "普通触发"}]
            for alias, label in {"reaction_conduct": "导电 · 复用电火花", "reaction_conduct_strike": "导电 · 复用落雷",
                                 "reaction_holy": "神圣火焰 · 复用燃烧", "reaction_dark_flame": "暗焰 · 复用燃烧"}.items():
                if alias not in e.get("cue_ids", []): continue
                case = clips.get(alias.removeprefix("reaction_"))
                observed = [s for s in case["sounds"] if s.get("cue") == alias and s["path"].removeprefix("res://") == e["path"]] if case else []
                if observed:
                    e["scenes"].append({"src":case["src"], "poster":case["poster"], "id":case["id"], "label":label,
                                        "trigger":max(0,observed[0]["time"]-case["frames"][0]), "evidence":"captures/"+case["id"]+"/result.json"})


def card(e):
    markup = base.card(e)
    scene = e.get("scene")
    if scene:
        selector = ''
        if len(e.get("scenes", [])) > 1:
            options = ''.join(f'<option value="{i}">{html.escape(s["label"])}</option>' for i,s in enumerate(e["scenes"]))
            selector = f'<label>触发场景 <select class="scene-select" aria-label="{html.escape(e["title"])}触发场景">{options}</select></label>'
        markup = markup.replace('<div class="decision">', f'''<div class="scene-preview">
{selector}
<video controls muted playsinline loop preload="metadata" poster="{scene['poster']}" src="{scene['src']}" aria-label="{html.escape(e['title'])}对应实机场景"></video>
<button type="button" class="sync ghost">看场景并试听</button>
<p><span class="scene-time">此音效在片段 {scene['trigger']:.2f} 秒处触发。</span>画面为当前版本实机；联合播放仅配本条素材。{'反射演示预设目标带有光与湿润状态，由实际冰附魔命中触发。' if scene['id'] == 'reflection' else ''}</p></div><div class="decision">''')
    elif e["status"] == "legacy":
        markup = markup.replace('<div class="decision">', '<div class="scene-preview unavailable">旧版留档；当前反应已使用共用素材。</div><div class="decision">')
    elif e["exists"]:
        markup = markup.replace('<div class="decision">', '<div class="scene-preview unavailable">本条暂未取得可验证的触发录像；可先试听素材并查看用途。</div><div class="decision">')
    refs = "<br>".join(html.escape(p) for p in e["references"])
    markup = markup.replace('</details></div>', f'<p>引用位置：<br>{refs}</p></details></div>')
    return markup


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True,exist_ok=True)
    previous = out/"inventory.json"
    previous_numbers = {e["path"]: e["number"] for e in json.loads(previous.read_text(encoding="utf-8"))["entries"]} if previous.exists() else {}
    entries, disabled = collect(previous_numbers)
    clips = assemble_media(out)
    attach_clips(entries,clips)
    counts = Counter(e["status"] for e in entries)
    playable = sum(e["exists"] for e in entries)
    covered = sum("scene" in e for e in entries)
    snapshot = {"created":datetime.now().astimezone().isoformat(timespec="seconds"),"entries":entries,"disabled":disabled,
                "counts":dict(counts),"playable":playable,"scene_coverage":covered,"review_title":"当前项目音效审阅",
                "scope":"当前工作区音效；背景音乐单列；停用项单列。","storage_key":"dome-sfx-scene-review-v1"}
    (out/"inventory.json").write_text(json.dumps(snapshot,ensure_ascii=False,indent=2),encoding="utf-8")
    page = base.TEMPLATE.read_text(encoding="utf-8")
    for key, value in {"@@CARDS@@":"\n".join(card(e) for e in entries),"@@DATA@@":json.dumps(snapshot,ensure_ascii=False).replace("</","<\\/"),
                       "@@PLAYABLE@@":str(playable),"@@ACTIVE@@":str(counts["active"]),"@@LEGACY@@":str(counts["legacy"]),"@@MISSING@@":str(counts["missing"]),
                       "@@CATEGORIES@@":"".join(f'<option>{c}</option>' for c in CATEGORY_ORDER if any(e['category']==c for e in entries))}.items():
        page = page.replace(key,value)
    page = page.replace("全音效试听 · 由你决定怎么改", "当前音效 · 逐项试听与场景审阅")
    page = page.replace("收录项目现有音效，包含武器、附魔、元素联动、界面、环境及旧版备用。每个资源只列一次；共用音效会标出用途。背景音乐已排除。",
        f"按当前工作区代码与资源核对：{counts['active']} 个正在使用的音效文件，{covered} 个有已验证触发的场景片段。每个文件列一次，共用武器会注明。先试听，再选保留或需要修改；备注自动保存在本机，可导出给我。")
    page = page.replace('<option value="active">', '<option value="active" selected>',1)
    page = page.replace('</header>', '<p>导电爆裂复用电火花，导电雷鸣复用落雷，2 个旧文件归入备用。火池燃烧、暗焰及神圣火焰音频已完全停用；默认只显示在用音效。</p></header>',1)
    page = page.replace('<div class="count"><strong>0</strong><small>旧版备用</small></div>',f'<div class="count"><strong>{covered}</strong><small>有场景片段</small></div>')
    page = page.replace('</style>', '''
.card-main{grid-template-columns:minmax(0,1fr) 285px}.scene-preview{grid-column:1;grid-row:2}.decision{grid-column:2;grid-row:1 / span 2}.scene-preview video{width:100%;max-height:390px;background:#0b100d;display:block;border-radius:6px}.scene-preview p{color:#b5c6b8;font-size:12px}.sync{margin-top:10px}.appendix{padding-top:24px;border-top:1px solid #344b3a}.appendix audio{max-width:480px}.scene-preview.unavailable{align-self:start}input,select{max-width:100%}#search{min-width:0;width:100%}@media(max-width:850px){.card-main{display:flex;flex-direction:column}.decision{display:block}.scene-preview{width:100%}}@media(prefers-reduced-motion:reduce){video{scroll-behavior:auto}}
</style>''')
    if (out/"user-audio/review.html").exists():
        page = page.replace('</header>', '<p><a href="user-audio/review.html">打开 audio.rar 替换后的实机录像：16 段在用音频、22 个场景</a></p></header>', 1)
    appendix = '<section class="appendix"><h2>停用与空入口</h2><p>寒冰、冻结、光暗湮灭、火池燃烧、神圣火焰和暗焰六项已明确停用，未计入缺失文件。秘仪书旧寒冰命中入口也被屏蔽，但独立点名声仍在使用。</p><p>局末哥布林语音的 4 条 voice_path 均为空，目前只有文字，没有配音。人物移动已接入脚步循环；环境水滴／湿地专用脚步没有在用文件。</p><h2>背景音乐（另列 2 首）</h2>'
    for name,label in [("bgm_menu.ogg","主菜单／营地"),("bgm_battle.ogg","战斗")]:
        target = out/"media"/name
        shutil.copy2(ROOT/"assets/audio/bgm"/name,target)
        appendix += f'<p>{label} · {name}</p><audio class="bgm-preview" controls preload="none" src="media/{name}"></audio>'
    appendix += '<p>素材试听应用单项增益，未模拟战斗压缩器、随机音调、叠加声部和游戏音量设置；背景音乐附录为原始音量。场景片段静音，联合播放只演示这一条音效的触发关系，不是实机混音录音。</p></section>'
    extra_js = '''
const videos=[...document.querySelectorAll("video")];
let syncJob=null;
function clearScene(){if(syncJob){cancelAnimationFrame(syncJob);syncJob=null;}videos.forEach(v=>v.pause());}
for(const e of entries){
 const c=cards.get(e.number),button=c.querySelector('.sync'),v=c.querySelector('video');
 if(!button)continue;
 let scene=e.scene;
 c.querySelector('.scene-select')?.addEventListener('change',event=>{
  clearScene();stopAll();scene=e.scenes[Number(event.target.value)];v.src=scene.src;v.poster=scene.poster;v.load();
  c.querySelector('.scene-time').textContent=`此音效在片段 ${scene.trigger.toFixed(2)} 秒处触发。`;
 });
 button.addEventListener('click',async()=>{
  clearScene();stopAll();document.querySelectorAll('.bgm-preview').forEach(a=>a.pause());
  const a=c.querySelector('audio'),t=scene.trigger;v.loop=false;v.currentTime=0;a.currentTime=0;
  let fired=false;
  const check=()=>{if(!fired&&v.currentTime>=t){fired=true;a.currentTime=Math.max(0,v.currentTime-t);a.play().catch(()=>notify('请点击音频播放按钮'));}
   if(!v.paused&&!v.ended)syncJob=requestAnimationFrame(check);};
  try{await v.play();syncJob=requestAnimationFrame(check);}catch(err){notify('场景播放失败：'+err.message);}
 });
}
$('stop').addEventListener('click',()=>{clearScene();document.querySelectorAll('.bgm-preview').forEach(a=>a.pause());});
for(const id of ['search','category','availability','decision-filter'])$(id).addEventListener(id==='search'?'input':'change',clearScene);
for(const a of document.querySelectorAll('.bgm-preview'))a.addEventListener('play',()=>{stopAll();clearScene();document.querySelectorAll('.bgm-preview').forEach(b=>{if(a!==b)b.pause();});});
for(const a of document.querySelectorAll('.sound-card audio'))a.addEventListener('play',()=>document.querySelectorAll('.bgm-preview').forEach(b=>b.pause()));
'''
    page = page.replace('</body>', appendix+'</body>')
    # Appendix belongs inside the width-constrained page surface.
    page = page.replace(appendix, "").replace('</main>',appendix+'</main>')
    before, after = page.rsplit('</script>', 1)
    page = before + extra_js + '</script>' + after
    assert "@@" not in page
    (out/"review.html").write_text(page,encoding="utf-8")
    lines=["# 当前项目音效清单", "", f"核对时间：{snapshot['created']}", "",f"当前使用 {counts['active']} 个音效；缺失 {counts['missing']} 个入口；明确停用 {len(disabled)} 项；另有 2 首背景音乐。", "",
           "| 编号 | 名称 | 分类 | 状态 | 文件 |", "|---|---|---|---|---|"]
    for e in entries:
        status = {"active": "当前使用", "legacy": "旧版备用", "missing": "缺失"}[e["status"]]
        lines.append(f"| {e['number']} | {e['title']} | {e['category']} | {status} | `{e['path']}` |")
    (out/"音效清单.md").write_text("\n".join(lines)+"\n",encoding="utf-8")
    print(json.dumps({"page":str(out/"review.html"),"counts":counts,"scene_coverage":covered,"without_scene":[e['path'] for e in entries if e['status']=='active' and 'scene' not in e]},ensure_ascii=True))


if __name__ == "__main__": main()
