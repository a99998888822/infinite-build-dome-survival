"""Offline art/audio review only. Never edits game scenes, config or player saves."""
from pathlib import Path
import argparse
import json
import math
import subprocess
import tempfile
import wave
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageEnhance
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'artifacts/previews/run_settlement'
WORK = Path(tempfile.gettempdir()) / 'codex_run_settlement_review'
RATE = 44100
W, H = 1152, 768
INK = '#101a17'
PANEL = '#202a23'
TEXT = '#e4d9bd'
MUTED = '#999e89'
GOLD = '#d6b476'
BRIGHT = '#ffe6a2'
GREEN = '#96bda3'
RED = '#c78f79'
FONTS = {}
FALLBACK_FONTS = {}
FONT_PATH = ROOT / 'assets/font/ark-pixel-12px-monospaced-zh_cn.otf'
COVERAGE = TTFont(FONT_PATH).getBestCmap()


def font(size):
    if size not in FONTS:
        FONTS[size] = ImageFont.truetype(str(FONT_PATH), size)
    return FONTS[size]


def text(im, xy, value, size=18, fill=TEXT, anchor=None):
    value=str(value)
    primary=font(size)
    if size not in FALLBACK_FONTS:
        FALLBACK_FONTS[size]=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',size)
    fonts=[primary if ord(char) in COVERAGE else FALLBACK_FONTS[size] for char in value]
    advances=[selected.getlength(char) for char,selected in zip(value,fonts)]
    x,y=xy
    if anchor and anchor.startswith('r'): x-=sum(advances)
    elif anchor and anchor.startswith('m'): x-=sum(advances)/2
    baseline=y+primary.getmetrics()[0]
    draw=ImageDraw.Draw(im)
    for char,selected,advance in zip(value,fonts,advances):
        draw.text((x,baseline),char,font=selected,fill=fill,anchor='ls')
        x+=advance


def fit_text(im, xy, value, width, size=18, fill=TEXT, spacing=7):
    draw = ImageDraw.Draw(im)
    lines = []
    for paragraph in value.split('\n'):
        current = ''
        for char in paragraph:
            if current and draw.textlength(current + char, font=font(size)) > width:
                lines.append(current)
                current = char
            else:
                current += char
        lines.append(current)
    y = xy[1]
    for line in lines:
        text(im, (xy[0], y), line, size, fill)
        y += size + spacing
    return y


def panel(im, rect, fill=PANEL, edge='#756748', width=1):
    x, y, w, h = map(int, rect)
    d = ImageDraw.Draw(im)
    d.rectangle((x, y, x+w, y+h), fill=INK, outline=edge, width=width)
    d.rectangle((x+3, y+3, x+w-3, y+h-3), fill=fill)
    for px, py, sx, sy in [(x,y,1,1),(x+w,y,-1,1),(x,y+h,1,-1),(x+w,y+h,-1,-1)]:
        d.line((px+sx*4,py+sy*2,px+sx*14,py+sy*2),fill=GOLD,width=2)
        d.line((px+sx*2,py+sy*4,px+sx*2,py+sy*14),fill=GOLD,width=2)


def glyph(kind):
    im = Image.new('RGBA',(32,32))
    d = ImageDraw.Draw(im)
    if kind == 'kills':
        for x0,x1 in [(7,24),(24,7)]:
            d.line((x0,5,x1,26),fill='#384a40',width=7)
            d.line((x0,5,x1,26),fill='#adbbab',width=3)
        d.line((5,22,12,27),fill=GOLD,width=3)
        d.line((20,27,27,22),fill=GOLD,width=3)
    elif kind == 'gold':
        for x,y in [(5,18),(16,14),(9,8)]:
            d.rectangle((x,y,x+12,y+7),fill='#8c6535',outline=GOLD,width=2)
            d.line((x+2,y+2,x+10,y+2),fill=BRIGHT,width=1)
    elif kind == 'waves':
        d.rectangle((6,4,8,27),fill='#a9b7a8')
        d.polygon([(9,5),(27,5),(23,11),(27,16),(9,16)],fill='#8ca491')
        d.line((12,8,20,8),fill='#d9deb9',width=2)
        d.rectangle((3,27,14,29),fill=GOLD)
    elif kind == 'interest':
        d.ellipse((4,16,17,29),fill='#816338',outline=GOLD,width=2)
        d.line((8,20,13,20),fill=BRIGHT,width=1)
        d.line((5,14,12,9,17,12,26,4),fill=GREEN,width=3)
        d.polygon([(19,4),(28,3),(28,12)],fill=GREEN)
    else:
        points=[(10,2),(22,2),(29,9),(29,23),(22,30),(10,30),(3,23),(3,9)]
        d.polygon(points,fill='#483e2a',outline='#edc883',width=2)
        d.polygon([(16,8),(24,23),(8,23)],fill='#cba96a')
        d.polygon([(16,14),(19,23),(13,23)],fill='#37463b')
        d.line((9,26,23,26),fill='#ffe4a0',width=1)
    return im


def make_goblins():
    # Review the installed artwork; legacy face/hand coordinates do not fit it.
    sheet=Image.open(ROOT/'assets/ui/settlement/goblin_reactions.png').convert('RGBA')
    assert sheet.size == (512,512)
    sheet.save(OUT/'assets/goblin_reactions.png')
    return sheet


def make_assets():
    for sub in ['assets','audio']:
        (OUT/sub).mkdir(parents=True,exist_ok=True)
    sheet=make_goblins()
    icons=Image.new('RGBA',(160,32))
    for index,kind in enumerate(['kills','gold','waves','interest','camp']): icons.alpha_composite(glyph(kind),(index*32,0))
    icons.save(OUT/'assets/settlement_icons.png')
    fx=Image.new('RGBA',(512,64))
    d=ImageDraw.Draw(fx)
    for i in range(8):
        p=i/7
        cx,cy=i*64+32,32
        radius=round(4+25*p)
        alpha=round(255*(1-p))
        d.ellipse((cx-radius,cy-radius,cx+radius,cy+radius),outline=(237,210,142,alpha),width=2)
        for a in range(8):
            angle=a*math.tau/8
            x,y=round(cx+radius*math.cos(angle)),round(cy+radius*math.sin(angle))
            d.rectangle((x,y,x+2,y+2),fill=(202,173,103,alpha))
    fx.save(OUT/'assets/payout_glint.png')
    return sheet


def contributions(case):
    return [case['kills']//10,case['gold']//20,case['waves']*20,min(case['interest']//50,case['waves']*20)]


def bell(duration,freq,decay):
    t=np.arange(round(duration*RATE))/RATE
    return np.minimum(1,t/.004)*np.exp(-t/decay)*(np.sin(2*np.pi*freq*t)+.24*np.sin(2*np.pi*freq*2.76*t))


def save_wav(path,data):
    data=np.clip(data,-.95,.95)
    with wave.open(str(path),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE)
        f.writeframes((data*32767).astype('<i2').tobytes())


def read_wav(path):
    with wave.open(str(path),'rb') as f:
        assert f.getframerate()==RATE and f.getnchannels()==1
        return np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').astype(float)/32768


def make_audio(_cases):
    starts=[.55,1.35,2.15,2.95,3.85]
    cues=[]
    for i,freq in enumerate([523.25,659.25,783.99,987.77,1174.66]):
        duration=.24+i*.05
        data=bell(duration,freq,.06+i*.014)
        if i==4:
            for offset,ratio in [(.035,1.25),(.075,1.5),(.12,2)]:
                n=round(offset*RATE)
                data[n:]+=.3*bell(duration-offset,freq*ratio,.1)
        data*=.25/max(np.max(np.abs(data)),.001)
        save_wav(OUT/f'audio/stage_{i+1}.wav',data)
        cues.append(data)
    # Goblin voice slots are intentionally empty; only score cues are mixed.
    duration=9.5
    signal=np.zeros(round(duration*RATE))
    for start,cue in zip(starts,cues):
        offset=round(start*RATE);signal[offset:offset+len(cue)]+=cue
    save_wav(WORK/'review_mix.wav',signal)
    return duration


def draw_preview(case,sheet,seconds=20):
    background=Image.open(ROOT/'assets/sprites/background/background-stone-brick-floor.png').convert('RGB').resize((W,H))
    im=Image.blend(background,Image.new('RGB',(W,H),'#080f0d'),.91).convert('RGBA')
    panel(im,(44,38,1064,688),'#151e19','#8d7953',2)
    d=ImageDraw.Draw(im)
    accent=GOLD if case['victory'] else RED
    text(im,(80,64),'冒险结束',36,accent)
    text(im,(80,112),'通关！' if case['victory'] else f"第{case['waves']+1}波 阵亡",14,MUTED)
    text(im,(1076,75),'营地结算',20,GOLD,'ra')
    text(im,(1076,110),'设计预览 · 示例数据',12,MUTED,'ra')
    d.line((80,145,1076,145),fill='#514c35',width=1)
    text(im,(80,167),'击杀记录',20,TEXT)
    text(im,(80,195),'本次击败的敌人',12,MUTED)
    # Actual game silhouettes, kept in their established pixel-art style.
    small=Image.open(ROOT/'assets/sprites/enemies/combat/enemy_gloom_mite_idle.png').convert('RGBA')
    knight=Image.open(ROOT/'assets/sprites/enemies/iron_knight/knight_idle.png').convert('RGBA').crop((0,0,160,160))
    for i,(sprite,label,count) in enumerate([(small,'天外幼体',case['kills']-case['elite_kills']),(knight,'钢甲骑士',case['elite_kills'])]):
        x=80+i*145
        panel(im,(x,228,132,161),'#1e2821','#45533f')
        sprite=sprite.crop(sprite.getbbox())
        scale=min(100/sprite.width,98/sprite.height)
        sprite=sprite.resize((round(sprite.width*scale),round(sprite.height*scale)),Image.Resampling.NEAREST)
        im.alpha_composite(sprite,(x+(132-sprite.width)//2,237+(98-sprite.height)//2))
        text(im,(x+66,336),label,16,TEXT,'ma')
        progress=min(1,max(0,(seconds-.55)/.6))
        text(im,(x+66,361),f'× {round(count*progress):,}',18,GOLD,'ma')
    # Four contributions; the strongest animation belongs to the final camp payout.
    labels=['总杀敌数','赚取金币','度过波次','赚取利息']
    values=[case['kills'],case['gold'],case['waves'],case['interest']]
    units=['只','金币','波','金币']
    points=contributions(case)
    starts=[.55,1.35,2.15,2.95]
    for i,(label,value,unit,points_value,start) in enumerate(zip(labels,values,units,points,starts)):
        y=166+i*65
        progress=min(1,max(0,(seconds-start)/.58))
        settled=seconds>=start+.58
        pulse=max(0,1-abs(seconds-start-.30)/.3)
        color=TEXT if progress>0 else '#4c594b'
        panel(im,(394,y,682,57),'#273127' if pulse else '#1b261f',GOLD if pulse else '#3f4b3b')
        im.alpha_composite(glyph(['kills','gold','waves','interest'][i]),(410,y+13))
        text(im,(453,y+18),label,18,color)
        text(im,(828,y+13),f'{round(value*(1-(1-progress)**3)):,}',24,color,'ra')
        text(im,(842,y+22),unit,12,MUTED)
        text(im,(1057,y+18),f'+{points_value if settled else round(points_value*progress):,}',20,GOLD if progress else '#626045','ra')
        if pulse:
            for particle in range(i*2+2):
                px=1059-((seconds-start)*140+particle*17)%126
                py=y+10+math.sin(particle*2.3+seconds*7)*8
                d.rectangle((px,py,px+2,py+2),fill=BRIGHT)
    text(im,(1067,432),'右列为各项折算的营地币',12,MUTED,'ra')
    total=sum(points)
    arrived=min(1,max(0,(seconds-3.85)/.6))
    hero_y=454
    pulse=max(0,1-abs(seconds-4.1)/.3)
    panel(im,(394,hero_y,682,132),'#302e20' if pulse else '#292c20',BRIGHT if pulse else '#9c834e',2)
    coin=glyph('camp').resize((70,70),Image.Resampling.NEAREST)
    im.alpha_composite(coin,(416,485))
    text(im,(510,474),'本次获得营地币',18,GOLD)
    text(im,(510,502),f'+ {round(total*(1-(1-arrived)**3)):,}',48,BRIGHT if arrived else '#666448')
    text(im,(1057,562),'已结算' if arrived>=1 else '正在清点…',14,GREEN,'ra')
    if 3.85<seconds<4.8:
        for k in range(20):
            p=min(1,max(0,(seconds-3.85-k*.017)/.6))
            if 0<p<1:
                px=730+math.cos(k*2.39)*p*210
                py=531+math.sin(k*2.39)*p*90
                d.rectangle((px,py,px+4,py+4),fill=GOLD)
    # Goblin aside, delivered after the score flourish so voice stays readable.
    speech_on=seconds>=4.5
    if speech_on:
        panel(im,(80,413,280,91),'#2a3023','#998252')
        display_speech={
            'death_followed':'哥布林包赚，\n但不包活哈哈哈！',
            'death_refused':'嘬嘬嘬，不听哥布林，\n吃亏在眼前！',
            'victory_followed':'再来，再来！',
            'victory_refused':'啧，稳妥点当然好，\n就是赚的少了些。',
        }[case['id']]
        spoken=display_speech[:max(0,int((seconds-4.5)/2.3*len(display_speech)))]
        fit_text(im,(95,428),spoken,251,18,TEXT,7)
        d.polygon([(122,504),(139,504),(129,516)],fill='#998252')
    row=0 if not case['victory'] and case['followed'] else 1 if not case['victory'] else 2 if case['followed'] else 3
    frame=int(seconds*5)%4 if speech_on else 0
    goblin=sheet.crop((frame*128,row*128,(frame+1)*128,(row+1)*128)).resize((168,168),Image.Resampling.NEAREST)
    im.alpha_composite(goblin,(133,500))
    desk=Image.open(ROOT/'assets/ui/finance/bank_counter_desk_picxel.png').convert('RGBA').resize((240,120),Image.Resampling.NEAREST)
    im.alpha_composite(desk,(94,604))
    panel(im,(632,649,218,44),'#212a23','#46523f')
    text(im,(741,662),'返回主界面',18,TEXT,'ma')
    text(im,(1074,669),'点击空白处快进',12,MUTED,'ra')
    return im.convert('RGB')


def make_art_board(sheet):
    im=Image.new('RGBA',(1152,440),'#111b17')
    text(im,(32,22),'哥布林 · 四种结算反应',24,GOLD)
    titles=['欣喜 / 包赚不包活','不悦 / 早说听我的','微笑 / 再来一局','失落 / 不情愿认账']
    for row,title in enumerate(titles):
        x=32+row*280
        panel(im,(x,75,264,297),'#222c22','#6e6243')
        pose=sheet.crop((128,row*128,256,(row+1)*128)).resize((224,224),Image.Resampling.NEAREST)
        im.alpha_composite(pose,(x+20,79))
        text(im,(x+132,327),title,16,TEXT,'ma')
    text(im,(32,402),'4 种反应 × 4 帧微动 · 复用银行哥布林造型 · 对白音频待添加',16,MUTED)
    im.convert('RGB').save(OUT/'goblin_art_board.png')


def make_video(case,sheet,duration):
    target=OUT/'settlement_preview.mp4'
    command=['ffmpeg','-y','-loglevel','error','-f','rawvideo','-vcodec','rawvideo','-pix_fmt','rgb24','-s',f'{W}x{H}','-r','24','-i','-','-i',str(WORK/'review_mix.wav'),'-c:v','libx264','-preset','fast','-crf','20','-pix_fmt','yuv420p','-c:a','aac','-b:a','160k','-shortest','-movflags','+faststart',str(target)]
    process=subprocess.Popen(command,stdin=subprocess.PIPE)
    for i in range(math.ceil(duration*24)):
        process.stdin.write(draw_preview(case,sheet,i/24).tobytes())
    process.stdin.close()
    if process.wait()!=0: raise RuntimeError('ffmpeg failed')


def make_review_html(cases):
    cards=''.join(f'<article><h3>{case["name"]}</h3><p>{case["speech"]}</p><small>音频待添加</small></article>' for case in cases)
    html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>营地币结算 · 设计审阅</title><style>body{max-width:1120px;margin:38px auto;padding:0 24px;background:#101915;color:#e3dcc4;font:16px/1.7 system-ui}h1,h2{color:#d6b476}video,img{width:100%;border:1px solid #665e43}section{display:grid;grid-template-columns:1fr 1fr;gap:18px}article{padding:20px;background:#202b22;border:1px solid #566043}audio{width:100%}label{display:flex;justify-content:space-between;margin:12px 0}input{background:#121e16;color:#f4dfac;border:1px solid #77724c;padding:8px;width:120px}output{font-size:34px;color:#f7d892}small{color:#a1aa95}@media(max-width:650px){section{grid-template-columns:1fr}}</style><h1>营地币结算 · 设计审阅</h1><p>这是独立演出原型，使用示例数据，尚未接入游戏。先看一次结算节奏，再审阅四句哥布林对白。</p><video controls preload="metadata" poster="death_preview.png" src="settlement_preview.mp4"></video><h2>四种反应与对白</h2><p><small>四句对白的音频已置空，等待后续添加。</small></p><section>''' + cards + '''</section><h2>营地币公式试算</h2><section><article><label>总杀敌数<input id="kills" type="number" min="0" value="1800"></label><label>战斗赚取金币<input id="gold" type="number" min="0" value="2500"></label><label>完整度过波次<input id="waves" type="number" min="0" max="20" value="8"></label><label>实际赚取利息<input id="interest" type="number" min="0" value="1600"></label></article><article><p id="breakdown"></p><output id="sum"></output><p><small>采纳建议的比例不影响营地币。利息贡献上限等于波次贡献，超额利息仍完整显示。</small></p></article></section><h2>死亡版</h2><img src="death_preview.png"><h2>通关版</h2><img src="victory_preview.png"><h2>哥布林表情素材</h2><img src="goblin_art_board.png"><script>function update(){const v=id=>Math.max(0,Math.floor(Number(document.getElementById(id).value)||0));const k=Math.floor(v('kills')/10),g=Math.floor(v('gold')/20),w=Math.min(20,v('waves'))*20,i=Math.min(Math.floor(v('interest')/50),w);document.getElementById('breakdown').textContent=`杀敌 ${k} + 金币 ${g} + 波次 ${w} + 利息 ${i}`;document.getElementById('sum').textContent=`+ ${k+g+w+i} 营地币`}document.querySelectorAll('input').forEach(x=>x.addEventListener('input',update));update();</script></html>'''
    (OUT/'review.html').write_text(html,encoding='utf-8')


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--art-only',action='store_true');args=parser.parse_args()
    OUT.mkdir(parents=True,exist_ok=True);WORK.mkdir(parents=True,exist_ok=True)
    cases=json.loads((OUT/'review_data.json').read_text(encoding='utf-8'))['cases']
    sheet=make_assets()
    draw_preview(cases[0],sheet).save(OUT/'death_preview.png')
    draw_preview(cases[3],sheet).save(OUT/'victory_preview.png')
    make_art_board(sheet)
    make_review_html(cases)
    if not args.art_only:
        duration=make_audio(cases)
        make_video(cases[0],sheet,duration)
    print('SETTLEMENT_REVIEW_READY',OUT)


if __name__=='__main__': main()
