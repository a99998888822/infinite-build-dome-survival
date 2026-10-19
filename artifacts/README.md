# 性能测试记录

2026-10-19 按用户要求清理：本目录仅保留性能测试、性能分析及配套验证材料。

- `reports/`：战斗加载、首次攻击、密集战斗开销、伤害结算／缓存、受击表现批处理、反射优化的指标、日志、对照基线与回归材料。
- `previews/battle_loading_20261019/`：加载性能验证的配套截图。
- `.gdignore`：阻止 Godot 导入报告中的基线脚本等材料。

本次已删除非性能审阅图、普通功能验证日志，以及 `sources/`、`editable/` 下的美术原图与编辑稿。游戏正式资源仍位于 `assets/`；本次清理未修改正式资源或运行脚本。

历史美术文档和制作工具中的 `artifacts/sources/`、`artifacts/editable/`、`artifacts/reviews/` 路径仅作为来源记录，清理后不再保证可访问。需要原图的重建工具需先恢复输入文件。

清理明细和保留文件哈希见[清理记录](../docs/asset/artifacts_cleanup_20261019_performance_only.json)。
