# 钢甲骑士原色12色完整动画接入（2026-10-03）

用户确认单帧样例后授权处理完整动画并接入战斗。本次安装16张唯一128×128帧，整组共用12色，组成待机1、行走6、蓄力7、冲刺2、收招1共5张图集。待机取行走第6帧，与确认样例逐像素相同。

沿用样例的3×3局部中值清理与原色量化，按各帧姿势保护头盔、握锤连接、腰扣及轮廓高光。每帧alpha、画布、脚底与动作位置保持原样。原第3、8攻击帧的锤顶裁切继承现有源图。

## 接入与验证

- 正式PNG与交付图集哈希一致；16张网格渲染与对应图集裁切逐像素一致。
- 实际场景保持既有1.12显示比例、半径33.6碰撞体及 `(0,-60.48)` 偏移，素材变更未修改场景、控制器与敌人数据。
- `SpriteFrames` 的UID、动画参数和裁切保持原样。历史安装器按文本格式比较资源，无法接受既有Godot UID序列化；本轮通过图集规格校验及引擎专项测试核验实际布局。
- Godot无窗口编辑器导入通过；现有 `iron_knight_test` 69项检查通过，未发现错误或警告。
- 正式GameRoot实机录制420帧，覆盖全部16张唯一动画帧及spawn、chase、windup、dash、recover、dead，验证遗物掉落。
- GPU在私有Windows桌面完成，实际桌面匹配，`foreground_samples=0`。
- 已查看帧组、实机动作分段截图与GIF解码画面，确认主要色块、透明边界和战斗背景对比。

## 文件

- [战斗动图](../../../artifacts/previews/knight_source12_animation/r01/delivery/live/battle.gif)
- [局部放大动图](../../../artifacts/previews/knight_source12_animation/r01/delivery/live/battle-detail.gif)
- [完整视频](../../../artifacts/previews/knight_source12_animation/r01/delivery/live/battle.mp4)
- [接入校验](../../../artifacts/previews/knight_source12_animation/r01/installation/validation.json)
- [旧版备份](../../../artifacts/previews/knight_source12_animation/r01/installation/previous/)
- [来源与逐帧处理记录](../../../artifacts/previews/knight_source12_animation/r01/method.json)

原始视口帧保存在系统临时目录；本轮审阅图、正式交付帧和实机成品位于 `artifacts/previews/knight_source12_animation/r01/`。
