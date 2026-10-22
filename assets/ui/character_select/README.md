# 选人页素材

当前分辨率及显示倍率统一见根目录的[美术清单](../../../art_asset_resolution_and_scale_audit.md)。正式背景已由原图经Picxel处理并采用；`asset_manifest.json` 记录源图和正式文件哈希。原图保存在 `artifacts/sources/character_select/`，最终画面保存在本目录的 `background.png`，不再单独保留切块网格。

角色、图标、文字与输入由 `scripts/ui/character_select_view.gd` 管理，角色开局限制来自 `data_config/characters.json` 的 `release_locked`。名册支持滚轮、拖动、滚动条及触屏；拖动不触发角色选择。资本家可查看档案但不能开局，剪影占位卡不可选择。

正式运行仅加载项目资源，不依赖处理预览目录。回归与后台截图入口为 `scenes/tests/character_select_view_test.tscn`。纹理使用最近邻，其他窗口仍遵循全局画布适配。
