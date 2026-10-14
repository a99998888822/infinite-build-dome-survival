"""Package provenance, immutable old assets, repaired assets and real GPU captures."""
from pathlib import Path
import html
import io
import json
import math
import shutil
import subprocess

from PIL import Image, ImageDraw, ImageFont
import repair_sprite_edges as r

T=r.TASK
RUNTIME=T/'runtime_approved'
FONT=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',16)
SMALL=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',13)
NAMES={
 'ruin_brick_wall':'砖石残墙','ruin_broken_arch':'残缺石拱','ruin_broken_column':'断裂长石柱',
 'ruin_curved_wall':'弧形残墙','ruin_eroded_pillar':'侵蚀石柱','ruin_short_column':'短石柱',
 'ruin_sloped_wall':'斜坡断墙','ruin_square_pillar':'方形石柱','ruin_stone_block':'石块','ruin_twin_pillar_wall':'双柱残墙',
 'void_hunter':'初心者','capitalist':'资本家','grub':'蠕虫',
 'goblin_neutral':'哥布林 · 平静','goblin_downcast':'哥布林 · 失落','goblin_displeased':'哥布林 · 不悦',
 'goblin_smile':'哥布林 · 微笑','goblin_delighted':'哥布林 · 欣喜',
 'small_desk':'小窗口独立桌子','wide_desk':'宽屏柜台／桌沿',
 'bat_move':'蝙蝠 · 飞行','bat_attack':'蝙蝠 · 攻击','knight_idle':'钢甲骑士 · 待机',
 'knight_move':'钢甲骑士 · 移动','knight_windup':'钢甲骑士 · 蓄力','knight_dash':'钢甲骑士 · 冲刺',
 'knight_recover':'钢甲骑士 · 收招','wolf_move':'冥狼 · 移动','wolf_attack':'冥狼 · 喷焰','wolf_jump':'冥狼 · 扑跃'}
GROUPS={'stone':'石柱与石墙','goblin':'哥布林五表情','finance':'柜台与桌子','player':'两名玩家','enemy':'四类怪物'}


def archive(path, name):
    dest=T/'originals'/name
    dest.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(path,dest)
    return dest


def source_for(rec):
    key=rec['id'];category=rec['category'];crop=None
    if category=='stone':
        dest=T/'originals'/(key+'_historical_128.png')
        blob=subprocess.check_output(['git','show','f1f746e:'+rec['before']],cwd=r.ROOT)
        Image.open(io.BytesIO(blob)).verify();dest.write_bytes(blob)
        return dest,'历史像素源 128×128；高清原图未留存',None,'git:f1f746e:'+rec['before']
    if category=='goblin':
        path=r.ROOT/'artifacts/sources/goblin/gobline_face.png'
        dest=archive(path,'goblin_original_sheet.png')
        state=next((s for s in r.read(r.BEFORE/'assets/ui/finance/portraits/source_manifest.json')['batch_manifest']['states'] if s['name']==key),None)
        crop=state['crop'] if state else [0,0,768,930]
        return dest,'原始表情图（按表情裁取）',crop,str(path)
    if category=='player':
        folder='初心者' if key=='void_hunter' else '资本家'
        path=r.ROOT/f'artifacts/sources/character_frames/{folder}/{folder}_walk1.png'
        return archive(path,key+'_source.png'),'保留的角色原始输入；旧逐帧映射未留存',None,str(path)
    if key=='grub':path=r.ROOT/'artifacts/sources/enemies/xiaoguai_move/move-01.png'
    elif key.startswith('bat_'):path=r.ROOT/f'artifacts/sources/enemies/echo_bat/{key[4:]}/01.png'
    elif key.startswith('wolf_'):
        action={'move':'move','attack':'attack','jump':'jump'}[key[5:]]
        path=r.ROOT/f'artifacts/sources/enemies/underworld_wolf/{action}/01.png'
    elif key.startswith('knight_'):
        action=key[7:]
        manifest=r.read(r.BEFORE/'assets/sprites/enemies/iron_knight/art_source_manifest.json')
        frame=manifest['atlas_sources']['knight_'+action+'.png'][0]
        path=r.ROOT/f'artifacts/sources/enemies/iron_knight/{frame}.png'
    elif key=='wide_desk':
        path=r.ROOT/'artifacts/sources/finance/finance_table_ui_scroll_short.png'
        return archive(path,'finance_background_source.png'),'原始短卷轴场景图（柜台局部）',[0,730,940,1390],str(path)
    else:
        return None,'原图未留存；来源清单中的 finance_bank_desktop.png 已缺失',None,'artifacts/sources/index.json'
    return archive(path,key+'_source.png'),'原始动作输入（首帧）',None,str(path)


def runtime_for(rec, shots):
    key=rec['id'];shot='battle_1280';subject=None;box=None
    if rec['category']=='stone':
        shot='stone_'+key
        if shot not in shots:
            active={row['id'] for row in r.read(r.ROOT/'data_config/cavern_meadow_battlefield.json')['props']}
            assert key not in active, 'Missing production stone capture: '+key
            return None,None,'备用石材，当前战场配置未引用'
        subject=0
    elif rec['category']=='goblin':
        shot='goblin_'+str(r.STATES.index(key[7:]));box=(112,177,325,428)
    elif key=='wide_desk':shot='finance_1280';box=(0,389,437,651)
    elif key=='small_desk':shot='finance_960';box=(42,207,246,294)
    elif key in ['void_hunter','capitalist']:shot=key+'_walk_00';subject=0
    elif key=='grub':subject=1
    elif key=='bat_move':subject=2
    elif key=='knight_idle':subject=3
    elif key=='wolf_move':subject=4
    elif key.startswith('knight_'):shot=key+'_00';subject=0
    elif key=='bat_attack':shot='bat_attack_00';subject=0
    elif key=='wolf_attack':shot='wolf_breath_charge_00';subject=0
    elif key=='wolf_jump':shot='wolf_leap_charge_00';subject=0
    if subject is not None:
        rect=shots[shot]['subjects'][subject]['rect']
        x,y,w,h=rect;box=(math.floor(x)-6,math.floor(y)-6,math.ceil(x+w)+6,math.ceil(y+h)+6)
    return RUNTIME/(shot+'.png'),box,'正式游戏视口截图，固定姿态；未改色或补画'


def panel(image, label, missing='', hd=False):
    canvas=Image.new('RGB',(324,296),(36,41,47));d=ImageDraw.Draw(canvas)
    if image is None:
        for i,line in enumerate([missing[j:j+19] for j in range(0,len(missing),19)]):
            d.text((12,90+i*24),line,font=FONT,fill='#b3babf')
        return canvas
    im=image.convert('RGBA')
    if hd:
        im.thumbnail((306,248),Image.Resampling.LANCZOS);zoom='原图缩览'
    else:
        bbox=im.getbbox()
        if bbox is not None:im=im.crop(bbox)
        factor=min(306/im.width,248/im.height)
        factor=max(1,int(factor)) if factor>=1 else factor
        im=im.resize((max(1,round(im.width*factor)),max(1,round(im.height*factor))),Image.Resampling.NEAREST)
        zoom=f'最近邻 ×{factor:.2g}'
    canvas.paste(im,((324-im.width)//2,18+(248-im.height)//2),im)
    d.text((12,276),label+' · '+zoom,font=SMALL,fill='#b7c4cc')
    return canvas


def main():
    (T/'originals').mkdir(exist_ok=True);(T/'review').mkdir(exist_ok=True)
    records=[entry for entry in r.read(T/'repair_manifest.json')['records']
             if entry['category'] in r.APPROVED_CATEGORIES]
    shots={s['name']:s for s in r.read(RUNTIME/'capture_metadata.json')['shots']}
    cards=[];proofs={}
    for rec in records:
        key=rec['id'];name=NAMES[key]
        source,note,source_box,origin=source_for(rec)
        raw=Image.open(source).convert('RGBA') if source else None
        if raw and source_box:raw=raw.crop(source_box)
        old_path=r.BEFORE/rec['before'];new_path=r.AFTER/rec['after']
        old=Image.open(old_path).convert('RGBA');new=Image.open(new_path).convert('RGBA')
        if rec.get('frames',1)>1:
            n=rec.get('before_frame_size',old.height);old=old.crop((0,0,n,n))
            n=rec['frame_size'];new=new.crop((0,0,n,n))
        if key=='wide_desk':old=old.crop((0,730,940,1390));new=new.crop((0,730,940,1390))
        runtime,box,runtime_note=runtime_for(rec,shots)
        live=Image.open(runtime).crop(box) if runtime else None
        panels=[panel(raw,'原图',note,hd=rec['category']!='stone'),panel(old,'原正式素材'),panel(new,'修复后素材'),panel(live,'修复后实机',runtime_note)]
        row=Image.new('RGB',(1296,344),(24,29,36));draw=ImageDraw.Draw(row)
        draw.text((14,9),name,font=FONT,fill='#eef3f5')
        for i,p in enumerate(panels):
            p.save(T/'review'/f'{key}_{i}.png');row.paste(p,(324*i,38))
        row.save(T/'review'/f'{key}_four_stages.png')
        proofs.setdefault(rec['category'],[]).append(row)
        cards.append({'id':key,'name':name,'category':rec['category'],'source':source.relative_to(T).as_posix() if source else None,'source_note':note,
            'source_origin':origin,'source_sha256':r.sha(source) if source else None,'before':'before/'+rec['before'],'after':'after/'+rec['after'],
            'runtime':runtime.relative_to(T).as_posix() if runtime else None,'runtime_note':runtime_note,'frames':rec.get('frames',1),
            'before_size':Image.open(old_path).size,'after_size':Image.open(new_path).size,
            'frame_size':rec.get('frame_size',new.height),'before_frame_size':rec.get('before_frame_size',old.height)})
    for category,rows in proofs.items():
        for offset in range(0,len(rows),5):
            selected=rows[offset:offset+5];im=Image.new('RGB',(1296,38+344*len(selected)),(24,29,36));d=ImageDraw.Draw(im)
            for i,label in enumerate(['① 原图 / 可追溯源','② 原正式素材','③ 修复后素材','④ 修复后实机']):d.text((i*324+14,8),label,font=FONT,fill='#e2c89a')
            for i,row in enumerate(selected):im.paste(row,(0,38+i*344))
            im.save(T/'review'/f'{category}_{offset//5+1}.png')
    # Animated crops are actual successive GPU frames at a fixed world-space box.
    for key in ['void_hunter','capitalist']:
        samples=[s for s in shots.values() if s['name'].startswith(key+'_walk_')]
        rect=samples[0]['subjects'][0]['rect'];x,y,w,h=rect
        box=(round(x)-8,round(y)-8,round(x+w)+8,round(y+h)+8)
        frames=[Image.open(RUNTIME/(s['name']+'.png')).crop(box).resize((int(w+16)*4,int(h+16)*4),Image.Resampling.NEAREST) for s in samples]
        frames[0].save(T/'review'/(key+'_runtime.gif'),save_all=True,append_images=frames[1:],duration=round(1000/len(samples)),loop=0)
    r.write(T/'review/catalog.json',cards)
    build_html(cards)
    print('REVIEW_READY',len(cards),'groups',T/'index.html')


def build_html(cards):
    data=json.dumps(cards,ensure_ascii=False).replace('</',r'<\/')
    page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>轮廓修复 · 四阶段审阅</title><style>
*{box-sizing:border-box}body{margin:0;background:#11161c;color:#e6eaee;font:15px/1.65 system-ui,"Microsoft YaHei",sans-serif}main{max-width:1480px;margin:auto;padding:34px 26px}h1{font-size:28px;margin:0 0 8px}p{color:#b5c0c9;margin:8px 0}a{color:#8cd3c4}nav{position:sticky;top:0;z-index:2;background:#11161cf5;display:flex;gap:8px;padding:14px 0;flex-wrap:wrap}button,select{border:1px solid #3c4954;background:#202a34;color:#e9f0f3;padding:9px 15px;border-radius:7px;cursor:pointer}button.active{background:#24544f;border-color:#73b7a5}.note{border-left:3px solid #d2aa69;padding:10px 16px;background:#242321;margin:18px 0}.card{margin:20px 0 30px;border:1px solid #34404c;border-radius:10px;overflow:hidden}.title{padding:13px 17px;background:#1d2731;display:flex;justify-content:space-between;gap:16px;flex-wrap:wrap}.title b{font-size:18px}.cols{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:1px;background:#34404c}.cell{background:#182129;padding:12px;min-width:0}.cell h3{margin:0 0 8px;font-size:14px;color:#d9bf96}.cell img{width:100%;display:block;image-rendering:pixelated;background:#24292f}.cell p{font-size:12px;min-height:42px;overflow-wrap:anywhere}.footer{padding:10px 17px;background:#182129;color:#a7b5be;font-size:13px}.screens{display:grid;grid-template-columns:1fr 1fr;gap:16px}.screens img{width:100%;image-rendering:pixelated}canvas{width:100%;image-rendering:pixelated;background:#24292f}.strip{display:none;grid-template-columns:1fr 1fr;gap:12px;padding:12px;background:#202a34}.strip.open{display:grid}.controls{grid-column:1/-1}input{vertical-align:middle;width:240px}.small{font-size:12px}@media(max-width:850px){.cols{grid-template-columns:1fr 1fr}.screens{grid-template-columns:1fr}main{padding:22px 12px}}
</style><main><h1>轮廓修复 · 四阶段审阅</h1>
<p>原图 / 可追溯源 → 修复前正式素材 → 修复后素材 → 正式游戏实机。点击图片查看对应原文件；动画组可展开逐帧比较。</p>
<p>已采用：石柱石墙、哥布林、桌子柜台、两名玩家，共 19 组。四类怪物及动作保留原版，未采用的修复稿已清理。玩家使用修复后的 1:1 显示帧。</p>
<div class="note">来源说明：石材高清原图未留存，第一列展示从 Git f1f746e 找回的 128px 历史像素源；小窗口桌子的原图也未留存，已明确留空。角色原始输入已保留，但旧逐帧对应记录已清理。不会用修复前素材冒充高清原图。</div>
<div class="screens"><a href="runtime_approved/battle_1280.png"><img src="runtime_approved/battle_1280.png"><span>当前正式战斗场景 · 修复玩家与石材，原版怪物</span></a><a href="runtime_approved/finance_1280.png"><img src="runtime_approved/finance_1280.png"><span>当前正式理财界面 · 已采用修复素材</span></a></div>
<nav id="filters"></nav><div id="cards"></div>
<p>实机截图来自独立 Windows 桌面上的 Godot GPU 视口，展示采用选择后的当前效果；为便于比较，审阅场景固定姿态、暂停刷怪。图像未补画或改色，不作为帧率基准。完整原始输入保存在项目 artifacts/sources 中。</p>
<p><a href="review/void_hunter_runtime.gif">初心者实机动作</a> · <a href="review/capitalist_runtime.gif">资本家实机动作</a> · <a href="review/catalog.json">完整来源与文件目录</a> · <a href="pixel_validation.json">已采用素材像素检查</a> · <a href="approved_capture.json">后台捕获记录</a></p>
</main><script>const rows=DATA;const groups={all:'全部',stone:'石柱 / 石墙',goblin:'哥布林',finance:'桌子 / 柜台',player:'玩家'};
const esc=s=>String(s||'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function card(r){const links=[r.source,r.before,r.after,r.runtime];const labels=['① 原图 / 可追溯源','② 原正式素材','③ 修复后素材','④ 修复后实机'];const notes=[r.source_note,r.before_size.join(' × ')+' PNG；修复前字节备份',r.after_size.join(' × ')+' PNG；'+r.frames+' 帧',r.runtime_note];return `<article class="card" data-category="${r.category}"><div class="title"><b>${esc(r.name)}</b><span class="small">${esc(r.id)} ${r.frames>1?`<button onclick="frames('${r.id}',this)">逐帧比较 (${r.frames})</button>`:''}</span></div><div class="cols">${labels.map((label,i)=>`<div class="cell"><h3>${label}</h3>${links[i]?`<a href="${esc(links[i])}" target="_blank">`:''}<img loading="lazy" src="review/${r.id}_${i}.png" alt="${esc(r.name+' '+label)}">${links[i]?'</a>':''}<p>${esc(notes[i])}</p></div>`).join('')}</div><div class="strip" id="strip-${r.id}"></div><div class="footer"><a href="review/${r.id}_four_stages.png" target="_blank">下载本项四列对照 PNG</a>${r.source_sha256?' · 原图 SHA-256 '+r.source_sha256.slice(0,16):''}</div></article>`}
document.getElementById('cards').innerHTML=rows.map(card).join('');document.getElementById('filters').innerHTML=Object.entries(groups).map(([id,label])=>`<button class="${id==='all'?'active':''}" onclick="filter('${id}',this)">${label}</button>`).join('');
function filter(id,b){document.querySelectorAll('nav button').forEach(x=>x.classList.toggle('active',x===b));document.querySelectorAll('.card').forEach(x=>x.style.display=id==='all'||x.dataset.category===id?'':'none')}
function frames(id,b){const r=rows.find(x=>x.id===id),box=document.getElementById('strip-'+id);box.classList.toggle('open');if(box.dataset.ready)return;box.dataset.ready=1;box.innerHTML=`<div class="controls">动作帧 <input type="range" min="0" max="${r.frames-1}" value="0"><span>1 / ${r.frames}</span></div><div>原正式帧<canvas width="384" height="300"></canvas></div><div>修复后帧<canvas width="384" height="300"></canvas></div>`;const ims=[new Image(),new Image()];let loaded=0;function paint(){if(loaded<2)return;const f=+box.querySelector('input').value;box.querySelector('span').textContent=`${f+1} / ${r.frames}`;box.querySelectorAll('canvas').forEach((c,i)=>{const ctx=c.getContext('2d'),n=i?r.frame_size:r.before_frame_size,z=Math.max(1,Math.floor(280/n));ctx.imageSmoothingEnabled=false;ctx.fillStyle='#24292f';ctx.fillRect(0,0,c.width,c.height);ctx.drawImage(ims[i],f*n,0,n,n,(c.width-n*z)/2,(c.height-n*z)/2,n*z,n*z)})}ims.forEach((im,i)=>{im.onload=()=>{loaded++;paint()};im.src=i?r.after:r.before});box.querySelector('input').oninput=paint}
</script></html>'''
    (T/'index.html').write_text(page.replace('DATA',data),encoding='utf-8')


if __name__=='__main__':main()
