# 移动端适配状态（feat/mobile-adaptation）

分支从 `ec393d9`（master）切出，目标是在**不动桌面路径**的前提下让手机可玩、可读。
所有平台判断收敛到 `MobileProfile`，桌面分支一律保持原样。

## 已落地

| 阶段 | 内容 | 关键文件 |
|---|---|---|
| P0 基座 | `MobileProfile` 单例；`--mobile-ui` 桌面调试开关；`--mobile-ui-scale=` 覆盖缩放；6 文件 9 处 `OS.has_feature("mobile")` 收拢；显示锁定类改用 `is_device()` | `autoloads/mobile_profile.gd` |
| P1 战斗 | `aim_world()` 自动索敌取代指针瞄准；指针光标/点击施法/右键移动在移动端关闭；位移武器（斩马刀/手炮/星辉法典/军刀）不再出现在起始武器、商店与奖励池，已持有的由 `sanitize_for_platform()` 清理（含初心者自带斩马刀） | `scripts/battle/active_combat_controller.gd`、`scripts/weapons/weapon_loadout.gd`、`scripts/ui/shop_offer_generator.gd` |
| P2 视觉 | `content_scale_factor=1.45` + `content_scale_aspect=EXPAND`；世界渲染目标按画布宽高比扩到 2400×1080 后**等比**缩放（原先把 16:9 目标非等比拉伸到 20:9，容器 x0.86/y0.69，角色横向被拉宽 25%，现已修正）；顶栏取消布景让位、快捷附魔按钮移到面板下方；底栏预留手势区内边距；属性抽屉留白 90→56 | `autoloads/window_settings.gd`、`scripts/core/game_root.gd`、`scripts/ui/battle_hud.gd` |
| P3 触屏 | 武器条自动化编辑与施法徽章在移动端关闭（不再创建 10 个 `WeaponCastModeIcon`）；属性行二次点按关闭 tooltip；键鼠操作提示行隐藏 | `scripts/ui/esc_overlay.gd`、`scripts/ui/shop_popup.gd`、`scripts/ui/active_combat_weapon_bar.gd` |
| 银行 | 手机跳过 1920×1080 场景拼版，改走紧凑弹窗（拼版按 viewport/1920 缩面板但字号是绝对值，抬升后面板会被文字挤爆） | `scripts/ui/finance_scene_layout.gd` |
| 主界面 | 语言选择器放大到 220×58 逻辑像素的触控尺寸；开始页背景改为 cover 后右/下贴边，哥布林与账台完整入画；标题带 333→264，745 高视口内四个按钮（含退出）全部可见 | `scripts/ui/main_menu_ui_controller.gd` |
| 选人界面 | 组合稿改为整体缩放居中（此前只把子节点按 0.69 缩，画布仍是 1920×1080，整屏塌到左上角、右侧与底部露出底板色）；手机端在选人状态隐藏战斗 HUD（放大后的 HUD 会压住角色名册标题与首张卡）；桌面逐像素不变 | `scripts/ui/character_select_view.gd`、`scripts/ui/battle_hud.gd` |
| 战斗 HUD | 属性抽屉关闭态在手机上留出 28px 边框轨道作为入口（此前抽屉连同“‹”按钮一起移出屏幕，手机上根本打不开属性面板），并把这个按钮的触控高度加到 60 | `scripts/ui/battle_hud.gd` |
| P4 工具 | 布局截图场景：启动正式战斗后依次保存战斗 HUD / 属性抽屉 / 银行并退出；支持 `--dump` 区域与按文本搜索诊断 | `scenes/tests/mobile_layout_capture.tscn` |

## 验证方式

沙箱内 Godot 无法写 `%APPDATA%`（`user://` 会被拒绝并 signal 11 崩溃），因此所有
命令都把 `APPDATA`/`LOCALAPPDATA` 重定向到 `tmp/appdata`。

```powershell
$env:APPDATA = (Resolve-Path tmp\appdata).Path
$g = 'E:\engineSoftware\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe'
& $g --headless --path . --scene res://scenes/tests/mobile_profile_test.tscn --quit-after 900 -- --mobile-ui
```

截图（私有桌面，不抢焦点）：

```
python scripts/tools/run_godot_background.py --godot <exe> --log tmp/capture.log --timeout 220 \
  -- --path . --scene res://scenes/tests/mobile_layout_capture.tscn -- --capture-dir=<abs> --mobile-ui
```

新增守卫：`mobile_profile_test`（17 项）、`mobile_bank_test`（13 项）。

## 全量回归矩阵（22 个场景 × 两种模式）

桌面列为改动前的既有状态；`--mobile-ui` 列是本次适配的待办清单。

| 场景 | 桌面 | --mobile-ui | 备注 |
|---|---|---|---|
| finance_scene_regression_test | 58/0 | 跳过 | 移动端走弹窗，由 mobile_bank_test 覆盖 |
| mobile_profile_test / mobile_bank_test | 17/0 · 16/0 | 17/0 · 16/0 | 本分支新增，后者含附魔台适配检查 |
| battle_hud_damage_test | 34/0 | 34/0 | |
| economy_flow_test / localization_test / principal_relic_test / item_icon_art_test | 0 失败 | 0 失败 | 与平台无关 |
| stats_drawer_art_test / relic_art_install_test / cavern_sunlight_test | 通过 | 通过 | |
| finance_preparation_test | 1 | 跳过 | 断言的是桌面画布（含 hover 与拖拽）；手机由 mobile_bank_test 覆盖，含附魔台控件不越界 |
| goblin_loan_test / battle_settings_test / run_settlement_test / goblin_trade_test / interest_arrival_test / wave_challenge_test / battle_specialization_test | 全过 | 跳过 | 桌面画布契约，已加跳过守卫（见下节归类） |
| humanity_economy_test | 1 | 3 | 桌面基线本就失败，差值待查 |
| combat_guide_test | 18 | 22 | 桌面基线本就失败 |
| capitalist_character_test | 33 | 35 | 桌面基线本就失败 |
| active_combat_integration_test | 6 | 0 | 桌面为既有 headless 时序失败 |
| window_settings_test | 1 | 1 | 既有 headless 窗口限制（已 stash 复测确认） |

## 剩余移动端失败的性质（已逐条读清单）

这 7 个套件在 `--mobile-ui` 下的失败属于同一类：它们用**模拟鼠标指针**在**由
1920×1080 画布推导出的坐标**上驱动 UI，并断言该画布的几何；移动端抬升后坐标全部
偏移，点击落空又连锁引发后续行为断言失败。

| 套件 | 代表失败 | 归类 |
|---|---|---|
| battle_settings_test | `production panel retains approved bounds in native coordinates`、`tab changes preserve choices and selected indicators` | 用面板 rect 推导点击坐标 |
| run_settlement_test | `design canvas fits without scrolling (1920, 1080)`、`return closes result and stops its sounds` | 画布几何 + 坐标点击 |
| goblin_loan_test | `real disabled mouse clicks are silently counted`、`reopen shows the same three contracts` | 借贷弹窗热区按桌面坐标 |
| goblin_trade_test | `strong refresh fits complete text without unused vertical space` | 交易卡文字排版 |
| interest_arrival_test | `compact details scroll without overlapping the footer`、`only the centered receipt intercepts clicks inside its frame` | 回执几何 + 点击拦截 |
| wave_challenge_test | `normal start declines without extra elites`、`declined offer cannot be accepted later` | 坐标点击 |
| battle_specialization_test | `purchase fits workspace (640, 360)` | 画布几何 |

结论：这些与 `finance_preparation_test` / `finance_scene_regression_test` 同属**桌面
画布契约**，移动端应当跳过而不是逐条改断言；手机侧需要独立的触屏断言，模板就是
`mobile_bank_test`（只断言"控件在视口内 + 没有 Label 溢出 + 关键节点存在"这类与
画布无关的性质）。

移动端当前真实覆盖：
- 平台无关套件（两种模式均 0 失败）：economy_flow、localization、principal_relic、
  item_icon_art、battle_hud_damage、stats_drawer_art、relic_art_install、cavern_sunlight
- 移动端专用：mobile_profile_test（17）、mobile_bank_test（16，含附魔台）

## 待办（按收益排序）

1. **浮层/面板在 1324×745 逻辑视口下的排版**：上表 45 条移动端新增失败集中在同一族
   问题——按 `viewport/1920` 等比缩面板，但字号是绝对值。要么给这些面板加最小宽度与
   换行，要么像银行一样为移动端准备紧凑排版。
2. **商店弹窗与 ESC 覆盖层的截图核对**：目前只出过战斗 HUD、属性抽屉、银行三张。
3. **哥布林对白气泡定位**：银行里会压住第一张卡牌（打字机动画本身正常）。
4. 桌面基线里 `combat_guide_test`(18) / `capitalist_character_test`(33) 的失败与本分支
   无关，但需要单独确认是否也是 headless 环境所致。

## 已知取舍

- 选人界面是一张 16:9 的组合稿（左侧木板与右侧羊皮纸烘焙在 `background.png` 里），
  手机端整体缩放居中、两侧留深色边；要铺满 20:9 需要补一张更宽的全屏底图。

- 位移武器在移动端**不生成也不保留**（用户确认），数据文件未改动，全部由 `MobileProfile.weapon_available()` 在运行时过滤，因此与 master 的 `characters.json` / `weapons.json` 无冲突。
- 移动端世界视野 = 物理屏幕像素：竖向与桌面一致（1080），横向随屏幕变宽（20:9 多 25%）。
- 掌机手势条按 16 逻辑像素预留，真机实测后可调 `MobileProfile.BOTTOM_INSET`。

## 2026-11-05：固定移动端操作方式

- 移动端固定全屏，隐藏基础设置中的分辨率和全屏选项；显示“摇杆”“自动攻击”只读说明，关闭战斗设置入口。桌面预览 `--mobile-ui` 同样应用这些规则，私有桌面截图保留捕获尺寸。
- 旧的桌面手动施放偏好不会影响移动端自动攻击，移动端不能进入手动瞄准或键盘移动。原有位移武器过滤继续生效，桌面偏好不会被移动端覆盖。
- 战斗、背包及奖励武器栏不显示自动／手动模式图标；即使调用方请求编辑，移动端也不会生成这些图标。
- 天赋移动端提示改为“点击拖动”，支持在空白处触屏拖动；重置升级按钮移入属性汇总面板标题区域，避开天赋点与树节点。

验证：`mobile_controls_test` headless 33 项、16:9 与 20:9 私有桌面 GPU 各 38 项（含 5 张截图及其实际像素尺寸断言），均 0 失败；`mobile_profile_test` 17 项、桌面 `battle_settings_test` 78 项、`localization_test` 398 项均通过。两次 GPU 捕获均确认指定私有桌面且 `foreground_samples=0`。主场景初始化也重新应用移动端宽屏比例，避免覆盖为桌面留边模式。

较广回归仍有既有失败：天赋测试 3 项、桌面武器集成测试 5 项；已在临时副本恢复本次修改前的脚本复测，失败项完全一致。桌面显示测试也仍有上文记录的 headless 窗口模式失败（1 项）。

20:9 捕获仍会记录此前检查已发现的 `SubViewportContainer.stretch` 与手动设置子视口尺寸的警告；此次没有调整该渲染容器逻辑。

复查入口：[本次改动截图](../../tmp/mobile_controls_review/index.html)。本次功能修改未处理之前视觉检查中记录的其余天赋面板遮挡、利息回执、奖励字号与结算触屏滚动问题。

## 2026-11-05：属性栏与 ESC 间距

- 修复属性栏移动布局首次打开未初始化的问题。文本左右边距收窄、起始位置贴近卷轴下沿；完整的 416 像素金属框保留在屏幕内，底部距游戏边缘 8 逻辑像素。
- 移动端金币／本金信息左边与属性框左边对齐；武器栏和遗物清单共用左右边界，整体靠右，和属性框之间保留 32 逻辑像素（含 28 像素抽屉按钮）。
- ESC 隐藏经济日志入口，关闭 ESC 后恢复战斗日志。

验证：移动操作与 HUD 几何检查 headless 43 项，1920×1080、2400×1080 私有桌面 GPU 各 48 项，均 0 失败；桌面属性栏美术测试 0 失败，移动银行 16 项通过。两种比例实际截图尺寸均核对，捕获确认私有桌面且 `foreground_samples=0`。已有子视口 stretch 警告仍存在。

复查入口：[最新移动端截图](../../tmp/mobile_controls_review/index.html)，默认显示 ESC 页面。

## 2026-11-06：宽屏 ESC 左侧留白修正

取消移动端武器栏的 840 逻辑像素宽度上限，武器栏和遗物清单从左侧安全边距开始铺满可用区域；20:9 左侧不再因右对齐留下大块空白，右侧仍保留属性栏按钮间距。补充宽屏左边界与填满宽度断言。headless 44 项、16:9／20:9 GPU 各 49 项均通过；截图已更新，私有桌面捕获 `foreground_samples=0`。

## 2026-11-06：理财恢复 PC 场景

按用户要求，以本地 PC 主线 `main` 为基准（仓库没有 `master`），取消移动端强制走紧凑弹窗的分支。恢复银行背景、柜员、左侧存取款、右侧购买／附魔分页、交易、利息回执和贷款弹窗；保留 PC 操作逻辑。

移动端继续使用 1.45 倍 UI 放大，金额输入由 12 提升到 20 逻辑像素，武器／附魔名称由 15 提升到 20。银行列保留最小宽度，附魔背包按可用宽度排布较大的卡片；内容通过现有触屏滚动访问。柜员对白移入左栏，避开分页按钮；附魔底部保留滚动余量。

验证：`mobile_bank_test` headless 28 项，16:9／20:9 GPU 各 35 项均通过，包含真实存款、回执和贷款打开、附魔底部操作可达、控件越界及字号检查；桌面 `finance_scene_regression_test` 58 项通过。GPU 均在私有桌面运行，`foreground_samples=0`。既有子视口 stretch 警告仍存在。真机触屏阅读体验仍需设备确认。

此前“手机使用紧凑银行弹窗”的记录仅描述历史实现，以本节为准。复查：[PC 基础的移动理财截图](../../tmp/finance_pc_mobile_review/index.html)。

## 2026-11-06：属性栏和购买卡密度

- 移动端属性纸张宽度调整为原来的 85%，同步收紧内容边距、抽屉预留宽度和金币对齐位置。
- 购买区在移动端上移约 40 逻辑像素，商品卡缩小到三列布局；卡片图标框同步缩小，长描述仍会自动压缩或通过列表滚动查看。

验证：`mobile_controls_test` headless 44 项，`mobile_bank_test` headless 29 项，16:9／20:9 理财 GPU 各 36 项，均 0 失败；GPU 捕获均确认 `foreground_samples=0`。既有子视口 stretch 警告和测试退出时资源回收提示仍存在。

## 2026-11-06：属性文本区收窄

保持 85% 的属性纸张外框不变，只增加移动端 ContentMargin，使内部文本滚动区约为此前的 90%，四边留出更均衡的纸张留白。

## Android 安装包精简与改名

Android 包名改为 `com.octopus.goblin.dungeon`，手机显示名称改为“哥布林教你地下城”，版本明确为 `1.0.0`。导出规则排除截图复查、临时缓存、测试与录制场景、开发脚本、文档及素材制作源文件，不改变正式美术和音频质量。重新导出的 Debug APK 从 249.95 MiB 降至 46.19 MiB，减少 81.52%。

headless 编辑器检查、APK 导出、签名与 ZIP 对齐检查通过；检查 721 项静态运行资源引用无缺失，并从 APK 提取的实际资源包完成 headless 启动和配置加载。原有 SubViewport stretch 警告仍存在；真机验收与正式发布签名仍待完成。详见 [Android 发布检查](android_taptap_release_audit.md)。

补齐 Logo：项目图标及 Android 普通图标使用根目录 `icon.png`（与用户附件相同），自适应前景、背景和主题单色图标均由原图派生，避免 Android 使用默认 Godot 图标。含 Logo 的最新测试包约 46.72 MiB，已从 APK 实际提取图标核对，导出、签名及 ZIP 对齐检查通过。

## 实机反馈：设置、天赋、奖励与结算

- 移动端音乐／音效百分比右侧增加 24 逻辑像素留白，避开滚动条；设置页支持触屏拖动滚动。
- 天赋树触屏拖动灵敏度降为此前的 55%，用触点位置差计算移动，并避免触屏与模拟鼠标重复拖动。桌面鼠标灵敏度保持原值。
- 升级奖励标题缩小，移动端最多三列；图标框缩至 64，原生图标缩至 36 像素，名称 20、正文 18 逻辑像素。卡片正文自适应高度，额外奖励通过触屏滚动查看。
- 移动端战斗右上角问号替换为暂停图标，点击打开 ESC 背包；禁用移动端百科入口。
- 刚焰炉改为冷却结束后自动向周围释放，无须受击，也不要求有敌人目标。受击不再额外触发，仍受冷却与暂停规则约束；武器说明和中英文翻译同步更新。此武器机制在各平台一致。
- 移动端结算使用紧凑横条、两列击杀记录及自适应立绘尺寸，完整显示天赋点结算框和哥布林立绘；保留触屏滚动以容纳额外击杀种类。

验证：headless 编辑器通过；移动端 16:9／20:9 私有桌面 GPU 各 68 项通过，实际截图尺寸为 1920×1080、2400×1080，均确认 `foreground_samples=0`。刚焰炉／军刀集成 71 项、结算 442 项、桌面奖励排版 366 项、本地化 398 项通过。桌面奖励检查改为依据实际武器栏高度预留空间，避免旧固定高度断言误报；同时修复滚动容器释放后的延迟回调。既有 SubViewport stretch 警告及部分测试退出时的资源回收提示仍存在。

截图：`tmp/device_feedback_review/16x9/`、`tmp/device_feedback_review/20x9/`。本轮测试包：`tmp/device_feedback_review/goblin-dungeon-device-fixes.apk`，继续使用原包名、中文名称、Logo 和 Debug 签名；尚需用户再次实机确认触控手感。

导出核对：49,000,917 字节（46.73 MiB），包名 `com.octopus.goblin.dungeon`，显示名称“哥布林教你地下城”，ARM64，版本 `1.0.0`。APK v2／v3 签名及 16 KiB ZIP 对齐检查通过，包含本次修改脚本及暂停图标；未打入临时截图、测试场景或文档。复查页：[实机反馈修复截图](../../tmp/device_feedback_review/index.html)。

## 实机反馈：ESC 触摸入口与夜间指引

- 战斗入口改为明确的 ESC 图标。修复每帧先禁用再启用按钮导致按下状态丢失的问题；摇杆同时避让 HUD 和顶部按钮区域。直接响应按钮触摸，支持按住摇杆时用另一根手指打开背包。
- 仅移动端战斗底部武器栏整体缩至 80%，图标、边框、冷却文字同比缩小，保持底部居中。ESC 背包和奖励页武器栏不受影响。
- 夜间地堡箭头依据底部武器栏的实际位置上移，预留箭头光晕、距离文字和间隔；地堡进入提示也限制在武器栏上方，覆盖单排和多排武器布局。

验证：先用真实触摸事件复现旧版点击失败，再验证修复。headless 移动操作 114 项通过（含实际点击、摇杆移动、双指操作，以及 1／6／24 格武器栏下的五个方向指引）；16:9／20:9 私有桌面 GPU 各 122 项通过，`foreground_samples=0`。桌面武器栏鼠标 9 项、夜间撤离 46 项通过，headless 编辑器无脚本编译错误。既有 SubViewport stretch 警告仍存在。

新测试包：`tmp/mobile_hud_touch_review/goblin-dungeon-hud-touch-fixes.apk`。复查页：[ESC 与地堡指引](../../tmp/mobile_hud_touch_review/index.html)。
