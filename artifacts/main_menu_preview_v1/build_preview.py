from pathlib import Path
import random

from PIL import Image, ImageDraw, ImageFont, ImageEnhance
from fontTools.ttLib import TTFont


ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
ASSETS = ROOT / 'assets'
NEAREST = Image.Resampling.NEAREST
FONT_PATH = ASSETS / 'font/ark-pixel-12px-monospaced-zh_cn.otf'
FONT = ImageFont.truetype(str(FONT_PATH), 12)
SMALL_FONT = ImageFont.truetype(str(ASSETS / 'font/ark-pixel-12px-monospaced-zh_cn.otf'), 12)
FALLBACK_FONT = ImageFont.truetype(str(ASSETS / 'font/IPix-pixel_font.ttf'), 12)
FONT_CMAP = TTFont(FONT_PATH).getBestCmap()

INK = '#101811'
TEXT = '#e0d6b6'
MUTED = '#a79f87'
GOLD = '#c5a16a'


def label(text, color=TEXT, font=FONT, scale=1):
    width = int(font.getlength(text))
    box = font.getbbox(text)
    result = Image.new('RGBA', (width + 2, box[3] - box[1] + 2))
    draw = ImageDraw.Draw(result)
    cursor = 1
    for char in text:
        active_font = font if ord(char) in FONT_CMAP else FALLBACK_FONT
        draw.text((cursor, 1 - box[1]), char, font=active_font, fill=color, stroke_width=0)
        cursor += int(font.getlength(char))
    if scale != 1:
        result = result.resize((result.width * scale, result.height * scale), NEAREST)
    return result


def put(canvas, text, x, y, color=TEXT, font=FONT, scale=1, center=False):
    image = label(text, color, font, scale)
    if center:
        x -= image.width // 2
    canvas.alpha_composite(image, (x, y))


wood_source = Image.open(ASSETS / 'ui/finance/finance_board.png').convert('RGBA')


def board(size):
    width, height = size
    result = Image.new('RGBA', size)
    edge = 12
    srcx = [0, edge, wood_source.width - edge, wood_source.width]
    srcy = [0, edge, wood_source.height - edge, wood_source.height]
    dstx = [0, edge, width - edge, width]
    dsty = [0, edge, height - edge, height]
    for row in range(3):
        for col in range(3):
            patch = wood_source.crop((srcx[col], srcy[row], srcx[col + 1], srcy[row + 1]))
            patch = patch.resize((dstx[col + 1] - dstx[col], dsty[row + 1] - dsty[row]), NEAREST)
            result.alpha_composite(patch, (dstx[col], dsty[row]))
    return result


def button(size, primary=False, pressed=False):
    w, h = size
    img = Image.new('RGBA', size)
    draw = ImageDraw.Draw(img)
    shape = [(4, 0), (w-5, 0), (w-5, 2), (w-1, 2), (w-1, h-6), (w-4, h-6), (w-4, h-2), (4, h-2), (4, h-4), (0, h-4), (0, 4), (4, 4)]
    draw.polygon([(x, min(h-1, y+2)) for x,y in shape], fill='#0e140f')
    draw.polygon(shape, fill='#ad915d' if primary else '#5c6348')
    draw.rectangle((4, 4, w-5, h-7), fill='#504831' if primary else '#293325')
    draw.line((5, 3, w-6, 3), fill='#e0c788' if primary else '#87906a', width=1)
    draw.line((5, h-7, w-6, h-7), fill='#26291c', width=2)
    rng = random.Random(27)
    for _ in range(26):
        x = rng.randrange(7, w-18)
        y = rng.randrange(6, h-9)
        draw.line((x, y, min(w-8, x+rng.randrange(3,16)), y), fill='#554b31' if primary else '#2c3626')
    for x in (8, w-11):
        for y in (7, h-12):
            draw.rectangle((x,y,x+2,y+2), fill='#d5ba7c' if primary else '#89906a')
            draw.point((x+2,y+2), fill='#31382a')
    if primary:
        draw.line((12, h-5, w-13, h-5), fill='#bda16a', width=1)
    if pressed:
        img = ImageEnhance.Brightness(img).enhance(0.86)
    return img


def make_ui():
    ui = Image.new('RGBA', (640,360))
    draw = ImageDraw.Draw(ui)
    # Native 12 px glyphs, used at exactly 3x for the title.
    title = label('\u7a79\u9876\u6c42\u751f', '#dfc287', scale=3)
    shadow = label('\u7a79\u9876\u6c42\u751f', '#121a13', scale=3)
    ui.alpha_composite(shadow, (58,63))
    ui.alpha_composite(title, (56,60))
    draw.line((65,102,185,102), fill='#706347')
    draw.rectangle((122,100,126,104), fill=GOLD)
    menu = board((174,190))
    ui.alpha_composite(menu, (42,118))
    # A decorative wood menu carrier, not a new gameplay feature.
    put(ui, '\u7a79\u9876\u4e4b\u4e0b', 129,129,MUTED,SMALL_FONT,center=True)
    entries = [('\u5f00\u59cb\u6218\u6597',150,34,True), ('\u5929\u8d4b',190,29,False), ('\u8bbe\u7f6e',225,29,False), ('\u9000\u51fa',267,27,False)]
    for text, y, height, primary in entries:
        surface = button((144,height),primary)
        ui.alpha_composite(surface,(57,y))
        glyph = label(text,'#f0deb0' if primary else TEXT)
        ui.alpha_composite(glyph,(129-glyph.width//2,y+(height-glyph.height)//2-2))
        if primary:
            draw.polygon([(65,y+12),(69,y+16),(65,y+20)],fill='#e8cc86')
    put(ui,'\u7a79\u9876\u4e4b\u4e0b\uff0c\u53e4\u795e\u6ce8\u89c6\u7740\u4f60\u2026\u2026',320,321,MUTED,SMALL_FONT,center=True)
    return ui


def make_preview():
    # Keep the original environment rendering: this is an honest layout review.
    bg = Image.open(ASSETS / 'ui/main_menu/bg_main_menu.png').convert('RGBA')
    bg = bg.resize((1920,1080),Image.Resampling.LANCZOS)
    shade = Image.new('RGBA',bg.size)
    sd = ImageDraw.Draw(shade)
    for x in range(bg.width):
        amount = max(0.0,1.0-x/1050)
        sd.line((x,0,x,1079),fill=(10,20,15,int(145*amount+20)))
    bg = Image.alpha_composite(bg,shade)
    player = Image.open(ASSETS / 'sprites/player/combat/void_hunter_idle_right.png').convert('RGBA')
    player = player.crop(player.getbbox())
    player = player.resize((player.width*4,player.height*4),NEAREST)
    x = 1116-player.width//2
    y = 757-player.height
    sd2 = ImageDraw.Draw(bg)
    sd2.rectangle((x+30,744,x+player.width-23,752),fill='#363c27')
    sd2.rectangle((x+46,753,x+player.width-38,757),fill='#363c27')
    bg.alpha_composite(player,(x,y))
    bg.alpha_composite(make_ui().resize((1920,1080),NEAREST))
    bg.convert('RGB').save(OUT/'main-menu-preview-v1.png')


def make_sheet():
    sheet = Image.new('RGBA',(640,400),'#172018')
    put(sheet,'\u9996\u9875\u6750\u8d28\u4e0e\u63a7\u4ef6',28,24,TEXT)
    put(sheet,'V1 / UI MATERIAL STUDY',28,50,MUTED,SMALL_FONT)
    panel = board((218,248))
    sheet.alpha_composite(panel,(28,91))
    put(sheet,'\u6df1\u8272\u6728\u677f\u00b7\u91d1\u5c5e\u5305\u89d2',137,113,TEXT,SMALL_FONT,center=True)
    for name, y, primary in [('\u5f00\u59cb\u6218\u6597',149,True), ('\u5929\u8d4b',199,False), ('\u8bbe\u7f6e',245,False)]:
        img=button((174,36),primary)
        sheet.alpha_composite(img,(50,y))
        put(sheet,name,137,y+9,TEXT,center=True)
    put(sheet,'\u4e3b\u6309\u94ae\uff1a\u65e7\u91d1\u8fb9\u6846',281,100,TEXT,SMALL_FONT)
    put(sheet,'\u6b21\u6309\u94ae\uff1a\u82d4\u7eff\u91d1\u5c5e',281,124,TEXT,SMALL_FONT)
    put(sheet,'\u6587\u5b57\uff1aArk Pixel 12px',281,148,TEXT,SMALL_FONT)
    colors=['#232a21','#30372a','#626b4e','#c5a16a','#e0d6b6','#a79f87']
    d=ImageDraw.Draw(sheet)
    for i,c in enumerate(colors):
        xx=281+(i%3)*98
        yy=198+(i//3)*62
        d.rectangle((xx,yy,xx+79,yy+25),fill=c)
        put(sheet,c.upper(),xx,yy+32,MUTED,SMALL_FONT)
    put(sheet,'\u80cc\u666f\u4e0e\u89d2\u8272\u4e3a\u73b0\u6709\u7d20\u6750\uff1b\u6b64\u9875\u7528\u4e8e\u5ba1\u9605\u6750\u8d28\u4e0e\u5c42\u7ea7\u3002',28,367,MUTED,SMALL_FONT)
    sheet.resize((1920,1200),NEAREST).convert('RGB').save(OUT/'menu-material-study-v1.png')


if __name__ == '__main__':
    board((174,190)).save(OUT/'menu-board-v1.png')
    button((144,34),True).save(OUT/'button-primary-v1.png')
    button((144,29),False).save(OUT/'button-secondary-v1.png')
    make_ui().save(OUT/'menu-overlay-v1.png')
    make_preview()
    make_sheet()
    print('Created review preview and UI material assets in:',OUT)
