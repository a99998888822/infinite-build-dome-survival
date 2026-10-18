# 理财界面确认素材接入（2026-10-18）

用户确认：哥布林采用最新 A+++，理财场景底图采用原始附件，属性栏采用 A+。随后按用户要求局部校正底图紫色光晕，使圆心对准吊灯中央；原始附件独立保留。

## 正式资源

| 资源 | 采用版本与尺寸 | 正式路径 |
|---|---|---|
| 理财背景 | 原图1672×941，局部校正吊灯光晕 | `assets/ui/finance/finance_background.png` |
| 银行／借贷哥布林 | A+++，5张320×320，横排1600×320 | `assets/ui/finance/goblin_banker_states.png` |
| 结算哥布林 | 同一版表情，4×4图集1280×1280 | `assets/ui/settlement/goblin_reactions.png` |
| 属性栏面板 | A+，288×516，文件字节不变 | `assets/ui/stats_drawer/stats_parchment_panel.png` |

确认PNG、可编辑PXG分块和坐标保存在 `artifacts/editable/finance_ui_20261018/`；三张原始附件保存在 `artifacts/sources/finance_ui_20261018/`。两个全局索引均已更新。版本、来源、哈希与分块坐标见可编辑目录的 `manifest.json`，旧资源备份见 `artifacts/validation/finance_ui_install_20261018/before/`。

五表情对应：`neutral→neutral`、`worried→downcast`、`angry→displeased`、`sly→smile`、`excited→delighted`。保留运行时存款／取款语义和结算行序 `[4,2,3,1]`，结算纵向浮动仍为 `[0,-2,0,2]`，未裁掉不透明像素。每张立绘最多16色、透明度仅0或255，图集帧与确认PNG逐像素一致。

## 显示适配

- 三处哥布林消费者均按图集实际尺寸裁切。柜台腰部接触点更新为原生坐标 `(160,282)`，手部接触点为 `(160,314)`，换算到原有128单位布局；显示区域保持原布局。
- 面板不再写死128×256。顶部216行、底部284行按显示宽度缩放，仅延展中间16行的纸面和无铆钉边轨，避免五金拉长。
- 属性栏后续微调：1920×1080下高度统一900（上下各90），字号18→22。按用户最新留白要求，左右内边距84、顶部144、底部84；每行文字上下各留2px，保留纸面和文字之间的空隙。取消根据内容压缩底部留白，超出内容通过滚动查看。保持最近邻采样和开合交互。
- 背景采用原始PNG的局部校正版：光晕圆心由原图坐标 `(727,284)` 移到灯芯 `(752,207)`，分离旧紫色染色、仅修补原光晕窄边缘，再将紫色投射到新位置；不移动吊灯、链条或招牌。处理范围外像素与原图一致。当前保留稿为 `artifacts/editable/finance_ui_20261018/background_lamp_aligned.png`，参数和原图哈希见同名JSON；生成入口为 `scripts/tools/align_finance_lamp_glow.py --output <新路径>`。归档工具优先读取清单中的 `revised_source` 并核对哈希。

## 复验与截图

验证目录：`artifacts/validation/finance_ui_install_20261018/`。资源检查通过 `install_goblin_portraits.py --check`、`install_stats_drawer_art.py --check`，背景归档重建逐像素等于正式原图。`installation.json` 记录四张正式PNG的尺寸、SHA-256和来源一致性。

Godot 4.7.2 已完成 headless 编辑器导入。运行验证涵盖属性栏开合与滚动、理财场景交互、借贷和结算；实际运行结果见 `headless_results.json` 与对应日志。主场景也完成120帧 headless 启动。

日志边界：首次 headless 属性栏测试在选人页皮肤加载时出现一次 dummy 渲染器 `Parameter "t" is null`，功能断言全部通过；主场景强制120帧退出有4个ObjectDB对象／2个资源的释放提示。没有解析或编译错误。以上日志如实保留，不称全工程零警告。

GPU实机截图由 `scripts/tools/run_godot_background.py` 在独立Windows桌面取得；报告同时记录引擎实际桌面和 `foreground_samples`，不切换用户桌面。最终截图与GPU回归结果在 `final_stats_drawer_art_test/`、`final_finance_scene_regression_test/`、`final_run_settlement_test/` 和对应 `gpu_*.log/.json`。

最终GPU结果：属性栏76项、理财场景76项、结算366项检查通过，三个进程退出码均为0，无脚本错误或警告，实际引擎桌面均验证一致且 `foreground_samples=0`。`gpu_results.json` 汇总结果。`asset_verification.json` 另确认四张正式PNG哈希、五张立绘逐帧相等、六项PNG可由保留网格精确重建及UTF-8文本检查。

属性栏高度／字号微调后的最新复验在 `artifacts/validation/stats_drawer_layout_20261018/`：`final_headless.log` 和 `final_gpu.log` 均为零失败，无脚本错误；`final_gpu.json` 验证独立引擎桌面且 `foreground_samples=0`。最新实机图为 `final/finance_1920x1080.png`，同目录保留战斗场景和多窗口尺寸截图；`capture_report.json` 记录实际面板、内容区和列表尺寸。

随后按用户要求增加上下和行间留白。该版最新验证在 `artifacts/validation/stats_drawer_padding_20261018/`：headless 50项、GPU 76项检查通过，无脚本错误，独立桌面验证通过且 `foreground_samples=0`。`captures/finance_1920x1080.png` 展示默认位置，`captures/finance_scrolled_1152x648.png` 展示滚动到底后的完整末尾属性。

吊灯光晕校正后的最新截图在 `artifacts/validation/finance_lamp_glow_20261018/captures/finance_1920x1080.png`，局部实机图为同级验证目录的 `lamp_runtime_crop.png`。导入与GPU回归通过，无脚本错误；引擎实际桌面验证一致且 `foreground_samples=0`。校正脚本同时核对吊灯／招牌保护区域和光晕处理区域外的像素未变。

## 后续重建

```powershell
python -B scripts/tools/install_goblin_portraits.py --source artifacts/editable/finance_ui_20261018/portraits
```

面板复制当前保留的 `panel_Aplus.png`，背景复制当前保留的 `background_lamp_aligned.png`（或运行光晕校正工具重新输出）。保留现有导入设置。旧256px立绘目录和旧背景分层文件仅用于历史追溯，不得覆盖本次确认稿。
