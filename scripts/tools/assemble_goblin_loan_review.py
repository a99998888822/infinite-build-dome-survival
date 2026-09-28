"""Curate the isolated Godot loan preview captures; raw frames stay in TEMP."""
from pathlib import Path
import argparse
import json
import shutil
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"artifacts/reviews/ui/goblin_loan"


def main(source):
    OUT.mkdir(parents=True,exist_ok=True)
    captures=source/"captures"
    for name in ("loan_popup","loan_small","loan_small_hud","loan_portrait"):
        shutil.copyfile(captures/f"{name}.png",OUT/f"{name}.png")
    shutil.copyfile(captures/"state_borrowed.png",OUT/"loan_bank_hud.png")
    layout=json.loads((captures/"layout.json").read_text(encoding="utf-8"))
    x,y,w,h=map(int,layout["strip_rect"])
    im=Image.new("RGB",(920,650),"#17221c")
    d=ImageDraw.Draw(im)
    title=ImageFont.truetype("C:/Windows/Fonts/msyh.ttc",22)
    font=ImageFont.truetype("C:/Windows/Fonts/msyh.ttc",16)
    d.text((28,18),"银行最底部 · 贷款栏",font=title,fill="#e5c78a")
    context=Image.open(captures/"state_borrowed.png").convert("RGB")
    bx,by,bw,bh=map(int,layout["bank_rect"])
    context=context.crop((bx,by+bh-142,bx+bw,by+bh))
    im.paste(context,(28,62))
    examples=[("state_available","关闭／拒绝后，可再次查看原条款"),
              ("state_borrowed","已接受，贷款文本后紧接「还清」"),
              ("state_compound","未能还款，当前应还额变为 720"),
              ("state_ready","钱包足够，「还清」按钮点亮")]
    for i,(name,label) in enumerate(examples):
        top=228+i*96
        d.text((28,top),label,font=font,fill="#aeb99c")
        crop=Image.open(captures/f"{name}.png").convert("RGB").crop((x,y,x+w,y+h))
        im.paste(crop,(28,top+28))
    im.save(OUT/"loan_hud_states.png")
    paths=sorted((source/"frames").glob("frame_*.png"))
    if paths:
        assert len(paths)==240,len(paths)
        frames=[Image.open(p).convert("RGB").crop((0,60,960,730)) for p in paths]
        atlas=Image.new("RGB",(960,670*12))
        for i,frame in enumerate(frames[::20]): atlas.paste(frame,(0,i*670))
        palette=atlas.quantize(colors=256,method=Image.Quantize.MEDIANCUT)
        indexed=[frame.quantize(palette=palette,dither=Image.Dither.NONE) for frame in frames]
        indexed[0].save(OUT/"loan_preview.gif",save_all=True,append_images=indexed[1:],
                        duration=50,loop=0,disposal=1,optimize=True)
    print("LOAN_REVIEW_READY",OUT)


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("source",type=Path)
    main(parser.parse_args().source)
