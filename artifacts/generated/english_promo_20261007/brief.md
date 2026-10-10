# 英文菜单标题 · 正式资源绘制源

英文名暂定 **Goblin's Guide to Dungeons**，对应“哥布林教你地下城”。标题采用两行：`GOBLIN'S` / `GUIDE TO DUNGEONS`，延续原版“大字角色名 + 小字说明”的层级。

## 交付文件

| 文件 | 规格 | 用途 |
| --- | --- | --- |
| `title_en.png` | 1760 × 502，RGBA，透明背景 | 英文标题独立素材 |
| `title_en_preview.png` | 1760 × 566，RGB | 深底标题预览 |
| `title_en_pixel_480.png` | 480 像素宽，RGBA，硬透明 | 已接入的英文菜单标题 |

## 制作方式

英文艺术字由本地定义的字母轮廓绘制，加入金色块面、笔触、浅色棱边和深色立体描边，没有调用图片 API。英文标题文件沿用首版。

2026-10-10 按用户要求删除方形宣传封面与无字方形背景。`build_art.py` 已移除封面生成分支，本目录仅保留英文标题及其可复现绘制源。

现有参考：

- `assets/ui/main_menu/title_main_menu.png`
- `artifacts/sources/originals/c591787d10-goblin-dungeon-title-oil-1200x640.png`
- `assets/ui/main_menu/bg_main_menu.png`

`build_art.py` 可复现输出，`manifest.json` 记录来源哈希、生成方式及文件规格。前期未执行的接口提示词已移除。本次没有提交付费图片任务。

## 审阅与多语言处理

`title_en_pixel_480.png` 与正式 `assets/ui/main_menu/title_main_menu_en.png` 的 SHA-256 相同；`localization/locales.json` 已引用正式 PNG。标题拼写、撇号、透明素材边缘及 PNG 解码均已核查。

正式标题、本地化映射以及高分辨率标题源稿继续保留。
