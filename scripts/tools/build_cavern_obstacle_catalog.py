"""Package an unchanged-art obstacle inventory with real GPU crops and provenance."""
from pathlib import Path
import hashlib
import html
import json
import math
import shutil
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'artifacts/analysis/obstacle_catalog_20261013'
RUN = OUT / 'runtime'
SOURCES = {p.name:p for p in (ROOT/'artifacts/analysis/battle_scene_20261012/sucai').rglob('*.png')}
NEAR = Image.Resampling.NEAREST
FONT = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',20)
SMALL = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',15)
HEAD = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',27)
rows = []
shots = {s['name']:s for s in json.loads((RUN/'capture_metadata.json').read_text(encoding='utf-8'))['shots']}
old = json.loads((ROOT/'data_config/cavern_battlefield.json').read_text(encoding='utf-8'))
current = json.loads((ROOT/'data_config/cavern_meadow_battlefield.json').read_text(encoding='utf-8'))
for folder in ['sources','textures','crops','cards','sheets']:
    (OUT/folder).mkdir(parents=True,exist_ok=True)

def freeze(path, folder, name=None):
    dest = OUT/folder/(name or path.name)
    shutil.copy2(path,dest)
    return dest.relative_to(OUT).as_posix()

def add(code,title,group,config,index,shot,source=None,box=None,note=''):
    item = config[index]
    texture = ROOT/item['texture'][6:]
    src = SOURCES[source] if isinstance(source,str) else source
    row = dict(code=code,title=title,group=group,id=item.get('id',texture.stem),
               texture=freeze(texture,'textures'),texture_path=str(texture),
               texture_sha256=hashlib.sha256(texture.read_bytes()).hexdigest(),
               texture_size=list(Image.open(texture).size),shot=shot,note=note,
               collision=False,destructible=False)
    if src and src.is_file():
        row['source'] = freeze(src,'sources')
        row['source_path'] = str(src)
        row['source_sha256'] = hashlib.sha256(src.read_bytes()).hexdigest()
        im=Image.open(src).convert('RGBA')
        if box:
            if max(box)<=1: box=tuple(int(v*(im.width if i%2==0 else im.height)) for i,v in enumerate(box))
            im=im.crop(box)
            row['source_box']=box
        im.save(OUT/'crops'/(code+'_source.png'))
        row['source_crop']='crops/'+code+'_source.png'
    if shot:
        meta=shots[shot]
        row['runtime_metadata']=meta
        im=Image.open(RUN/(shot+'.png')).convert('RGB')
        x,y,w,h=meta['rect']
        # Keep context on the real ground; crops never repaint the subject.
        box=(max(0,math.floor(x)-28),max(0,math.floor(y)-24),
             min(im.width,math.ceil(x+w)+28),min(im.height,math.ceil(y+h)+24))
        row['runtime_crop_box']=box
        im.crop(box).save(OUT/'crops'/(code+'_runtime.png'))
        row['runtime_crop']='crops/'+code+'_runtime.png'
        row['runtime_full']='runtime/'+shot+'.png'
    rows.append(row)

prop_specs=[
 ('A01','圆石','ground_Barier1.png',(.035,.025,.465,.335)),
 ('A05','倒木／枯木','ground_wood1.png',(.01,.51,.49,.74))]
for i,(code,title,source,box) in enumerate(prop_specs):
    note='已修最外缘描线；原尺寸、内部 RGBA 和透明轮廓不变。附件方案自然生成；当前正式草地版不加载。'
    add(code,title,'A · 保留并描线',old['props'],i,'attachment_prop_'+str(i),source,box,note)
for i,box in enumerate([(.613,.894,.69,.95),(.691,.905,.741,.951)]):
    add(f'B{i+1:02}','小碎石 '+str(i+1),'附件版 · 地面碎石',old['rubble'],i,
        'attachment_rubble_'+str(i),'ground_Barier1.png',box,'从原图重做为 4 倍分辨率，清除邻近墙体阴影；屏幕大小保持原设置。')
for i,(name,box) in enumerate([
 ('残缺石拱',(.52,.52,.96,.97)),('方形石柱',(.60,.03,.89,.47)),
 ('尖碑／残柱',(.12,.04,.38,.46)),('灯柱／祭台',(.12,.53,.38,.94))]):
    add(f'C{i+1:02}',name,'两版共用 · 远景',old['ruins'],i,'far_'+str(i),
        'ground_view1 (6).png',box,'从原图重做为 4 倍分辨率，恢复细节；原屏幕大小、26% 视差和底缘渐隐保持。')
for i,(name,box) in enumerate([
 ('左上角巨石',(0,0,850,590)),('右上角巨石',(2030,0,2752,590)),
 ('左下角巨石',(0,570,1170,1536)),('右下角巨石与枯木',(1670,700,2752,1536))]):
    add(f'D{i+1:02}',name,'两版共用 · 近景边框',old['foreground'],i,'foreground_'+str(i),
        'front_view1.png',box,'使用原图尺寸和原色，仅去除背景；保持已确认的半尺寸屏幕占比和贴角位置。')
names=['弧形残墙','斜坡断墙','石块','断裂长石柱','砖石残墙']
for i,item in enumerate(current['props']):
    source=ROOT/'artifacts/previews/edge_repair_20261013/originals'/(item['id']+'_historical_128.png')
    add(f'P{i+1:02}',names[i],'当前正式版 · 大摆件',current['props'],i,'production_prop_'+str(i),source,
        note='当前正式入口自然生成；原始高清图未留存，源图列展示可追溯的历史 128×128 像素源。')
for i,title in enumerate(['单块砖','堆叠砖','碎砖片','散落小石','高碎石堆','低碎石堆','扁平石片']):
    source=ROOT/'artifacts/analysis/obstacle_revision_v02_20261013/sources'/(current['rubble'][i]['id']+'_historical_128.png')
    add(f'Q{i+1:02}',title,'当前正式版 · 地面碎石',current['rubble'],i,'production_rubble_'+str(i),
        source,note='已简化为少量大色块并重做外缘；原 alpha、尺寸和石块分组保持。右列为找回的历史 128px 像素源，并非高清原画。')

def checker(size):
    im=Image.new('RGB',size,'#282d32');d=ImageDraw.Draw(im)
    for y in range(0,size[1],12):
        for x in range(0,size[0],12):
            if (x//12+y//12)%2:d.rectangle((x,y,x+11,y+11),fill='#33393f')
    return im

def place(canvas,path,box,pixel=True):
    im=Image.open(path).convert('RGBA');x,y,w,h=box
    factor=min(w/im.width,h/im.height)
    if pixel and factor>=1:factor=max(1,math.floor(factor))
    size=(max(1,round(im.width*factor)),max(1,round(im.height*factor)))
    im=im.resize(size,NEAR if pixel else Image.Resampling.LANCZOS)
    canvas.paste(im,(x+(w-size[0])//2,y+(h-size[1])//2),im)
    return factor

for row in rows:
    card=Image.new('RGB',(1120,340),'#151b22');d=ImageDraw.Draw(card)
    d.text((18,12),row['code']+'  '+row['title'],font=HEAD,fill='#f0e6c7')
    d.text((600,20),row['group']+' · 装饰／无碰撞',font=SMALL,fill='#a6b5c3')
    for x,w in [(18,390),(426,248),(692,410)]:card.paste(checker((w,208)),(x,90))
    d.text((18,60),'实机场景截取（点击可看完整画面）',font=SMALL,fill='#eeeeee')
    d.text((426,60),'实际加载 PNG · 最近邻',font=SMALL,fill='#eeeeee')
    source_label='历史像素源 128×128（非高清原画）' if row['code'].startswith(('P','Q')) else '原始素材表局部／可追溯源'
    d.text((692,60),source_label,font=SMALL,fill='#eeeeee')
    if row.get('runtime_crop'):
        factor=place(card,OUT/row['runtime_crop'],(18,90,390,208))
        d.text((22,276),f'截图 ×{factor:g}',font=SMALL,fill='#ffffff',stroke_width=1,stroke_fill='#000000')
    else:d.text((48,164),'未自然生成，无实机截图',font=FONT,fill='#c0c8d0')
    place(card,OUT/row['texture'],(432,96,236,180))
    d.text((432,278),' × '.join(map(str,row['texture_size']))+' px',font=SMALL,fill='#ffffff')
    if row.get('source_crop'):place(card,OUT/row['source_crop'],(698,96,398,196),False)
    else:d.text((745,167),'高清源图未留存／未找到',font=FONT,fill='#c0c8d0')
    d.text((18,312),row['id'],font=SMALL,fill='#9dafba')
    path=OUT/'cards'/(row['code']+'.png');card.save(path);row['card']='cards/'+path.name

groups={}
for row in rows:groups.setdefault(row['group'],[]).append(row)
sheet_files=[]
for gi,(group,items) in enumerate(groups.items()):
    for page in range(0,len(items),3):
        batch=items[page:page+3]
        im=Image.new('RGB',(1120,70+len(batch)*344),'#0e141b');d=ImageDraw.Draw(im)
        d.text((18,18),group+'  '+str(page//3+1),font=HEAD,fill='#e7dec5')
        for j,row in enumerate(batch):im.paste(Image.open(OUT/row['card']),(0,70+j*344))
        name=f'sheets/group_{gi+1}_{page//3+1}.png';im.save(OUT/name);sheet_files.append(name)

reference=Path('C:/Users/mi/AppData/Local/Temp/codex-clipboard-40565b2a-3519-40ae-986e-5da2e66560d9.png')
freeze(reference,'sources','user_attachment.png')
intro='A01、A05 保留已确认的描线结果。B、C 从源图重做为 4 倍分辨率；D 改用原图尺寸与原色透明裁片；Q 简化大色块并描线。P01–P05 的原图、处理图与正式资源已清理。原编号不复用；所有在用项都有实机截图。'
method='实机图来自 Godot GPU 视口：通过角色选择进入正式战斗，暂停刷怪，再把相机移到确定性自然生成位置。附件方案只在本次审阅进程中切回仍保留的旧背景脚本及配置，沿用当前 UI／贴角位置；未改写正式入口或素材。截图未补画、提亮或更换纹理；局部只做裁剪和最近邻放大。透明 PNG 的棋盘底仅用于本页展示。'
parts=['<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>战斗场景障碍物清单</title>',
 '<style>body{margin:0;background:#10161c;color:#dee5ed;font:16px/1.7 system-ui,"Microsoft YaHei"}main{max-width:1120px;margin:auto;padding:24px}h1{color:#f0e6c7}nav{position:sticky;top:0;background:#1c2531;padding:10px;z-index:5}a{color:#a7d3ee;margin-right:14px}article{margin:24px 0;background:#1c2531;padding-bottom:18px;border-radius:8px;overflow:hidden}article>img{display:block;width:100%;cursor:zoom-in}article p{padding:0 18px}code{overflow-wrap:anywhere;font-size:13px}.overview{display:grid;grid-template-columns:1fr 1fr;gap:12px}.overview img{width:100%}small{color:#b2bfc9}dialog{max-width:96vw;max-height:95vh;background:#18212c;color:white;border:1px solid #536273}dialog img{max-width:90vw;max-height:82vh;object-fit:contain}button{cursor:pointer;padding:8px 20px;background:#385366;color:white;border:0}h2{scroll-margin-top:70px}</style><main>',
 '<h1>战斗场景障碍物与装饰清单</h1><p>'+intro+'</p><p>'+method+'</p>',
 '<p><b>A02、A03、A04、A06、A07 及 P01–P05 已删除，不再展示旧图。</b> Q 来自当前正式草地版，其余来自附件方案或共用层，均为装饰、无碰撞和破坏逻辑。</p>',
 '<div class="overview"><div>用户附件<img onclick="show(this.src)" src="sources/user_attachment.png"></div><div>当前正式入口实机<img onclick="show(this.src)" src="runtime/production_overview.png"></div></div>',
 '<nav>'+''.join(f'<a href="#g{i}">{html.escape(g)}</a>' for i,g in enumerate(groups))+'</nav>']
for i,(group,items) in enumerate(groups.items()):
    parts.append(f'<h2 id="g{i}">{group}（{len(items)} 项）</h2>')
    for row in items:
        parts.append(f'<article id="{row["code"]}"><img src="{row["card"]}" onclick="show(this.src)"><p>{html.escape(row["note"])}</p><p>')
        for key,label in [('runtime_full','实机完整截图'),('texture','实际 PNG 原文件'),('source','原始素材完整图')]:
            if row.get(key):parts.append(f'<a href="{row[key]}" target="_blank">{label}</a>')
        parts.append('</p><p><small>正式路径</small><br><code>'+html.escape(row['texture_path'])+'</code></p>')
        if row.get('source_path'):parts.append('<p><small>来源</small><br><code>'+html.escape(row['source_path'])+'</code></p>')
        parts.append('</article>')
parts.append('<p>原始尺寸、文件哈希、实机位置与裁剪框记录于 <a href="catalog.json">catalog.json</a>。</p><dialog id="viewer"><button onclick="this.parentElement.close()">关闭</button><br><img id="large"></dialog><script>function show(src){document.getElementById("large").src=src;document.getElementById("viewer").showModal()}</script></main></html>')
(OUT/'index.html').write_text('\n'.join(parts),encoding='utf-8')
(OUT/'catalog.json').write_text(json.dumps({'intro':intro,'method':method,'items':rows,'sheets':sheet_files},ensure_ascii=False,indent=2),encoding='utf-8')
md=['# 战斗场景障碍物审阅清单','',intro,'',method,'','| 编号 | 名称 | 使用范围 | 实机完整图 | 加载 PNG | 原始来源 |','| --- | --- | --- | --- | --- | --- |']
def link(label,path):return f'[{label}](<{(OUT/path).as_posix()}>)' if path else '无自然摆放截图／源图未找到'
for r in rows:md.append('| '+' | '.join([r['code'],r['title'],r['group'],link('实机',r.get('runtime_full')),link('PNG',r['texture']),link('原始图',r.get('source'))])+' |')
md+=['','A02、A03、A04、A06、A07 已清理；其余在用项均有对应实机截图。所有列出项均无碰撞、不可破坏。','',link('完整图文审阅页','index.html')]
(OUT/'inventory.md').write_text('\n'.join(md)+'\n',encoding='utf-8')
print(json.dumps({'items':len(rows),'with_runtime':sum(bool(r['shot']) for r in rows),'groups':{g:len(v) for g,v in groups.items()}},ensure_ascii=True))
