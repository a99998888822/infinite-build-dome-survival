# 美术源文件

本目录保留原始素材、必要参考、编辑源索引和说明。正式游戏资源与对应的 PXG/PAL 编辑源位于 `assets/`。

2026-10-07 清理完成：删除 1,142 个中间文件，共 342.18 MiB；原图、编辑源、报告数据和必要的最终对照附件保留。逐帧截图、缓存、旧版重复导出、一次性脚本和旧源码副本已删除。历史报告提及的原始日志已归纳为[验证日志摘要](maintenance/validation_log_summary_20261007.json)，包含测试结果及错误、警告上下文；它们是历史记录，不代表重新运行测试。详见[本轮清理报告](maintenance/cleanup_20261007.md)与[逐文件哈希清单](maintenance/cleanup_20261007.json)。

| 目录 | 保留内容 |
| --- | --- |
| [sources/](sources/) | 用户原图、角色与敌人原始动画帧、UI 原图及布局说明 |
| [reference/](reference/) | 用户提供的画风、油画、场景和动效参考；包括明确要求保留的[冰元素组合实机 GIF](reference/effects/ice-combos/README.md) |
| [editable/](editable/) | 12 张原生地面色片、理财底图最终像素网格与合成遮罩，以及正式资源与编辑源的对应索引 |
| [performance/](performance/) | 性能报告、测量数据、必要的原始绘制参考和最终对照附件 |
| [previews/](previews/) | 历史审阅报告及最终附件；未正式采用的霸体设计保留独有源码和审阅页 |
| [reviews/](reviews/) | 敌人强度及压力曲线报告、数据和图表 |
| [maintenance/](maintenance/) | 清理明细、完整性核对记录及历史验证日志摘要 |

[来源索引](sources/index.json) 记录原路径、归集后的路径和 SHA-256；[编辑源索引](editable/index.json) 指向当前存在的正式 PNG 或可编辑网格。标题的 SVG 字形与设计 JSON 属于原始设计源，继续保留。

2026-10-04 按用户要求删除多轮审阅图、实机截图和动图、重复导出、旧资源备份、抠图中间稿、临时网格、一次性代码及处理配置。清理前先将散落的钢甲骑士、小怪、银行等原图归入 `sources/` 并核对哈希；正式素材和游戏代码保持不变。

2026-10-05 再次清理 `previews/` 中的中间稿、重复导出、旧备份、实机审阅媒体和一次性代码配置。四张遗物原图及84件图标的名称、裁切位置、B／D选择、正式PNG／PXG／PAL路径与哈希保留在[遗物来源映射](sources/relics/yiwu_icon_manifest.json)。正式资源、游戏代码和现存原始素材均保留。

本次移出3922个文件，合计605.67 MiB，采用可恢复归档，位置为 `D:/project/useless/review-archives/artifacts-cleanup-20261005/`。永久递归删除被自动审批策略拦截，回收站操作未成功，因此没有永久删除文件或释放磁盘空间。已结束两个只服务旧审阅目录的临时HTTP进程并移除空目录。

清理前发现银行原图 `sources/finance/finance_bank_desktop.png` 已缺失，历史路径和下载目录也未找到副本；来源索引保留原哈希并注明缺失状态。另一张缺失的银行画风参考已从原始剪贴板文件恢复，哈希一致。银行其余原图、布局参考及正式底图仍在。

旧文档中的已清理路径仅表示历史制作位置；后续编辑从本目录原图和 `assets/` 中的正式编辑源开始，审阅截图可通过项目现有工具重新生成。当前安装规格见 `docs/asset/`。独立附魔优化审阅工程仍在 `D:/project/useless/review-archives/enchantment-opt-20261004/`，本次只清理其在 `artifacts` 中的临时导出；说明见[动效参考记录](reference/effects/README.md)。

2026-10-05 未提交文件复核：删除 916 个已淘汰试稿、重复导出、旧版设置截图、运行日志、Python 缓存和两个一次性脚本（删除体积 25.28 MiB）。其中理财底图实际使用的 18 张 PXG、色板、688×384 底层与遮罩先归入 [最终编辑源](editable/finance_background/README.md)，缩短卷轴的高清修订及记录归入 `sources/finance/`；归集文件逐个核对哈希，合成结果与正式底图逐像素一致。正式代码、资源、原始素材、最新设置与理财预览，以及性能测量／审阅记录均保留。此轮执行的是文件删除，不是前述归档迁移；删除明细暂存于 `C:/Users/mi/AppData/Local/Temp/codex-cleanup-20261005/`。
