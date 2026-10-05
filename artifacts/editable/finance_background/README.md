# 理财底图最终编辑源

2026-10-05 清理未提交试稿时，从正式底图实际使用的合成输入中归集。文件按原字节保留，来源与 SHA-256 见 `source-map.json`。

- `tiles/`：18 张最终 128×128 PXG；其中 14 张沿用原场景，4 张使用短卷轴修订。
- `scene.pal`：最终场景色板。
- `pixel_background.png`：拼接裁切后的 688×384 像素底层。
- `scroll_mask.png`：2752×1536 灰度遮罩，白色区域使用高清卷轴。
- 高清输入：`artifacts/sources/finance/finance_table_ui_scroll_short.png`。
- 正式成品：`assets/ui/finance/finance_background.png`。

复合方式：将像素底层以最近邻放大至 2752×1536；用遮罩混合高清输入与放大的底层。Pillow 对应 `Image.composite(short_scroll_RGBA, background_RGBA, mask_L)`。已核对结果与正式成品逐像素一致。网格按 `source-map.json` 的行列拼接为 768×384，再裁切至 688×384；画布右侧补齐区不属于正式底图。

旧的分辨率候选、放大预览、分块参考及任务中间稿已清理。后续编辑使用此目录，不再依赖旧 `artifacts/previews/finance_table_ui/` 试稿目录。
