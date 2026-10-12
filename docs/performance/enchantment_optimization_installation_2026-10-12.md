# 附魔特效优化正式合入记录

2026-10-12，按用户“先把目前的工作进度替换到正式资源中”的指令，已将审阅版的 16 个运行时文件合入正式工程。

## 已生效的改动

- 震荡、雷电命中碎光、短时光照、落雷预警和反射绘制使用局部密度预算；冰场实际使用已有的不同细节 PNG 图集。
- 风刃、闪电跳转与反射使用有序空间候选，并处理同帧移动、父级变换、目标增删等失效情况。
- 优化属性缓存读取、受击反馈设置查询，以及波次压力的重复首击采样。

本次安装的是已审阅脚本及 Godot 生成的 UID，继续使用现有 PNG。伤害、控制和反应次数保持原规则。极端雷火仍有较高的逐次伤害结算开销，详见原审阅报告。

## 同期改动的合并

15 个文件与审阅基线相符。`wave_manager.gd` 的波次时长逻辑已有同期修改，因此通过三方合并保留当前“从 waves 配置读取时长”的行为，同时加入压力采样优化。已核验全部 16 个安装文件的 SHA-256。

安装前备份及校验清单：

- [安装前清单](D:/project/useless/review-archives/enchantment-review-20261012-01/installation/20261012-194755/before_manifest.json)
- [实际安装清单](D:/project/useless/review-archives/enchantment-review-20261012-01/installation/20261012-194755/installed_manifest.json)

对应旧文件保存在同一安装目录的 `before` 子目录中。

## 正式工程验证

使用 Godot 4.7.2 的 headless 模式执行，没有打开游戏窗口或抢占前台。

| 检查 | 结果 |
| --- | --- |
| 编辑器导入／脚本检查 | 通过，无解析、编译或脚本错误 |
| 主场景启动 120 帧 | 通过 |
| 空间边界、同帧传送、暂停和预算恢复 | 31/31 通过 |
| 属性缓存、碰撞与状态等优化回归 | 134/134 通过 |
| 密集命中与掉落回归 | 37/37 通过 |
| 元素反应 | 68/68 通过 |
| 震荡 | 38/38 通过 |
| 雷电 PNG 兼容性 | 131/131 通过 |
| 雷火视觉分级 | 40/40 通过 |
| 当前波次压力测试 | 385/387 通过，2 项密度阈值断言失败 |

七组特效与缓存专项合计 **479/479 通过**。兼容性测试通过专用测试入口关闭新增视觉降级，以核对原有粒子参数和玩法行为；空间／预算专项及雷火分级使用默认开启的配置。测试入口只位于 `artifacts/reviews/enchantment_install_20261012`，不进入正常游戏流程。

当前 16 波配置下，两项失败均为“后期刷怪密度超过开局三倍”。在独立诊断子类中使用安装前的压力采样回调复跑，仍是相同两项失败，因此该失败不依赖本次新增的提前返回逻辑。此诊断保留当前正式配置及其余安装代码，并非回滚整个工程；密度阈值与配置的关系仍需另行校对。

编辑器还报告本机 Android build-tools 目录不可用；本次 Windows 检查正常完成。

- [本次完整验证结果](D:/project/useless/resources/infinite-build-dome-survival/artifacts/reviews/enchantment_install_20261012/results.json)
- [旧压力回调复核日志](D:/project/useless/resources/infinite-build-dome-survival/artifacts/reviews/enchantment_install_20261012/legacy_pressure_callback.log)
- [原始视觉对比和性能报告](D:/project/useless/review-archives/enchantment-review-20261012-01/repair_report.md)

本次仅做合入与针对性验证；原审阅阶段的性能数字不应当作本次重新运行的完整战局跑分。
