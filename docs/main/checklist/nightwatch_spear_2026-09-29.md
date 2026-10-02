# 守夜长枪正式接入验收（2026-09-29）

- 已注册 `weapon_nightwatch_spear`，可以在开局选择和商店／奖励池获得；支持五级升级、附魔、出售和伤害统计。
- 基础近战伤害14、角色近战系数1.0、间隔1.10秒、负载16；三级解锁第二附魔槽，五级基础伤害26。
- 保留已审阅的248×28枪身原始字节，新增64×64正式图标；两项均14种不透明颜色，Alpha仅0／255，渲染使用最近邻。
- 连续刺击使用实际碰撞体查询；低帧率、边走边刺、背后与宽度边界、地形遮挡、每次刺击去重、攻速和两种范围属性均已验证。
- 分裂读取实际卷轴，生成默认2枚60%伤害短矛；继承暴击，排除本轮主刺目标，仅一代，并正常触发元素附魔。穿透卷轴在装填时被拒绝。
- 暂停、死亡、出售、重新初始化及运行节点清理均覆盖主刺与短矛。共享火区修正灼烧来源，持续伤害正确计入对应武器。

| 验证入口 | 结果 |
| --- | --- |
| `nightwatch_spear_test.tscn` | 69项通过 |
| `meteor_flail_test.tscn` | 45项通过 |
| `weapon_balance_test.tscn` | 70项通过 |
| `tome_purse_weapon_test.tscn` | 65项通过 |
| `grenade_weapon_test.tscn` | 88项通过 |
| `element_reaction_test.tscn` | 62项通过 |
| `combat_audio_test.tscn` | 45项通过 |
| `combat_audio_reaction_test.tscn` | 29项通过 |
| 编辑器无界面导入、Bootstrap运行120帧 | 无脚本／配置错误 |
| UTF-8与差异空白检查 | 通过 |

四种正式实战配置（基础、分裂、分裂＋火焰、分裂＋闪电）均通过，使用真实GameRoot、正式开局装备流程、自动索敌和移动敌人；伤害进入武器统计。双附魔通过正式升级到三级获得槽位。图像检查覆盖基础刺击及分裂火焰；演示用固定敌群、240敌人生命、角色增加990最大生命、暴击归零，独立临时存档，不改正式战斗配置。

无界面测试的断言全部通过，但长枪、榴弹炮、元素反应和反应音效测试在退出时仍可能报告音频资源尚未释放；已确认长枪报告的对象为 `AudioStreamWAV` 和 `AudioStreamPlaybackWAV`，没有脚本或配置错误。完整场景录制在释放场景、停止音效并等待后正常退出。负载回归中拒绝重复购买、超载购买的警告是预期断言。

复现脚本为 `scripts/tests/nightwatch_spear_live_capture.gd`，场景与上述测试均在 `scenes/tests/`。使用 `--fixed-fps 30 -- --transient-session --variant=base|split|split_fire|split_lightning --capture-dir=<项目外目录>`，录制时启用实际渲染。图片和日志输出到系统临时目录；已接入的旧长枪设计预览从 `artifacts` 删除，重建资源工具保留在 `scripts/tools/build_nightwatch_spear_art.py`。
