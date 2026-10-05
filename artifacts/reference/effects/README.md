# 动效参考与历史审阅

- `download.gif`：原有动效参考。
- [ice-combos/](ice-combos/README.md)：用户明确要求保留的两组冰元素实机动图，原始字节和来源哈希保持不变。

2026-10-05将主动战斗和附魔优化的多轮截图、录像、补丁及临时验证文件移至项目外的 `D:/project/useless/review-archives/artifacts-cleanup-20261005/`。附魔优化的独立源码快照与重现工具仍位于 `D:/project/useless/review-archives/enchantment-opt-20261004/`，其中 `v3/` 为第三轮优化，`diagnostics-20261005/` 为后续开销定位。它们是独立审阅工程，其结果不代表当前正式工程的性能。

此前诊断建议优先检查密集雷火命中时反复创建受击动画，以及冰光反射的全表扫描和绘图成本。关闭视觉的诊断对照不等于最终优化收益；继续优化时应从上述快照复测。本次清理不修改正式游戏代码。
