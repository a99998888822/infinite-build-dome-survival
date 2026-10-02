# 第四批：12件遗物按64×64正式接入

用户提供2364×1773白底图，并授权像素化后直接替换。本轮包含密教圣盾、迷途者胫环、守魂人面石雕、苦痛祭皿、真银护甲、圣质银杯、受难甲壳、代价生命之种、无影遁形胫甲、苦难前行之枷锁、虚空触手和磨损格斗拳套。与此前24件一起，累计36件遗物采用64×64正式资源。

## 像素处理

每件从原图尺度独立裁切、抠白底，经项目Picxel生成64px网格，助手对照原图、原尺寸与放大稿检查，再逐件登记选稿并完成 `finish`。每件14～16色、无抖色、硬透明、透明边界至少1px；保留原图材质和轮廓。

金属环与锁链孔洞单独处理。石雕的深眼窝保持原样，没有添加眼白。拳套腕口下沿被水印遮挡，局部补绘约3行最终像素对应的皮革弧边；原图、坐标和修整说明保留在[来源记录](../../../artifacts/previews/art_refresh_v1/relics_sheet_04/r01/split_and_matte.json)。未调用图片生成模型。

## 安装与验证

正式文件沿用 `assets/ui/icons/relics/` 原路径与配置ID，PNG旁保存同名可编辑PXG。旧PNG及 `.png.import` 已备份，导入UID和设置保留。只将这12件加入原生图标名单，沿用上一轮已适配的64px槽位。

Godot无界面导入、两组各6件的无界面和后台GPU回归，覆盖两种窗口尺寸的遗物列表、商店顶部／中部／底部、逐件图鉴、小尺寸奖励卡、结算行高及滚动末行。实际GPU图标与正式PNG进行不透明像素比对，并检查旧武器布局恢复。后台运行位于独立Windows桌面，不切换用户桌面。

结果：12件全部通过，84次实机图标像素比对通过，检查失败数为0、前台抢占采样为0。

- [成品预览](../../../artifacts/previews/art_refresh_v1/relics_sheet_04/r01/review/final_dark.png)
- [逐件安装哈希及备份索引](../../../artifacts/previews/art_refresh_v1/relics_sheet_04/r01/installation/assets.json)
- [验证结果](../../../artifacts/previews/art_refresh_v1/relics_sheet_04/r01/installation/verification.json)
- [临时实机截图位置](../../../artifacts/previews/art_refresh_v1/relics_sheet_04/r01/installation/capture_locations.json)

下一步：[第五批12件生成包](batches/relics_sheet_05/README.md)。继续只上传一张画风参考并使用精简文字描述，从零设计物件；后处理目标64×64。
