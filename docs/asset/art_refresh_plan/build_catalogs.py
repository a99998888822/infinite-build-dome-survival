"""Build documentation and reference copies; never writes production assets."""
from pathlib import Path
from collections import defaultdict
import hashlib
import json
import shutil
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]

REFS = [
    ('R01_forest_shapes.jpg', 'scene/u=4143898148,827992823&fm=253&app=138&f=JPEG.jpg', '环境大块面、岩石切面、空间层次'),
    ('R02_darkest_ink.webp', 'darkest_dungeon/u=439607916,3606041519&fm=253&fmt=auto&app=120&f=JPEG.webp', '轮廓、硬阴影、概括材质；减少排线'),
    ('R03_armor_shapes.webp', 'darkest_dungeon/u=2637947151,2706126914&fm=253&fmt=auto&app=120&f=JPEG.webp', '盔甲块面与厚重轮廓；不复制武器与徽记'),
    ('R04_creature_shapes.webp', 'cuthulu/u=1044588798,3208899356&fm=253&fmt=auto&app=120&f=JPEG.webp', '怪物有机剪影与非对称；降低饱和度'),
    ('R05_face_planes.webp', 'cuthulu/u=1758180758,1661537932&fm=253&fmt=auto&app=138&f=JPEG.webp', '人脸概括明暗；不复制人物身份'),
    ('R06_marsh_mood.jpg', 'scene/zzLi-fychtth0163612.jpg', '湿地、雾层与旧建筑氛围；不复制写实纹理'),
]

STYLE = ('请生成一张用于暗色幻想生存游戏的高清物品原画，1024×1024，单件物品居中，完整轮廓，四边适当留白。'
         '附件1只参考轮廓、硬边阴影和材质概括；附件2只参考该物件的身份、主要结构和朝向，不沿用其旧画风。'
         '统一为清楚的大色块、深色轮廓、每种材质约3档明暗、少量形状明确的高光，光从左上方照射。'
         '以青灰、炭黑、旧金、暗棕和骨白为基础，功能点缀色克制。'
         '不要像素化、马赛克、景深、柔焦、复杂场景、密集排线、织物噪点、密集金属反光；不绘制名称、数值、水印或商标。'
         '优先真实透明背景；若无法输出真实透明，使用纯白背景且不画投影，不绘制棋盘格。')

SUBJECTS = {
 'weapon_void_blade': '一张木质弓与搭在弓上的箭，弓身弯曲轮廓明确，弓弦加粗为可读线条，箭尖醒目；不要画成匕首。',
 'weapon_plasma_cannon': '短身双导轨电浆炮，深色金属外壳，两条粗导轨，青蓝能量芯；结构集中，不加入复杂机械小零件。',
 'weapon_iron_grenade_cannon': '铸铁榴弹炮，粗短炮管、木柄、旧黄铜箍，突出大口径圆筒，不画成现代枪械。',
 'weapon_kunyu_ritual_tome': '厚重的坤舆秘仪书，暗青封皮、厚书页和一个简洁几何封印，保留附件旧书上的菱形/方形构成，符号用大形状而非小文字。',
 'weapon_rentier_purse': '鼓起的旧皮钱袋，束口、圆腹与三枚露出的旧金币，避免密集缝线。',
 'weapon_nightwatch_spear': '斜向摆放的守夜长枪，浅银叶形枪尖、深色枪杆、旧金接箍；为小图标适度加粗杆身，尖端与握持部位可分辨。',
 'weapon_meteor_flail': '流星摆锤，短握柄、少量粗链节与沉重圆形锤头，以清楚的折线构图连接三部分；不要画成一团细链。',
 'relic_piggy_bank': '陶制猪形存钱罐，圆腹、小耳朵、猪鼻和背部投币口清晰，少量旧金细节；采用灰陶/暗赭色与深色轮廓，不做粉红表情贴纸。',
 'relic_finance_manager': '哥布林理财经理的小型半身徽像，尖耳、窄脸、深色西装与一份账簿；简化五官并保留完整头部轮廓。',
 'relic_dividend_check': '旧纸支票，卷起一角、几条宽横线与一枚金色印章，不写可读文字或金额。',
 'relic_fixed_deposit_certificate': '带蓝青封印的存单，一张坚挺浅色纸页和清楚的边角，避免与金色支票同剪影。',
 'relic_flyer_ad': '一张破角的旧广告纸，以一个大红色记号为视觉中心，无实际文字。',
 'relic_quant_trading': '旧黄铜框的小算盘，三行粗算珠，以不同珠位表达交易；不画现代电脑屏幕。',
 'relic_hostile_takeover': '两份交叠的契约，被一只简化暗紫手掌压住，用交叠和抓握表达强占。',
 'relic_merger_reorg': '两本薄账册由一条旧金搭扣合并成一册，双册轮廓与扣件明确。',
 'relic_medical_cutback': '带红色医疗十字与断裂封条的纸质方案，红十字是主要识别点，不写正文。',
 'relic_welfare_cutback': '带划断礼盒图案和暗红封蜡的福利方案，保持礼盒轮廓可读。',
 'relic_annual_leave_cutback': '撕去一角的日历纸，两个顶端挂环和少量大日期格，不绘制数字。',
 'relic_salary_adjustment': '一份工资契约和一枚被扣走的硬币，宽纸页和红色封蜡，避免密集文字。',
 'relic_divine_fusion': '一只古旧金杯中融合一枚大菱形晶石，以杯口和晶石两种轮廓表达融合。',
 'relic_goblin_central_bank_printer': '小型旧式印钞压印机，绿色横梁、双立柱和一张露出的纸币，避免细齿轮。',
 'relic_bankruptcy_reorg': '一道破裂的金属环被旧金箍重新接合，破口与连接件可见。',
 'relic_frenzied_dividend': '打开的钱封和跳出的两枚金币，金钱形状清楚，红封蜡形成唯一暖色强调。',
 'relic_gift_mark': '一枚旧金与暗紫构成的赐福纹章，中央一个简洁眼形符号，减少环绕小符文。',
 'relic_lucid_vow': '细长的浅青水滴宝石吊坠，清楚的顶部挂环与深色金属包边。',
 'scroll_water': '一个单圈回卷水浪，内部留出清楚空隙，蓝青主体和少量骨白浪尖。',
 'scroll_light_sword': '一柄竖直的宽刃光剑符号，直刃和横护手清楚，骨白主体与少量旧金。',
 'scroll_black_hole': '暗紫引力环，中心大面积空洞，环外只留两处不对称弯曲拉伸形状。',
 'scroll_fire': '一簇向上尖收的火焰，三层大色块，深橙、琥珀、浅金，外轮廓与爆炸不同。',
 'scroll_explosion': '一枚向多个方向展开的爆裂星形，中央亮块，放射尖角，避免与竖向火焰混淆。',
 'scroll_lightning': '粗折线闪电，青白主体与蓝色背影，折角清楚，不画细电网。',
 'scroll_split': '一束分成三条的叉形能量路径，三个分支之间留出明显空隙，以浅紫点缀。',
 'scroll_pierce': '一支粗箭穿过两片相隔的薄甲片，突出直线贯穿关系，用旧金与铁灰。',
 'scroll_ice': '一枚六角冰晶，六条短粗分支，浅青与骨白，避免复杂雪花细枝。',
 'scroll_wind': '两道同向弯曲风刃，青灰与浅青，留出间隔，不画成水浪或羽毛。',
}

def link(path):
    return Path(path).as_posix()

def main():
    refs_dir = OUT / 'references'
    refs_dir.mkdir(exist_ok=True)
    ref_data=[]
    for name,source,use in REFS:
        src=ROOT/'artifacts/reference'/source
        dst=refs_dir/name
        shutil.copyfile(src,dst)
        ref_data.append(dict(id=name[:3],file='references/'+name,source=src.relative_to(ROOT).as_posix(),use=use,
                             sha256=hashlib.sha256(src.read_bytes()).hexdigest()))
    (OUT/'reference_manifest.json').write_text(json.dumps(ref_data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    bank_path=ROOT/'assets/ui/finance/goblin_banker_states.png'
    with Image.open(bank_path) as bank:
        bank.crop((0,0,128,128)).save(refs_dir/'current_goblin_neutral.png')
    (OUT/'identity_reference_manifest.json').write_text(json.dumps([
        dict(file='references/current_goblin_neutral.png',source=bank_path.relative_to(ROOT).as_posix(),
             source_sha256=hashlib.sha256(bank_path.read_bytes()).hexdigest(),crop=[0,0,128,128],
             method='Original current frame cropped without redrawing or scaling; identity reference only')
    ],ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    canvas=Image.new('RGB',(1200,650),'#22272b')
    draw=ImageDraw.Draw(canvas)
    font=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',15)
    for i,(name,_,_) in enumerate(REFS):
        im=Image.open(refs_dir/name).convert('RGB'); im.thumbnail((384,286))
        x=i%3*400;y=i//3*325
        canvas.paste(im,(x+(400-im.width)//2,y+5))
        draw.text((x+8,y+297),name,font=font,fill='white')
    canvas.save(refs_dir/'reference_overview.jpg',quality=92)

    icon_manifest=[]
    for table,filename,label,size in [('weapons','03a_weapon_prompts.md','武器',32),('relics','03b_relic_prompts.md','遗物',32),('augmentations','03c_augmentation_prompts.md','附魔',32)]:
        records=json.loads((ROOT/f'data_config/{table}.json').read_text(encoding='utf-8'))
        groups=defaultdict(list)
        for item in records: groups[item['icon']].append(item)
        lines=[f'# {label}：逐项豆包提示词', '', '每个条目都是一次独立生成。上传附件1：本包 `references/R02_darkest_ink.webp`；上传附件2：该条目列出的旧图。附件2只约束物件身份，不约束旧画风。首批通过后，追加用户确认的新样板。', '',
               '高清文件按条目文件名保存。生成后先由用户审阅，再执行 [Picxel 步骤](05_picxel_commands.md)。本文件不表示这些资产已获准替换。', '']
        for index,(icon,items) in enumerate(groups.items()):
            item=items[0]; key=Path(icon).stem; names=' / '.join(x['display_name'] for x in items)
            subject=SUBJECTS.get(item['id'],f'主题是“{item["display_name"]}”。保留附件2物件的大轮廓、主材质与最重要的两处识别结构，归并内部小纹理；主题为抽象概念时，沿用附件2已经使用的实体载体，不画一整张叙事场景。')
            tail=('这是武器缩略图，首先保证32×32显示可读；主体最长边约占画布80%～88%，细杆、弓弦、链节适度加粗。64×64详情版以后从同一高清稿独立转换。' if table=='weapons' else
                  '这是32×32的遗物小图标，主体最长边约占画布80%～88%，避免细小文字和仅依赖颜色的区别。' if table=='relics' else
                  '这是32×32的附魔符号，不画纸卷或统一方框。主体轮廓应能与其他元素符号区分，主形占画布约80%。')
            old=ROOT/icon.removeprefix('res://')
            rel='../../../'+old.relative_to(ROOT).as_posix()
            lines += [f'## {names} · `{key}`','',f'- 高清文件：`{key}.png`（1024×1024）',
                      f'- 旧造型参考：[打开旧图]({rel})；配置 ID：'+', '.join('`'+x['id']+'`' for x in items),
                      f'- Picxel 首轮：`--sizes {size}`；计划 UI 图标档位：32 / 64 整数倍。','', '> '+STYLE+subject+tail,'']
            if len(items)>1: lines += ['注意：这些配置当前共用一张图。此次保留共用关系；如需区分，需另建图标并修改配置，不能假称已经有两张独立素材。','']
            icon_manifest.append(dict(key=key,names=[x['display_name'] for x in items],config_ids=[x['id'] for x in items],table=table,batch=f'{table}_{index//20+1:02d}',
                                      original_path=icon,original_size=list(Image.open(old).size),highres_name=key+'.png',highres_size=[1024,1024],
                                      draft_pixel_size=[32,32],detail_pixel_size=[64,64] if table=='weapons' else None,prompt_file=filename,
                                      status='planned',integration='32px replacement; UI slot normalization required' if table!='relics' else 'retain 32px canvas; UI slot normalization required'))
        (OUT/filename).write_text('\n'.join(lines),encoding='utf-8')
    (OUT/'icon_manifest.json').write_text(json.dumps(icon_manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

    scenery=json.loads((ROOT/'data_config/battle_scenery.json').read_text(encoding='utf-8'))
    lines=['# 湿地场景件：30 个独立提示词','', '附件1：`references/R01_forest_shapes.jpg`；附件2：每个条目的当前贴图。只借鉴森林图的块面，不把当前湿地遗迹改成森林关卡。编号沿用现有环境安装器，实际导出时应核对当前 `SPECS` 顺序。','',
           '统一高清1024×1024；Picxel128×128；最终保留透明画布、测量新可见范围并更新 content_rect/hash，现有 world_extent 数值作为首轮物理尺度。','']
    for i,(key,item) in enumerate(scenery['assets'].items(),1):
        old=ROOT/item['texture'].removeprefix('res://')
        subject=Path(item.get('source_file',key)).stem
        if key.startswith('ruin_'):
            extra='一件独立旧石遗迹，保持附件2底面与立面的视角，青灰石材、较大接缝与少量暗苔，边缘破损用少量大缺口，完整基座，不带地面或投影。'
        elif key.startswith('fx_'):
            extra='一圈稀疏而连贯的椭圆水纹，只用两到三档青灰亮度，中心留空，线段粗细满足最终显示约52像素可读，不带水面背景和光晕。'
        else:
            extra='贴在湿地地表上的独立装饰，保持附件2的地面投影角度，图形沿地表展开，不做竖直摆拍；概括成少量石块、裂缝或苔藓组，避免细碎颗粒。'
        lines += [f'## {i:02d} · {subject} · `{key}`','',f'- 高清文件：`{key}.png`；旧参考：[打开](../../../{old.relative_to(ROOT).as_posix()})',
                  f'- 当前世界可见长边基准：`{item["world_extent"]}`；目标标准像素画布：128×128。','',
                  '> 生成一张1024×1024高清游戏场景件，主题为“'+subject+'”。附件1只参考大块面和环境色，附件2只参考主体结构与观察角度。'+extra+
                  '左上柔和定向光，但阴影边界清楚，主体明暗分组不超过四大档；深青灰、暗苔绿、少量骨白。优先真实透明背景，无法提供时使用均匀纯白背景且不画落地投影。不要文字、水印、马赛克、细密刻线或复杂环境。完整保留轮廓。','']
    (OUT/'04_scenery_prompts.md').write_text('\n'.join(lines),encoding='utf-8')

    coverage=[]
    for p in sorted((ROOT/'assets').rglob('*')):
        if p.suffix.lower() not in ('.png','.svg') or 'tobe_handled' in p.parts: continue
        rel=p.relative_to(ROOT).as_posix()
        if '/icons/weapons/' in rel: recipe='03a_weapon_prompts.md'; phase='P2'
        elif '/icons/relics/' in rel: recipe='03b_relic_prompts.md'; phase='P2'
        elif '/icons/augmentations/' in rel: recipe='03c_augmentation_prompts.md'; phase='P2'
        elif '/wetland/' in rel: recipe='04_scenery_prompts.md'; phase='P4'
        elif '/camp/' in rel: recipe='02_doubao_recipes.md#后续营地素材'; phase='P6'
        elif '/main_menu/' in rel: recipe='02_doubao_recipes.md#主界面'; phase='P5'
        elif '/player/' in rel or '/enemies/' in rel or '/icons/characters/' in rel: recipe='02_doubao_recipes.md#角色与怪物'; phase='P3'
        elif '/sprites/weapons/' in rel: recipe='02_doubao_recipes.md#战斗武器与特效'; phase='P6' if p.name=='weapon_kunyu_ritual_tome_animated.png' else 'P4'
        elif '/sprites/background/' in rel and 'icon-' not in rel: recipe='02_doubao_recipes.md#战斗地表与天幕'; phase='P4'
        else: recipe='02_doubao_recipes.md#ui组件与银行'; phase='P1'
        coverage.append(dict(path=rel,current_canvas=list(Image.open(p).size) if p.suffix=='.png' else None,recipe=recipe,phase=phase,
                             status='planned',sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
    (OUT/'asset_coverage.json').write_text(json.dumps(coverage,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(references=len(ref_data),unique_icons=len(icon_manifest),scenery=len(scenery['assets']),covered_assets=len(coverage)),ensure_ascii=True))

if __name__=='__main__': main()
