# 设置界面像素框体正式版

2026-10-18：用户确认采用调整内边距后的版本，现作为正式设置界面。沿用天赋页已经确认的旧铜色双层外框、方形护角及 `hud_background.png`、`hud_border_background.png`，主菜单和战斗入口均直接使用本版 `GameSettingsPanel` 与 `settings_pixel_style.gd`，运行不依赖审阅目录。

外框固定，左侧分页和右侧内容各自采用暗紫色面板；按钮、移动模式卡片、按键标签、分辨率下拉菜单、音量滑块与滚动条统一为像素边线及暖金色状态提示。设置选项、保存逻辑、战斗暂停与返回流程保持原有行为。

专用样式位于 `scripts/ui/settings_pixel_style.gd`，仅供设置界面使用；天赋页外框脚本直接复用。未修改其他界面的共用 `SettingsUIStyle`。

已完成编辑器导入、78 项无界面设置交互检查、96 项含后台 GPU 截图检查，均无失败、运行错误或警告。覆盖主菜单与战斗入口、音量同步、移动方式和快捷施法切换、ESC 返回，以及 1024×576、960×540 下的滚动和底部按钮可达性。GPU 验证使用私有桌面，未抢占用户前台。

用户复审后调整内边距：分辨率控件右侧额外留 16 逻辑像素，下拉箭头距自身右边缘 12 逻辑像素；左侧分页按钮距两侧面板边缘各 16 逻辑像素；移动方式卡片整行右侧额外留 32 逻辑像素，两张卡片等宽收窄。

最新截图目录：`artifacts/previews/settings_padding_20261018/`；初版保留在 `artifacts/previews/settings_pixel_20261018/`。

- `13_pixel_general_1080.png`：中文基础设置。
- `14_pixel_combat_1080.png`：中文战斗设置。
- `15_pixel_combat_en.png`、`16_pixel_general_en.png`：英文布局。
- `17_pixel_resolution_dropdown.png`：分辨率菜单。
- `11_review_960.png`、`11_review_1024.png`：较小窗口与滚动状态。

测试使用临时进度；截图中的音量数值仅为交互验证状态。
