# 遗物像素绘制源

从旧审阅脚本保留的原创像素绘制函数，不包含历史说明、校验日志或打包逻辑。函数返回 Pillow 图像，输出路径由调用者指定。

- `capital_relics.py`：`trigger`、`ledger`、`amplifier`、`dividend`、`vow`，对应镀金扳机、无眠账簿、失控增幅器、狂热分红、清醒誓言。
- `principal_relics.py`：`coin_heart`、`hoarders_ring`、`golden_sarcophagus`。
- `challenge_vault.py`：已正式采用的保险箱像素绘图源；`challenge_vault.json` 保存调色板、参考来源、尺寸与正式 PNG 哈希。运行绘图脚本会重建 `assets/ui/finance/` 中的两张正式 PNG，并将临时预览写入 `artifacts/previews/vault_redraw/`。

正式 PNG 位于 `assets/ui/icons/relics/`。此目录保留绘制能力，审阅文件夹不再重复保存这些正式资源。
