# 组合反应大色块候选版（2026-10-17）

最新状态：用户已确认，最终版本已替换正式资源。下文保留首轮候选审阅记录；雷火与冰系以[正式替换清单](effects_production_install_2026-10-17.md)为准。

状态：已制作并完成实机审阅录制，等待用户审阅。正常游戏仍使用原有组合反应；候选模块 `ReactionBlockPreview.enabled` 默认关闭，仅审阅场景开启。

## 本轮视觉修改

| 项目 | 候选表现 |
| --- | --- |
| 蒸汽 | 相连的灰白烟团，使用深灰、灰绿、浅灰白分面，膨起后上浮消散，替代空心描边圈。 |
| 雷火 | 连片橙黄爆燃主体，内含一道粗亮折线；旧大量方粒爆炸由一个着色器面片代替。密集时继续遵守原有显示预算，缩短、缩小低档视觉，不改变伤害。 |
| 湿润传播 | 朝传播目标移动的短水带，中间宽、两端收窄，深蓝至浅青分色，替代 2px 淡线和终点碎点。 |
| 冰场及风扩冰场 | 连续冰面由七块大晶面拼接，扩张前沿采用厚冰缘，替代雪花细枝；纯视觉代理加入现有地面深度排序，冰场物理节点、查询、中心、半径保持原状。草丛仍有自然遮挡。 |
| 导电 | 更厚的蓝白折线电弧，深蓝外侧、亮蓝主体、浅色中心，保留原本跟随目标和持续时间。 |
| 光折射 | 有宽窄变化的棱面光束，蓝白主体、浅金切面，去掉外围小碎光，保留原扫射方向、范围和命中判定。 |
| 解冻 | 三块完整分色冰晶散开、下落消失，替代细碎冰屑；持续冻结冰壳与原冻结起手图集保留。 |

所有候选形状使用 3px 网格和离散色阶，采用项目现有的 Godot 程序化像素特效方式制作，未调用图像生成服务。火焰换色、光暗抵消，以及之前已确认的单附魔资源保持原状。

## 审阅媒体

- [主要四项动图（无损 WebP）](D:/project/useless/review-archives/reaction-block-preview-r01-20261017/primary.webp)
- [导电、光折射、解冻动图（无损 WebP）](D:/project/useless/review-archives/reaction-block-preview-r01-20261017/secondary.webp)
- [主要四项 GIF](D:/project/useless/review-archives/reaction-block-preview-r01-20261017/primary.gif)
- [其余三项 GIF](D:/project/useless/review-archives/reaction-block-preview-r01-20261017/secondary.gif)
- [7 项完整视频，约 27 秒](D:/project/useless/review-archives/reaction-block-preview-r01-20261017/reaction-block-review.mp4)

两组动图均为原像素比例裁切拼版；各单项完整视频保留 720×560 实机裁切区域。按记录时间播放，没有加速、重绘或插帧。无损 WebP 保留原始颜色；GIF 为方便兼容的调色板版本。

## 实机条件与结果

- 真实 `GameRoot` 主战斗，1920×1080 基准，6 只高血量静止怪物。
- 使用木质弓箭的实际施放、投射物碰撞、附魔与组合反应入口，没有直接调用伤害或组合反应生成方法。
- 审阅夹具只将弓箭冷却缩为 300ms，并提供 2 个附魔槽，以便在一个短片中连续射出不同元素；这些设置没有写入正式武器配置。
- 第一轮 14 个组合案例全部完成。冰场显示层次、解冻调整后，对冰场扩张、冻结／解冻、光折射再次录制，3 项全部完成。交付使用最新对应版本。
- 各交付片段实际伤害覆盖 2–5 个不同怪物；记录同时确认候选效果确实被绘制。
- 两轮有效 GPU 记录均退出 0，无 Parse/Compile/SCRIPT ERROR；私有桌面与实际引擎桌面一致，`foreground_samples=0`，未抢用户焦点。
- 14 例：[gpu-r01/results.json](D:/project/useless/review-archives/reaction-block-preview-r01-20261017/gpu-r01/results.json)；后续 3 例：[gpu-r03/results.json](D:/project/useless/review-archives/reaction-block-preview-r01-20261017/gpu-r03/results.json)；交付映射：[delivery.json](D:/project/useless/review-archives/reaction-block-preview-r01-20261017/delivery.json)。

## 验证与已知基线问题

- Headless 编辑器导入检查通过。
- `reaction_block_preview_test`：9 项通过，验证正常游戏默认关闭、密集视觉不漏伤害／地形调用、伤害一致、显示预算、暂停和销毁。
- `thunder_fire_lod_test`：40 项通过。
- `water_ice_atlas_test`：28 项通过，验证关闭候选时原图集行为保留。
- `pixel_baked_runtime_test` 存在 3 条旧断言失败：要求密集冰场始终保留最高细节，但当前基线按密度降档。在独立基线目录中撤去本轮四处视觉接入后，复现完全相同的 3 条失败。
- 普通主场景 `--quit-after 120` 有退出清理告警：2 个资源仍在使用。独立基线也复现相同告警；本轮正常完成并清理的实机审阅与候选测试没有此错误。
- 基线比较：[prior-baseline.json](D:/project/useless/review-archives/reaction-block-preview-r01-20261017/prior-baseline.json)。旧测试与退出告警未作为本次视觉任务扩展修改。

## 文件入口

- [已移入正式目录的绘制模块](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/reaction_block_visual.gd)
- [已移入正式目录的像素着色器](D:/project/useless/resources/infinite-build-dome-survival/shaders/effects/reaction_blocks.gdshader)
- [真实弓箭审阅场景](D:/project/useless/resources/infinite-build-dome-survival/scenes/tests/reaction_block_visual_review.tscn)
- [视觉隔离与密集反应测试](D:/project/useless/resources/infinite-build-dome-survival/scripts/tests/reaction_block_preview_test.gd)
