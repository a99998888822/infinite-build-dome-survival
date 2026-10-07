# 闪电命中 PNG R02 正式安装记录

2026-10-07，按用户审阅后的明确授权，将 R02 候选安装到正式项目。

## 安装结果

- 电火花／闪电链与落雷的命中飞溅改为 PNG 帧动画。单颗粒子继续独立运动，GPU 从图集中选帧；每次命中使用两组 MultiMesh。
- 相对于恢复原始数量的 R01，数量系数为 `0.5`，飞溅距离系数为 `0.5`，整数粒子数按配置取整。
- 保持已审阅的辉光半径：额外半径系数 `0.5`；叠加闪电链原有系数后，链式命中的总系数为 `0.25`，落雷为 `0.5`。
- 新命中飞溅不占用 ParticleWorld 的 900 个槽位，普通粒子池满时仍可播放。此保证针对这次迁移的闪电命中效果；其他普通粒子仍受旧池上限约束。
- 保留原有辅助地面光场。闪电线条、落雷预警与落地扩散圈继续使用现有程序绘制。
- 裂地战锤的落雷密度和多投射物 10° 夹角逻辑未在本次安装中重写，并通过对应回归测试。

安装 20 个文件，包括 4 张 PNG、导入设置、运行脚本、着色器及测试。已逐文件核对 SHA256，与 R02 审阅清单完全一致。正式项目已有的其他修改未由安装脚本覆盖。

候选和安装证据：

- [R02 审阅清单](D:/project/useless/review-archives/lightning-png-impact-20261007-r02/verification.json)
- [安装记录与文件哈希](D:/project/useless/review-archives/lightning-png-impact-20261007-r02/installation-20261007-103507/installation.json)
- 原有文件备份目录：`D:/project/useless/review-archives/lightning-png-impact-20261007-r02/installation-20261007-103507/backup/`。

## 正式项目验证

Godot 4.7.2，无界面导入和运行，使用临时存档会话。

| 检查 | 结果 |
| --- | --- |
| Headless editor 导入／脚本解析 | 退出码 0，无解析或编译错误 |
| lightning_hit_png_test | 130 项，0 失败 |
| lightning_pixel_test | 107 项，0 失败 |
| enchantment_stacking_test | 242 项，0 失败 |
| hammer_density_test | 230 项，0 失败 |
| 主场景 120 帧 | 启动成功、退出码 0；退出时仍有音频资源告警，见下文 |

安装前，后三组回归测试也分别为 107／242／230 项、0 失败。全部四组安装后测试合计 709 项。

主场景退出时报告 4 个 ObjectDB 实例、2 个资源未释放。追加 `--verbose` 后，两个资源明确为 `bgm_menu.ogg` 及其 `OggPacketSequence`，另外两个实例是对应的音频播放对象；未列出闪电 PNG、材质或粒子对象。该退出告警尚未修复，因此不能把整次验证描述为“所有日志无错误”。安装脚本因捕获到该告警返回 1，但文件安装和哈希验证均已完成。

[主场景详细日志](D:/project/useless/review-archives/lightning-png-impact-20261007-r02/installation-20261007-103507/after-main-verbose.log)

R02 原审阅动图来自隔离候选项目，保留为已批准外观的证据，不标注为本次正式项目重新录制。正式项目这次运行的 GPU 对照图是结霜诊断，见[特效绘制审计](D:/project/useless/resources/infinite-build-dome-survival/docs/main/effect_rendering_audit_2026-10-07.md)。
