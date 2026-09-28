# 资本家：正式接入

2026-09-28。通过正式角色选择界面进入战斗，采用已替换的 Picxel 原图转换美术。名称为“资本家”，简介留空；初始武器为食利者钱袋，一个空附魔槽，不附带附魔。

| 文件 | 内容 |
|---|---|
| [selection.png](selection.png) | 角色列表、立绘与四方案生效后的实际开局属性 |
| [traits.png](traits.png) | 可滚动的特性说明、四件原遗物图标 |
| [bank.png](bank.png) | 第一波利息到账 65，本金保持 500，利率 13% |
| [walk.gif](walk.gif) | 游戏内向右、向左行走实录的中心局部，640×400、48 帧，按采集间隔播放 |

截图使用真实游戏 UI。行走演示停用刷怪，仍通过角色控制器移动；手动结束第一波展示结息，不代表实际过关表现。GIF 根据 PNG 文件时间间隔播放，取整到 GIF 的 10 毫秒精度，未改变角色动画的 6 FPS 参数。原始帧与日志保存在系统临时目录，仓库只保留上述成品。

重现：运行 `scenes/tests/capitalist_character_test.tscn`。可附加 `--transient-session --capture-dir=<系统临时目录>`；图形采集在当前机器使用 `--rendering-driver opengl3_angle`。无截图参数时执行 97 项功能检查，截图模式共 149 项；营地使用临时状态。

[完整实现与数值说明](../../../../docs/main/21-capitalist_character_design_review.md) · [美术源预览](../../../previews/player_picxel/README.md)
