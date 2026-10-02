# 第六批：12件遗物按64×64正式接入

用户提供2364×1773白底图并授权处理后直接替换。本批为裁决之眼吊坠、分裂晶石弹头、淘金者的手套、残缺的占卜骰子、商旅账本、被亵渎的祈福铜钱、扩容背包束带、观星者的镜片、丰收的牺牲祭器、人性护符、馈赠印记、虚空收纳匣。累计60件遗物使用64×64正式资源。

## 制作与修整

逐件裁切和抠底，经项目Picxel生成64px网格；核对原图、原尺寸与放大效果后逐件登记选稿并完成 `finish`。每件15～16色、无抖色、硬透明且至少留1px透明边界。

保留吊坠红瞳、手套金粒、骨骰点数和缺口、晶石弹座、蜡封礼结及骨手形状。镜片两颗较大星点局部恢复十字形，沿用原色板，其余像素不变。收纳匣下沿及相邻菱形护角受水印遮挡，按原图补齐几何和金属色面，主体与箱盖保留。原图、抠图坐标及修整说明分别见[来源记录](../../../artifacts/previews/art_refresh_v1/relics_sheet_06/r01/split_and_matte.json)和[星点修整记录](../../../artifacts/previews/art_refresh_v1/relics_sheet_06/r01/repair_log.json)。没有进行模型重绘。

## 接入与验证

保留正式PNG路径、配置ID、导入UID和设置，PNG旁安装同名可编辑PXG。旧PNG与 `.png.import` 保存在本批 `installation/previous/`。本批加入原生遗物图标名单，复用已适配的64px槽位。

使用Godot无界面导入、两组六件的无界面和独立Windows桌面GPU回归，检查两种窗口尺寸的商店滚动位置、遗物列表、逐件图鉴、小尺寸奖励卡、结算行高、末行滚动与旧武器布局恢复。对实际GPU图标的不透明像素和正式PNG进行比对。

验证通过：12件正式文件与导出哈希一致，84项实际界面像素比对通过，无界面及GPU回归均零失败，前台窗口采样为0。已检查遗物列表与商店截图。

- [成品预览](../../../artifacts/previews/art_refresh_v1/relics_sheet_06/r01/review/final_dark.png)
- [安装哈希及备份索引](../../../artifacts/previews/art_refresh_v1/relics_sheet_06/r01/installation/assets.json)
- [验证结果](../../../artifacts/previews/art_refresh_v1/relics_sheet_06/r01/installation/verification.json)
- [临时截图位置](../../../artifacts/previews/art_refresh_v1/relics_sheet_06/r01/installation/capture_locations.json)

下一步使用[第七批12件生成包](batches/relics_sheet_07/README.md)。只上传画风参考，按精简文字从零设计；新提示词要求画布底部保留整条10%白边。
