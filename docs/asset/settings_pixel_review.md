# 设置界面像素框体正式版

2026-10-19（最新）：采用用户确认的「炭黑底＋灰铁边＋骨白文字」整体方案，当前选中的移动方式卡片恢复此前「烟褐＋古铜」样式，包括底色、边框、标题、说明和菱形标记；切换移动方式后，原卡片恢复灰铁色。分页、复选框、通用按钮与滑块沿用中性色。正式样式由 `scripts/ui/hud_palette.gd` 提供，中性贴图位于 `assets/ui/hud/neutral_iron/`，选中卡片复用原烟褐素材。

本轮 78 项设置、194 项天赋无界面检查全部通过；后台 GPU 完成中英文、分辨率菜单与双向选择切换截图，实际私有桌面已核验，`foreground_samples=0`。最新截图位于 `artifacts/reviews/neutral_iron_bronze_selection_20261019/`：`03_settings_combat.png` 为键盘移动选中，`03b_settings_mouse_selected.png` 为鼠标移动选中。GPU 运行无错误或警告；额外无界面截图流程退出时出现既有的 4 个对象／2 个资源未释放提示，交互测试均正常退出。下方保留历史记录。

2026-10-19：设置界面随用户选定的「烟褐＋古铜」天赋方案更新。两页共用 `smoke_bronze_palette.gd` 及正式 HUD 贴图，设置的分页、移动方式卡片、按键标签、按钮、滑块、滚动条、复选框和分辨率菜单均使用烟褐底与铜色状态提示；外框像素宽度收细为 2。原布局、字号、留白及保存／返回逻辑保持不变。已通过 194 项天赋与 78 项设置无界面检查，另完成主菜单中英文、下拉菜单及天赋正式场景的后台 GPU 截图。截图位于 `artifacts/reviews/smoke_bronze_install_20261019/`，`01_settings_general.png` 和 `03_settings_combat.png` 为中文效果；旧稿与原始素材保留。下方为此前版本记录。

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
