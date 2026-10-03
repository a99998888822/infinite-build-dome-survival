# 理财简洁框体 R02 正式接入

用户确认 `frame_skin_review_r02` 后，已将简洁框体安装到正式理财页。

## 接入内容

- 正式素材：`assets/ui/finance/clean_frames/`，12 张 PNG 与 R02 审阅素材字节一致；不依赖工作目录或预览脚本。
- 正式皮肤：`scripts/ui/finance_frame_skin.gd`，纯深绿内衬、单层暗铜色像素细边、小切角，选中项使用旧金色。最近邻采样与九宫格平铺保留像素边缘。
- 银行表单、顶部汇总/余额框、购买卡片、附魔区域、按钮、输入框、滚动滑块、日志、出售确认、交易/贷款/利息框体使用已确认皮肤。
- 保留原有内容内边距、按钮状态、商品稀有度提示、动态强力刷新提示以及所有游戏操作。强力刷新在新纹理上作轻微色彩脉动，仍使用原有动态文字提示。
- 皮肤在创建控件或状态变化时应用，不运行审阅稿中的每帧递归覆盖。用于波次挑战的共用交易控件保留原有风格。

## 验证与备份

替换前脚本保存在 `artifacts/wip/finance/clean_skin_installation/before/`；审阅 R01、R02 保留。

运行证据统一在 `artifacts/wip/finance/clean_skin_installation/`：

- `asset_hashes.json`：12 张素材校验值。
- `editor.log`：Godot 4.7.2 无界面导入检查。Android build-tools 目录提示与桌面界面无关。
- `test_results.json`：购买/出售/附魔/银行、交易规则、交易取消、贷款、利息、属性栏六组检查。交易测试补齐临时进度结束与音频释放，消除退出时遗留资源的提示。
- `capture_report.json`：正式资源和正式控件的运行检查，覆盖 1152×648、1280×720、960×540、640×360，以及属性栏收放、长交易、银行预览；无审阅样式覆盖。
- `visual_comparison.json`：正式购买页、附魔页、属性栏收起、长交易、银行预览与已确认 R02 截图逐像素一致，差异均为 0。
- `gpu.json`：引擎所在专用桌面已验证，`foreground_samples=0`。

正式运行截图：`finance_shop_1152x648.png`、`finance_enchant_1152x648.png`。
