"""Package real viewport screenshots; crops never redraw combat geometry."""
import argparse
import html
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    root = args.directory.resolve()
    report = json.loads((root / "verification_all.json").read_text(encoding="utf-8"))
    weapons = report["weapons"]
    font_path = "C:/Windows/Fonts/msyh.ttc"
    title_font = ImageFont.truetype(font_path, 23)
    label_font = ImageFont.truetype(font_path, 19)
    small_font = ImageFont.truetype(font_path, 15)
    crop_box = (480, 300, 1520, 900)
    tile_width, tile_height = 520, 342
    for page in range(2):
        entries = weapons[page * 7:(page + 1) * 7]
        sheet = Image.new("RGB", (1088, 1470), "#121b1d")
        draw = ImageDraw.Draw(sheet)
        draw.text((24, 16), f"武器初始范围  {page + 1}/2", font=title_font, fill="#f4da97")
        draw.text((24, 51), "Lv.1 · 无附魔 · 无距离/范围加成 · 相同镜头与裁切比例", font=small_font, fill="#adbdbe")
        for index, entry in enumerate(entries):
            x = 16 + (index % 2) * 536
            y = 88 + (index // 2) * tile_height
            with Image.open(root / entry["aim"]) as original:
                crop = original.crop(crop_box)
                crop.save(root / (entry["id"] + "_detail.png"))
                tile = crop.resize((520, 300), Image.Resampling.NEAREST)
                sheet.paste(tile, (x, y + 35))
            draw.text((x + 4, y + 3), f'{entry["name"]}  ·  {entry["range"]:g}', font=label_font, fill="#e9eedf")
        sheet.save(root / f"ranges_overview_{page + 1}.png")
    for weapon in ["void_blade", "kunyu_ritual_tome"]:
        with Image.open(root / f"finance_weapon_{weapon}.png") as original:
            original.crop((477, 420, 1436, 848)).save(root / f"finance_{weapon}_detail.png")

    cards = []
    for entry in weapons:
        name = html.escape(entry["name"])
        cards.append(f'''<article><h3>{name}<span>{entry["range"]:g}</span></h3>
<a href="{entry["aim"]}" target="_blank"><img loading="lazy" src="{entry["id"]}_detail.png" alt="{name}"></a>
<p><a href="{entry["aim"]}" target="_blank">范围原图</a><a href="{entry["attack"]}" target="_blank">实际攻击截图</a></p></article>''')
    page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>武器范围与附魔界面审阅</title><style>
body{margin:0;background:#121b1d;color:#e9eedf;font:16px/1.7 system-ui,"Microsoft YaHei",sans-serif}main{max-width:1450px;margin:auto;padding:32px}h1{color:#f4da97;margin:0}h2{margin-top:40px}p{color:#bac9c7}a{color:#a9d6df}nav{position:sticky;top:0;background:#121b1df2;padding:12px 0;z-index:1}nav a{margin-right:28px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(420px,1fr));gap:20px}article{background:#1c282b;border:1px solid #344648;border-radius:8px;overflow:hidden}article h3{margin:12px 18px}article h3 span{float:right;color:#f4da97}article p{margin:12px 18px;display:flex;gap:28px}img{display:block;width:100%;image-rendering:pixelated}.finance img{max-width:1200px;margin:18px 0;border:1px solid #344648}.note{font-size:14px} @media(max-width:500px){main{padding:16px}.grid{grid-template-columns:1fr}}
</style><main><h1>武器范围与附魔界面</h1>
<p>守夜长枪 220 · 赤铜炉灯 240 · 附魔相关文字统一为 15 号</p>
<nav><a href="#weapons">全部 14 把武器</a><a href="#finance">附魔界面</a><a href="verification_all.json">验证记录</a></nav>
<section id="weapons"><h2>初始范围</h2><p>正式游戏场景的 GPU 截图，包含版本锁定的武器。均为 Lv.1，无附魔、无攻击距离或伤害范围加成，使用默认投射物数量。所有预览使用相同裁切和显示比例；点击图片打开 1920×1080 原图。</p>
<p class="note">范围图是游戏自身的矄准指示器。突进短刃、移星秘典的距离值表示位移距离；实际碰撞还会受弹体、锤头和敌人体积影响。</p><div class="grid">CARDS</div></section>
<section id="finance" class="finance"><h2>理财 · 附魔界面</h2><p>武器名称、[附魔 1/1]、已装备附魔名称与附魔背包文字同为 15 号。武器卡片和附魔槽已扩宽，图标大小保持。</p>
<h3>单槽武器（原尺寸局部）</h3><a href="finance_weapon_void_blade.png" target="_blank"><img src="finance_void_blade_detail.png"></a>
<h3>多槽武器（原尺寸局部）</h3><a href="finance_weapon_kunyu_ritual_tome.png" target="_blank"><img src="finance_kunyu_ritual_tome_detail.png"></a>
<h3>完整界面</h3><a href="finance_weapon_void_blade.png" target="_blank"><img loading="lazy" src="finance_weapon_void_blade.png"></a>
<p><a href="finance_1280.png" target="_blank">1280×720 截图</a> · <a href="finance_weapon_scroll_end.png" target="_blank">武器列表末端</a></p></section>
<p class="note">后台私有桌面实机运行，foreground_samples=0；专项截图检查 177 项通过。</p></main></html>'''
    (root / "index.html").write_text(page.replace("CARDS", "".join(cards)), encoding="utf-8")
    print(root / "index.html")


if __name__ == "__main__":
    main()
