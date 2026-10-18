# 正式素材来源

本目录仅保存当前正式资源的原图、有效编辑源和必要映射。

- `sources/`：唯一原图、已采用的角色来源帧、洞穴原图、图标母表、音频原件和来源索引。
- `editable/`：当前 61 帧角色动作网格、银行底图网格/色板/遮罩，以及正式资源编辑入口索引。
- `.gdignore`：阻止 Godot 把制作源文件作为游戏资源导入。

可复用绘制和处理脚本统一在 `scripts/tools/source_art/`。截图、日志和其他可再生成输出写入 `temp/`。

执行 `python scripts/tools/art_source_archive.py --check` 可核对来源哈希、编辑入口、61 帧角色图集和银行底图。加 `--output <目录>` 可导出重建图片，不覆盖正式资源。

2026-10-19 已清理审阅录像、预览图、验证日志及旧稿隔离目录；保留来源与可编辑文件。音效正式资源位于 `assets/audio/`，确认结果及本次清理记录见[音效正式接入](../docs/asset/audio_finalization_20261019.md)。更早的整理见[清理记录](../docs/asset/artifacts_cleanup_20261015.md)。
