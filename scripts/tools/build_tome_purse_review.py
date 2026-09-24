"""Export labeled GIFs from actual Godot material-review captures."""
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"artifacts/tome_purse_review"
TEMP=Path("C:/Users/mi/AppData/Local/Temp")
FFMPEG=Path("D:/soft/ffmpeg-N-116796-gb730defd52-win64-gpl-shared/bin/ffmpeg.exe")
LABELS={"tome":("坤舆秘仪书 · 方粒虚线领域", "粒子间距大幅波动 / 随机朝向与轻微旋转 / 符文缓慢明灭", "#a5d4dd"),
        "purse":("食利者钱袋 · 每轮三枚金币", "隐藏钱袋本体 / 金币翻转 / 演示本金 400，每枚伤害 10", "#dfbd79")}


def export(kind, revision):
    source=TEMP/f"codex-tome-purse-{revision}-{kind}"
    manifest=json.loads((source/"capture.json").read_text(encoding="utf-8"))
    assert manifest["failures"]==0
    (OUT/f"{kind}_capture_{revision}.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
    frames=TEMP/f"codex-tome-purse-export-{revision}-{kind}"
    frames.mkdir(parents=True,exist_ok=True)
    title,subtitle,color=LABELS[kind]
    for index in range(168):
        board=Image.new("RGB",(640,540),"#10191e")
        # Leave the complete domain, player and surrounding enemy ring visible.
        board.paste(Image.open(source/f"frame_{index:04d}.png").crop((255,84,895,564)),(0,60))
        draw=ImageDraw.Draw(board)
        draw.text((14,6),title,font=ImageFont.truetype("C:/Windows/Fonts/msyh.ttc",21),fill=color)
        draw.text((14,35),subtitle,font=ImageFont.truetype("C:/Windows/Fonts/msyh.ttc",13),fill="#9cadaa")
        board.save(frames/f"frame_{index:04d}.png")
        if index in [0,15,23,31,40,66,75,121]: board.save(OUT/f"{kind}_{revision}_frame_{index:03d}.png")
    subprocess.run([str(FFMPEG),"-hide_banner","-loglevel","warning","-framerate","30","-i",str(frames/"frame_%04d.png"),
                    "-filter_complex","fps=20,split[a][b];[a]palettegen=max_colors=192:stats_mode=full[p];[b][p]paletteuse=dither=none",
                    "-loop","0","-final_delay","5","-y",str(OUT/f"{kind}_battle_{revision}.gif")],check=True)
    subprocess.run([str(FFMPEG),"-hide_banner","-loglevel","warning","-framerate","30","-i",str(source/"frame_%04d.png"),
                    "-frames:v","168","-c:v","libx264","-crf","18","-pix_fmt","yuv420p","-movflags","+faststart","-y",str(OUT/f"{kind}_battle_{revision}.mp4")],check=True)
    print(f"EXPORTED {kind}",flush=True)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--variants",nargs="+",default=["tome","purse"])
    parser.add_argument("--revision",default="v2")
    args=parser.parse_args()
    for kind in args.variants: export(kind, args.revision)
    validation={}
    for path in OUT.glob(f"*_battle_{args.revision}.gif"):
        with Image.open(path) as im:
            duration=sum(im.seek(index) or im.info.get("duration",0) for index in range(im.n_frames))
            assert im.n_frames==112 and duration==5600
            validation[path.name]={"frames":im.n_frames,"duration_ms":duration,"size":list(im.size),"bytes":path.stat().st_size}
    (OUT/f"media_validation_{args.revision}.json").write_text(json.dumps(validation,indent=2)+"\n",encoding="utf-8")


if __name__=="__main__": main()
