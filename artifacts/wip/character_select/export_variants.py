"""Local layout blockout only; uses existing sprites, no generation API."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
im = Image.new('RGB', (640, 360), '#231e2a')
d = ImageDraw.Draw(im)

def poly(points, color):
    d.polygon(points, fill=color)

def rect(box, color):
    d.rectangle(box, fill=color)

# Broad room planes; intentionally no texture or fine ornament.
poly([(0,0),(204,0),(189,272),(0,303)], '#2b2531')
poly([(392,0),(640,0),(640,308),(399,270)], '#312a35')
poly([(0,285),(229,260),(398,266),(640,307),(640,360),(0,360)], '#343238')
poly([(181,298),(260,268),(376,270),(431,328),(362,346),(224,340)], '#414044')
poly([(0,0),(34,0),(40,93),(23,148),(30,264),(0,299)], '#241823')
poly([(640,0),(601,0),(609,74),(597,123),(618,210),(640,238)], '#432632')

# Low ceiling, patched masonry and exposed service pipe identify the cellar.
rect((0,0,640,13), '#1d1b23')
poly([(0,14),(640,14),(640,22),(0,19)], '#49404a')
rect((145,20,155,72), '#38333c')
rect((399,20,411,78), '#39333c')
for box in ((14,69,48,77),(53,69,90,77),(7,79,29,86),
            (112,47,153,57),(125,60,162,68),(418,40,454,48),
            (584,58,623,67),(607,70,639,80),(143,216,165,230)):
    rect(box, '#38343e')
poly([(0,35),(83,35),(96,44),(96,87),(89,87),(89,49),(80,43),(0,43)], '#55615b')
rect((0,35,79,37), '#738071')
for x in (23,67):
    rect((x,31,x+5,47), '#343c3b')
    rect((x+1,32,x+3,46), '#737568')
poly([(89,55),(94,50),(102,50),(108,56),(108,62),(102,68),(95,68),(89,62)], '#806454')
rect((95,54,101,64), '#373338')
rect((90,58,107,60), '#ab8b66')

# A barred window sits high on the wall, above ground level.
poly([(476,27),(552,27),(560,34),(556,60),(474,60),(470,52),(470,33)], '#555952')
rect((478,32,550,53), '#213034')
rect((481,34,547,50), '#536d69')
rect((482,36,546,40), '#7d9291')
for x in (487,503,519,535):
    rect((x,31,x+3,53), '#303d3e')
rect((475,55,558,59), '#717768')

# Broken, stepped arch behind the character.
poly([(167,271),(167,121),(184,121),(184,91),(217,91),(217,68),(263,68),(263,56),(319,56),(319,67),(362,67),(362,91),(386,91),(386,127),(400,127),(400,274)], '#46524e')
poly([(184,266),(184,133),(202,133),(202,105),(231,105),(231,86),(269,86),(269,77),(314,77),(314,88),(348,88),(348,109),(369,109),(369,141),(383,141),(383,267)], '#191f26')
poly([(202,252),(203,139),(223,139),(223,115),(252,115),(252,100),(317,100),(317,117),(342,117),(342,146),(362,146),(362,263)], '#273436')
poly([(218,248),(233,157),(257,122),(309,113),(337,182),(350,262)], '#344541')
rect((170,160,181,267), '#586258')
rect((383,171,392,270), '#394441')

# An ascending staircase recedes into the alcove behind the character.
poly([(299,123),(328,123),(350,159),(367,178),(367,249),(322,249)], '#242d30')
for box in ((319,139,338,145),(323,151,346,157),(329,164,353,171),
            (334,179,363,188),(340,198,367,209),(346,222,376,235)):
    rect(box, '#48534e')
rect((341,157,344,179), '#606b5d')
rect((352,178,355,199), '#606b5d')

# Abstract violet light patch and a chunky hanging lantern.
poly([(180,88),(209,86),(233,171),(213,201),(166,162)], '#3e324b')
rect((191,45,193,88), '#645862')
poly([(181,86),(202,86),(210,99),(205,125),(180,125),(176,99)], '#675169')
poly([(186,91),(198,91),(201,110),(197,117),(185,114)], '#ac7bb9')
rect((189,95,195,108), '#d0abc9')
rect((180,124,206,128), '#746977')

# Wooden roster holds six compact rows instead of two full-body cards.
poly([(14,89),(128,83),(139,97),(135,294),(19,296),(11,282)], '#302d2d')
poly([(18,85),(126,82),(135,91),(24,96)], '#595041')
for x in (35,114):
    rect((x,82,x+3,106), '#8b7762')
for index in range(6):
    y = 109 + index * 29
    edge = '#a8997c' if index == 0 else '#625b51'
    fill = '#b1a183' if index == 0 else ('#756d60' if index == 1 else '#403d3c')
    poly([(23,y),(124,y),(128,y+4),(128,y+22),(124,y+26),(23,y+26),(20,y+22),(20,y+4)], edge)
    rect((23,y+3,125,y+23), fill)
    if index > 1:
        # Unnamed placeholders show capacity without inventing new characters.
        rect((51,y+11,94,y+13), '#5a5650')
rect((20,112,22,132), '#ba91b8')
rect((131,111,132,276), '#24292b')
rect((131,114,132,163), '#827968')

# Storage objects sit in the side margins, keeping the character readable.
poly([(145,270),(168,265),(193,274),(193,297),(161,301),(145,291)], '#55483c')
poly([(145,270),(168,265),(193,274),(166,280)], '#76644d')
poly([(151,276),(155,277),(180,296),(175,297)], '#8a7456')
rect((150,279,154,292), '#726048')
poly([(190,254),(203,250),(215,254),(220,265),(220,285),(215,296),(201,300),(187,291),(185,268)], '#625343')
poly([(190,255),(204,252),(214,256),(216,263),(189,264)], '#887456')
poly([(186,269),(219,266),(220,271),(186,274)], '#424d49')
poly([(187,286),(220,282),(218,288),(190,292)], '#424d49')
poly([(166,291),(178,291),(183,298),(173,299),(164,296)], '#465647')
poly([(388,278),(402,278),(408,285),(400,291),(385,289)], '#3c5047')
poly([(369,298),(403,291),(419,300),(385,307)], '#262e30')
for offset in (0,7,14,21):
    poly([(377+offset,298-offset//4),(380+offset,298-offset//4),(391+offset,302-offset//4),(388+offset,303-offset//4)], '#4d5552')

# Low platform anchors the character without boxing it in.
poly([(230,268),(336,266),(368,282),(341,297),(229,297),(210,284)], '#22272c')
poly([(230,264),(335,263),(366,278),(337,289),(230,289),(210,278)], '#647168')
poly([(225,277),(336,275),(348,280),(335,284),(231,284)], '#35443f')

# Irregular parchment is one continuous information surface.
poly([(426,73),(619,77),(628,94),(622,277),(630,291),(613,302),(420,293),(413,279),(419,88)], '#191b20')
poly([(421,67),(615,71),(623,86),(618,272),(624,284),(610,294),(419,285),(412,273),(416,85)], '#8e816a')
poly([(426,75),(609,78),(614,91),(611,273),(607,284),(425,278),(420,269),(423,89)], '#c0b08e')
poly([(590,77),(609,78),(614,94),(592,96)], '#e0cba4')
rect((499,61,541,73), '#454b47')
rect((504,62,536,67), '#828775')
rect((434,131,600,132), '#9f8d6e')
rect((434,191,600,192), '#9f8d6e')

# Bottom choice tokens and restrained navigation frames.
for x, selected in ((195,True),(234,False),(273,False)):
    poly([(x,316),(x+7,309),(x+27,309),(x+34,316),(x+34,337),(x+27,344),(x+7,344),(x,337)], '#b7a17c' if selected else '#545258')
    poly([(x+3,318),(x+9,313),(x+25,313),(x+30,318),(x+30,335),(x+24,339),(x+9,339),(x+3,335)], '#715178' if selected else '#343139')
def small_button(x, y, width, edge, fill):
    height = 20
    poly([(x+2,y),(x+width-2,y),(x+width,y+2),(x+width,y+height-2),
          (x+width-2,y+height),(x+2,y+height),(x,y+height-2),(x,y+2)], edge)
    poly([(x+2,y+1),(x+width-2,y+1),(x+width-1,y+2),(x+width-1,y+height-2),
          (x+width-2,y+height-1),(x+2,y+height-1),(x+1,y+height-2),(x+1,y+2)], fill)

small_button(21,318,91,'#686354','#2d2e30')
small_button(560,318,60,'#727766','#303934')

im = im.resize((1280,720), Image.Resampling.NEAREST).convert('RGBA')
d = ImageDraw.Draw(im)
FONT = 'C:/Windows/Fonts/msyh.ttc'
BOLD = 'C:/Windows/Fonts/msyhbd.ttc'

def draw_text(x, y, s, size=22, color='#dac9a9', bold=False, anchor=None):
    font = ImageFont.truetype(BOLD if bold else FONT,size)
    if '◀' in s or '▶' in s:
        symbol_font = ImageFont.truetype('C:/Windows/Fonts/seguisym.ttf',size)
        runs = [(char, symbol_font if char in '◀▶' else font) for char in s]
        if anchor == 'mm':
            x -= sum(f.getlength(char) for char,f in runs) / 2
            y -= (min(f.getbbox(char)[1] for char,f in runs) + max(f.getbbox(char)[3] for char,f in runs)) / 2
        for char,run_font in runs:
            d.text((x,y),char,font=run_font,fill=color)
            x += run_font.getlength(char)
        return
    d.text((x,y), s, font=font, fill=color, anchor=anchor)

text_items = []

def text(*args, **kwargs):
    # Keep all labels separate: both exports share the exact same artwork.
    text_items.append((args, kwargs))

def sprite(path, position, scale=1, crop=True):
    src = Image.open(ROOT / path).convert('RGBA')
    if crop:
        src = src.crop(src.getbbox())
    src = src.resize((src.width*scale,src.height*scale), Image.Resampling.NEAREST)
    im.alpha_composite(src, position)

text(47,187,'角色名册',20,'#cdbb99')

def portrait(path, x, y):
    src = Image.open(ROOT / path).convert('RGBA')
    src = src.crop(src.getbbox())
    ratio = min(42/src.width,42/src.height)
    src = src.resize((round(src.width*ratio),round(src.height*ratio)), Image.Resampling.NEAREST)
    im.alpha_composite(src, (x + (42-src.width)//2, y + (42-src.height)//2))

text(108,232,'初心者',21,'#302e2e',True)
text(108,290,'资本家',21,'#ece0c0',True)

# The sprite is a 5x nearest-neighbour enlargement of the approved production art.
text(574,194,'初心者',30,'#eee0bc',True,'mm')
text(574,232,'每一次生还，都是成长。',18,'#aab6a7',anchor='mm')
text(574,599,'角色展示',16,'#a7afa2',anchor='mm')

# Restore dossier copy for the complete-text export only.
ink = '#353638'
muted = '#625847'
text(866,167,'出征档案',28,ink,True)
text(868,213,'初心者 / 初始角色',18,muted)
text(868,276,'开局属性',18,muted,True)
text(868,310,'生命',19,ink)
text(994,310,'5',24,ink,True,anchor='ra')
text(1046,310,'移速',19,ink)
text(1195,310,'240',24,ink,True,anchor='ra')
text(868,349,'负载',19,ink)
text(994,349,'100',24,ink,True,anchor='ra')
text(1046,349,'人性',19,ink)
text(1195,349,'100',24,ink,True,anchor='ra')
text(868,400,'初始武器',18,muted,True)
text(927,441,'异化触手',23,ink,True)
text(868,493,'角色特性',18,muted,True)
text(868,526,'每级生命 +1（升级不回血）',20,ink)

text(133,656,'◀ 返回主界面',20,'#c4b7a1',anchor='mm')
text(317,652,'难度',19,'#bdb09c',anchor='mm')
for x, label in ((424,'I'),(502,'II'),(580,'III')):
    text(x,653,label,25,'#efe0bb',True,'mm')
text(643,650,'标准难度',21,'#d4c5a6',anchor='lm')
text(1180,656,'继续 ▶',20,'#d0c7ad',anchor='mm')

im.convert('RGB').save(OUT / '01-no-text.png')
portrait('assets/ui/icons/characters/icon_void_hunter.png',51,225)
portrait('assets/ui/icons/characters/icon_capitalist.png',51,283)
sprite('assets/sprites/player/combat/void_hunter_idle_right.png',(521,295),5)
for index in range(2,6):
    y = 109 + index * 29
    # Reproduce the original low-resolution placeholder shapes at 2x.
    d.rectangle((58,2*(y+6),77,2*(y+14)+1), fill='#5a5752')
    tile = Image.new('RGBA',(640,360))
    ImageDraw.Draw(tile).polygon([(28,y+15),(40,y+15),(43,y+21),(25,y+21)],fill='#5a5752')
    im.alpha_composite(tile.resize(im.size,Image.Resampling.NEAREST))
sprite('assets/ui/icons/weapons/weapon_mutant_tentacle.png',(870,435),1)
for args,kwargs in text_items:
    draw_text(*args, **kwargs)
im.convert('RGB').save(OUT / '02-full-text.png')
print(OUT / '01-no-text.png')
print(OUT / '02-full-text.png')
