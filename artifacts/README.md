# 美术原稿、编辑源与在制稿

正式游戏资源保存在 `assets/`。本目录仅保留唯一原稿、必要编辑源、当前在制稿及画风参考，不再保存逐轮处理包。

## 当前入口

- [sources/](sources/)：44 张角色／敌人高清输入帧，以及去重后的道具、地面、UI、主菜单原稿。标题原始字形 SVG 与设计 JSON 位于 `originals/title_design/`；路径迁移见 [index.json](sources/index.json)。
- [editable/ground_tiles/](editable/ground_tiles/)：12 张原生 128×128 PNG 地面色片，可直接看图、拼接和编辑。[index.json](editable/index.json) 登记正式 PNG 及其编辑源；与正式图重复的单层网格直接复用 PNG，已有 `assets/` 内的编辑源保持原样。
- [wip/character_select/](wip/character_select/)：角色选择界面当前在制稿，包括[无文字底框](wip/character_select/01-no-text.png)、[完整文字版](wip/character_select/02-full-text.png)、说明与独立导出脚本。无文字版不含头像、人物或触手。
- [按钮高清原图](sources/originals/263cf9a972-button_copper_oil_hd.png)：1728×448 透明 PNG；正式采用的 108×28 底图、图标和样式位于 [assets/ui/main_menu](../assets/ui/main_menu/README.md)。
- `reference/`、`effects/`、`oil_painting/`：用户提供的画风与动效参考。

主菜单背景、标题、按钮和 C 方案战场均已接入正式资源，不再作为在制包保留。`previews/` 与 `generated/` 中的重复导出、旧版本、截图、备份和隔离运行缓存已清理。按钮制作的分辨率候选、分块网格、预览代码和临时审阅文件也已移除，仅保留唯一高清原图与正式资源。

## 编辑与保留规则

PNG 可以作为单层像素画的无损编辑源。本目录原有 59 份 PXG 中，47 份与正式 PNG 或图集帧逐像素一致，已合并到正式图；另 12 份独有地面色片无损导出为 PNG 后保留。角色帧序由索引中的 `frame_size`、`frame_count` 和正式图集从左至右的位置确定。没有删除独有像素、分层绘画或高清输入。

角色选择界面的在制草图与导出脚本继续保留。按钮高清 PNG 与正式像素 PNG 作为无损位图源，不再保留生成脚本、候选设计参数或预览适配器。原稿与编辑源说明合并在本页，按钮使用说明位于正式资源目录，两份用途不同的来源／编辑索引继续保留。

原稿去重按解码后的尺寸和可见像素判断；新复制的原稿字节不变。`sources/index.json` 记录旧路径、保留位置及旧文件哈希。主菜单背景仅保留高清原图和最终合成 PNG，之前已删除的多分辨率处理稿、图层和蒙版没有恢复；原生 PNG 不代表完整分层源。

历史文档与配置中的旧包路径仅用于记录来源，可能已不存在；当前编辑入口以本页及索引为准。清理清单与验证见[本轮整理记录](../docs/maintenance/art_consolidation_2026-10-02/README.md)。
