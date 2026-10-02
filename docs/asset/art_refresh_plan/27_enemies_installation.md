# 小怪与 Boss 正式接入

2026-09-30。用户确认像素审阅稿后要求替换，已安装全部23张独立动作帧，组装为7张正式PNG。原图、像素审阅包和已安装玩家素材均保持不变。

| 对象／动作 | 单帧 | 帧数 | 来源与播放 |
|---|---|---|---|
| 天外幼体 idle | 64×64 | 1 | 移动第1帧 |
| 天外幼体 move | 64×64 | 7 | 移动1–7，7FPS |
| 钢甲骑士 idle | 128×128 | 1 | 行走第6帧 |
| 钢甲骑士 move | 128×128 | 6 | 行走1–6，6FPS |
| 钢甲骑士 windup | 128×128 | 7 | 攻击1–7，0.8秒 |
| 钢甲骑士 dash | 128×128 | 2 | 攻击8–9，0.16秒 |
| 钢甲骑士 recover | 128×128 | 1 | 攻击10，保持0.5秒 |

正式目录为 `assets/sprites/enemies/combat/` 与 `assets/sprites/enemies/iron_knight/`。两个目录均附 `frames/` 内的Picxel网格／色板，以及 `art_source_manifest.json` 来源映射。原生PNG直接使用确认稿像素，没有重新缩图、平滑或重绘。

小怪使用1倍显示，Sprite2D偏移 `(0,-8)`，保持原可见高度与脚底位置；身体碰撞半径不变。Boss保持0.7显示、半径21，128px帧的脚底参考点为 `(64,118)`，Sprite2D偏移改为 `(0,-37.8)`。帧表裁切、安装器、临时对照图工具、专项回归与素材清单同步更新。`enemies.json`、两个敌人行为控制器未修改，伤害、碰撞、预警和技能时长沿用现有逻辑。

源图限制按确认稿保留：攻击第3、8帧锤头顶部截断；第10帧没有完整回到站姿的收招。正式收招保持第10帧，结束后切回现有idle／移动，未合成过渡帧。死亡仍冻结当前姿势并淡出。

## 验证

- 7张正式贴图与来源逐帧核对，23张唯一帧的PNG与可编辑网格一致；小怪整组15色、Boss整组16色，硬透明；旧资源与修改前文件有备份。
- Godot无界面导入与主场景加载完成，无脚本解析／编译错误；安装器检查通过。
- `iron_knight_test` 67项、`elite_relic_decay_test` 71项、`elite_effect_revision_test` 13项、`erosion_pressure_test` 64项，共215项断言通过。
- 三个联动测试和主场景定时退出出现ObjectDB／资源未释放告警，日志已保留；专项67项、导入和GPU录制无这些告警。未把退出告警隐瞒为完全无警告。
- 真实GameRoot战斗录制：小怪144帧、Boss420帧；通过正式WaveManager生成敌人，观察到spawn／chase／windup／dash／recover／dead与遗物奖励掉落。骑士所有采样帧均为128×128。
- 后台桌面验证匹配，前台抢占 `0 / 6742` 次采样；没有把Godot显示到用户当前桌面。

[Boss实机动图](../../../artifacts/previews/art_refresh_v1/enemies_frames_01/install_r01/live/boss_battle.gif) · [小怪实机动图](../../../artifacts/previews/art_refresh_v1/enemies_frames_01/install_r01/live/grub_battle.gif) · [接入报告](../../../artifacts/previews/art_refresh_v1/enemies_frames_01/install_r01/installation_report.json)

备份和来源记录位于 `artifacts/previews/art_refresh_v1/enemies_frames_01/install_r01/`，原始实机帧保存在系统临时目录 `enemies-install-r01-capture`，成品动图在本轮 `live/`。像素审阅包位于相邻 `pixel_r01/`，仍可对照。
