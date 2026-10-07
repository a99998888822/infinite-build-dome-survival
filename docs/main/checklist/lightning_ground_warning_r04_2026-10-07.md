# 落雷地面电弧与 PNG 预警 R04 正式安装记录

2026-10-07，按用户审阅后的明确授权，将 R04 候选安装到正式项目。

## 安装内容

- 黄色旋转预警改为 256 个 PNG 方向帧和单个 MultiMesh 批次，保留 24 粒子、轨迹、范围、亮度和渐隐。范围变化只移动粒子中心，不放大粒子及小辉光。
- 落雷地面电弧使用两张 PNG 形态，与主闪电共用同一个时钟：亮 0.16 秒、暗 0.04 秒、第二段亮 0.16 秒，默认合计 0.36 秒。暂停和持续时间倍率同步生效。
- 保留原有命中 PNG 飞溅、伤害、战锤落雷密度与 10° 多投射物夹角。

安装范围为已审阅的 20 个文件，包括运行脚本、着色器、两张 PNG 图集、导入设置和专项测试。20 个文件均按 SHA256 核对，与 R04 审阅清单一致。安装前的两个已有脚本已备份，其他文件为新增文件。

- [安装清单、哈希与验证日志索引](D:/project/useless/review-archives/lightning-ground-arcs-20261007-r04/installation/installation.json)
- [旧资源备份：闪电控制脚本](D:/project/useless/review-archives/lightning-ground-arcs-20261007-r04/installation/backup/scripts/effects/lightning_particle_effect.gd)
- [旧资源备份：黄色预警脚本](D:/project/useless/review-archives/lightning-ground-arcs-20261007-r04/installation/backup/scripts/effects/electric_spark_effect.gd)
- [原审阅记录](D:/project/useless/review-archives/lightning-ground-arcs-20261007-r04/review.md)

## 正式项目验证

使用 Godot 4.7.2，在无界面、临时存档会话中完成检查，没有启动可见游戏窗口。

| 检查 | 结果 |
| --- | --- |
| Headless editor 导入及脚本解析 | 退出码 0，无错误或告警 |
| warning_test | 29 项，0 失败 |
| lightning_ground_arc_test | 364 项，0 失败 |
| lightning_pixel_test | 107 项，0 失败 |
| lightning_hit_png_test | 130 项，0 失败 |
| hammer_density_test | 230 项，0 失败 |
| enchantment_stacking_test | 242 项，0 失败 |
| 正式主场景 120 帧 | 正常启动、退出码 0；强制退出音频告警见下文 |

六组相关测试合计 **1102 项，0 失败**。安装文件的 UTF-8、异常替换字符和差异空白检查通过。

主场景用 `--quit-after 120` 强制退出时，仍报告此前安装记录中已有的 4 个音频实例、2 个资源未释放。详细日志确认资源为菜单 `bgm_menu.ogg` 及其 `OggPacketSequence`，实例为对应的 Ogg 播放对象；未列出本次 PNG、粒子或材质资源。因此不能把这次主场景日志描述为完全无错误。该历史音频退出问题未在本次特效替换中改动。

[正式主场景详细日志](D:/project/useless/review-archives/lightning-ground-arcs-20261007-r04/installation/formal-main.log)

## 已审阅的性能证据

R04 审阅阶段的三轮对照中，单路落雷平均帧耗时中位数为 12.08 → 5.02 ms，密集三路为 49.87 → 8.43 ms；完整预警画面保持显示。这些数值来自隔离审阅工程的固定场景，本次安装没有重跑性能基准，也不将原动图标注为正式项目重新录制。

[R04 性能记录](D:/project/useless/review-archives/lightning-ground-arcs-20261007-r04/performance-summary.json)
