# 当前原图与来源

[index.json](index.json) 记录保留图片、SHA-256、用途及对应正式资源，所有 `retained` 路径均应存在。

- `player_actions/novice_128/`：当前 61 帧的来源图、帧序和正式图集映射；`composition/` 保存移动施法所需的原始步态和捐赠帧。编辑网格位于 `artifacts/editable/player_actions/current/`。
- `cavern/`：5 张洞穴远景、废墟母图、前景母图、岩石和木头原图。`rubble/` 保存当前碎石的历史像素原稿及最后一次材质处理输入，不把这些像素稿称为高清原图。
- `enemies/`：当前钢甲骑士 17 张、普通怪 7 张及冥狼保留攻击帧原图。上轮已删除的其他拆分原图不恢复。
- `relics/`、`weapons/`、`spells/`：现行图标原图及裁切映射。仍使用第八批旧图表的 6 件 64px 遗物，其母图保留在 `originals/`。
- `finance/`、`character_select/`：现行银行桌面、短卷轴修订、属性面板、选人背景原图。
- `originals/`、`main_menu/`：当前主菜单背景、中文和英文标题、按钮及草丛母图。
- `ui/`：目的地动画原图。
- `effects/manifest.json`：9 个程序绘制特效的正式路径与哈希，绘制源在 `scripts/tools/source_art/pixel_effects.py`。

现成 PNG/PXG 是当前正式稿的依据。原图重处理、历史地面配方与局部修整函数可产生候选，不代表能自动重现全部人工确认的像素修改。精确重建能力以验证结果为准。
