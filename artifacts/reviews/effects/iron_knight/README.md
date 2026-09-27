# 钢甲骑士实机验证

- [实机动图](game.gif)：7 秒，截取实际 Godot 视口并最近邻放大 2 倍。
- [录制数据摘要](capture_summary.json)。

录像启动正式 `GameRoot`、战斗场景和 `WaveManager`，展示骑士出现、追赶、预警、冲刺挥锤、收招、宽站姿及死亡掉落。为清楚展示，录制固定了刷怪环境，由脚本控制玩家侧移、终结骑士，并临时关闭拾取吸引，让奖励保留在地面。怪物动作、距离限制、预警和掉落使用正式实现。

## 检查结果

| 检查 | 结果 |
| --- | --- |
| 骑士专项：距离、动画、伤害、胶囊边界、暂停、障碍 | 41 / 41 |
| 精英掉落衰减、波末奖励、数量调度、原属性倍率 | 71 / 71 |
| 控制抗性与已有元素联动 | 13 / 13 |
| 侵蚀属性与实际伤害 | 64 / 64 |
| 合计 | 189 项断言通过 |
| Godot 无界面编辑器导入、主场景启动 | 通过，无 Parse/Compile/SCRIPT ERROR |
| 实机状态与遗物掉落观察 | 六种状态及实际遗物掉落均观察到 |

新骑士专项场景正常退出。主场景和部分旧回归场景退出时仍报告 Canvas / CanvasItem / ObjectDB 或资源未释放提示，本次未修改这些场景的通用生命周期。编辑器另外提示本机 Android build-tools 目录不可用；本次验证目标为 Windows 桌面运行。

实机录制使用 Godot 4.7.2 的 `opengl3_angle` 驱动。默认 OpenGL 录制启动耗时较长，因此仅对录制命令切换驱动，没有改变项目默认渲染配置。原始视口帧与完整采样数据保存在系统临时目录，仓库只保留本页成品。

## 重现

使用 Godot 运行 `scenes/tests/iron_knight_live_capture.tscn`，参数包括 `--rendering-driver opengl3_angle --fixed-fps 60 -- --transient-session --capture-dir=<临时目录>`，然后执行：

```text
python -B scripts/tools/assemble_iron_knight_capture.py <临时目录>
```

资源导出与逻辑说明见 [钢甲骑士接入记录](../../../../docs/asset/iron_knight_integration.md)。
