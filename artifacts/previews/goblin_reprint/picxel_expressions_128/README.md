# 哥布林表情素材（128×128）

沿用已确认默认表情的原图提取、Picxel 像素化和局部修整流程，共用 16 色，透明度仅 0/255。四张均从各自高清原图处理；保留原图表情、姿势与视线，补回金链、镜框和少量瞳孔细节。

- 微笑：`work/goblin_smile-128.png`
- 不悦：`work/goblin_displeased-128.png`
- 欣喜：`work/goblin_delighted-128.png`
- 失落：`work/goblin_downcast-128.png`

五表情对照：`goblin-expressions-review.png`。上排 2 倍最近邻放大，下排原尺寸；默认表情沿用之前已确认文件，内容未修改。可编辑版本为 `work/*-128-detail-face.pxg`。

上一级目录保留五张原始高清图，工作目录仅保留最终 PNG、可编辑网格、色板与局部修整参数。重新处理时，准备脚本会从原图恢复 `refs/` 图片；抠图副本、旧尺寸试稿和重复成品已清理。

这是本地原图像素后处理，没有调用图片生成模型。五种表情现已覆盖正式理财和结算图集，并同步接入贷款弹窗；可运行 `scripts/tools/install_goblin_portraits.py` 重建。`sources.json` 记录来源，`validation.json` 记录尺寸、色板、透明度及完整性检查。
