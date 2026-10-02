# Main Menu UI Assets

首页场景、主题及脚本从本目录加载以下素材：

| 文件名 | 用途 | 推荐尺寸 | 格式要求 |
| --- | --- | --- | --- |
| `bg_main_menu.png` | 首页全屏背景 | 当前确认版 1024x572；最近邻等比铺满 | PNG，不透明；不要包含标题、按钮、文字、水印 |
| `title_main_menu.png` | 标题艺术字 | 当前确认版 240x128；等比显示于高 200 的标题区域 | 透明 PNG；上行“哥布林”，下行向右错位“教你地下城”；最近邻采样 |
| `button_main_menu.png` | 四个首页按钮共用底图 | 已确认 Picxel 108x28；两倍最近邻显示为 216x56 | 透明 PNG，14 个可见颜色，二值透明；不包含按钮文字或图标 |
| `icon_battle.png`、`icon_talent.png`、`icon_settings.png`、`icon_quit.png` | 四个按钮的独立图标 | 原图 24x24，显示宽度 20px | 透明 PNG，最近邻采样 |
| `button_focus.png` | 键盘焦点四角标记 | 原图 240x56，按主题配置显示 | 透明 PNG |
| `menu_button_theme.tres` | 按钮字体、颜色、状态与内边距 | 文字 18px、描边 1px | Godot Theme，引用正式 PNG 与项目字体 |

Godot 导入建议：

- Texture Filter: Nearest
- Mipmaps: Disabled
- Repeat: Disabled
- 保留透明通道，尤其是标题和按钮底图

2026-10-02 已将用户确认的 108x28 版本及缩小的图标、文字接入正式主界面。按钮之间间隔 8px，标题与按钮列表的布局间距为 32px。四个按钮共用底图，默认文字为浅米色，悬停/焦点时提亮；按下时文字下移 2px，键盘焦点显示浅金四角。按钮保持稳定的尺寸和方向，完整点击区域为 216x56。

场景通过 `menu_button_theme.tres` 加载按钮样式。唯一的 [1728x448 按钮高清原图](../../../artifacts/sources/originals/263cf9a972-button_copper_oil_hd.png) 已归入原稿目录，迁移路径与哈希记录在 `artifacts/sources/index.json`；正式 PNG 及当前哈希登记在 `artifacts/editable/index.json`。本轮分辨率候选、Picxel 分块网格、绘图/预览脚本、截图及临时备份已清理。

当前标题采用 2026-10-02 确认的 Picxel 240x128 版本，正式文件为本目录的 `title_main_menu.png`。标题为原创楔形字形，油画笔触像素化，使用 15 色和二值透明度。标题与四个按钮保持左侧纵向布局，内容顶部锚点为 0.045；标题上方横线与底部动态文字已移除。

标题高清原稿、原始字形 SVG 与设计 JSON 已归入 `artifacts/sources/originals/`，路径映射见 `artifacts/sources/index.json`。

当前背景使用 2026-10-02 确认的哥布林地牢像素稿 `r06_gaze_up`，正式文件为本目录的 `bg_main_menu.png`。左墙与红色深渊采用 256x143 像素尺度，其余场景采用 512x286，哥布林上半身与金币采用 1024x572；瞳孔为最终上移版。背景节点使用最近邻采样，保留原有等比铺满布局。

2026-10-02 整理后，正式背景与标题的原生 PNG 同时作为无损位图编辑源，高清原稿保留唯一一份；旧候选、备份和历史处理包已移除。编辑入口见 `artifacts/editable/index.json`，清理详情见 `docs/maintenance/art_consolidation_2026-10-02/README.md`。
