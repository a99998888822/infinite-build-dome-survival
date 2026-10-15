# artifacts 保留与清理建议（2026-10-15）

> 后续已按本建议完成归档、修复和清理，实际结果见[清理记录](artifacts_cleanup_20261015.md)。下文保留清理前的审计快照，其中旧路径及过程附件不再代表当前目录。

本轮仅梳理，没有删除或移动 `artifacts` 中的文件，也没有修改正式素材和运行代码。

保留口径：以当前 `assets/` 的 426 个媒体文件为准，包括用户要求保留的 7 个独立营地场景素材。保留其有效原图、唯一编辑源、必要的来源映射，以及仍可用于这些素材的绘制或处理脚本。实机截图、审阅录像、旧方案、成品副本、测试项目快照和一次性操作脚本不属于目标保留范围。

## 数量和空间

共 **29,281 个普通文件，7,602.79 MiB，约 7.42 GiB**。统计按文件逻辑大小，不等同于磁盘实际可释放空间；未遍历 5 个 Windows 目录联接，不重复计入它们指向的正式项目文件。

| 目录 | 文件数 | 大小 MiB | 建议 |
|---|---:|---:|---|
| `analysis/` | 6,178 | 3,318.63 | 提取仍有效的洞穴原图、少量制作输入后，清理审计、截图、日志和旧方案 |
| `reviews/` | 16,257 | 3,105.76 | 清理审阅包、录像和项目快照；先提取正式地面、光照的可复用绘制逻辑 |
| `previews/` | 6,506 | 1,000.66 | 先提取当前动作原图和有效编辑稿，再清理其余过程文件 |
| `sources/` | 136 | 152.77 | 保留现行来源，去掉旧版角色帧、参考资料、重复或失效来源记录 |
| `reference/` | 29 | 19.64 | 按本轮保留口径可删除：画风、场景、油画、动效参考，不是当前成品的直接原图 |
| `localization/` | 30 | 3.37 | 全部为验证日志，可删除 |
| `editable/` | 138 | 1.88 | 保留当前有效稿；存在旧动作网格、重复网格和废弃地面色片，不能整目录保留 |
| `generated/` | 5 | 0.08 | 英文标题绘制脚本、高分辨率母图和必要映射保留；正式成品副本可删 |
| 根目录说明与 `.gdignore` | 2 | <0.01 | 保留精简说明和 `.gdignore` |

仅下列三组、按互斥规则统计的临时内容就有 **22,352 个文件，约 5.04 GiB**：

| 内容 | 文件数 | 大小 MiB |
|---|---:|---:|
| 三处审阅项目快照 | 13,937 | 1,375.46 |
| 实机截图及其捕获目录内容 | 7,990 | 3,776.86 |
| 项目快照以外的日志、错误输出等 | 425 | 6.59 |

这不是最终删除数量。其余 6,929 个文件还混有原图、编辑源、录像、旧试稿和重复产物；其中也有大量可清理内容。完整目录统计及已定位的来源见[机器可读梳理清单](artifacts_audit_candidates_20261015.json)。

## 必须先从临时目录提取的内容

### 当前初心者动作

已逐项定位 **61 张来源图，合计约 12.97 MiB**，覆盖当前 8 类、61 帧动作；来源哈希和文件存在性已核对。

| 来源 | 数量 | 当前用途 |
|---|---:|---|
| `previews/player_actions_video_20261014/` 等原制作路径 | 34 | 待机 1、攻击 7、持续施法 8、移动施法 8、现行前跳 10 |
| `previews/player_move_128_20261014_r02/refs/play_move1.png` 至 `play_move8.png` | 8 | 当前普通移动 |
| `previews/novice_new_actions_20261015/r01/refs/` | 19 | 移动攻击 9、新后跳 10 |

建议按当前动作名归档到 `sources/player_actions/novice_128/`，仅留一套已采用来源，不保留全部视频拆帧、分类压缩包、缩略图、对比图和逐轮处理包。原视频位于项目外的下载目录，不在本次 `artifacts` 处置范围。

编辑稿有一个实际问题：`editable/player_actions/novice_128/` 中现有 79 份 PXG，只有 63 份能匹配当前图集中的帧，覆盖 53 个当前帧；另外 16 份是旧普通移动和旧前跳。

- 当前普通移动的 8 份正确 PXG 在 `previews/player_move_128_20261014_r02/delivery/editable/play_move1.pxg` 至 `play_move8.pxg`。逐像素核对与正式 `move.png` 的 8 帧一致，应归档并替换旧稿记录。
- 原目录 `move_00.pxg` 至 `move_07.pxg`、`jump_forward_00.pxg` 至 `jump_forward_07.pxg` 共 16 份不匹配当前动作，建议删除。
- 原目录 `jump_backward_00.pxg` 至 `jump_backward_09.pxg` 与新目录的现行前跳重复，可在保留按当前名称登记的一份后删除重复稿。
- 整理目标是与当前 **61 帧一一对应的 61 份编辑稿**，配套必要色板和最新来源映射。

### 当前洞穴场景

以下 **7 张原图，约 5.97 MiB**，仍在 `analysis/battle_scene_20261012/sucai/`，在现有 `sources/` 中未发现相同哈希副本：

- `1-最远处背景/far_background_1.png` 至 `far_background_5.png`：当前拼接洞穴远景的 5 张原图。
- `2-远景/ground_view1 (6).png`：拱门、柱子、方尖碑、灯的共同来源。
- `4-近景/front_view1.png`：四角前景原图。

来源关系由 `scripts/tools/export_cavern_scenery.py` 和当前场景配置确认。建议归档到 `sources/cavern/`。

岩石与木头使用的 `ground_Barier1.png`、`ground_wood1.png` 在 `sources/sucai_20261011/` 已有来源副本，只需保留一份。该旧附件目录的其余图不能因“在 sources 中”就全部保留，应依据当前素材逐项去旧。

碎砖、碎石等 Q 系列的最后一次处理仍读取 `analysis/obstacle_revision_v02_20261013/sources/` 中的历史输入。执行清理时，应先确认其中哪些是当前稿的唯一制作输入，再归档；不要将整个 `sources/` 子目录一并归为截图。

## sources 和 editable 内部也有可清理项

| 路径或内容 | 建议与证据 |
|---|---|
| `sources/character_frames/`：37 张、16.41 MiB | 旧 Boss 攻击/行走、旧普通怪、旧初心者帧。当前钢甲骑士和普通怪使用 `sources/enemies/` 中更新的原图，初心者使用上文新动作来源；建议删除这批旧帧 |
| `sources/enemies/iron_knight/`：17 张 | 保留，当前钢甲骑士来源 |
| `sources/enemies/xiaoguai_move/`：7 张 | 保留，当前普通怪来源 |
| `sources/enemies/underworld_wolf/attack/01.png` | 保留，仍有对应正式资源；其余已在上轮按清单删除 |
| `sources/enemies/echo_bat/manifest.json` | 原图已在上轮删除，只剩空来源清单；可并入精简总索引后去掉空目录 |
| `sources/weapons/`、`spells/`、`relics/` | 保留当前图标对应的原始图表及裁切映射；与 `originals/` 中早期图表区别对待 |
| `sources/finance/`、`character_select/` | 保留当前桌面、短卷轴修订、选人背景及当前属性面板的来源；旧表情图、概念方案等需要去旧，不建议整目录无条件保留 |
| `sources/originals/`：27 个文件、59.33 MiB | 混合主菜单、标题、按钮、属性栏原图，以及早期武器/遗物图表、A/B/C 地面候选。保留与当前成品有关的图；早期表格可能仍供应个别未替换图标，应按映射筛选，不能整批删除 |
| `sources/ui_layout/`：7 个文件 | UI 布局草图和设计说明，按“只留正式原图”的口径可删除；必要设计文字可留在 `docs/` |
| `editable/ground_tiles/`：12 张 | 旧 A/B/C 地面色片，当前地面已替换为 `pit-ground.png`，当前编辑源索引也不再引用，建议删除 |
| `editable/finance_background/`：41 个文件 | 保留当前底图制作需要的像素底层、卷轴遮罩、网格与色板；索引哈希存在过时项，整理时先与正式稿核对 |
| 英文标题 `title_en_pixel_480.png` | 与正式 `assets/ui/main_menu/title_main_menu_en.png` 哈希完全相同，是成品副本，可删除；高分辨率 `title_en.png` 与绘制脚本保留 |

## 哪些脚本值得保留

`artifacts` 内共发现 1,599 个代码文件，其中 1,352 个在审阅项目快照中；剩余 247 个包括 89 个 Python、1 个 PowerShell、118 个 GDScript、39 个着色器/包含文件。不能把“存在脚本”直接视为“可复用”。

**明确应保留的素材绘制源：**

| 脚本 | 用途 | 建议 |
|---|---|---|
| `generated/english_promo_20261007/build_art.py` | 当前英文标题的字形与绘制方法 | 迁入 `scripts/tools/source_art/`，调整输出位置 |
| `sources/effect_drawings/build_candidates.py` | 9 个已安装的位移、风刃、链锤特效绘制函数；来源清单中的 9 个哈希均与当前 PNG 一致 | 保留绘制函数，移除旧候选打包、代码替换等一次性逻辑，再迁入 `scripts/tools/source_art/` |

**有保留价值，但需要整理后才能算可复用工具：**

- `previews/player_move_128_20261014_r02/process_move.py`：当前移动帧的去背景、修边和面部处理；应去掉固定任务目录，改为显式输入输出。
- `previews/novice_move_attack_backjump_20261015/r01/process_video.py`：源视频拆帧和动作对齐；应去掉固定下载文件名及审阅包依赖。
- `previews/player_actions_video_20261014/moving_sustain_r01/compose_moving_sustain.py`：当前移动施法帧的合成过程；必要输入应随原图归档。
- `previews/cavern_foreground_d03/20261014_v01/refine.py` 和 `previews/cavern_foreground_all/20261014_v01/refine.py`：当前前景的局部修整配方；只提取仍对应正式稿的处理逻辑。
- `reviews/pit_sunlight_r01/build_assets.py`：当前云噪声、岩石受光遮罩的生成逻辑。两个生成图与现行正式图哈希相同；应保留生成部分，去掉审阅着色器拼接逻辑。
- `reviews/ground_reference_r02/build_ground.py`：当前地面与分布图的制作配方，生成图与正式 `pit-ground.png`、`pit-ground-context.png` 哈希一致；但它依赖上轮已删除的旧地面输入，**目前不能直接复建**，应标注此限制并整理可独立复用的部分。

已有通用素材工具在 `scripts/tools/` 和 `.agents/skills/`，不需要为了保存工具而保留整个审阅项目。截图拼版、录像编码、启动临时服务器、旧版本安装/回退、一次性删除脚本、审阅专用 GDScript 和代码备份均列为清理候选。

## 清理时需要同步处理的依赖

1. `scripts/tools/build_player_action_frames.py`、`build_novice_new_actions.py` 仍读取旧 `previews` 制作路径；先迁移必要输入并修改路径，再删除目录。
2. `export_cavern_scenery.py`、`refine_cavern_bcdq.py`、`build_cavern_obstacle_catalog.py` 仍从 `analysis` 读取场景来源；需要改指向归档原图，或删除不再需要的历史审阅入口。
3. `editable/index.json` 有 **12 条素材哈希与当前正式文件不一致**，包括普通移动、Q 系列、银行底图和哥布林图集；旧角色 `source-map.json` 也有 3 条过时哈希。清理前应更新有效映射，不能把旧索引当作现状证明。
4. `previews/ground_indicators_production_20261014/baseline_project/` 下的 5 个目录联接分别指向正式 `assets`、`data_config`、`localization`、`shaders`、`.godot/imported`。清理只移除联接本身及快照文件，不能沿联接删除目标。
5. 审计报告、验证截图等文档链接会随清理失效；需要保留的结论写入 `docs/`，并移除或注明已清理的附件链接。`artifacts/.gdignore` 保留，防止 Godot 导入原图和审阅数据。

## 建议执行顺序

先建立“正式资源 → 唯一原图/编辑源 → 必要脚本”的保留清单，归档以上散落输入，修正工具路径与过时索引；随后清理项目快照、截图、日志、录像、试稿、成品副本和废弃脚本，最后核验 426 个正式媒体文件未变、保留脚本的输入完整。

本轮已完成目录全量盘点、16,678 个图像/编辑源/脚本等文件的哈希扫描、当前动作 PXG 与图集像素核对。上述数量是本次扫描快照；这份报告是清理建议，不是已经执行的删除清单。
