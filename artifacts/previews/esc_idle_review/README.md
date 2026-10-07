# ESC 附魔介绍与全身呼吸动画

2026-10-07 已接入正式项目：ESC 武器详情中的已装备附魔可悬停查看名称和简短描述，立即显示并自动换行，移开或关闭页面时隐藏。选人界面的 idle 动画改为全身同步上下起伏，每3秒完成一轮，保持人物形状；走路和切换角色时复位。

验证记录见 `validation_summary.json`：选人界面151项无界面检查、理财准备176项回归、ESC悬停41项检查通过。私有桌面实机检查中，选人界面167项、ESC悬停41项通过；两次录制均确认实际私有桌面与预期一致，`foreground_samples=0`。

- `esc_1152_scroll_fire.png`、`esc_1152_scroll_water.png`：常规窗口附魔介绍。
- `esc_640_scroll_fire.png`、`esc_640_scroll_water.png`：小窗口换行与避让。
- `character/character_select_breath_in.png`、`character/character_select_breath_out.png`：同一角色上下起伏的两个极值帧。

`tooltip_review.tscn` 使用正式游戏场景和临时进度，验证火焰/水流图标切换、说明内容、换行、边界、只读右键及关闭重开，不写入正式存档。截图来自实际GPU渲染。
