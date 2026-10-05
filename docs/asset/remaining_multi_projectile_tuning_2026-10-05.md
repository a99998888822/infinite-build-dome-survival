# 四把武器的节奏与火焰效果修订

本页保留 R02。短刀、摆锤与秘仪书的后续节奏调整见 [R03](remaining_multi_projectile_r03_2026-10-05.md)；炉灯仍使用本页版本。

按用户“短刀稍慢、摆锤稍快、炉灯参考火焰附魔、秘仪书大幅缩短点名间隔”的要求完成 R02 调试。继续使用独立审阅场景的真实 GameRoot、攻击运行时、碰撞和伤害，录制原速 1／3／5 投射物。

| 武器 | R01 | R02 |
|---|---|---|
| 营地短刀 | 每次完整斩击 0.24 秒 | 每次 0.30 秒；1／3／5 次共 0.30／0.90／1.50 秒，速度降低 20% |
| 流星摆锤 | 每次完整挥击 0.88 秒 | 每次 0.72 秒；1／3／5 次共 0.72／2.16／3.60 秒，完整收招后接下一次 |
| 坤舆秘仪书 | 点名间隔 0.8 秒 | 间隔 0.2 秒；首击 0.22 秒、末击收尾 0.3 秒，3／5／7 次点名总动作约 0.92／1.32／1.72 秒 |
| 赤铜炉灯 | 向前散布的方形火粒 | 连续火芯和火舌，参考火焰附魔的暗红、橙红、暖橙、淡黄四层配色及 18 帧噪声流动 |

炉灯使用独立喷射 Shader，让火焰向前流动并逐渐分出火舌；少量余烬沿喷射方向前进。视觉与原判定共用喷口偏移、范围角和射程，基础仍为单束 60°；额外投射物仍将喷射延长至 1.8／5.4／9 秒。每条原生或分裂火流复用视觉节点，避免逐帧创建粒子节点；没有新增火焰附魔伤害或地面火区。

秘仪书保持原版法阵和爆纹。点名数仍为 `3 + 额外投射物数`，允许重复点名同一存活敌人，空阵等待时不消耗次数，全部点名与收尾结束后才开始冷却。

短刀完整连击和放慢仍由独立审阅调度；摆锤节奏、炉灯视觉在共享运行时更新，秘仪书新间隔只影响主动施放模式。正式主战斗输入、HUD、清剿和数值迁移继续按根目录方案实施。

## 动图

- [营地短刀](../../artifacts/previews/active_combat/remaining_multi_r02/weapon_camp_dagger.gif)
- [流星摆锤](../../artifacts/previews/active_combat/remaining_multi_r02/weapon_meteor_flail.gif)
- [赤铜炉灯](../../artifacts/previews/active_combat/remaining_multi_r02/weapon_copper_lamp.gif)
- [坤舆秘仪书](../../artifacts/previews/active_combat/remaining_multi_r02/weapon_kunyu_ritual_tome.gif)

复现入口：`scenes/tests/remaining_multi_projectile_review.tscn`，可用逗号分隔的 `--review-weapon=` 选择武器，用 `--review-count=1|3|5` 选择单档。GPU 仍使用私有桌面的 `scripts/tools/run_godot_background.py`；原始截图在 `tmp/multi_projectile_review/remaining_r02/`，旧版 R01 保留用于比较。

## 检查

- 6 组、588 项无界面功能检查通过：攻击修订、摆锤、三武器、弹跳、秘仪书／钱袋、独立实机审阅。检查快速点名的首击延迟、200 毫秒间隔、低帧率补发次数与最终收尾，以及火焰方向、结束隐藏和每跳伤害。
- 无界面编辑器加载及默认主场景启动通过。部分无界面测试仍有退出资源提示；攻击专项测试的详细退出日志仅列出 WAV 音效及播放对象，实机录制没有资源退出提示。
- 四武器正式录制共 912 项检查通过，保存 827 张真实帧；引擎实际位于私有桌面，`foreground_samples=0`。GIF 保持实际物理帧时间，未加速或补画动画。
- [功能检查记录](../../artifacts/previews/active_combat/remaining_multi_r02/headless_checks.json)、[实机记录](../../artifacts/previews/active_combat/remaining_multi_r02/review_report.json)、[导出核验](../../artifacts/previews/active_combat/remaining_multi_r02/verification.json)。
