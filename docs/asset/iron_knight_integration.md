# 钢甲骑士小 Boss：正式接入

更新：2026-09-29，已接入用户确认的 Picxel 新版移动与攻击。沿用 `enemy_elite_rusher` ID 与 `EliteRusher` 类，展示名为“钢甲骑士”。

## 资源与配置

正式资源位于 `assets/sprites/enemies/iron_knight/`，待机 1、行走 11、蓄力 7、冲刺挥锤 2、收招 2。每帧由原生 128 像素稿加透明留白至 160×160，最多 16 色，硬透明 PNG；安装逐文件核对审阅稿哈希。移动 11 FPS；攻击三阶段按技能持续时间播放完整帧序。没有提供死亡姿势，死亡时冻结当前图像并在 0.2 秒内淡出；旧死亡图及导入文件已删除。

场景保持 0.7 显示比例与半径 21 的身体碰撞体，按新移动图 `(80,128)` 脚底参考锚点将 `Sprite2D` 偏移设为 `(0,-33.6)`；攻击保留动作自身上下变化及鞋底外的火花。技能动画按实际技能时钟映射到帧表，暂停和短控制同时暂停动作。

| 参数 | 当前值 |
| --- | --- |
| 起手距离 | 玩家中心距 ≤ `dash_distance`，当前 240 |
| 起手条件 | 存活、追赶状态、目标存活、冷却就绪，并保留多精英起手错峰 |
| 蓄力预警 | 800 毫秒；起手后锁定方向 |
| 冲刺与挥锤 | 160 毫秒；240 距离对应 1500 单位/秒 |
| 收招 / 冷却 | 500 / 6000 毫秒 |
| 预警内部不透明度 | 12% |
| 两条长边不透明度 | 42%～55% 脉动 |
| 边缘方粒不透明度 | 48%～60% 脉动 |

预警是无箭头、无圆角的矩形，由实际冲刺距离与半宽生成；图层在角色下方绘制。透明度百分比与时间都读取 `enemies.json` 的 `elite_profile`。距离不够时继续追赶，不消耗冷却，也不原地停住。

冲刺伤害检测覆盖每次移动的整段范围，支持玩家实际胶囊碰撞体和圆形碰撞体，包括碰撞节点的偏移与旋转；每次冲刺只尝试命中一次。撞墙或撞人后停止位移，挥锤在剩余的 160 毫秒技能时间内完成，再进入收招。

生命、护甲、侵蚀加成、每波小 Boss 数量和前半波生成规则沿用现有配置。首个遗物选择奖励基础掉落 100%，落地即计入后续掉落衰减；近距离拾取与波末收取沿用现有奖励链路。

## 制作与验证入口

```text
python scripts/tools/build_iron_knight_review.py
python -B scripts/tools/install_iron_knight_assets.py
```

第一条将当前已确认的 Boss 预览复制到系统临时目录，不再绘制旧版造型。第二条从 `artifacts/previews/combat_picxel_3838180/delivery/boss/combat/` 核对并安装五张正式贴图，重建匹配的 `SpriteFrames`；附加 `--check` 仅校验。修改工作流见[本轮 Picxel 记录](../../artifacts/previews/combat_picxel_3838180/README.md)。实机材料见 `artifacts/reviews/effects/iron_knight/`。

专项场景为 `scenes/tests/iron_knight_test.tscn`，检查距离边界、远处继续追赶、冷却、方向锁定、动画同步、160 毫秒位移、胶囊擦边命中与落空、低帧率扫掠、暂停/冻结和障碍阻挡。联动回归使用 `elite_relic_decay_test`、`elite_effect_revision_test`、`erosion_pressure_test`。测试与录像通过 `-- --transient-session` 避免写入正式营地存档。

实机录像使用 `scenes/tests/iron_knight_live_capture.tscn`，它启动正式 `GameRoot` 和战斗场景，通过现有 `WaveManager` 生成骑士。录制时固定刷怪环境并脚本控制玩家侧移、终结骑士；怪物 AI、动画、碰撞和奖励均使用正式实现，原始视口帧写入系统临时目录。
