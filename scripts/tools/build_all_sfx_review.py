"""Read-only inventory and offline decision page for every asset SFX, no BGM.

Run from any directory: python scripts/tools/build_all_sfx_review.py
Writes an on-demand review to the system temporary directory; never changes audio.
"""
from pathlib import Path
import ast
import base64
from datetime import datetime
import hashlib
import html
import json
import re
import tempfile
import wave

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(tempfile.gettempdir()) / "dome-survival-sfx-review"
TEMPLATE = Path(__file__).parent / "templates/all_sfx_review.html"
AUDIO_EXTENSIONS = {".wav", ".ogg", ".mp3", ".flac", ".aac", ".m4a"}
CATEGORIES = ["武器", "附魔", "元素联动", "界面与银行", "环境", "旧版备用", "其他", "待补音效"]
EXTRAS = {
    "combat/grenade_launch_01.wav": ("榴弹炮 · 发射", "武器", 0, "铸铁榴弹炮发射；爆炸命中另用爆炸音效。"),
    "combat/meteor_flail_hit.wav": ("流星摆锤 · 命中", "武器", 0, "流星摆锤的独立金属撞击。"),
    "ui/bank_deposit.wav": ("银行 · 存入", "界面与银行", -8, "向银行存入资金。"),
    "ui/bank_withdraw.wav": ("银行 · 取出", "界面与银行", -8, "从银行取出资金。"),
    "ui/stats_chain_open.wav": ("战斗统计抽屉 · 展开", "界面与银行", -2, "统计抽屉展开；游戏播放速度随动画时长变化。"),
    "ui/stats_chain_close.wav": ("战斗统计抽屉 · 收起", "界面与银行", -2, "统计抽屉收起；游戏播放速度随动画时长变化。"),
    "environment/water_drop.wav": ("湿地 · 环境水滴", "环境", -12, "湿地场景间歇水滴；游戏中有轻微随机音高。"),
    "environment/wet_step_01.wav": ("湿地 · 脚步 1", "环境", -8, "湿地行走的交替脚步之一。"),
    "environment/wet_step_02.wav": ("湿地 · 脚步 2", "环境", -8, "湿地行走的交替脚步之二。"),
    "effects/lighting_1.wav": ("旧版电音 1", "旧版备用", None, "资源保留，未发现当前玩法引用。"),
    "effects/lighting_2.wav": ("旧版电音 2", "旧版备用", None, "资源保留，未发现当前玩法引用。"),
    "effects/thunder_1.wav": ("旧版雷声", "旧版备用", None, "资源保留，当前落雷使用战斗音效包中的新雷鸣。"),
}
MISSING_LABELS = {
    "sfx_ui_modal_open.ogg": "通用弹窗 · 打开",
    "sfx_ui_modal_close.ogg": "通用弹窗 · 关闭",
    "sfx_ui_confirm.ogg": "通用按钮 · 确认",
    "sfx_ui_zone_select.ogg": "关卡 · 选择",
    "sfx_ui_reward_reveal.ogg": "奖励 · 展示",
    "sfx_interest_settle.ogg": "利息 · 结算",
    "sfx_ui_purchase_success.ogg": "购买 · 成功",
    "sfx_ui_purchase_error.ogg": "购买 · 失败",
    "sfx_exp_orb_collect.ogg": "经验球 · 拾取",
    "sfx_wave_end_safe.ogg": "波次 · 结束",
}
NOTES = {
    "lightning": "已接入你确认的“原味提亮”；单次放电，实际连锁按命中分别触发。",
    "spark_charge": "落雷启动时的蓄能声；雷击约在半秒后另行播放。",
    "electric_spark": "真正落雷时的雷击与滚雷尾音；已经下调过播放音量。",
    "reaction_conduct": "电火花命中湿润目标：确认版电弧与导电元素层。",
    "reaction_thunder_fire": "电火花与火反应：确认版电弧与爆燃元素层。",
    "reaction_conduct_strike": "落雷命中湿润目标，保留落雷雷鸣。",
    "reaction_thunder_fire_strike": "落雷命中燃烧目标，保留落雷雷鸣与爆燃。",
}


def inventory():
    source = (ROOT / "scripts/tools/build_combat_audio.py").read_text(encoding="utf-8")
    specs = next(ast.literal_eval(n.value) for n in ast.parse(source).body
                 if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "SPECS" for t in n.targets))
    labels = {row[0]: (row[1], "元素联动" if row[2] == "联动" else row[2]) for row in specs}
    profiles = {}
    for line in (ROOT / "scripts/audio/combat_sound_library.gd").read_text(encoding="utf-8").splitlines():
        found = re.search(r'^\s*"([^"]+)":.*?preload\("([^"]+)"\).*?"gain_db":\s*(-?[\d.]+)', line)
        if found:
            key, path, gain = found.groups()
            profiles[path[6:]] = (key, float(gain))
    references = {}
    for directory in ["autoloads", "scripts", "scenes", "data_config"]:
        for path in (ROOT/directory).rglob("*"):
            if path.suffix not in {".gd", ".tscn", ".tres", ".json"} or "tests" in path.parts or "tools" in path.parts:
                continue
            text = path.read_text(encoding="utf-8")
            for match in re.finditer(r'res://([^"\s]+\.(?:wav|ogg|mp3|flac|aac|m4a))', text):
                resource = match.group(1)
                if "%" not in resource and "/bgm/" not in resource:
                    references.setdefault(resource, []).append(path.relative_to(ROOT).as_posix())
    weapons = json.loads((ROOT/"data_config/weapons.json").read_text(encoding="utf-8"))
    uses = {}
    for weapon in weapons:
        for field, action in [("hit_sfx", "命中"), ("launch_sfx", "发射")]:
            path = str(weapon.get(field, "")).removeprefix("res://")
            if path:
                uses.setdefault(path, []).append(weapon["display_name"] + " · " + action)
    entries = []
    assets = [p for p in (ROOT/"assets").rglob("*") if p.suffix.lower() in AUDIO_EXTENSIONS and "bgm" not in p.parts]
    for path in assets:
        rel = path.relative_to(ROOT).as_posix()
        key = rel.removeprefix("assets/audio/sfx/")
        cue = ""
        if rel in profiles:
            cue, gain = profiles[rel]
            title, category = labels.get(cue, (cue, "其他"))
            description = NOTES.get(cue, "对应事件触发的单次音效。")
        else:
            title, category, gain, description = EXTRAS.get(key, (path.stem, "其他", None, "按现有资源收录，播放用途待核对。"))
        status = "active" if rel in profiles or (key in EXTRAS and category != "旧版备用") or rel in references else "legacy"
        with wave.open(str(path)) as stream:
            duration = stream.getnframes()/stream.getframerate()
            channels, rate = stream.getnchannels(), stream.getframerate()
        entries.append({"path": rel, "title": title, "category": category, "gain_db": gain,
                        "description": description, "status": status, "exists": True,
                        "seconds": duration, "channels": channels, "rate": rate, "cue": cue,
                        "uses": uses.get(rel, []), "references": sorted(set(references.get(rel, []))),
                        "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    for rel, refs in references.items():
        if (ROOT/rel).exists():
            continue
        entries.append({"path": rel, "title": MISSING_LABELS.get(Path(rel).name, Path(rel).stem),
                        "category": "待补音效", "gain_db": None, "description": "已配置播放路径，但文件缺失，当前无法试听。",
                        "status": "missing", "exists": False, "seconds": 0, "uses": [],
                        "references": sorted(set(refs)), "sha256": None})
    entries.sort(key=lambda e: (CATEGORIES.index(e["category"]), e["path"]))
    for index, entry in enumerate(entries, 1):
        entry["number"] = f"S{index:02d}"
    return entries


def card(entry):
    esc = html.escape
    number, path = entry["number"], entry["path"]
    status = {"active": "当前使用", "legacy": "旧版备用", "missing": "文件缺失"}[entry["status"]]
    player = '<div class="unavailable">文件缺失 · 暂无音频可试听</div>'
    if entry["exists"]:
        data = base64.b64encode((ROOT/path).read_bytes()).decode("ascii")
        player = f'<audio controls preload="none" aria-label="{esc(number+" "+entry["title"])}" src="data:audio/wav;base64,{data}"></audio><button class="repeat ghost" type="button">连听 3 次</button>'
    comparison = ""
    if entry.get("before"):
        before = entry["before"]
        data = base64.b64encode((ROOT/before["path"]).read_bytes()).decode("ascii")
        comparison = f'<details class="resource before"><summary>对照修改前的声音</summary><audio data-before="true" data-gain="{before["gain_db"]}" controls preload="none" aria-label="{esc(number)} 修改前" src="data:audio/wav;base64,{data}"></audio></details>'
    instructions = ""
    if entry.get("previous_note"):
        instructions += f'<p class="revision-note"><strong>上轮意见：</strong>{esc(entry["previous_note"])}</p>'
    if entry.get("change_summary"):
        instructions += f'<p class="revision-note"><strong>本轮调整：</strong>{esc(entry["change_summary"])}</p>'
    uses = "；".join(entry["uses"])
    gain = f'{entry["gain_db"]:g} dB' if entry["gain_db"] is not None else "未配置（使用原始音量）"
    technical = f'{entry["seconds"]:.2f} 秒 · {entry.get("rate", 0)} Hz' if entry["exists"] else "尚无素材"
    return f'''<article data-number="{number}" class="sound-card"><div class="identity"><span class="number">{number}</span><span class="tag">{esc(entry["category"])}</span><span class="state {entry["status"]}">{status}</span><span class="heard">未试听</span></div>
<div class="card-main"><div class="sound"><h2>{esc(entry["title"])}</h2><p>{esc(entry["description"])}</p>{instructions}{f'<p class="uses">共用：{esc(uses)}</p>' if uses else ''}<div class="player">{player}</div>{comparison}
<details class="resource"><summary>资源与播放说明 · {technical}</summary><p class="filepath">{esc(path)}</p><p>单项播放增益：{gain}</p></details></div>
<div class="decision"><label for="decision-{number}">我的决定</label><select id="decision-{number}" class="decision-select"><option value="pending">未决定</option><option value="keep">保留</option><option value="modify">需要修改</option></select><label for="note-{number}">修改方向 / 备注</label><textarea id="note-{number}" rows="3" placeholder="例如：声音太闷，希望更清脆；音量降低；尾音缩短。"></textarea></div></div></article>'''


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    entries = inventory()
    assert all("/bgm/" not in e["path"] for e in entries)
    counts = {status: sum(e["status"] == status for e in entries) for status in ["active", "legacy", "missing"]}
    playable = sum(e["exists"] for e in entries)
    categories = [c for c in CATEGORIES if c != "待补音效" and any(e["category"] == c for e in entries)]
    snapshot = {"created": datetime.now().astimezone().isoformat(timespec="seconds"), "counts": counts, "playable": playable, "entries": entries}
    (OUT/"inventory.json").write_text(json.dumps(snapshot, ensure_ascii=False, indent=2), encoding="utf-8")
    page = TEMPLATE.read_text(encoding="utf-8")
    replacements = {"@@CARDS@@": "\n".join(card(e) for e in entries),
                    "@@DATA@@": json.dumps(snapshot, ensure_ascii=False).replace("</", "<\\/"),
                    "@@PLAYABLE@@": str(playable), "@@ACTIVE@@": str(counts["active"]),
                    "@@LEGACY@@": str(counts["legacy"]), "@@MISSING@@": str(counts["missing"]),
                    "@@CATEGORIES@@": "".join(f'<option>{html.escape(c)}</option>' for c in categories)}
    for key, value in replacements.items():
        page = page.replace(key, value)
    assert "@@" not in page
    (OUT/"review.html").write_text(page, encoding="utf-8")
    print(json.dumps({"playable": playable, **counts, "page": str(OUT/"review.html")}, ensure_ascii=True))


if __name__ == "__main__":
    main()
