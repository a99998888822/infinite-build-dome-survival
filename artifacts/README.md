# 工作产物

性能状态统一见根目录的[战斗性能现状](../battle_performance_optimization_checklist.md)。性能过程材料不作为运行依赖或长期档案保留。

美术规格统一见根目录的[美术素材分辨率与场景缩放清单](../art_asset_resolution_and_scale_audit.md)。本轮美术处理的旧稿、预览、截图及验证日志已清理。

`sources/` 保存原图，`reference/` 保存外部参考。`editable/` 中的分帧稿、网格、色板及处理记录已删除，不再额外归档；最终画面保存在 `assets/` 的正式 PNG／图集中，正式图标旁已有的网格和色板沿用。来源记录保留原图及正式图集的对应关系。

其它功能任务仍在使用的 `previews/`、`reviews/`、`validation/` 内容按原路径保留。

`.gdignore` 阻止 Godot 将产物目录中的报告、脚本副本与截图导入正式资源。
