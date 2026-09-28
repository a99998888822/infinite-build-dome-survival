# 原图重新处理：128×128 哥布林

输入为用户提供的 1536×1536 高清默认表情原图。最终仅输出 128×128，16 色，真实透明 PNG。没有使用上一轮的 64×64 成品或程序绘制中间稿。

本轮采用原图保形的本地像素化与局部像素修整；没有调用图像生成模型，不将其描述为模型重新绘制。

流程：原图重新抠出主体与手臂空隙 → Picxel 取色与网格转换 → 针对自动色板中金属失色的问题锁定 16 色 → 在原生网格补回细金链、调整原有镜框色 → 对照原图只修补眼睛的小区域。眉毛、鼻子、嘴形和主体透明轮廓保留原图转换结果。

主要文件：

- `work/goblin-128.png`：选定的透明成品。
- `work/goblin-128-detail-face.pxg`：与成品对应的可编辑像素稿。
- `work/goblin.face.json`：眼部局部补丁。
- `refs/goblin.anchor.json`：本轮特征、区域、视线与色板设定。
- `concepts/method.json`：输入哈希与实际处理方式。
- `work/validation.json`：最终格式、色数和透明轮廓验证。
- `work/goblin-128.pxg`、`work/goblin-128-detail.pxg`：局部修整脚本使用的网格输入。

原始高清图仅在上一级目录保留一份。五表情对照见 `../picxel_expressions_128/goblin-expressions-review.png`；重复放大图、抠图和面板导出副本已清理。

准备与局部修整脚本分别为 `scripts/tools/prepare_picxel_goblin_128.py` 和 `scripts/tools/refine_picxel_goblin_128.py`。Picxel 的脚本未改动。

原图未改写，五种表情已确认并接入正式理财与结算图集。运行 `scripts/tools/install_goblin_portraits.py` 使用保留的成品重建；重新处理原图时，准备脚本会恢复所需的工作副本。
