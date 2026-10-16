# 主战斗场景动效清单与受击反馈更新记录

**2026-10-16 武器视觉第二轮：战锤、长枪、手炮进一步放大。** 战锤本体和锤风放大 2.2 倍，地裂改成宽裂口和翻起的块状石板；长枪枪芒加厚至 2.2 倍并加长 12%；手炮使用赤铜炉灯的火焰质感，改成向前喷出并脱离枪口的短促喷焰。真实武器伤害回执保持一致，363 项相关检查通过，说明与对照见 [武器大色块动效](D:/project/useless/resources/infinite-build-dome-survival/docs/main/weapon_block_visuals_2026-10-16.md)。

**2026-10-16 武器视觉更新：七把武器已接入大色块像素动效。** 铸铁榴弹炮改为块状爆焰，坤舆秘仪书改为厚符印，异化触手增加紫色甩击带，裂地战锤增加跟随锤头的厚锤弧，守夜长枪增加尖楔枪芒，流星摆锤改为宽弧拖尾，巨型手持火炮改为粗厚枪口焰与块状命中爆点。说明与实机对照见 [武器大色块动效](D:/project/useless/resources/infinite-build-dome-survival/docs/main/weapon_block_visuals_2026-10-16.md)。

**2026-10-16 最新更新：通用反馈第二版。** 普通怪物受击通体闪白并大幅震动，小 Boss（钢甲骑士、幽焰冥狼）只震动；单体命中不震屏。三档震屏幅度从 2／6／14 降至 1／2／6 逻辑像素，每次卡肉统一为 0.05 秒。同一次攻击在固定圆心、半径 240 世界像素的小范围内累计不同受击怪物，达到 3、6、12、15、18……只时触发，12 只后每新增 3 只重复最高档；同瞬间跨过多个阈值只播放一次。连续 0.2 秒有效游戏时间没有新目标则清零，卡肉时间不计入。不同施放和远处群体分开统计，燃烧跳伤不累计震屏。已通过真实短刀、榴弹和战锤施放录制。参数、实现与验证记录见 [通用受击反馈设计](D:/project/useless/resources/infinite-build-dome-survival/docs/main/combat_general_feedback_2026-10-16.md)。

**以下移除记录和更早的清单均为历史快照。** 新版通用闪白、震动、局部震屏与卡肉取代旧分类反馈；普通命中不自动击退，旧轻击／重击／秘仪／持续伤害的接触装饰继续保持移除。

**2026-10-16 后续更新：七类怪物受击反馈已移除。** 普通伤害不再触发通用提亮、贴图抖动和短击退，也不再创建轻击、重击、秘仪、持续伤害的分级响应及其接触装饰。武器正式命中入口已改为直接结算伤害；旧 `take_damage_with_feedback` 仅保留兼容转发，不再产生反馈。删除了 `combat_feedback_r02.gd`，地面装饰脚本只保留战锤碎屑。

伤害、暴击数字、死亡淡出、武器本体特效、元素状态与反应、秘仪点名纹路／图标回弹／短音、战锤地裂与地面碎屑继续保留。风刃、震荡、移星冲击等显式技能控制，以及怪物接触玩家后的排斥行为保留；这次移除的是普通伤害附带的短击退。冥狼的贴图位置现在直接跟随当前动作帧与跳跃高度。旧抖动所消耗的一次随机采样仍保留，避免连带改变后续伤害与掉落随机序列。

移除验证：Godot 4.7.2 无界面编辑器检查及主场景 120 帧启动检查均退出 0，无脚本／编译错误；受击移除 53 项、冥狼姿态 126 项、霸体 61 项、控制属性 92 项，共 332 项回归通过。覆盖旧反馈开关的两种状态、重复命中、燃烧、嵌套伤害、子类减伤、随机序列、显式击退和保留效果。日志保存在 [本次验证目录](D:/project/useless/review-archives/remove-hit-feedback-20261016)。编辑器另有 Android build-tools 目录缺失提示。

**以下为同日移除前的梳理快照，供对照；其中七类受击反馈及相关缺口描述不再代表当前实现。**

2026-10-16。依据当前工作区的正式场景、脚本、配置及已接入资源整理，包含尚未提交的现有修改。本次为静态核对，没有重新录制实机画面、进行听感评测或性能测试。下列时间是代码默认值；装备属性、主动／自动施放路径与效果预算可能改变实际表现。

当前动效主要由武器动作、接触装饰、敌人受击、元素状态与反应、角色与敌人技能、拾取和 HUD、场景环境组成。已有局部受击抖动和暴击数字抖动，未发现生产战斗中的统一攻击震屏、命中顿帧或手柄震动系统。

**正式场景与核对范围**

- 主入口为 [game_root.tscn](D:/project/useless/resources/infinite-build-dome-survival/scenes/core/game_root.tscn)，战斗部分为 [battle_root.tscn](D:/project/useless/resources/infinite-build-dome-survival/scenes/battle/battle_root.tscn)。
- 当前背景接入 `CavernSunlightBackdrop`、`CavernPitHorizon` 和 `cavern_meadow_battlefield.json`，是带洞穴远景、草地和移动光照的版本。
- 特效宿主包括 `CombatRenderWorld`、`ParticleWorld`、`ParticleLightField`；不少独立图集和代码绘制效果不计入通用粒子池。
- 10 月 10 日分析中“草没有风摆”“武器栏没有就绪动效”等描述已不适用于当前版本。旧文档所述 CRT 氛围层未在当前正式场景和生产脚本中发现接入。

**1. 武器击中怪物时，共享的反馈有哪些**

| 层次 | 当前行为 | 参数与边界 |
| --- | --- | --- |
| 普通受击提亮 | 将怪物原色提亮，再恢复 | `modulate = (1.35, 1.35, 1.35)`，约 100 ms 恢复；不是把轮廓完全染成纯白的专用受击材质 |
| 普通身体抖动 | 怪物贴图随机倾斜，带回弹地恢复正向 | 初始角度 ±0.08 弧度，约 ±4.6°；160 ms 回正。只影响贴图旋转 |
| 普通命中击退 | 有攻击来向、允许受控时，怪物身体短暂后移并减速 | 初始速度 60 世界单位／秒，默认 60 ms；受抗控与免控规则约束。它与贴图抖动是两件事 |
| 轻击反馈 | 紧凑十字／短切口形亮点、3 个方向性碎点；目标快速偏移回弹 | 短刀接入 `light`；贴图偏移 2 世界单位，响应 120 ms，提亮衰减 50 ms，接触图形 140 ms |
| 重击反馈 | 棱角状冲击核心、亮核、5 个方向性碎点；目标更明显地偏移和摆动 | 战锤接入 `heavy`；贴图偏移 4 世界单位，响应 240 ms，提亮衰减 75 ms，接触图形 240 ms |
| 秘仪反馈 | 四个斜向符号向外展开，配合轻提亮 | 秘仪书接入 `ritual`；不设置方向性贴图位移，响应 160 ms，接触图形 220 ms；另有武器自己的命中纹路 |
| 持续伤害反馈 | 首次接触给橙色小爆点，连续命中只间歇提亮 | 炉灯接入 `sustain`；响应 80 ms，连续接触约每 280 ms 才允许一次强调。中断至少约 450 ms 后再次接触可重播接触装饰 |
| 死亡 | 通常缩小并淡出 | 默认 200 ms 内缩至原来的 82%；钢甲骑士有专用死亡入口，保留当前姿态淡出，不额外缩小 |

分级反馈默认开启，接触图形以 30 FPS 量化装饰运动。接触装饰上限 96 个，当前生成点是怪物根节点向上 10 世界单位，并非精确的武器与身体交点。

分级入口目前只覆盖短刀、战锤、秘仪书、炉灯等指定路径。弓箭、电浆、金币、榴弹、长枪、摆锤、触手和位移武器的其他原生命中仍走通用反馈；它们可以同时拥有各自的武器特效。燃烧跳伤也走通用入口。分级系统内部会保护尚未结束的重击，但通用入口会中断当前分级反馈，所以混装时的轻重表现还没有完全统一。

免控敌人保留受击确认，但抑制失衡式旋转和击退；分级轻重反馈也避免用明显贴图位移暗示其被打退。这里的 120／240 ms 是受击动画恢复时间，不是顿帧时间。

原核对入口：[敌人伤害与死亡](D:/project/useless/resources/infinite-build-dome-survival/scripts/enemies/enemy_controller.gd)、已删除的 `scripts/effects/combat_feedback_r02.gd`、[现仅保留地面碎屑的装饰脚本](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/combat_impact_r02.gd)、[武器公共命中入口](D:/project/useless/resources/infinite-build-dome-survival/scripts/weapons/directed_weapon_runtime.gd)。

**2. 14 把武器各自的动作与视觉**

| 武器 | 出手／运动 | 接触与收尾 |
| --- | --- | --- |
| 木质弓箭 | 定向木箭和稀疏短拖尾，多箭按配置展开 | 通用受击、击退、飘字及附魔；旧绿色命中飞溅由 `ENABLE_ENEMY_HIT_GREEN_PARTICLES = false` 关闭 |
| 电浆炮 | 蓝白球核与呼吸光晕，细电弧向地面放电，球下暗影及落点闪点；边缘有短命小电花 | 接触灼击与持续跳伤、通用受击。弹体另有接触减速／恢复速度机制，不是全局命中停顿 |
| 铸铁榴弹炮 | 抛物线飞行，弹体下方阴影，四点落地标记逐渐收拢 | 落地爆炸图集表现核心、烟尘和火星，爆炸视觉约 520 ms；分裂可产生子榴弹 |
| 坤舆秘仪书 | 跟随施法者的椭圆领域，星形符文呼吸，边界方块漂移；主动路径逐次点名 | 默认约 220 ms 首次点名，后续间隔 350 ms；目标命中纹路、`ritual` 反馈、专用短音和来源图标回弹同步，结束领域淡出 |
| 食利者钱袋 | 扇形金币，8 帧翻转循环，金色方块短尾 | 金币专用碰撞飞溅，加通用受击；分裂继续使用金币 |
| 赤铜炉灯 | 橙黄扇形连续火流，缓慢转向；分裂有较短侧喷流 | 持续接触采用 `sustain` 降频反馈，仍正常结算伤害；当前主动运行路径不显示旧自动路径的热量条 |
| 异化触手 | 紫色触手卷曲、展开、拍地、回收；多段动作图集 | 拍地后约 160 ms 的少量灰色碎屑；分裂侧枝短暂出现并淡出，目标仍是通用受击 |
| 裂地战锤 | 默认 560 ms 显现蓄势、60 ms 砸落、40 ms 接触姿态、60 ms 锤体淡出 | 地裂默认 5 节、间隔 100 ms 推进；首节点有 300 ms 定向地面碎屑，各主裂节点前 75 ms 短暂提亮，首节点更强；地裂约 1.25 秒内消退，敌人接入 `heavy` |
| 营地短刀 | 正反手交替挥斩，刀身与月牙刀光同步；默认 60 ms 蓄势、100 ms 挥斩、80 ms 收势 | `light` 接触反馈；多次攻击／分裂形成接续斩击，附魔影响刀光颜色 |
| 守夜长枪 | 后撤蓄势、伸出贯穿、回收；默认 100／120／160 ms；刺击路径和短粒点拖尾 | 通用受击；分裂可从命中位置射出长枪碎片 |
| 流星摆锤 | 铁链、锤头旋转、扇面拖影和小方块尾迹；130 ms 蓄势、370 ms 扫击、100 ms 收势 | 命中火星；附魔有附着亮点。外圈增伤已存在，但没有额外专属重击分类或镜头强调 |
| 突进短刃 | 玩家突进，跟随式拖影；初心者使用对应跳跃动作 | 抵达后快速青白圆斩，按地面投影显示，圆斩约 208 ms；命中走公共伤害路径 |
| 巨型手持火炮 | 定向枪口焰、散弹，玩家后滑／后跳，起点扬尘 | 弹丸命中图集，后坐移动与发射配合；没有枪击震屏 |
| 移星秘典 | 起点消失、落点出现、起点循环星印；瞬移后镜头缓动追上 | 落点冲击环约 417 ms，敌人受到冲击击退；手动施放可留下返回标记与返回图标，再次施放有返程图集。自动施放不保留返回机会 |

依据：[武器配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/weapons.json)、[弓箭／电浆](D:/project/useless/resources/infinite-build-dome-survival/scripts/weapons/projectile_instance.gd)、[电浆外观](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/plasma_ball_visual.gd)、[榴弹](D:/project/useless/resources/infinite-build-dome-survival/scripts/weapons/grenade_projectile.gd)、[金币](D:/project/useless/resources/infinite-build-dome-survival/scripts/weapons/coin_projectile.gd)、[秘仪](D:/project/useless/resources/infinite-build-dome-survival/scripts/weapons/ritual_domain.gd)、[炉灯](D:/project/useless/resources/infinite-build-dome-survival/scripts/weapons/copper_lamp.gd)、[触手](D:/project/useless/resources/infinite-build-dome-survival/scripts/weapons/mutant_tentacle.gd)、[战锤](D:/project/useless/resources/infinite-build-dome-survival/scripts/weapons/earth_hammer.gd)、[短刀](D:/project/useless/resources/infinite-build-dome-survival/scripts/weapons/camp_dagger.gd)、[长枪](D:/project/useless/resources/infinite-build-dome-survival/scripts/weapons/nightwatch_spear.gd)、[摆锤](D:/project/useless/resources/infinite-build-dome-survival/scripts/weapons/meteor_flail.gd)、[三种位移武器](D:/project/useless/resources/infinite-build-dome-survival/scripts/weapons/mobility_weapon_runtime.gd)。

**3. 附魔、状态与组合反应**

| 类别 | 当前画面 | 需要区分的层次 |
| --- | --- | --- |
| 火焰 | 火种、地面燃烧、敌人身上的动态火焰 | 首次附着、地场和持续状态分别表现；神圣火焰、暗焰使用不同火焰色板 |
| 震荡 | 白色方块粒子向外迸散，并将附近可受控敌人推开 | 内部沿用 `explosion` ID，但当前普通附魔走纯击退路径；与榴弹和雷火伤害爆炸不同，也不摇镜头 |
| 闪电链 | 目标之间的像素折线电弧、接触电花、地面弧光与局部辉光 | 跳跃连线说明传播方向；目标还可出现绕头旋转的小电粒点 |
| 落雷／电火花 | 黄色三层环绕预警、竖向落雷与落地点效果 | 默认等待 500 ms 后启动雷击；落地后预警再用 280 ms 淡出。密集时预警装饰密度受预算控制 |
| 结霜 | 地面雪花状晶体生长、冰屑起手、逐渐消退 | 敌人减速时有脚下霜纹，冻结时另有冰壳；当前结霜装饰有密度档位 |
| 水流 | 蓝白单圈水浪向外展开、泡沫与内侧淡纹 | 默认余波动画 850 ms；伤害和打湿在生成时同步结算，不能把扩散画面当作逐圈判伤 |
| 风刃 | 浅青白弧形刀风，沿路径移动、旋转与消退 | 当前外观由图集播放；可击退敌人、传播湿润并扩张火场／冰场 |
| 光辉剑 | 等待悬剑、落下、入地／碎解、少量碎光与地面短裂纹 | 地面标记与剑身分层，命中后可给目标附加光状态 |
| 黑洞 | 暗紫球体、前后环绕轨道、向内吸入线段、独立地面阴影，末段收拢 | 球体视觉与实际地面吸附中心分开；目标拉向中心是实际位移 |
| 状态图标 | 湿润水滴、光状态太阳形、暗状态眼形；减速霜纹与冻结冰壳 | 多数图标及冰壳是状态持续期间的静态标记，不应全部算作循环动画 |
| 蒸汽 | 灰白／淡青烟团膨起并上升 | 独立短反应提示，约 1.1 秒 |
| 冻结／解冻 | 冰晶碎片生成、散落与消失 | 独立共享图集；冻结提示约 620 ms，解冻提示约 720 ms |
| 传导 | 蓝白电花，附带“传导”反应浮字 | 接触电花与文字是两个独立入口，文字默认开启 |
| 湿润传播 | 从起点朝目标移动的细水带，终点小亮点 | 约 500 ms，直观表达传播对象 |
| 冰场扩展 | 冰晶前沿向外生长 | 对应风推动冰场扩大 |
| 雷火 | 暖黄爆炸粒子和“雷火”反应浮字 | 有单独的密集爆炸视觉预算；伤害、文字与音效不等同于粒子是否全部显示 |
| 光折射 | 明亮传播光束／射线、星芒、少量碎光 | 与光、冻结状态组合相关，使用独立效果脚本 |
| 神圣火焰／暗焰／光暗抵消 | 前两者有持续火焰换色；三者有声音调度 | 独立 `ElementReactionVisual` 提示入口主动跳过这三类，不能写成每次都额外爆一团反应粒子 |
| 分裂／弹射 | 复用子弹、金币、侧裂、侧喷、补刀、碎片或重演攻击 | 没有给所有武器统一套同一种分裂粒子 |

反应文字目前明确支持“雷火”和“传导”，持续 820 ms、上浮 40 世界单位；并非所有元素反应都会出现文字。反应图形会合并同类型、80 ms 内、距离小于 8 世界单位的重叠提示，湿润传播除外。

依据：[附魔分发](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/combat_effect_world.gd:19)、[震荡与爆炸分流](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/explosion_effect.gd:54)、[反应图形](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/element_reaction_visual.gd:34)、[反应文字](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/element_reaction_text.gd)、[状态图标与冰壳](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/enemy_status_visual.gd)、[电状态](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/lightning_status_visual.gd)。其余效果分别在 `scripts/effects/` 下的同名脚本中。

**4. 怪物动作、技能预警与霸体**

| 对象 | 已有表现 |
| --- | --- |
| 普通怪物 | 自身移动帧动画、朝向变化、共享受击和死亡；具体动作数量由各自素材决定 |
| 钢甲骑士 | 移动、冲锋蓄势、冲锋、收势；红色走廊预警，边线脉动、沿方向移动的亮点；头顶生命条与精英菱形标志 |
| 回声蝙蝠 | 原地和移动中拍翼；口部蓄力图集、闪动直线预警、音波弹体循环图集；音波碰撞后播放 6 帧、约 250 ms 的命中图集 |
| 幽焰冥狼 | 出场地面环、移动、吐息蓄力及动态火流；扇形吐息范围与进度弧；跃击锁定落点、落地区域与进度圈；跳跃贴图高度变化；落地 300 ms 扩散环及 12 个方形碎点 |
| 霸体 | 跟随真实怪物动作帧的金色轮廓，以及上浮消退的“霸体”文字；轮廓随实际免控时钟存在，文字约 1 秒，不因每次受击无限刷新 |

依据：[钢甲骑士](D:/project/useless/resources/infinite-build-dome-survival/scripts/enemies/elite_rusher.gd)、[回声蝙蝠](D:/project/useless/resources/infinite-build-dome-survival/scripts/enemies/echo_bat.gd)、[音波](D:/project/useless/resources/infinite-build-dome-survival/scripts/enemies/echo_bat_sonic.gd)、[幽焰冥狼](D:/project/useless/resources/infinite-build-dome-survival/scripts/enemies/underworld_wolf.gd:347)、[霸体](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/enemy_super_armor_visual.gd)。

**5. 玩家、镜头与瞄准**

- 初心者已接入待机、移动、站立攻击、移动攻击、持续施法、移动持续施法、前跳和后跳。站立攻击为 7 帧／14 FPS，约 500 ms；移动攻击约 750 ms；持续施法有进入、维持、退出三个阶段。后跳支持逐帧时长。当前待机只有 1 帧。
- 普通攻击切换站立／前进攻击姿态，秘仪和炉灯使用持续施法，位移武器使用前后跳。后退中施放普通武器保留站立攻击。角色和武器各自计时，尚不是所有武器都逐阶段同步；资本家当前配置只有待机和行走，不具备初心者整套动作。
- 玩家受伤时贴图变红，160 ms 恢复原色；护盾承担伤害时也会调用这一受伤反馈。未发现按命中统一触发的全屏红闪或相机抖动。
- 复活时背后展开像素天使翅膀，整段 1.5 秒，约 950 ms 完成展开，1.05 秒开始淡出；角色在 1 秒复活无敌期间每 100 ms 切换透明度。
- 玩家脚下有静态接触暗影／短弧，背后有低强度呼吸光；它们承担定位辅助，不是命中粒子。
- 镜头将主体放在画面高度约 57% 处，普通跟随按像素取整；瞬移后用 360 ms 缓动追上新位置。没有发现统一攻击震屏、全局慢动作、命中顿帧或手柄震动调用。
- 瞄准轮廓按武器显示扇形、箭头／直线、椭圆领域、榴弹落点；位移武器另有移动路径、落点／冲击范围和返回位置提示。形状跟随瞄准与可施放状态变化，并在玩家周围留出空隙。这主要是动态几何预览，不是持续播放的命中特效。

依据：[角色动作映射](D:/project/useless/resources/infinite-build-dome-survival/scripts/player/player_controller.gd:876)、[动作图集配置](D:/project/useless/resources/infinite-build-dome-survival/assets/sprites/player/actions/novice_128/animations.json)、[受伤](D:/project/useless/resources/infinite-build-dome-survival/scripts/player/player_controller.gd:455)、[复活翅膀](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/revive_angel_wings.gd)、[相机](D:/project/useless/resources/infinite-build-dome-survival/scripts/player/player_controller.gd:819)、[普通武器指示](D:/project/useless/resources/infinite-build-dome-survival/scripts/battle/weapon_attack_indicator.gd)、[位移武器指示](D:/project/useless/resources/infinite-build-dome-survival/scripts/battle/mobility_weapon_indicator.gd)。

**6. 飘字、武器栏、HUD 与拾取**

| 对象 | 已有动效 |
| --- | --- |
| 普通伤害数字 | 随机小范围错开位置，100 ms 显入、140 ms 弹性放大；620 ms 上浮 42 世界单位，随后停留 100 ms、280 ms 淡出 |
| 暴击数字 | 字号 26，普通为 18；上浮同时抖动 300 ms，最大横向振幅 5、纵向 2 世界单位，再衰减 |
| 数字颜色 | 按伤害数量级由白、黄、橙到红变化，未按火冰雷元素分类；当前没有同来源持续跳伤的时间窗口聚合 |
| 秘仪武器图标 | 每次主点名压至 88%、弹至 110%、恢复；全程约 230 ms，带提亮和小角线。其他武器不因此自动获得同样施放回弹 |
| 武器冷却 | 圆形冷却遮罩及倒计时；就绪后短亮边、角线外扩和两个小闪点，约 380 ms；延迟 50 ms 合并立即自动重施放的提示 |
| 移星武器栏 | 返回可用时切换图标与遮罩状态；未发现临近返回到期的独立提醒动画 |
| 生命／护盾／经验 | 数值条一般用 200 ms 平滑过渡，变化时 80 ms 颜色强调加 240 ms 恢复；护盾为零时所在行降透明度；回满生命等路径可即时刷新 |
| 金币／本金 | 变化时文字颜色脉冲，资源增减浮字约 520 ms 移动淡出 |
| 波次 | 开始时面板脉冲，临近结束时计时文字脉动；结束提示 550 ms 滑入、180 ms 显入，停留后淡出 |
| 面板 | 战斗属性抽屉有滑动过渡；模态界面使用背景遮罩，属于界面层 |
| 经验／金币拾取物 | 进入范围后吸向玩家；波末强制归集更快，并带上拱轨迹与旋转。带金币有效期的拾取物有逐渐耗尽的环，过期后颜色变暗 |
| 强化拾取物 | 图标后方轻微呼吸光，靠近后吸附；没有不透明大徽章或持续自转 |
| 遗物拾取物 | 小宝匣上下轻浮、光晕呼吸、4 个稀疏上升方点、周期性边缘闪光 |
| 治疗包 | 靠近后向玩家吸附 |

依据：[伤害数字](D:/project/useless/resources/infinite-build-dome-survival/scripts/enemies/enemy_controller.gd:751)、[秘仪图标脉冲](D:/project/useless/resources/infinite-build-dome-survival/scripts/ui/weapon_pulse_r02.gd)、[冷却就绪](D:/project/useless/resources/infinite-build-dome-survival/scripts/ui/weapon_cooldown_feedback.gd)、[HUD](D:/project/useless/resources/infinite-build-dome-survival/scripts/ui/battle_hud.gd:568)、[经验／金币归集](D:/project/useless/resources/infinite-build-dome-survival/scripts/pickups/exp_orb.gd)、[遗物](D:/project/useless/resources/infinite-build-dome-survival/scripts/pickups/relic_pickup.gd)。

**7. 环境与光照**

- 当前草尖由共享着色器做轻微风摆，幅度参数为 1.25 绘制单位，根部基本保持稳定。
- 云影沿世界地面移动；云间出现不规则暖色阳光斑块，并有细小植被影变化。地面、草、石头、装饰和玩家使用相关受光材质，环境时间随战斗暂停。
- 草按脚底深度分前后层；岩石遮住玩家时有轮廓／暗影辅助显示。场景物件有接触暗影和斜向投影。
- 洞穴远景根据横向相机位移产生视差，近地面与远景之间有渐隐过渡；该位移不是远景自己持续飘动。
- 电浆与闪电等有局部贴地光晕，独立光场支持短暂光斑衰减；这是局部视觉叠加，不是全屏闪光或真实全场景动态光照系统。
- 未在当前正式路径发现角色踩踏压草、爆炸推草、烧焦草地或战斗留下永久地表痕迹。战锤地裂属于有生命周期的战斗效果。

依据：[环境接入](D:/project/useless/resources/infinite-build-dome-survival/scripts/battle/cavern_sunlight_backdrop.gd:13)、[草风摆](D:/project/useless/resources/infinite-build-dome-survival/shaders/battle/meadow/sunlight/grass.gdshader:11)、[云影与阳光](D:/project/useless/resources/infinite-build-dome-survival/shaders/battle/meadow/sunlight/sunlight.gdshaderinc:16)、[玩家遮挡](D:/project/useless/resources/infinite-build-dome-survival/scripts/battle/cavern_population_backdrop.gd:337)、[远景](D:/project/useless/resources/infinite-build-dome-survival/scripts/battle/cavern_pit_horizon.gd:39)、[局部光场](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/particle_light_field.gd)。

**8. 音效及密集战斗时的表现约束**

音效虽不属于画面动画，但参与命中节拍：已有武器命中音、部分发射音、元素音、反应音与专用秘仪点名音。战斗声音配置 12 个声部，按音色限频、限制同类同时播放数量并处理优先级；有些音效带小范围音高变化。反应音会替换对应基础元素音，同一接触发生反应时，武器音降低 5 dB。

声音身份尚未完全分开：弓箭、短刀、长枪、金币等复用木箭命中资源，触手、战锤、摆锤复用重击资源。结霜与冻结音在配置中明确禁用；秘仪旧配置指向的冰音也被禁用，但现在有独立的点名短音。

当前预算分别作用于不同子系统，不能把其中一个上限解释成“全屏所有特效的总数”：

| 子系统 | 当前约束 |
| --- | --- |
| 通用粒子 | 900 槽；火焰类／投射拖尾预留 180 槽给其他反馈，达到预算时会减少发射或复用旧槽 |
| 分级接触图形 | 最多 96 个 |
| 反应提示图形 | 最多 96 个，另有空间／时间合并与装饰档位 |
| 局部光场 | 最多 96 个，另外按位置与颜色控制密集度 |
| 伤害数字 | 最多 160 个；普通数字最多占 128 个，为暴击保留 32 个位置 |
| 雷火、闪电、落雷预警、结霜等 | 有各自的密度预算／装饰降级；例如落雷预警可由 24 个装饰点降到 12、4 或 0 |

图集、着色器、代码绘制、GPU 粒子共同构成当前视觉；“看起来像粒子”不代表一定是独立粒子节点。预算主要控制显示成本，不应据此推断实际伤害或状态被减少。本次没有测量密集场景帧耗时。

依据：[声音库](D:/project/useless/resources/infinite-build-dome-survival/scripts/audio/combat_sound_library.gd)、[反应声音替换](D:/project/useless/resources/infinite-build-dome-survival/scripts/audio/combat_audio_impact.gd)、[音效调度](D:/project/useless/resources/infinite-build-dome-survival/autoloads/audio_manager.gd:12)、[粒子预算](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/particle_world.gd:595)、[通用装饰预算](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/effect_visual_budget.gd)。

**尚未落地或不能视为全覆盖的设计**

1. 按轻击、重击、暴击、终结统一分类的全武器命中反馈；当前只是部分路径接入分级。
2. 真正按命中触发的局部顿帧、重要攻击震屏、手柄震动，以及配套强度设置。
3. 所有武器的角色关键帧与实际接触时刻同步。
4. 暴击、摆锤外圈、精英终结各自独有的身体反馈和有限镜头强调。
5. 所有武器统一的施放图标回弹；目前明确接入的是秘仪点名，冷却就绪则已是通用能力。
6. 同目标同来源持续伤害数字聚合、精确身体接触锚点、战斗驱动的压草／地表变化。

这些方向部分已写入 [10 月 15 日打击感方案](D:/project/useless/resources/infinite-build-dome-survival/docs/main/combat_hitfeel_plan_2026-10-15.md)，应与本清单中的已实现项分开。此次仅新增现状文档。
