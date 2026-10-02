# 直线落雷测试原型

目标：从玩家右侧开始，落点每隔 0.1 秒向右推进，预警后依次劈下，用于审阅新攻击类型的节奏。

## 当前参数

- 8 个落点；首个距玩家 40 像素，间距 64 像素，最后一个距玩家 488 像素。按审阅意见拉开间距，让黄色预警圈在旋转时也留有空隙。
- 每 0.1 秒生成一个预警，沿施放时锁定的水平线向右推进。
- 完整复用 `scroll_electric_spark` 的 `ElectricSparkEffect`：0.5 秒预警、黄色环、落雷、命中伤害与音效。实际落地还经过原有调度器，存在帧级延迟。
- 同一目标可能被相邻落点重复命中，这是原有独立落雷的范围判定行为。
- 目前仅为独立测试场景。短刀实例只提供附魔和伤害上下文，正式武器列表和普通战斗逻辑没有新增此攻击。

## 文件与运行

- `scripts/tests/lightning_line_sequence.gd`：时间和落点序列，参数通过导出属性调整，遵循战斗暂停。
- `scenes/tests/lightning_line_preview.tscn`：6 秒、30 FPS 的固定审阅场景。第一轮演示空地落雷，第二轮增加三个固定目标和一个范围外目标。
- `scripts/tests/lightning_line_preview.gd`：真实 GameRoot、附魔挂载、命中检查、逐帧截图。目标停止追击，但仍调用正式伤害逻辑；不改存档。

此录制场景按固定 30 FPS 校验，使用下面的命令运行：

```powershell
& 'D:/soft/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' `
  --headless --path . --scene res://scenes/tests/lightning_line_preview.tscn `
  --fixed-fps 30 --quit-after 1000 -- --transient-session `
  --capture-dir="$env:TEMP/lightning-line-spacing64-review/headless"

python scripts/tools/run_godot_background.py `
  --godot 'D:/soft/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' `
  --log "$env:TEMP/lightning-line-spacing64-review/capture.log" --timeout 180 -- `
  --path . --scene res://scenes/tests/lightning_line_preview.tscn `
  --rendering-method gl_compatibility --rendering-driver opengl3_angle `
  --resolution 1152x768 --fixed-fps 30 --quit-after 1000 -- `
  --transient-session --capture-dir="$env:TEMP/lightning-line-spacing64-review/frames"
```

图形运行继续使用私有后台桌面，不切换用户桌面。截图、GIF 和日志均放系统临时目录，不写入 `artifacts`。

## 审阅结果

- 无界面和真实 GPU 录制均通过 10 项检查：两轮共 16 个落点，间隔和方向正确，每个落点均延迟落地，行内三个目标受伤，行外目标未受伤，伤害归属保留。
- GPU 录制确认 `verified_desktop` 为私有桌面，`foreground_samples=0`。
- `lightning-line-spacing64.gif`：实机区域裁剪后最近邻放大 2 倍，保持原速，已检查黄色预警圈之间留有空隙；`lightning-line-full.mp4`：完整视口原速视频，无音轨。
