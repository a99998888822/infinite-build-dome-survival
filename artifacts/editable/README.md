# 当前有效编辑源

`index.json` 登记当前正式图片的内容哈希和编辑入口；已移除不存在的历史条目。

- `player_actions/current/`：按当前 8 类动作分组的 61 份 PXG，逐帧匹配正式图集。帧时序与原图映射在 `../sources/player_actions/novice_128/manifest.json`。
- `finance_background/`：像素底层、卷轴遮罩、18 张网格与色板，可重建当前银行底图。
- 其他素材的编辑源位于其 `assets/` 目录，或直接使用当前 PNG；索引不会把已删除的拆分图标为可用源稿。

使用 `python scripts/tools/art_source_archive.py --check` 核对；需要导出时传入 `--output <目录>`。正式资源不会被该命令覆盖。
