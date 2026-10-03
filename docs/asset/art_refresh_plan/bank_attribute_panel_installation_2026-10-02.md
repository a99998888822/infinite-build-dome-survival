# 银行属性面板正式接入

用户于 2026-10-02 选定 Picxel 128×256 版本，并要求以 `<`、`>` 替换旧皮革铆钉拉手。

- 原图：`artifacts/sources/finance/dark_fantasy_bank_attribute_panel_1024x2048.png`。
- 选定稿：`artifacts/previews/bank_attribute_panel/r01/delivery/bank_attribute_panel_128x256.png`。
- 正式资源：`assets/ui/stats_drawer/stats_parchment_panel.png`，与选定稿逐字节一致，透明 PNG、16 色、128×256。
- SHA-256：`2fd0efb6858667028831a844ac33b5b7a63a528178da185332e49fdf76681749`。

`scripts/ui/stats_drawer_skin.gd` 使用新纸张资源，以最近邻方式显示为 256 像素宽。上下段保留金属夹与包角比例，中间段随抽屉高度适配。新资源未烘焙文字，属性数值继续实时显示。

`scripts/ui/battle_hud.gd` 移除皮革拉手节点及贴图引用，使用纯字符按钮：收起时 `<`，展开时 `>`；点击区域完整保留 28×44。银行界面默认展开且允许手动收起，保留既有滑动动画。文字改为深色，属性增长／下降分别使用深绿／深红。顶部留 84 像素避开夹子，底部留 76 像素，并为滚动提示单独留出空间。

验证：Godot 4.7.2 无头导入、主场景启动通过；属性面板交互无头检查 39 项通过，最终 GPU 检查 65 项通过。覆盖 1152×648、1024×576、1920×1080、640×360 的开合、按钮点击区域、滚动到底和内容边距；银行页面可收起、重新展开并保留滚动位置。无脚本、编译或运行错误。导入日志有已有的 Android build-tools 目录提示，与本次桌面预览无关。

后台 GPU 运行使用 `scripts/tools/run_godot_background.py`，实际引擎窗口位于独立 Windows 桌面，`foreground_samples=0`。

实机截图和日志：`artifacts/wip/finance/attribute_panel_install/`，其中 `finance_1152x648.png` 为展开效果，`finance_closed_1152x648.png` 为收起效果，`finance_scrolled_1152x648.png` 为滚动到底。
