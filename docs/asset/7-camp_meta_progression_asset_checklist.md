# 局外营地与成长模块素材 Checklist

本文档用于记录“局外营地与成长模块”在设计阶段需要准备的图片素材、提示词、目标路径与当前状态。当前阶段只要求满足 MVP：营地能显示、建筑能区分废墟与正式形态、界面能识别建筑入口。

## 1. 统一美术要求

| 项目 | 约定 |
|---|---|
| 画风 | 清新、像素风、像素精度中高、氛围偏黄昏/夜晚但不脏乱 |
| 场景 | 森林 + 篝火 + 河流，整体安静、温和、略带奇幻感 |
| 场景组织 | 营地场景采用分层素材拼装，不要求单张底图 |
| 背景 | 需要透明度或可叠加到场景图层，便于 Godot 组合 |
| 格式 | PNG，优先透明背景 |
| 命名 | 全部使用 snake_case，小写英文 |

## 2. 必需素材

> 注：`camp_armory_workshop`、`camp_relic_archive` 等初始自带建筑不需要废墟图，只保留正式建筑素材。

| 状态 | 素材名 | 文件名 | 最终路径 | 建议尺寸 | 格式 | 内容说明 | 中文提示词 |
|---|---|---|---|---|---|---|---|
| 未生成 | 大草地地表 | `camp_ground_grass.png` | `assets/sprites/camp/backgrounds/camp_ground_grass.png` | 1920x1080 或可平铺 | PNG | 营地主地表草地 | 生成一张像素风草地地表素材，颜色清新、干净、偏自然绿，适合与河流、树木、石头、花草叠加拼成营地场景。不要脏乱、不要噪点、不要复杂背景，PNG，可平铺或可大面积铺底。 |
| 未生成 | 河流地表 | `camp_river.png` | `assets/sprites/camp/backgrounds/camp_river.png` | 1920x1080 或可平铺 | PNG | 营地河流素材 | 生成一张像素风河流素材，水体清澈、颜色柔和，适合拼接在营地场景中，带一点黄昏或夜晚氛围，但不要脏乱、不要噪点、不要恐怖感，PNG，可平铺或可拼接。 |
| 未生成 | 树木素材 | `camp_tree_01.png` | `assets/sprites/camp/props/camp_tree_01.png` | 128x256 或 256x256 | PNG | 营地树木装饰 | 生成一棵像素风森林树木素材，造型简单、清新、轮廓清楚，适合摆在营地场景边缘，PNG，透明背景。 |
| 未生成 | 石头素材 | `camp_rock_01.png` | `assets/sprites/camp/props/camp_rock_01.png` | 64x64 或 128x128 | PNG | 营地石头装饰 | 生成一块像素风石头素材，造型简单、干净、轮廓清楚，适合散布在营地草地上，PNG，透明背景。 |
| 未生成 | 花草素材 | `camp_flower_01.png` | `assets/sprites/camp/props/camp_flower_01.png` | 64x64 或 128x128 | PNG | 营地花草装饰 | 生成一组像素风花草素材，颜色清新、自然、适合铺在草地上作为装饰，PNG，透明背景。 |
| 未生成 | 篝火素材 | `camp_campfire.png` | `assets/sprites/camp/props/camp_campfire.png` | 128x128 或 256x256 | PNG | 营地核心篝火 | 生成一组像素风篝火素材，火焰温暖、明亮但不过曝，适合营地中心点缀，PNG，透明背景。 |
| 未生成 | 军械工坊建筑 | `camp_armory_workshop.png` | `assets/sprites/camp/buildings/unlocked/camp_armory_workshop.png` | 256x256 | PNG | 军械工坊正式建筑外观 | 生成一张像素风建筑图，主题是“军械工坊”，小型工匠建筑、木质与金属结合、轮廓清楚、结构简单、清新、适合森林营地。不要脏乱、不要噪点、不要恐怖元素，PNG，透明背景。 |
| 未生成 | 遗物档案馆建筑 | `camp_relic_archive.png` | `assets/sprites/camp/buildings/unlocked/camp_relic_archive.png` | 256x256 | PNG | 遗物档案馆正式建筑外观 | 生成一张像素风建筑图，主题是“遗物档案馆”，小型古旧档案馆气质，干净、清新、带一点神秘感但不阴森，适合森林营地，PNG，透明背景。 |
| 未生成 | 利刃演武场建筑 | `camp_blade_arena.png` | `assets/sprites/camp/buildings/unlocked/camp_blade_arena.png` | 256x256 | PNG | 利刃演武场正式建筑外观 | 生成一张像素风训练场建筑图，主题是“利刃演武场”，小型近战训练设施，木质木桩、石台和简化兵器架，清新、像素精度中高，PNG，透明背景。 |
| 未生成 | 远星射靶台建筑 | `camp_farstar_range.png` | `assets/sprites/camp/buildings/unlocked/camp_farstar_range.png` | 256x256 | PNG | 远星射靶台正式建筑外观 | 生成一张像素风建筑图，主题是“远星射靶台”，小型高台和靶场设施，清新、简洁、适合森林营地，PNG，透明背景。 |
| 未生成 | 眷族培育栏建筑 | `camp_kin_nursery.png` | `assets/sprites/camp/buildings/unlocked/camp_kin_nursery.png` | 256x256 | PNG | 眷族培育栏正式建筑外观 | 生成一张像素风建筑图，主题是“眷族培育栏”，简化的生物培养设施，带轻微机械感但不恐怖，适合清新森林营地，PNG，透明背景。 |
| 未生成 | 畸变研究所建筑 | `camp_mutation_laboratory.png` | `assets/sprites/camp/buildings/unlocked/camp_mutation_laboratory.png` | 256x256 | PNG | 畸变研究所正式建筑外观 | 生成一张像素风建筑图，主题是“畸变研究所”，简洁实验建筑，轻微克系氛围但不恐怖，清新、像素精度中高，PNG，透明背景。 |
| 未生成 | 穹顶庇护所建筑 | `camp_dome_shelter.png` | `assets/sprites/camp/buildings/unlocked/camp_dome_shelter.png` | 256x256 | PNG | 穹顶庇护所正式建筑外观 | 生成一张像素风建筑图，主题是“穹顶庇护所”，小型圆顶庇护建筑，明亮、清新、适合森林营地，PNG，透明背景。 |
| 未生成 | 议事大厅建筑 | `camp_council_hall.png` | `assets/sprites/camp/buildings/unlocked/camp_council_hall.png` | 256x256 | PNG | 议事大厅正式建筑外观 | 生成一张像素风建筑图，主题是“议事大厅”，小型公共建筑，清新、安静、适合森林营地，PNG，透明背景。 |

## 3. 可选素材

| 状态 | 素材名 | 文件名 | 最终路径 | 建议尺寸 | 格式 | 内容说明 | 中文提示词 |
|---|---|---|---|---|---|---|---|
| 可暂空 | 营地 UI 图标 | `icon_camp.png` | `assets/ui/icons/camp/icon_camp.png` | 128x128 | PNG | 营地入口图标 | 生成一个像素风营地图标，主题是“营地 / 篝火 / 小屋”，清新、简洁、透明背景，适合作为 UI 入口按钮。 |
| 可暂空 | 建筑升级图标 | `icon_building_upgrade.png` | `assets/ui/icons/camp/icon_building_upgrade.png` | 128x128 | PNG | 建筑升级提示图标 | 生成一个像素风升级图标，主题是“建筑升级”，可用星光、齿轮或向上箭头表示，清新、简洁、透明背景。 |

## 4. Godot 导入约定

1. 场景底图由多层素材拼装，不依赖单张大底图。
2. 每个建筑素材保持独立 PNG，便于单独替换。
3. 未解锁与已解锁素材文件名必须一一对应，方便脚本按 ID 拼接路径。
4. 初始自带建筑只保留正式建筑素材，不需要废墟图。
5. 后续如果你再改建筑，只需要替换对应 PNG，不需要改这份清单结构。