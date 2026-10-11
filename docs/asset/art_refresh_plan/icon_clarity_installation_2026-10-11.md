# 武器与遗物图标清晰度正式接入

2026-10-11：按用户确认的 R01 方案，将 15 张武器图标（含回收状态图）和 90 张遗物图标的缩小版本接入正式界面。正常启动游戏即可使用，无需预览脚本。

## 文件归属

| 类别 | 目录 | 用途 |
|---|---|---|
| 原始素材、可编辑稿 | `artifacts/sources/` 及已有素材制作记录 | 保留原图、来源和编辑历史 |
| 正式资源 | `assets/ui/icons/weapons/`、`relics/`、`clarity/` | 原有 105 张 PNG 保留为较大显示的母版；`clarity/` 存放正式小尺寸图集 |
| 本次验证 | `artifacts/validation/icon_clarity_install_20261011/` | 正式代码实机截图、日志、尺寸记录、安装校验及修改前文件备份 |

正式接入后，已按用户要求于 2026-10-11 将 `artifacts/previews/icon_clarity_20261011/` 历史预览目录移至回收站，并关闭对应预览服务。素材保留原图和正式资源两类；正式接入的实机截图、验证记录继续保留。清理前后已校验 105 张母版 PNG 和正式图集文件完全一致，见验证目录中的 `preview_cleanup.json`。`artifacts/.gdignore` 将制作记录排除在正常导入之外。

## 资源与运行方式

R01 使用本地算法在源色板内缩减纹理、重建外轮廓，并保持硬透明；此次安装没有重新生成或重画图标。`scripts/tools/install_icon_clarity.py` 将 1,842 个非原尺寸版本无损打包为 18 张图集，每个格子带 2px 透明间隔。每个图集区域的 RGBA 像素均与对应审阅 PNG 一致，原有 105 张 PNG 的 SHA-256 不变。

安装脚本及验证目录中的 `create_capture.py`、`render_review.py` 保留为处理过程记录；其历史预览输入已经清理，不能直接重跑原流程。正式图集和独立的 `capture.gd/.tscn` 均不依赖已删除目录。

`assets/ui/icons/clarity/catalog.gd` 保存来源、尺寸和区域。`scripts/ui/item_icon_art.gd` 在控件显示、布局或窗口尺寸变化时，按物理显示尺寸选择最接近的版本，使用最近邻过滤并缓存图集区域。原尺寸或更大的显示使用原有母版。正常运行不依赖 Python 或预览文件，也不逐帧扫描界面。

已覆盖顶部武器按钮、底部战斗栏、遗物清单、商店、附魔页、奖励卡、百科、选角初始武器、出售预览、收款动画、挑战图标、鼠标武器提示及伤害统计。行内发光图标沿用已有合成方式，底图改用清晰度版本。

| 常用位置 | 1152×648 使用尺寸 | 2560×1440 使用尺寸 |
|---|---:|---:|
| 顶部武器 | 34px | 76px |
| 底部战斗武器 | 46px | 102px |
| 遗物列表／商店 | 40px | 89px |
| 商店武器 | 44px | 98px |
| 附魔武器／出售小图 | 36px／26px | 80px／58px |
| 奖励遗物 | 48px | 107px |
| 百科遗物（128px 母版） | 64px | 128px 母版 |

全局 `project.godot`、窗口缩放、UI 布局和反馈动画保持原样。正式绑定不采用预览脚本的控件尺寸取整，因此非整数缩放时仍可能有不足 1px 的采样差异。对于未制作的物理尺寸，选择最近的尺寸；16px 伤害统计图标仍需要从最小 26px 版本缩小。此次重点解决常用界面尺寸的边线丢失与线性过滤模糊，不代表任意缩放下像素都能一一对应。

## 验证

- Godot 4.7.2 编辑器无窗口导入和主场景运行通过；无脚本解析或编译错误。编辑器仍提示本机 Android build-tools 不可用、忽略 `tmp` 内另一项目。
- 图标回归覆盖尺寸切换、缓存、控件复用、清空、原图身份、回收状态图、裁剪图，以及全部 1,842 个图集区域；另验证真实奖励卡的尺寸变化与遗物／武器复用。
- 冷却反馈回归 29 项通过。附魔页回归 16 项通过；测试夹具单独提高负载上限以装入五张卡片，不依赖当前角色平衡。首次退出出现资源清理提示，详细日志复跑未复现。
- GPU 在私有 Windows 桌面运行，核验实际引擎桌面一致，`foreground_samples=0`。1152×648、2560×1440 各捕获选角、战斗、清单、百科、商店、附魔及奖励组件，共 14 张截图。奖励组件为单独挂载的真实控件，其他界面由正常流程打开。
- 运行记录确认受支持图标使用最近邻，读取路径全部位于正式 `assets`。逐页目视检查正式截图，重点核对细长武器、遗物外轮廓、奖励卡和选角裁剪。全量素材的视觉检查范围沿用 R01：40px／64px 全页检查，其余尺寸技术验证与代表样本实机检查。

## 实机审阅

下图上排为修改前截图，下排为本次正式代码截图；放大只复制像素。

![1152 实机局部对照](../../../artifacts/validation/icon_clarity_install_20261011/detail_1152.png)

![2560 实机局部对照](../../../artifacts/validation/icon_clarity_install_20261011/detail_2560.png)

完整 PNG：

| 界面 | 1152×648 | 2560×1440 |
|---|---|---|
| 遗物清单 | [查看](../../../artifacts/validation/icon_clarity_install_20261011/inventory_1152.png) | [查看](../../../artifacts/validation/icon_clarity_install_20261011/inventory_2560.png) |
| 商店 | [查看](../../../artifacts/validation/icon_clarity_install_20261011/shop_1152.png) | [查看](../../../artifacts/validation/icon_clarity_install_20261011/shop_2560.png) |
| 附魔 | [查看](../../../artifacts/validation/icon_clarity_install_20261011/workbench_1152.png) | [查看](../../../artifacts/validation/icon_clarity_install_20261011/workbench_2560.png) |
| 百科 | [查看](../../../artifacts/validation/icon_clarity_install_20261011/encyclopedia_1152.png) | [查看](../../../artifacts/validation/icon_clarity_install_20261011/encyclopedia_2560.png) |
| 选角 | [查看](../../../artifacts/validation/icon_clarity_install_20261011/character_1152.png) | [查看](../../../artifacts/validation/icon_clarity_install_20261011/character_2560.png) |
| 战斗 | [查看](../../../artifacts/validation/icon_clarity_install_20261011/battle_1152.png) | [查看](../../../artifacts/validation/icon_clarity_install_20261011/battle_2560.png) |
| 奖励组件 | [查看](../../../artifacts/validation/icon_clarity_install_20261011/reward_1152.png) | [查看](../../../artifacts/validation/icon_clarity_install_20261011/reward_2560.png) |

来源与打包记录见 `installation.json`，实机路径和尺寸见 `measurements.json`，后台运行及图片校验见 `verification.json`，均位于本次验证目录。
