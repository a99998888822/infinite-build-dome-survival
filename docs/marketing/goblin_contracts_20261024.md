# 哥布林引诱：借款追债与本金护箱

本次按“先拍1、2段”补拍两个故事。沿用原生哥布林对白、手动施法的手指图标和真实交易流程。输出目录：`artifacts/previews/goblin_contracts_20261024/`。

## 成片

| 文件 | 时长 | 镜头内容 |
| --- | --- | --- |
| `01_debt_hunter_story.mp4` | 13.25 秒 | 买不起物品 → 哥布林借款 → 借 500、欠 600 → 完成购买 → 接受击败强敌减债的条件 → 冥狼现身、交战、扑击 |
| `02_vault_rescue_story.mp4` | 9.75 秒 | 哥布林提出保管本金 → 接受押 200、守住返还 300 → 临近地堡 → 折返回保险箱 → 箱子受击后及时击退敌人 |

两段均为 1920×1080、60fps、H.264/AAC。音效设置 100，背景音乐 0 且静音；没有新增配乐、古筝、配音或外部字幕。对白和说明来自游戏原生 UI。借款和挑战时使用局部近景，保留完整条件文字。

## 内容边界

- 第一段的“奖励”是减免已有欠款，不是额外发金币。击败目标减欠款 600，未击败就撤离则增加欠款 600。本片以危险兑现收尾，没有展示清债成功。
- 第二段本金从 2000 实际扣至 1800，押出的 200 在满足生存与保险箱完整的条件后连同奖励返还 300。本片展示救场，没有提前发放未结算奖励。
- 护箱过程中保险箱实际从 57 生命降至 49，玩家通过真实攻击消灭 3 个敌人。镜头结束时玩家与保险箱均存活，玩家未进入地堡。
- 冥狼使用实际追债目标的属性倍率与标记，扑击使玩家从 19 生命降至 2，突出接受条件后的风险。

## 录制与验证

新增独立拍摄场景 `scenes/debug/goblin_contracts_promo.tscn`，复用现有 `RecordingSession` 和 `greed_promo.gd` 的输入、相机及音效检查。仅在临时局中布置初始本金、装备、敌人位置和挑战候选；借款、购买、扣款、技能、碰撞、怪物 AI 与伤害使用正式逻辑。控制为右键移动、数字键选技能、左键释放。

分镜源文件为 `debt_bank.mp4`、`debt_fight.mp4`、`vault_offer.mp4`、`vault_rescue.mp4`。银行转战斗时切到独立布置的后续战场，省去等待；没有把两次录制描述成连续实时游玩。

```powershell
python scripts/tools/record_goblin_contracts.py --mode headless
python scripts/tools/record_goblin_contracts.py --mode record
python scripts/tools/finish_goblin_contracts.py
```

Godot 导入与无窗口运行已检查。GPU 录制均在私有 Windows 桌面完成，实际引擎桌面与目标桌面一致，`foreground_samples=0`。每段的 `report.json` 记录交易、技能输入、生命、伤害与音频总线；`capture.json` 记录后台桌面验证；成片的 `delivery_validation.json` 记录帧数、时长、分辨率及音频峰值。逐帧抽查结果保存在 `delivery_review/` 和 `delivery_contact.jpg`。

无窗口检查偶见既有营地 UI 的 dummy texture 提示，正式 GPU 录制要求无脚本/资源错误。未修改已有正式战斗机制，也未覆盖此前交付的宣传片。
