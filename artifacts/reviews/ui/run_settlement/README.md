# 死亡 / 通关结算 · 正式界面

已接入游戏。本目录截图由正式 Godot 控件渲染，账单使用固定测试数据，便于对比四种对白与布局；不是一次实际游玩的战绩。

- [听从建议后死亡](death_followed.png)
- [拒绝建议后死亡](death_refused.png)
- [听从建议后通关](victory_followed.png)
- [拒绝建议后通关](victory_refused.png)
- [640×360 小窗口](compact_640.png)
- [360×640 竖屏](compact_360.png)

主标题为「冒险结束」，下方小字显示「第x波 阵亡」或「通关！」。底部只保留「返回主界面」。按钮立即可用；点击空白处、空格、Esc 可结束演出，停止后续音效。

正式配置：`data_config/run_settlement.json`。美术：`assets/ui/settlement/`。声音：`assets/audio/sfx/settlement/`，保留五级递升结算声。四种反应的 `voice_path` 均已置空，文字台词照常显示。

添加配音时，将音频文件放入项目资源目录，再填写对应 `reactions` 项的 `voice_path`，例如 `res://assets/audio/sfx/settlement/my_voice.ogg`。路径为空或资源不存在时跳过播放；`speech` 单独控制文字台词。

验证：`scenes/tests/run_settlement_test.tscn`，使用 `--transient-session`；可加 `--capture-dir=artifacts/reviews/ui/run_settlement` 重建截图。实机检查 74 项通过，包含统计去重、保存失败回滚、重复结算、四种对白、实际鼠标与键盘输入、三种分辨率、死亡边界、通关结息与全额存款顺序。

相关回归：下一波挑战 71 项、哥布林交易 98 项、利息演出 40 项、经济流程 57 项通过。Bootstrap 自检通过、配置校验错误为 0。旧 Bootstrap / 经济测试退出时会报告音频资源仍在使用；详细检查定位为既有 BGM Ogg 播放资源，新结算专项在停止 BGM 后清理正常。

完整规则见 [设计与实现说明](../../../../docs/main/23-run_settlement_design_review.md)。过期离线初稿已清理。
