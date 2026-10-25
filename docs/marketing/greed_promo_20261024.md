# 贪婪主题补拍 · 2026-10-24

本次补拍聚焦玩家的取舍与哥布林的交易诱惑，交付两个独立片段。

## 高价收购镜头修订 v2

新版目录：`artifacts/previews/greed_promo_20261024_v2/`。最终剪辑仍为 `02_goblin_buyout_story.mp4`（11.5 秒），完整交易画面为 `02_sell_the_best_weapon.mp4`（8 秒）。

- 直接在原视频上叠加动画，保留原机位、成交时间、6.2 秒切换全景和 8 秒切换战斗的节奏。
- 使用武器栏原有 `assets/ui/icons/cast_manual.svg`，保持手动施法图标的金色。5.1 秒出现，靠近“接受”按钮，5.5 秒完成按压，随后回弹、淡出。
- 沿用成交时原有微笑表情；5.7 秒开始以原交易气泡、项目像素字体显示“明智的选择”，完整文字持续到交易镜头结束。这是宣传片叠加的对白，没有更改正式游戏交易文案。
- 保留原音轨，未增加配音或音乐。音效 100、背景音乐 0。验证 AAC 音频流哈希与原片完全相同；原视频文件 SHA-256 不变。
- `revision_validation.json` 保存时长、帧数、源文件及音轨验证，`revision_contact.jpg` 保存动作与对白抽帧。处理脚本为 `scripts/tools/revise_goblin_buyout.py`；手指 SVG 使用同目录 `export_manual_icon.gd` 经 Godot 无窗口导出。

## 交付

目录：`artifacts/previews/greed_promo_20261024/`。

| 文件 | 时长 | 内容 |
| --- | --- | --- |
| `01_one_more_coin.mp4` | 10 秒 | 地堡前停顿，折返拾取收益，夜色加深，追兵逼近 |
| `02_goblin_buyout_story.mp4` | 11.5 秒 | 哥布林与报价近景，成交后武器消失，金币到账，切到短刀难以清敌的后果 |
| `02_sell_the_best_weapon.mp4` | 8 秒 | 完整交易界面原始镜头，便于重新剪辑 |
| `03_price_of_the_deal.mp4` | 3.5 秒 | 卖掉主武器后，仅用营地短刀命中敌人并后退的独立素材 |

全部为 1920×1080、60 fps、H.264/AAC。游戏音效 100，背景音乐 0；没有另加字幕、音乐或音效。保留游戏自身的夜幕提示、交易条款和 HUD。

## 镜头设计

夜幕片段开场同时呈现地堡、玩家和远处散落的奖励。玩家靠近安全区，在边界外约 21 像素处停住，于 2.25 秒转身离开，拾取金币并尝试继续杀怪。后半段机位略向下跟随，维持人物与追兵完整可见。真实金币从 12 增至 28，杀死 3 只初始追兵，没有进入地堡；夜幕进度自然推进至 100%。

交易片段展示裂地战锤 Lv.5 和多投、落雷、智慧三个附魔。使用现有 `weapon_buyout` 交易，价格为 442 金币；点击接受后，主武器连同附魔实际移除，金币从 12 增至 454，仅留下 Lv.1 营地短刀。近景裁切放大哥布林、交易条款和附魔槽；6.2 秒恢复完整界面，让到账金额可见；8 秒切到下一波的实际战斗。

后果片段中，短刀分别对两名敌人造成 16 点伤害，敌人均剩 71 生命，18 名追兵全部存活。人物后退，画面保留只有一把短刀的技能栏与 454 金币，形成装备和财富的取舍。

## 录制与验证范围

- 独立录制场景 `scenes/debug/greed_promo.tscn`，通过 `RecordingSession` 创建临时游戏，不写存档。
- 预设装备、钱包、上一波表现及初始怪物和拾取物位置。收购资格使用 8 秒健康观察、战锤 900 / 短刀 30 的上一波伤害记录作为录制布景；从真实合格报价池选中收购交易。没有修改交易价格、交易文案、生产武器数值或夜幕规则。
- 战斗通过右键移动、数字键选择、左键施放；执行实际碰撞、伤害、掉落、拾取和冷却。
- 夜幕持续时间与后续增援使用真实逻辑。夜幕追兵的初始位置在录制开始前布置。
- 哥布林的表情由已有图集切换，报价和接受按钮均为生产 UI。最终剪辑只裁切画面和连接两段录制，音轨来自原始游戏录制。
- 营地短刀当前数据带有 `release_locked` 标记，本素材对应开发版本。
- 先进行 Godot 无窗口检查；图形录制通过 `run_godot_background.py` 的独立 Windows 桌面，核对 `private_desktop == verified_desktop`、`foreground_samples == 0`。
- 各镜头 `report.json` 记录输入、钱包、伤害和角色位置；`delivery_validation.json` 记录实际导出时长、帧数、分辨率和音频峰值，`delivery_contact.jpg` 用于抽帧检查。

## 重录

```powershell
python scripts/tools/record_greed_promo.py --mode headless
python scripts/tools/record_greed_promo.py --mode record
python scripts/tools/finish_greed_promo.py
```

Godot 编辑器检查的原有警告为 Android build-tools 路径和 `temp/effect_depth_baseline` 嵌套项目。一次无窗口排演遇到 camp UI 的 dummy-renderer 空纹理诊断；最终 GPU 录制要求日志无错误。
