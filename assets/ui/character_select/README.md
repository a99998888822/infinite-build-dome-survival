# 角色选择正式资源

2026-10-02 按 `artifacts/wip/character_select/ui_refinement_review` 审阅结果接入正式角色选择界面。

- `background.png`：640×360，原文件逐字节复制。按 1280×720 设计画布最近邻显示，窗口变化时背景、控件和输入区域统一等比缩放。
- `roster_frame.png`：114×178，旧木与暗铜名册框；三种 `roster_*.png` 为普通、选中及空位底图，各 88×20。
- `back_button.png` / `continue_button.png`：98×25 / 66×25，无文字按钮底图。
- `difficulty_normal.png` / `difficulty_selected.png`：32×32，无文字难度底图。
- `asset_manifest.json`：来源与正式 PNG 的尺寸、SHA-256。

控件美术以 2 倍最近邻显示。文字、人物、图标、数据和交互均由 `scripts/ui/character_select_view.gd` 实时绘制，`scripts/ui/main_menu_ui_controller.gd` 负责角色选择和开战流程。正式运行不依赖 `artifacts/`。

人物使用各角色已有的完整 64×64 战斗帧画布，显示为 224×224。初心者可见范围约 70×182，为初版的 0.7 倍；悬停或键盘聚焦时读取角色配置播放行走，离开后恢复静止。资本家沿用自身七帧动画、真实开局属性及可滚动的完整特性。

列表行 176×40，图标 32×34，角色名 18px；档案标题 20px；属性标签和数字由 20px 缩至 14px，行距 22px。返回和继续使用原生按钮图标排版，左右各保留 24px，箭头不再由独立文字节点绘制。三档难度说明来自 `BattleDifficulty`。文字优先使用系统微软雅黑／Noto Sans CJK，缺字回退工程自带像素字体，不复制操作系统字体文件。

门洞内不显示角色名字下方的小字，人物悬停仍播放行走但不弹出文字提示。资本家特性仅显示“开局获得如下四件遗物”及一排四件图标；按用户澄清，仅删除汇总文案，角色属性与四件遗物的现有效果全部保留。

档案标题与角色名称固定显示，标题区高度比初次正式版缩短约 20px。正文放在 `DossierBody` 的滚动区域内，上下各保留 12px；超长内容裁切于安全边界，并自动显示垂直滚动条。设计坐标中的正文可视范围为 y=246～546，末尾图标不会贴住纸张底边。最新截图与验证见 `artifacts/wip/character_select/dossier_padding_review/`。

验证使用 `scenes/tests/character_select_view_test.tscn`，覆盖真实控件点击、动画、滚动、窗口缩放及开战参数。GPU 截图通过私有 Windows 桌面采集，记录和截图位于 `artifacts/wip/character_select/installed_validation/`。
