# 遗物性能复核资料

详细说明：`docs/main/checklist/relic_performance_2026-10-07.md`。

2026-10-07 已删除旧源码副本、一次性诊断场景及原始日志。下列日志名称用于查阅[日志摘要](../../maintenance/validation_log_summary_20261007.json)中的历史结果和异常上下文；最终指标、截图、回归报告及源码 SHA-256 索引保留。

- `before_gpu_metrics.json` / `after_gpu_metrics.json`：最终 GPU 对照指标；包含 0 件和 60 件遗物、购买后全部属性、操作耗时和空闲帧耗时。
- `before_control_gpu.log` / `after_gpu.log`：对应引擎日志。
- `before_control_gpu.json` / `after_gpu.json`：独立桌面验证报告，均为 `foreground_samples=0`。
- `before_headless.json` / `after_headless.json`：此前 headless 诊断指标，不与 GPU 帧耗时混用。
- `60_battle_idle.png` / `60_esc_idle.png` / `60_shop_idle.png` / `60_enchant_idle.png`：优化后的后台实机截图；`0_` 前缀为无遗物对照。
- `regressions.json` 与各测试日志：回归结果；`final_cache_test.log` 为最终 19 项缓存检查。
- `principal_baseline.log`：优化前工程复现的 4 项既有本金遗物测试失败。
- `final_editor.log`：最终 headless 编辑器检查。
- `before_sources.json`：本轮开始前源码的 SHA-256 索引；包含此前已完成的功能修改，不能直接当作 Git HEAD。对应旧源码副本已清理。

注意：`before_gpu.json` 是早期运行的桌面报告。后台运行工具会写入与日志同名的 JSON，因此最终性能数据使用独立的 `*_metrics.json` 文件名。

历史测试通过 `scripts/tools/run_godot_background.py` 启动诊断场景，固定种子、0/60 件遗物、无敌人、120 帧采样，仅用于隔离遗物与 UI 开销。诊断场景已清理；后续重测需要重新搭建，并保持指标文件与引擎日志不同名。
