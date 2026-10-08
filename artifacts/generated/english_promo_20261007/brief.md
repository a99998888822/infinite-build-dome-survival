# 英文标题与方形宣传封面 · 正式像素背景修订版

英文名暂定 **Goblin's Guide to Dungeons**，对应“哥布林教你地下城”。标题采用两行：`GOBLIN'S` / `GUIDE TO DUNGEONS`，延续原版“大字角色名 + 小字说明”的层级。

## 交付文件

| 文件 | 规格 | 用途 |
| --- | --- | --- |
| `title_en.png` | 1760 × 502，RGBA，透明背景 | 英文标题独立素材 |
| `title_en_preview.png` | 1760 × 566，RGB | 深底标题预览 |
| `title_en_pixel_480.png` | 480 像素宽，RGBA，硬透明 | 最近邻缩小的可选菜单候选稿 |
| `cover_en_pixel_2048.png` | 2048 × 2048，RGB | 1:1 宣传封面大图 |
| `cover_en_pixel_1024.png` | 1024 × 1024，RGB | 封面预览 |
| `cover_en_pixel_512.png` | 512 × 512，RGB | 小封面 |
| `cover_en_pixel_256.png` | 256 × 256，RGB | 缩略图可读性检查 |
| `cover_background_pixel_2048.png` | 2048 × 2048，RGB | 无文字背景，供其他语言版本复用 |

## 制作方式

按用户最新要求，未使用技能或外部绘图接口。英文艺术字由本次定义的字母轮廓绘制，加入金色块面、笔触、浅色棱边和深色立体描边。修订版封面使用正式资源 `assets/ui/main_menu/bg_main_menu.png`（1024 × 572）进行方形裁切、明暗调整与标题合成。背景在原生像素尺寸下调整明暗，各尺寸分别使用最近邻缩放，以保持像素边缘清晰。英文标题文件沿用首版。

当前交付使用文件名包含 `_pixel_` 的封面。先前 `cover_en_*.png` 和 `cover_background_2048.png` 为旧版存档。

现有参考：

- `assets/ui/main_menu/title_main_menu.png`
- `artifacts/sources/originals/c591787d10-goblin-dungeon-title-oil-1200x640.png`
- `assets/ui/main_menu/bg_main_menu.png`

`build_art.py` 可复现输出，`manifest.json` 记录来源哈希、生成方式及文件规格。前期未执行的接口提示词已移除。本次没有提交付费图片任务。

## 审阅与多语言处理

已目视检查标题拼写、撇号、透明素材边缘、方形构图及 256 像素缩略图可读性。PNG 文件均已解码校验。原有游戏素材的哈希保持一致；没有修改场景、脚本或正式素材引用，没有进行或声称完成运行时接入。

其他语言版本可以复用无文字背景，并替换独立标题图层。英文名称与字形仍为首版候选，等待用户审阅。
