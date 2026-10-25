# 坤舆秘仪书补拍

## 已完成：镶嵌演示

`artifacts/previews/kunyu_promo_20261024/01_kunyu_enchantments.mp4`

- 3.5 秒，1920×1080，60fps，H.264/AAC。
- 满级坤舆秘仪书依次镶嵌“多投 → 领域 → 落雷”，复用原先附魔演示的飞入动画与正式装配 API。
- 音效 100、背景音乐 0 且静音；没有添加外部字幕、配乐或古筝。
- 已完成无窗口检查、私有桌面 GPU 录制、首尾与飞行动画抽帧、音频峰值与有效音轨检查。`foreground_samples=0`。

## 已完成：多投＋分裂＋落雷战斗

用户后续指定以“多投＋分裂＋落雷，玩家投射物属性为 3”录制，替代原先同时五目标的方案。沿用现有正式攻击规则，无需修改机制。

`artifacts/previews/kunyu_split_promo_20261024/02_kunyu_multishot_split_lightning.mp4`

- 5 秒，1920×1080，60fps，H.264/AAC。
- 满级坤舆秘仪书依次装备“多投 → 分裂 → 落雷”。玩家面板投射物数量为 3；叠加武器原生数量和多投后，武器实际数量为 6。
- 一次手动施法连续攻击 8 轮，每轮命中 1 个主目标、分裂命中另外 2 个目标；两个子攻击分别触发落雷，共记录 24 次直接命中、16 次落雷。
- 60 只怪物分散布置，保留正常 AI 追击、碰撞与伤害，玩家右键移动、数字键选武器、左键施法。最终击杀 6 只，玩家生命维持 19，没有使用无敌或脚本扣血。
- 音效 100、背景音乐 0 且静音；没有添加外部字幕、配乐或古筝。
- 已通过无窗口排练、私有桌面 GPU 录制及画面抽帧检查，`foreground_samples=0`。成片音频非静音且未削波，峰值 0.321。

## 共用装备配置

`scripts/debug/fixtures/kunyu_promo_build.gd` 保存录制临时配置，不改正式平衡数据或存档。镶嵌演示沿用一份双腔弹匣，武器合计 5 投；本次战斗使用两份双腔弹匣，玩家面板 3 投，武器合计 6 投。

使用合法叠加数量的旧铜望远镜 3、长焦目镜 1、地平仪 1、折叠星图 1、黄金测距仪 1，并保有 1000 本金。实际攻击距离加成 175，法阵半轴 562.5×453.75。“领域”与其他伤害范围加成影响命中附魔的范围，当前不直接扩大法阵选敌范围。

```powershell
python scripts/tools/record_kunyu_promo.py --take enchant --mode headless
python scripts/tools/record_kunyu_promo.py --take enchant --mode record
python scripts/tools/record_kunyu_promo.py --take combat --mode headless --output artifacts/previews/kunyu_split_promo_20261024
python scripts/tools/record_kunyu_promo.py --take combat --mode record --output artifacts/previews/kunyu_split_promo_20261024
```

`enchant/report.json`、`enchant/capture.json`、`enchant/export.json` 与 `enchant_delivery_validation.json` 保留验证记录。

本次战斗的 `combat/report.json`、`combat/capture.json`、`combat/export.json`、`delivery_validation.json` 和 `delivery_contact.jpg` 位于 `artifacts/previews/kunyu_split_promo_20261024/`。

## 改版：双分裂＋落雷，迎面推进

新版按用户指定改为“分裂 → 分裂 → 落雷”，投射物属性为额外 +5（玩家原生 1 加成后为 6，满级武器最终为 8），不包含多投附魔。配置独立保存在 `advance_config()`，旧版配置和成片保留。

- 法阵攻击距离加成从 175 降至 80，半轴从 562.5×453.75 缩至 420×338.8，直径缩小约 25%。
- 使用合法元素伤害与伤害增幅遗物补足清怪能力，未修改怪物生命、正式技能机制或效果资源。
- 48 只正常怪物在玩家前方分散成群，保留自然间隙与正常追击。玩家右键向前推进，数字键加左键起手展开法阵。
- 每轮最多 1 个主目标加 4 个分裂目标。无窗口排练在 5 秒内完成 9 轮、33 次落雷，清掉全部 48 只怪物；玩家生命保持 19。
- 音效 100、背景音乐 0，无额外字幕、配乐或古筝。

```powershell
python scripts/tools/record_kunyu_promo.py --take advance --mode headless --output artifacts/previews/kunyu_double_split_promo_20261024/final
python scripts/tools/record_kunyu_promo.py --take advance --mode record --output artifacts/previews/kunyu_double_split_promo_20261024/final
```

输出文件为 `artifacts/previews/kunyu_double_split_promo_20261024/final/03_kunyu_double_split_advance.mp4`。对应 `advance/report.json` 记录实际攻击、移动和伤害，`advance/capture.json` 记录私有桌面验证。

成片已完成画面抽帧与音轨检查：5 秒、1920×1080、60fps，音频峰值 0.316，无削波，`foreground_samples=0`。实际推进 589.2 像素，击杀与排练一致。验证与联系表保存在 `delivery_validation.json` 和 `delivery_contact.jpg`。
