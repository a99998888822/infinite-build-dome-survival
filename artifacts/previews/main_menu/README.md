# 主菜单像素背景（待审阅）

尚未接入正式首页。保留无人物的遗迹前厅、暗木与苔绿旧金配色，左侧为菜单预留低对比空间。

- [纯背景](background-redrawn-v2.png)：1920×1080，原生像素图放大三倍。
- [菜单叠加预览](homepage-preview-v2.png)。
- `background-native-640x360.png`：可用于后续接入的原生背景。
- `menu-overlay-v2.png`：独立透明菜单层，供合成预览使用。
- `draw_background.py`：原创像素绘制源文件，执行后重新生成上述背景与合成预览。

分层图片可以由绘制代码重建，因此不另存中间图。
