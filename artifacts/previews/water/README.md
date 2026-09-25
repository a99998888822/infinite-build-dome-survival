# 单圈扩散水流（待审阅）

最新草稿：[动图](water_expansion.gif)。未替换正式水流；已经确认的组合效果见 [元素实录](../../reviews/effects/)。

圆形波浪边缘从小向外扩散，带卷曲泡沫和淡回流波纹，无新增的两层内浪。最大半径 78.54，较原参考半径 92.4 缩小 15%；单次 0.85 秒。

`expanding_water_draft.gd` 是待接入的绘制源稿。`range_check.json` 记录隔离场景内真实水流伤害查询的最大半径检查：同步缩至 78.54 后，碰撞体与边界重叠 3 像素命中，边界外相隔 3 像素不命中。正式伤害配置尚未修改；逐帧扩散伤害也尚未实现。

从项目根目录依次运行 `python artifacts/previews/water/build_preview.py prepare`、同一脚本的 `capture`、`export` 可复现。需要 Godot、Python/Pillow 与 FFmpeg；原始帧、隔离工程及日志写到系统临时目录。
