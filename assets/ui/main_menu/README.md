# 主菜单素材

当前资源尺寸、显示倍率及裁切规则统一见根目录的[美术清单](../../../art_asset_resolution_and_scale_audit.md)。背景、中文／英文标题、按钮皮肤和4枚入口图标由主菜单场景及 `scripts/ui/main_menu_ui_controller.gd` 加载。

`menu_button_theme.tres` 管理字体、颜色、状态与内边距；图标使用按钮内独立 `TextureRect`。标题保留整数像素浮动，语言和布局变化后重新居中。纹理采用最近邻，关闭Mipmaps和Repeat，保留透明通道；不同窗口通过项目全局画布适配。
