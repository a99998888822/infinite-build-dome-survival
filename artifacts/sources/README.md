# 原始素材与来源

- `enemies/iron_knight/`：本轮钢甲骑士原始图片，移动 7 张、攻击 10 张，每张 720×720，保留压缩包中的原始字节。对应正式素材为 `assets/sprites/enemies/iron_knight/` 中的 256×256 帧。攻击第 3 张锤头左侧在原图中已有裁切。
- `enemies/xiaoguai_move/`：本轮小怪移动原始图片 7 张，每张 720×720。对应正式素材为 `assets/sprites/enemies/combat/` 中的 128×128 帧。
- `character_frames/`：此前保留的角色与敌人高清帧，与本轮素材不同，继续作为原始来源保存。
- `character_select/`、`finance/`：角色选择、银行场景、属性栏与哥布林表情原图；银行剪贴板输入也单独保留。
- `finance/finance_table_ui.png`：2026-10-05新增银行桌面原图，2752×1536；本轮卷轴缩短与上移修改基于此图，原始字节保留。
- `finance/finance_table_ui_scroll_short.png`：正式底图采用的短卷轴高清修订；同名 `.edit-notes.json` 保留修订记录。合成遮罩、像素底层及最终18张网格见 `artifacts/editable/finance_background/`。
- `goblin/gobline_face.png`：五种哥布林表情原图；裁切与正式立绘映射见 `assets/ui/finance/portraits/source_manifest.json`。
- `weapons/`：11件武器的原始图表和名称映射；正式图标为128×128。
- `spells/`：法术原始图表和名称映射；忽略用户指定的第二排末尾图标，19件正式图标为64×64。
- `relics/`：四张遗物原始图表；[来源映射](relics/yiwu_icon_manifest.json) 保存84件图标的名称、裁切位置、B／D选择和正式128×128资源路径、哈希。
- `ui/move_indictor.png`：用户提供的目的地动画原图，横排 8 帧；正式接入图集位于 `assets/ui/combat/move_destination.png`。
- `ui_layout/`：角色选择和理财界面的原始布局参考与设计说明。
- `originals/`：既有道具、地面、主菜单、标题和按钮原稿；哈希前缀用于区分同名来源。

[index.json](index.json) 保存历史路径与归档原图的对应关系，新增动画还记录压缩包路径和成员名。索引中的 `original` 可以是已经清理的历史位置；`retained` 是归档路径。2026-10-05清理前发现 `finance/finance_bank_desktop.png` 已缺失，已在索引标注 `availability` 并保留原哈希；其余现存原图均核对哈希一致。银行风格参考从原始剪贴板文件恢复至 `artifacts/reference/oil_painting/finance-style-reference.png`。

本轮正式编辑网格和色板已随素材安装在 `assets/`，这里不重复保存缩放预览、透明抠图、像素转换过程、正式成品副本或审阅录像。
