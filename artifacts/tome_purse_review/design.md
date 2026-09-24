# 坤舆秘仪书与食利者钱袋：素材审阅 V5

本轮为原创像素素材及可运行的战斗表现原型；未加入正式武器配置、商店或奖励池。透明 PNG 采用项目既有的本地像素绘制方式，未调用生图 API。两段战斗动图来自 Godot 实际渲染，不是离线示意动画。

后续状态：V5 已获确认并迁移到正式武器代码；本文保留素材审阅时的记录。正式参数与运行产物见 `docs/main/4-weapon_loadout_design.md` 第 21 节和 `artifacts/tome_purse_implementation/`。

## 坤舆秘仪书

- 64×64 透明图标：藏蓝厚封皮、旧银包角、露出的层叠书页、浅蓝书签，以及暗淡的地图／眼形纹章。
- 战斗中隐藏秘仪书本体，图标与书页素材保留。
- 领域以玩家为中心，半长轴 220、半短轴 145。48 组浅蓝小正方形粒子构成椭圆虚线边界，每组 3 个独立的 2×2 像素方粒，中心间距约 5 像素；组间留出更大空隙。采用类似闪电链的独立粒子明灭表现，密度更疏，不绘制连接短线。外侧另有 24 个 1×1 方粒轻微流动。边界持续显示并跟随玩家。
- V5 保持上述数量与尺寸：粒子组沿边缘随机错开最多 4 像素，组内每粒额外错开最多 1.5 像素，沿边缘以独立相位缓慢波动 ±4 像素，为 V4 动态幅度的 8 倍，局部间距明显收缩与扩张；外围伴随粒子的角度波动由 ±0.003 弧度增加到 ±0.022 弧度。径向偏移与波动合计仍不超过 0.95 像素。每粒初始角度随机取 −45°～45°，随后慢速摆动 ±8°。随机参数在初始化时缓存，使用独立的视觉随机源，不改变伤害选敌序列；不逐帧重新随机。
- 中央复杂符文包含经纬线、破碎星盘、七角交错图和外围秘文，以 4.4 秒为周期缓慢淡入淡出，保持居中。符文 PNG 的最大 Alpha 为 51/255；运行时不透明度约 1.6%～20%，交点不叠加增亮。
- 每 0.8 秒随机点名一个领域内敌人，目标出现小型方折符印和上浮方粒。基础伤害 10，元素伤害系数 1.0，再计算通用伤害加成及敌方护甲。
- 本次展示原生秘仪攻击，不附加火、冰或电状态。领域外敌人不受伤害。

## 食利者钱袋

- 64×64 透明图标：深棕皮革、宽窄褶皱、缝线、黄铜束口和钱币印章，袋口露出数枚旧金币。
- 战斗中隐藏钱袋本体；钱袋图标及原有素材保留。
- 默认每 1.1 秒从玩家处发射 3 枚金币，方向彼此相隔 120°；下一轮发射角度偏转 30°。金币使用 8 帧正面／侧面翻转素材，拖尾和命中反馈均为小方块。
- 本次提案：飞行速度 380、距离 280，命中一名敌人后碎成金色像素。同一轮对同一目标最多造成一次原生伤害。
- 伤害提案：`4 + 远程伤害 × 0.6 + 0.3 × sqrt(当前本金)`，再计算通用增伤及敌方护甲。演示本金固定为 400、远程伤害为 0，每枚金币伤害 10。
- 本金只提供伤害加成，攻击不消耗本金。金币是攻击弹体，不计入货币掉落。

## 文件

| 素材 | 路径 |
|---|---|
| 两张图标 | `assets/ui/icons/weapons/weapon_kunyu_ritual_tome.png`、`weapon_rentier_purse.png` |
| 战斗主体及 4 帧动画 | `assets/sprites/weapons/weapon_kunyu_ritual_tome*.png`、`weapon_rentier_purse*.png` |
| 20% 符文 | `assets/sprites/weapons/kunyu_domain_rune.png`，384×240 |
| 8 帧金币 | `assets/sprites/weapons/rentier_coin_spin.png`，128×16 |
| 图标审阅板 | `icons_review_v2.png` |
| 实录 | `tome_battle_v5.gif`、`purse_battle_v2.gif`；同名 MP4 为完整视口、30 帧/秒版本 |

GIF 各 5.6 秒、20 帧/秒。录制使用固定位置、高生命敌人保留连续动画；未展示暴击和附魔，也不进行音效验收。

## 复现与验证

- 素材绘制：`python scripts/tools/build_tome_purse_art.py`。
- 场景：`scenes/tests/tome_purse_capture.tscn`，在隔离存档副本中以 `--fixed-fps 30 -- --variant=tome|purse --capture-dir=<工程外目录>` 录制。
- 秘仪书 V5 导出：`python scripts/tools/build_tome_purse_review.py --variants tome --revision v5`，读取工程外 `codex-tome-purse-v5-tome` 录制目录；钱袋继续使用 V2 录制。
- 原型复用玩家属性、怪物伤害处理和暂停标记；金币原型使用连续线段与敌人中心半径 14 的接触判定，正式接入时需适配武器系统。
- `asset_validation.json` 验证图标透明通道与留白、动画帧数、符文 Alpha；`tome_capture_v5.json` 与 `purse_capture_v2.json` 记录实际攻击与命中；对应版本的 `media_validation_*.json` 记录动图规格。
- 录制退出时的既有节点／资源清理提示保留在日志中。

V5 重点验收：粒子数量保持，方粒间距大幅波动，每粒朝向不同并轻微旋转；秘仪书本体隐藏，椭圆边界持续显示，中央符文独立明灭。

V5 验证：编辑器无脚本解析或编译错误；秘仪书 headless 与图形录制各 8 项通过。日志为 `editor_v5.log`、`headless_v5_tome.log`、`capture_v5_tome.log`，退出时仍有既有 Canvas／ObjectDB 清理提示。全景 `tome_battle_v5.gif` 为 112 帧，5 倍最近邻放大 `boundary_detail_v5.gif` 为 111 帧，均为 5.6 秒；规格见 `media_validation_v5.json`。

V2 验证：headless 和图形录制各 17 项通过。V3 的秘仪书 headless 与图形录制各 8 项通过，钱袋 headless 回归 10 项通过，编辑器无脚本解析或编译错误。结果见 `editor_v3.log`、`headless_v3_*.log` 与 `capture_v3_tome.log`。新增 `boundary_detail_v3.gif` 为实际录制中边界的 5 倍最近邻放大，便于确认独立正方形和粒子间隙；总览 112 帧，局部 111 帧，两段均为 5.6 秒，具体规格见 `media_validation_v3.json`。

V4 验证：编辑器无脚本解析或编译错误；秘仪书 headless 与图形录制各 8 项通过，覆盖隐藏本体、领域外目标不受伤、单目标攻击、跟随和暂停。结果见 `editor_v4.log`、`headless_v4_tome.log`、`capture_v4_tome.log`。全景 `tome_battle_v4.gif` 为 112 帧，5 倍最近邻放大 `boundary_detail_v4.gif` 为 111 帧，两段均为 5.6 秒，规格见 `media_validation_v4.json`。像素方粒不使用抗锯齿，微小旋转在原始分辨率下表现为像素轮廓变化。退出时仍有既有 Canvas／ObjectDB／资源清理提示，未发现录制检查失败。
