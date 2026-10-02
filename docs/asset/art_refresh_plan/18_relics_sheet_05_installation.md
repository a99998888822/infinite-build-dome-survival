# 第五批：12件遗物按64×64正式接入

用户提供2364×1773白底图并授权像素化后直接替换。本批为裂痕石子弹、急促弹簧扳机、粗糙研磨透镜、阻滞配重石、嗜血皮带、毒雾投囊、震颤握柄、黑斑鹰眼水晶、狂战士铜质徽章、蚀腐吹管、疾风轮盘、屠戮者臂铠。累计48件遗物采用64×64正式资源。

## 处理

逐件按实际物件裁切和抠白底，经项目Picxel生成64px网格；助手核对原图、原尺寸与放大图后逐件登记选稿并完成 `finish`。每件15～16色，无抖色、硬透明、至少1px透明边界；保留裂纹、双斧浮雕、轮盘五孔与水晶黑色中央竖纹。

吊环、皮带中心、弹簧间隙和轮盘孔洞单独抠图。臂铠右下沿被水印遮挡，局部补齐金属弧边并从邻近原图延续金属色面；完整左沿和上部保留。原图和所有处理坐标见[来源记录](../../../artifacts/previews/art_refresh_v1/relics_sheet_05/r01/split_and_matte.json)。本次是原图像素化与局部修整，未进行模型重绘。

## 接入与验证

沿用正式PNG原路径、配置ID和导入设置；每张PNG旁新增同名可编辑PXG。原PNG和 `.png.import` 已备份。本批加入 `FinanceUIStyle.NATIVE_RELIC_ICONS`，复用此前已适配的原生64px槽位。

执行Godot无界面导入、两组六件的无界面及独立Windows桌面GPU回归。覆盖1152×648和1024×576商店滚动位置、遗物列表、逐件图鉴、小尺寸奖励卡、结算行高和末行可达，并核对旧武器布局恢复。实机图标的不透明像素与正式PNG逐像素比对。

结果：12件全部通过，84次实机图标像素比对通过，检查失败数为0，前台抢占采样为0。

- [本批成品预览](../../../artifacts/previews/art_refresh_v1/relics_sheet_05/r01/review/final_dark.png)
- [逐件安装记录](../../../artifacts/previews/art_refresh_v1/relics_sheet_05/r01/installation/assets.json)
- [验证结果](../../../artifacts/previews/art_refresh_v1/relics_sheet_05/r01/installation/verification.json)
- [临时实机截图位置](../../../artifacts/previews/art_refresh_v1/relics_sheet_05/r01/installation/capture_locations.json)

下一步使用[第六批12件生成包](batches/relics_sheet_06/README.md)，只上传画风参考＋精简提示词；高清图生成后继续处理为64×64。
