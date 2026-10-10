# 小 Boss 霸体视觉正式接入

2026-10-10，按用户确认将 V02 暖色流动描边与“霸体”飘字接入钢甲骑士、幽焰冥狼。正常游戏自动启用，不依赖 artifacts 或 review 开关。

## 行为

- 实际抵抗减速、潮湿减速、冻结、致盲、眩晕或击退时触发；包含普通命中／接触击退、风刃、震荡波和黑洞牵引。
- 钢甲骑士仍保留 0.1 控制倍率，冥狼仍保留 0.25 控制倍率；既有风刃／震荡位移免疫不变。这里的“霸体”是抗控反馈，未额外增加无敌或完全免控时段。
- 描边在最后一次触发后维持 2 秒，文字约 0.8 秒；连续触发延长描边，不重复弹字。暖色轮廓以 0.88 圈／秒流动。
- 独立轮廓 Sprite 跟随真实动画帧、镜像、偏移、旋转和体型缩放，不占用敌人本体材质，兼容 R02 受击闪白。暂停冻结视觉计时，死亡／重新初始化／波次清理立即隐藏。

正式入口：`scripts/enemies/enemy_controller.gd`；显示组件：`scripts/effects/enemy_super_armor_visual.gd`；着色器：`assets/shaders/enemy_super_armor.gdshader`；本地化键：`combat.super_armor`。

## 验证与截图

- 霸体专项 31 项、玩家属性回归 92 项、R02 回归 24 项，共 147 项通过；最终日志无脚本错误或资源泄漏提示。
- Godot 无窗口编辑器检查通过。环境已有 Android build-tools 目录提示及 tmp 内嵌工程忽略警告，与本次资源接入无关。
- 真实 GameRoot 战斗场景由测试脚本固定敌人位置并调用正式击退接口，以 20fps 确定性步进观察触发、轮廓流动、换帧、镜像及消退。这是可复现的战斗审阅布置，不是自然刷怪录像；未将显示效果合成进游戏截图。
- GPU 捕获在私有 Windows 桌面完成，实际引擎桌面匹配，`foreground_samples=0`。完整证明、截图和动图位于 `artifacts/validation/super_armor_install_20261010/`。
- `review.png` 是第 0.35 秒战斗截图的局部最近邻 2 倍放大；`review.gif` 包含 2.4 秒完整变化。旧 sandbox 已清理，保留正式实现及本轮证据。

复现：`scenes/tests/enemy_super_armor_test.tscn`；截图：通过 `scripts/tools/run_godot_background.py` 运行 `scenes/tests/enemy_super_armor_capture.tscn`，传入 `--transient-session --capture-dir=<输出目录>`。
