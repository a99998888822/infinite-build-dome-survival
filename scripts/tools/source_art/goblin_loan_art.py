"""Draw the loan review's pixel assets. No gameplay configuration is modified."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/ui/finance/loan"
REVIEW = ROOT / "artifacts/reviews/ui/goblin_loan"
INK = "#151e19"
SHADE = "#544329"
GOLD = "#b99555"
LIGHT = "#edce85"
PAPER = "#a89d74"
GREEN = "#97b982"


def coin(d, x, y, r=5):
    d.ellipse((x-r, y-r, x+r, y+r), fill=INK)
    d.ellipse((x-r+1, y-r+1, x+r-1, y+r-1), fill=GOLD)
    d.arc((x-r+2, y-r+2, x+r-2, y+r-2), 160, 330, fill=LIGHT)
    d.line((x, y-r+3, x, y+r-2), fill=SHADE)


def scroll(d, x, y, w=20, h=27):
    d.polygon([(x+3,y),(x+w-2,y),(x+w,y+3),(x+w,y+h-3),
               (x+w-3,y+h),(x,y+h),(x,y+3)], fill=INK)
    d.rectangle((x+3,y+2,x+w-2,y+h-3), fill=PAPER)
    d.rectangle((x+5,y+3,x+w-4,y+h-5), fill="#c4b585")
    d.line((x+3,y+2,x+w-3,y+2), fill="#ead7a2")
    for n in range(3):
        d.line((x+6,y+7+n*4,x+w-6-(n%2)*3,y+7+n*4), fill="#6c684d")
    d.rectangle((x+2,y+h-5,x+w-3,y+h-2), fill="#83704c")


def make_offer(tier):
    im = Image.new("RGBA", (48,48))
    d = ImageDraw.Draw(im)
    d.ellipse((5,39,43,44), fill="#101b1690")
    if tier == 100:
        scroll(d,11,5,23,31)
        for x,y in [(12,35),(22,36),(18,30),(30,35)]: coin(d,x,y,6)
        d.rectangle((29,10,31,14), fill="#6e3f2b")
    elif tier == 200:
        scroll(d,7,5,21,30)
        d.polygon([(29,9),(37,9),(35,15),(41,24),(43,35),(39,40),
                   (22,40),(18,35),(21,24),(28,15)], fill=INK)
        d.polygon([(29,12),(34,12),(33,18),(38,25),(40,34),(36,37),
                   (24,37),(21,33),(24,25),(30,18)], fill="#8f7143")
        d.line((27,17,36,17),fill=LIGHT,width=2)
        d.line((25,26,24,33),fill=GOLD,width=2)
        coin(d,31,29,6)
        coin(d,14,37,6)
        coin(d,37,39,5)
    else:
        scroll(d,6,3,22,28)
        d.polygon([(9,23),(15,15),(38,15),(44,22),(44,39),(8,39)],fill=INK)
        d.rectangle((12,23,41,36),fill="#635330")
        d.polygon([(12,21),(17,17),(37,17),(41,21)],fill=GOLD)
        d.line((12,24,41,24),fill=LIGHT,width=2)
        for x in [14,36]:
            d.rectangle((x,18,x+3,36),fill=GOLD)
            d.point((x+1,28),fill=LIGHT)
        d.rectangle((24,22,31,32),fill=INK)
        d.polygon([(24,26),(27,23),(31,26),(27,29)],fill=GREEN)
        d.line((27,24,27,28),fill=INK)
        for x,y in [(8,37),(19,40),(38,39)]: coin(d,x,y,5)
    d.line((39,5,39,11),fill=LIGHT)
    d.line((36,8,42,8),fill=LIGHT)
    d.point((39,8),fill="#fff0b3")
    im.save(OUT / f"loan_{tier}.png")


def symbols():
    im=Image.new("RGBA",(24,24)); d=ImageDraw.Draw(im)
    scroll(d,3,1,17,20)
    d.polygon([(10,17),(8,23),(12,21),(15,23),(15,17)],fill="#665034")
    coin(d,12,15,5)
    d.polygon([(9,15),(12,13),(15,15),(12,17)],fill=GREEN)
    d.line((12,14,12,16),fill=INK)
    im.save(OUT/"loan_note.png")
    im=Image.new("RGBA",(24,24)); d=ImageDraw.Draw(im)
    d.arc((3,3,20,20),35,290,fill=INK,width=5)
    d.arc((3,3,20,20),35,290,fill="#c28b58",width=2)
    d.polygon([(16,1),(22,5),(16,8)],fill="#e0b277")
    coin(d,11,12,5)
    im.save(OUT/"loan_rollover.png")


def board():
    im=Image.new("RGB",(960,300),"#17221c"); d=ImageDraw.Draw(im)
    font=ImageFont.truetype("C:/Windows/Fonts/msyh.ttc",18)
    small=ImageFont.truetype("C:/Windows/Fonts/msyh.ttc",14)
    d.text((28,20),"哥布林贷款 · 像素素材",font=font,fill=LIGHT)
    entries=[("loan_100.png","100 · 零钱借据"),("loan_200.png","200 · 钱袋借据"),
             ("loan_500.png","500 · 金库诱饵"),("loan_note.png","贷款状态"),("loan_rollover.png","复利状态")]
    for i,(name,label) in enumerate(entries):
        x=28+i*188
        d.rectangle((x,64,x+160,242),fill="#212b22",outline="#536046")
        sprite=Image.open(OUT/name)
        factor=3 if sprite.width==48 else 5
        sprite=sprite.resize((sprite.width*factor,sprite.height*factor),Image.Resampling.NEAREST)
        im.paste(sprite,(x+(160-sprite.width)//2,76),sprite)
        d.text((x+10,216),label,font=small,fill="#ddd5b8")
    d.text((28,266),"透明 PNG · 48 / 24 像素 · 沿用银行旧金与暗绿色板",font=small,fill="#a6ac93")
    im.save(REVIEW/"asset_board.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True,exist_ok=True)
    REVIEW.mkdir(parents=True,exist_ok=True)
    for tier in (100,200,500): make_offer(tier)
    symbols(); board()
    print("LOAN_ART_READY",OUT)
