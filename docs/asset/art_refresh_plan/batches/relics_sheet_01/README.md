# 遗物白底图集：第一批6件

实际处理与正式安装已完成：[6件32px成品](../../../../../artifacts/previews/art_refresh_v1/relics_sheet_01/r01/README.md)已获用户像素审阅通过，见[正式接入记录](../../12_relics_sheet_01_installation.md)。以下生成附件作为来源与后续补做记录保留；当前操作转到[第二批](../relics_sheet_02/README.md)。

当前为生成准备包。`02_identity_reference_white.png`是6张现有32px图标的最近邻放大拼图，仅参考物件身份和排列，没有经过重绘。

上传顺序：

1. `01_style_reference.png`：来自项目reference的《暗黑地牢》风格参考。
2. `02_identity_reference_white.png`：无文字、无格线的旧物件参考。
3. 复制 `doubao_prompt.txt` 完整提示词。

`review_labeled_do_not_upload.png`只供人核对名称，不上传给豆包，避免把名称带入生成结果。用户展示的服饰图仅参考“多个独立物件排列成图集”的形式，不是本批的物件或画风附件。

| 位置 | 遗物 | 拆分后文件 |
|---|---|---|
| 第一行左 | 猪猪存钱罐 | `relic_piggy_bank.png` |
| 第一行中 | 钢铁保险柜 | `relic_steel_vault.png` |
| 第一行右 | 吸金罗盘 | `relic_gold_compass.png` |
| 第二行左 | 复利宝典 | `relic_compound_interest_tome.png` |
| 第二行中 | 周期分红钟 | `relic_periodic_dividend_clock.png` |
| 第二行右 | 量化操盘 | `relic_quant_trading.png` |

请求3列×2行、纯白底、无格线无文字。优先3072×2048（理论每格1024px），若当前豆包规格不支持，1536×1024（每格512px）也可用于32px图标小样。这些是请求规格，不保证模型按原尺寸、顺序或数量返回；下载后检查实际文件。

下载生成的原图，命名 `relics_sheet_01_hd.png`，发回当前对话。先审阅六件造型和数量，再拆分。物件缺失、重叠或身份串换时，只重做失败项，不从其他格复制冒充。

高清通过后的指令：

> 这张六件遗物白底图集已确认。请先按实际物件检查数量、身份和位置，对照 `docs/asset/art_refresh_plan/batches/relics_sheet_01/manifest.json` 拆成6张独立高清原图，保留来源图和裁切坐标，分别抠掉白底并检查内部孔洞，不要误删浅色纸页、表盘或高光。然后使用项目Picxel外部图片流程，逐件输出32×32、每件最多16色、硬透明、无抖色的像素审阅稿。保持统一的材质配色与视觉重量，但不要拉宽细长物体；提供原尺寸、4倍最近邻、深浅背景总览。等待我的像素审阅后再接入正式资源。

白底图集不能整体压成一张32px或128px方图。先拆分高清物件，再为每件创建anchor和PNG，Picxel处理6个输入文件。物件内的白色镂空独立检查，不能简单把所有白色像素透明化。未收到并确认高清图之前，不启动Picxel转换或修改正式资源。
