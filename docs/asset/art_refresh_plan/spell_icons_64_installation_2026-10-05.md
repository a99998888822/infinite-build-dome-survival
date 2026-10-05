# 19张法术图标64×64正式接入

用户确认 `20261005-all64-r2` 审阅稿后，19张透明PNG及对应PXG／PAL已安装到 `assets/ui/icons/augmentations/`。原图第二排第四格按用户说明忽略。全部正式PNG与批准稿哈希一致，尺寸64×64，透明通道仅0／255，每图最多16色，有透明边距，PXG与PNG像素一致。

按中文名称匹配配置，保留既有玩法ID。电火花对应 `scroll_lightning.png`，落雷对应独立的 `scroll_electric_spark.png`；仅更新落雷的图标路径，未修改玩法参数。

ESC背包、拖拽、附魔背包及装备槽继续使用32px图标显示区域，采用最近邻等比缩放；掉落物按纹理尺寸缩放到32px，避免64px纹理使其外观变大。卡片尺寸、布局和拾取逻辑保持原样。

- 原图：[fashu_icon.png](../../../artifacts/sources/spells/fashu_icon.png)
- 来源格位、名称、正式路径与哈希：[来源清单](../../../artifacts/sources/spells/fashu_icon_manifest.json)
- 批准稿：[审阅说明](../../../artifacts/previews/spell_icons/20261005-all64-r2/README.md)
- 可编辑源索引：[index.json](../../../artifacts/editable/index.json)

当前同名PXG是重建依据。旧属性图标生成器和历史32px稿不能覆盖当前确认稿。

验证完成：Godot无界面导入成功；素材／界面171项、掉落63项、属性附魔262项检查全部通过。后台GPU检查175项全部通过，生成1152×768与1024×576两种尺寸、首尾滚动状态共4张实机截图，已逐张检查。实际引擎桌面与专用桌面一致，前台抢占采样0。工程导入仅保留既有Android build-tools目录提示，运行检查无脚本错误或警告。

截图、日志、验证JSON及替换前备份保存在外部审阅目录：`C:/Users/mi/.codex/visualizations/2026/10/04/01a104c9-baaa-7751-9d04-db1d997cefc6/spell-icons-64/`。

同日后续布局修正：去掉金币信息框、附魔内容框额外的6px宽度，与标签栏及底部框的右侧对齐。附魔背包改为最多四列，卡片最小宽度84px，按滚动区域可用宽度平均分配；缩小横向留白和放大镜，保留32px法术图标、11px名称与40px卡片高度。过窄的非场景布局仍可减少列数。

最终后台实机检查367项通过，覆盖1152×768、1024×576和1000×540的四列、名称完整显示、右边缘对齐与末项滚动选择。引擎运行在已核验的专用桌面，前台抢占采样0。最新截图与日志：`C:/Users/mi/.codex/visualizations/2026/10/04/01a104c9-baaa-7751-9d04-db1d997cefc6/enchantment-layout-four-columns/`，以 `gpu-r2.log`、`gpu-r2.json` 和 `captures-r2/` 为最终结果。

后续等距修正：附魔内容区域左右都留12px，四列卡片随可用宽度等分收窄，使最左和最右卡片到大框的留白一致。法术图标、名称字号、四列布局保持原样。对应截图和布局测量日志位于外部审阅目录的 `enchantment-equal-padding/`。
