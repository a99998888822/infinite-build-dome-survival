# 下一批：暗绿遗址地面

先做5张地表纹理＋1张含3种矮灌木的排版图，共8项素材。生成高清稿后交回处理；本批尚未生成新地面像素图。

## 操作

新开豆包对话，上传 `01_ground_planes_reference.png`，复制一份 `prompts/G01...G05...txt` 的完整内容，生成一张铺满画布的2048×2048材质图。五种地表分别生成，不混成一张完整场景，不上传旧石盘或游戏截图。模型尺寸受限时保存最高原生输出，不自行放大。

灌木使用 `02_vegetation_reference.png` 与 `prompts/G06_G08_bushes.txt`，一次生成白底的3种矮灌木。白底与抠图要求只用于灌木。

第一张图确认后，后续用同一套文字色系和画风参考保持一致。如果要上传第一张新图，只把它当作已确认材质的风格样本，不能让模型复刻同一块草地／石砖布局。默认只传对应画风裁图即可。

| 保存文件名 | 使用提示词 | 内容 |
|---|---|---|
| `G01_grass_sparse.png` | `prompts/G01_grass_sparse.txt` | 稀疏暗绿草地，铺满画布 |
| `G02_grass_dense.png` | `prompts/G02_grass_dense.txt` | 成片密草，铺满画布 |
| `G03_wet_earth.png` | `prompts/G03_wet_earth.txt` | 深棕湿土，铺满画布 |
| `G04_paving_worn.png` | `prompts/G04_paving_worn.txt` | 磨损铺砖，铺满画布 |
| `G05_paving_broken.png` | `prompts/G05_paving_broken.txt` | 破损铺砖，铺满画布 |
| `G06_G08_bushes.png` | `prompts/G06_G08_bushes.txt` | 左矮圆、中扁长、右稀疏枯枝，白底 |

建议放入 `temp/battle_ground_01/`。原文件交回后可以说：

> 请检查temp/battle_ground_01里的5张地表和3种灌木，按主战斗场景更新方案处理成像素素材、修接缝和边界，并拼接候选战场，给我黄昏与夜晚的后台实机预览，审阅后再替换。

## 参考与后续

参考1取自用户指定的大块面森林图的地面／岩石局部；参考2换用另一张克苏鲁环境图的前景植被局部，只借鉴叶丛分组，不画发光异形植物。均从 `artifacts/reference` 裁出，未放大。来源与坐标见 `reference_manifest.json`。

地表后续按128×128的tile母纹理处理，保持不透明；灌木独立透明128×128。母纹理用于组合256–512世界单位的大区域，不会把整个战场压缩成128像素，也不会把128px画布等同于每丛灌木的世界大小。

豆包生成的“可平铺”并不保证边缘严丝合缝，我会在像素化后检查重复和过渡。黄昏、夜晚由同套素材的场景配色与光照统一处理，不要求分别画两套完全不同的地形。

[完整方案](../../28_battle_ground_redesign.md) · [分层布局示意](layout_proposal.png) · [下载提示词与参考包](battle_ground_01_doubao.zip)
