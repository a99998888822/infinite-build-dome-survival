# 下一波：12张附魔图标

**当前进度：用户已选定32×32，12张已正式安装。** 见[接入与后台验证](../../24_augmentations_sheet_01_installation.md)。[32／64尺寸对照](../../../../../artifacts/previews/art_refresh_v1/augmentations_sheet_01/pixel32_r01/README.md)和[64px候选稿](../../../../../artifacts/previews/art_refresh_v1/augmentations_sheet_01/pixel_r01/README.md)保留，以下为历史生成配方。下一批进入[四角色母稿](../characters_sheet_01/README.md)。

按当前 `data_config/augmentations.json` 核对，共13条配置、12张独立图标。旧方案的10张已过时：新增弹跳、共鸣；当前显示名为电火花、落雷的两项继续共用 `scroll_lightning`。名称按现行配置使用，结霜、风刃不再沿用旧方案的冰霜、疾风叫法。

## 豆包操作

新开对话，只上传 [01_arcane_ink_reference.png](01_arcane_ink_reference.png)，粘贴 [doubao_prompt.txt](doubao_prompt.txt)。本次换用项目reference中的另一张暗黑地牢秘术人物裁图，只参考硬边明暗、线面与魔法气质；不复制人物、骷髅、装备或原配色。具体效果身份由文字要素给出，不上传旧图标或上一轮武器表。

沿用武器最终确认的思路：保留识别要素，重新设计轮廓和组合。12张均为独立魔法符号，以不同剪影与颜色区分，不共用纸卷或徽章底框。

| 行 | 第1列 | 第2列 | 第3列 | 第4列 |
|---|---|---|---|---|
| 1 | 弹跳 | 共鸣 | 水流 | 光辉剑 |
| 2 | 黑洞 | 火焰 | 震荡 | 电火花／落雷 |
| 3 | 分裂 | 穿透 | 结霜 | 风刃 |

生成4列×3行白底高清图集，优先4096×3072或最高可用分辨率，底部留10%白边。下载原始文件发回，建议命名 `augmentations_sheet_01_source.png`。先审阅造型，再从高清源处理为64×64透明PNG与PXG。

[完整生成包](augmentations_sheet_01_doubao.zip) · [配置映射与参考来源](manifest.json)

## 工程范围

本批更新12张UI图标，不生成元素战斗特效。弹跳与共鸣已改用PNG；电火花与落雷保留共用关系，其余10张PNG原路径保留。

初始64px制作规格在审阅后改选32px。正式接入已调整工作台、背包和拖拽显示，并验证小窗口滚动及装备槽；详细改动见接入记录。
