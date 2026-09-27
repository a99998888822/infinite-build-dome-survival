# 单圈扩散水流（已接入）

2026-09-26 已按用户确认替换正式水流。当前正式实录：[水流动图](../../reviews/effects/water.gif)。本目录的[原草稿动图](water_expansion.gif)与绘制源稿保留作设计出处。

圆形波浪边缘从小向外扩散，带卷曲泡沫和淡回流波纹，无新增的两层内浪。最大半径 78.54，较原参考半径 92.4 缩小 15%；单次 0.85 秒。

绘制已移入 `scripts/effects/water_wave_effect.gd`，正式最大伤害半径同步缩至78.54，动画时长同步为0.85秒。伤害与打湿仍在生成时一次结算；逐帧扩散伤害不属于这次视觉替换。`range_check.json` 是此前草稿阶段的隔离边界检查记录。

正式录制使用 `scenes/tests/water_effect_live_capture.tscn`，参数为 `--transient-session --variant=water --capture-dir=<绝对路径>`。本目录录制脚本属于旧草稿阶段；新增原始帧与日志继续写到系统临时目录。
