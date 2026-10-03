# 美术原图、制作脚本与参考

正式游戏资源位于 `assets/`。本目录保留原稿、必要制作输入、脚本和说明。2026-10-03 已将 6,540 个旧预览、重复导出、截图、备份和临时文件移至仓库外的可恢复归档，本轮清单内的内容由约 382 MiB 减至 178 MiB。清单、验证与恢复方式见[清理记录](../docs/maintenance/artifacts_cleanup_2026-10-03/README.md)。

## 原图与参考

- [sources/](sources/)：角色与敌人高清帧、去重后的道具／地面／主菜单原稿，以及角色选择和银行原图。历史路径迁移见 [index.json](sources/index.json)。
- [sources/originals/title_design/](sources/originals/title_design/)：标题原始字形 SVG 与设计 JSON；按钮高清原图为 [button_copper_oil_hd.png](sources/originals/263cf9a972-button_copper_oil_hd.png)。
- [sources/character_select/](sources/character_select/)：角色选择场景原图；[sources/finance/](sources/finance/)：银行场景、属性面板、哥布林表情原图。
- [editable/ground_tiles/](editable/ground_tiles/)：12 张原生 128×128 地面色片。[editable/index.json](editable/index.json) 记录正式资源与编辑源的对应关系；与正式 PNG 重复的单层内容复用正式 PNG。
- [reference/](reference/)、[effects/](effects/)、[oil_painting/](oil_painting/)：用户提供的画风、动效和原始绘画参考。
- `wip/character_select/`、`wip/finance/` 顶层的布局图、设计说明和绘制提示词保留，供后续调整参考。

## 制作入口

| 用途 | 脚本 |
| --- | --- |
| 角色选择背景像素处理 | [process.py](wip/character_select/picxel_review/process.py) |
| 角色选择布局／UI 绘制 | [export_variants.py](wip/character_select/export_variants.py)、[render_preview.py](wip/character_select/ui_refinement_review/render_preview.py) |
| 银行属性面板像素处理 | [process.py](previews/bank_attribute_panel/r01/process.py) |
| 银行背景与灯光平移 | [R02 process.py](previews/goblin_bank_background/r02/process.py)、[edit.py](previews/goblin_bank_background/r04_lamp_left/edit.py)；R01 适配脚本仍是其依赖 |
| 简化理财框体绘制 | [build_skin.py](wip/finance/frame_skin_review_r02/build_skin.py)，无需外部图像输入，使用 Pillow 生成纹理 |
| 遗物像素制作 | `previews/relic_*/` 中保留的准备、修图、交付脚本及参数／来源记录 |

脚本依赖的选定参考、上游裁切和抠图输入保留；重复的候选图、放大预览和导出包已归档。后续重建应先运行准备、转换步骤，再运行修图／交付步骤，不能直接读取已归档的临时网格。具体依赖与恢复示例见清理记录。

主菜单、角色选择、银行背景、属性栏和简化理财框体均已接入正式资源。实际使用方式以 `assets/ui/` 和 `scripts/ui/` 为准。子目录旧 README 和 JSON 是历史制作记录，其截图、候选版本和安装包路径可能已归档；其中“尚未接入”等旧状态不代表当前游戏状态。

## 暂时保留的活动数据

项目 Picxel 面板当前使用的敌人样例、遗物 R02／R03、银行背景输入与工作输出继续保留。遗物第五批的未完成制作输入也保留。清理期间另一个铁骑士制作任务新建的 `previews/knight_source12_animation/` 及其正式资源更新未作改动，因此 `previews/`、`wip/` 内仍有活动任务产物。

后续已停止占用 `flat_hover_review/` 的旧角色选择 HTTP 服务（端口 8782），将仅剩的两份日志移入同一归档的 `_followup/flat_hover_review/`。原目录已移出，记录见 [flat_hover_followup.json](../docs/maintenance/artifacts_cleanup_2026-10-03/flat_hover_followup.json)。

归档位置：`C:/Users/mi/CodexArtifactArchives/infinite-build-dome-survival-20261003-090240`。原始输入和保留文件已核对；本次清理没有写入正式游戏资源或代码。本次只是迁出中间文件，没有释放归档所占的磁盘空间。
