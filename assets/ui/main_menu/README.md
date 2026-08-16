# Main Menu UI Assets

首页脚本会自动从本目录加载以下素材：

| 文件名 | 用途 | 推荐尺寸 | 格式要求 |
| --- | --- | --- | --- |
| `bg_main_menu.png` | 首页全屏背景 | 2048x1152，最低 1920x1080 | PNG，不透明；不要包含标题、按钮、文字、水印 |
| `title_main_menu.png` | 标题艺术字 | 700x160 的显示比例，推荐源图 1400x320 | PNG，透明背景；只包含“穹顶求生”艺术字 |
| `button_main_menu.png` | 三个首页按钮共用底图 | 显示尺寸 300x84，推荐源图 600x168 | PNG，透明背景；不要包含按钮文字 |

Godot 导入建议：

- Texture Filter: Nearest
- Mipmaps: Disabled
- Repeat: Disabled
- 保留透明通道，尤其是标题和按钮底图

