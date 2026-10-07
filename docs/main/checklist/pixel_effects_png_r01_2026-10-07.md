# 像素特效 PNG／GPU R01 正式安装

2026-10-07，经用户审阅批准，将 `pixel-effects-20261007-r01` 候选安装至正式项目。安装严格使用已审阅的 85 文件清单：替换 9 个既有脚本，新增 76 个图集、导入配置、着色器、共享绘制及测试文件。安装后全部 SHA256 与审阅版一致。

## 已生效的效果

- 光辉剑、黑洞、光折射、结霜、持续冰壳、榴弹爆炸、秘仪书／钱币命中、蒸汽、传导及风扩散冰霜采用共享 PNG 帧或组合贴图。
- 震荡、雷火爆炸、结霜碎屑、地形碎屑及普通投射物拖尾通过共享粒子系统使用 PNG 形状采样，逐帧运动、旋转、渐变和辉光合成由 GPU 处理。
- 结霜保留完整中心分支和 6 个外围晶体，取消附近第 3／5 个冰场及全局数量触发的自动简化；基础范围、投影、透明度和伤害／控制规则保持原有值，起手碎屑为 13 颗。
- 普通粒子池保持 900 槽。池满时新命中复用最旧槽位，旧颗粒可能提前结束；拖尾继续为命中反馈让出容量。
- 已批准的闪电命中 PNG R02、粒子数量与飞溅距离减半、辉光设置，以及战锤落雷密度和多投射物 10° 夹角继续沿用。

本次范围与审阅版相同。专用程序火焰、闪电线条、落雷预警、武器局部拖尾等审阅范围之外的绘制方式仍按原实现运行。

## 备份与可追溯文件

- [安装清单及每个文件替换前／后的 SHA256](D:/project/useless/review-archives/pixel-effects-20261007-r01/installation-20261007-130042/install-manifest.json)
- [既有文件备份目录](D:/project/useless/review-archives/pixel-effects-20261007-r01/installation-20261007-130042/backup)
- [安装后校验](D:/project/useless/review-archives/pixel-effects-20261007-r01/installation-20261007-130042/installed-verification.json)
- [审阅时的文件清单](D:/project/useless/review-archives/pixel-effects-20261007-r01/verification.json)与[候选变更包](D:/project/useless/review-archives/pixel-effects-20261007-r01/candidate-changes.zip)
- [安装验证汇总](D:/project/useless/review-archives/pixel-effects-20261007-r01/installation-20261007-130042/installation-summary.json)

待替换的 9 个脚本在安装前与审阅快照一致，没有合并冲突；另核对 1,872 个既有资源／脚本均未改变。未将候选项目中的配置、其他武器行为或其他测试文件覆盖到正式项目。

UTF-8 与乱码检查通过。差异格式检查仅报告批准版中已有的两处文件末尾空行（`enemy_status_visual.gd`、`ice_field_effect.gd`）；为保持安装文件与审阅 SHA256 一致，未做额外格式清理。

回退时依据安装清单区分原先存在和新增文件：恢复备份中的旧文件，仅对清单标记为原先不存在且仍与本次安装校验值一致的文件执行移除。若文件在安装后又有修改，应先合并或另行保留，避免覆盖后续工作。

## 验证

Godot 4.7.2 无界面导入通过，无解析或编译错误。新增运行测试无界面 16 项通过，GPU 17 项通过，覆盖完整结霜、13 颗碎屑、900 槽上限、满池复用、暂停和过期回收。GPU 满池画面检测到 490 个非背景像素，来源为新碎屑及其辉光。

GPU 运行通过私有 Windows 桌面完成，实际引擎桌面与目标一致，`foreground_samples=0`，没有占用用户前台。[GPU 日志](D:/project/useless/review-archives/pixel-effects-20261007-r01/installation-20261007-130042/gpu.log) · [桌面核验](D:/project/useless/review-archives/pixel-effects-20261007-r01/installation-20261007-130042/gpu.json) · [满池验证图](D:/project/useless/review-archives/pixel-effects-20261007-r01/installation-20261007-130042/full-pool-proof.png)。

主场景运行 120 帧并退出。首轮退出出现 4 个 ObjectDB 实例／2 个资源未释放提示；随后用安装前代码和当前正式代码分别开启详细日志复测，两边均退出 0 且无警告／错误，未重现该提示。首轮原始日志保留，不将其归因于已确认的既有缺陷。[主场景复测对照](D:/project/useless/review-archives/pixel-effects-20261007-r01/installation-20261007-130042/main-comparison.json)。

安装前使用当前正式项目重新建立基线；9 组共 957 项检查的安装前后结果完全一致，未新增失败：

| 测试 | 检查数 | 安装前失败 | 安装后失败 |
| --- | ---: | ---: | ---: |
| 像素战斗特效 | 27 | 1 | 1 |
| 震荡附魔 | 38 | 0 | 0 |
| 水／冰图集 | 41 | 0 | 0 |
| 榴弹武器 | 90 | 22 | 22 |
| 秘仪书／钱袋 | 91 | 12 | 12 |
| 元素反应 | 68 | 0 | 0 |
| 附魔叠加 | 242 | 0 | 0 |
| 闪电命中 PNG | 130 | 0 | 0 |
| 战锤密度 | 230 | 0 | 0 |

当前仍有 35 项既有失败，涉及水流范围修正及榴弹、秘仪书／钱袋的数值断言。本次未改动这些断言。[安装前结果](D:/project/useless/review-archives/pixel-effects-20261007-r01/installation-20261007-130042/before/regressions.json) · [安装后结果](D:/project/useless/review-archives/pixel-effects-20261007-r01/installation-20261007-130042/after/regressions.json) · [逐组比较](D:/project/useless/review-archives/pixel-effects-20261007-r01/installation-20261007-130042/regression-comparison.json)。

## 已审阅的取舍

主要复杂效果的绘制 CPU 微基准开销下降约 79–99%，不能换算为整局 FPS 提升，当前后端没有有效的独立 GPU 计时。图集解码约 61.3 MiB；审阅微基准的引擎贴图统计峰值约从 95 MiB 增至 178 MiB。贴图均共享加载。

范围放大时 PNG 像素粗细随缩放变化；光折射旋转边缘、粒子解析运动轨迹与旧版存在细微差异。成熟结霜使用稳定帧，生长和淡出继续播放。这些行为与获批的审阅版本一致。
