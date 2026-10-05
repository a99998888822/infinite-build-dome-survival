# 11张附魔32×32图标正式接入

> 历史记录：2026-10-05 已更新为用户确认的19张64×64法术图标，电火花与落雷各用独立图标。当前素材与验证见[64版接入记录](spell_icons_64_installation_2026-10-05.md)。以下描述保留当时的32版状态。

用户已选定32×32稿并授权替换。11张透明PNG及对应PXG／PAL已安装到 `assets/ui/icons/augmentations/`，覆盖12条配置；电火花与落雷继续共用闪电图。弹跳的引用已由SVG改为PNG，其余配置内容保持原样。旧SVG留存但不再被附魔配置引用。

工作台背包图标由20px调整到原生32px，卡片高度相应增加；装备槽图标区域及滚动容器同步留出空间。ESC背包和拖拽预览保持新图标原生32px，使用最近邻过滤；掉落物沿用原生比例，现在显示32px。未更换导航栏、按钮、边框，也未改武器／附魔玩法参数。

已核对正式PNG与审阅导出的哈希一致、PNG与网格一致；10张原有PNG的导入元数据保留，新增PNG由Godot生成导入文件。旧素材、配置与本轮修改前的UI脚本已备份。其他90件遗物和11件武器文件未改，64px附魔候选稿保留。

验证：Godot无界面导入通过；附魔掉落回归57项、附魔素材与工作台检查93项、既有工作台回归16项均无失败。真实GPU工作台在1152×768与1024×576下检查97项，覆盖全部12条记录的展示、新增PNG的装备槽显示以及小窗口滚动／选择，前台抢占采样0。测试退出时显式停止BGM，已消除早期无界面审阅退出时的音频资源残留告警；工程导入仍有与本任务无关的Android build-tools目录提示。

- [安装与备份](../../../artifacts/previews/art_refresh_v1/augmentations_sheet_01/pixel32_r01/installation/assets.json)
- [完整验证记录](../../../artifacts/previews/art_refresh_v1/augmentations_sheet_01/pixel32_r01/installation/verification.json)
- [大窗口完整展示](../../../artifacts/previews/art_refresh_v1/augmentations_sheet_01/pixel32_r01/installation/captures/augmentations_1152x768.png)
- [小窗口末项滚动与选择](../../../artifacts/previews/art_refresh_v1/augmentations_sheet_01/pixel32_r01/installation/captures/augmentations_end_1024x576.png)
- [下一批：4个角色静态母稿](batches/characters_sheet_01/README.md)

物品图标阶段至此完成112／112：90张遗物64px、11张武器64px、11张附魔32px。角色、战场、理财大框和主界面等其他美术类别仍按方案继续，不能将物品图标收尾视为全项目美术完成。
