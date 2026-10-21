# 当前游戏流程与持久化

主流程由 [main_flow_coordinator.gd](../../scripts/core/main_flow_coordinator.gd)编排，波次由 [wave_manager.gd](../../scripts/waves/wave_manager.gd)管理。正式主场景为 `scenes/core/game_root.tscn`。

## 一局游戏

主界面选择角色和难度后进入战斗。首次游玩先处理开局升级奖励，再显示[操作指引](combat_guide.md)，完成或跳过后开始首波。角色可用性按运行配置检查，资本家目前可展示但锁定开局。

波次配置定义 20 波。正常计时结束后进入夜幕降临阶段，并在视野外生成哥布林地堡；清空敌人或等待不会自动进入理财。玩家脚底进入地堡周围的水蓝色光圈后安全撤离，吸取有效掉落、完成波次结算与回血，再进入理财；最终波撤离后通关。

理财期间可操作银行、商店、武器与附魔，并处理符合条件的哥布林交易。开始下一波时处理挑战；同一次备战关闭重开不重抽，拒绝不施加效果。具体条目和条件见[交易清单](../../goblin_trades_list.md)、[合同](goblin_contracts.md)与[挑战](challenge_expansion.md)。本金、理智与侵蚀会影响相关遗物、交易和敌人属性，具体公式以对应配置和系统为准。

死亡、通关与主动撤离进入整局结算，统计由独立结算模块处理并防止重复发放。结算界面提供返回主界面操作。运行时遗物效果保留，当前 `bonds.json` 为空表，没有启用的羁绊奖励组合。

## 持久化

`CampProgression` 保存局外货币、建筑与升级进度，主存档为 `user://saves/profile_01.json`，另有备份和临时写入文件。正常存档不支持从战斗中途续局。

操作及逐技能释放偏好存于 `user://combat_settings.cfg`；窗口、音频和语言由对应 Autoload 管理。录制台使用临时会话，独立配置构筑，不写入正式进度。具体启动方式见[录制台说明](../marketing/recording_studio.md)。
