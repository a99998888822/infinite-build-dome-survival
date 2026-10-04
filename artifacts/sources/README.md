# 原始素材与来源

- `enemies/iron_knight/`：本轮钢甲骑士原始图片，移动 7 张、攻击 10 张，每张 720×720，保留压缩包中的原始字节。对应正式素材为 `assets/sprites/enemies/iron_knight/` 中的 256×256 帧。攻击第 3 张锤头左侧在原图中已有裁切。
- `enemies/xiaoguai_move/`：本轮小怪移动原始图片 7 张，每张 720×720。对应正式素材为 `assets/sprites/enemies/combat/` 中的 128×128 帧。
- `character_frames/`：此前保留的角色与敌人高清帧，与本轮素材不同，继续作为原始来源保存。
- `character_select/`、`finance/`：角色选择、银行场景、属性栏与哥布林表情原图；银行剪贴板输入也单独保留。
- `ui/move_indictor.png`：用户提供的目的地动画原图，横排 8 帧；正式接入图集位于 `assets/ui/combat/move_destination.png`。
- `ui_layout/`：角色选择和理财界面的原始布局参考与设计说明。
- `originals/`：既有道具、地面、主菜单、标题和按钮原稿；哈希前缀用于区分同名来源。

[index.json](index.json) 保存历史路径与现存原图的对应关系，新增动画还记录压缩包路径和成员名。索引中的 `original` 可以是已经清理的历史位置；`retained` 是当前可读取的文件。

本轮正式编辑网格和色板已随素材安装在 `assets/`，这里不重复保存缩放预览、透明抠图、像素转换过程、正式成品副本或审阅录像。
