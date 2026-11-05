# 移动端适配状态（feat/mobile-adaptation）

分支从 `ec393d9`（master）切出，目标是在**不动桌面路径**的前提下让手机可玩、可读。
所有平台判断收敛到 `MobileProfile`，桌面分支一律保持原样。

## 已落地

| 阶段 | 内容 | 关键文件 |
|---|---|---|
| P0 基座 | `MobileProfile` 单例；`--mobile-ui` 桌面调试开关；`--mobile-ui-scale=` 覆盖缩放；6 文件 9 处 `OS.has_feature("mobile")` 收拢；显示锁定类改用 `is_device()` | `autoloads/mobile_profile.gd` |
| P1 战斗 | `aim_world()` 自动索敌取代指针瞄准；指针光标/点击施法/右键移动在移动端关闭；位移武器（斩马刀/手炮/星辉法典/军刀）不再出现在起始武器、商店与奖励池，已持有的由 `sanitize_for_platform()` 清理（含初心者自带斩马刀） | `scripts/battle/active_combat_controller.gd`、`scripts/weapons/weapon_loadout.gd`、`scripts/ui/shop_offer_generator.gd` |
| P2 视觉 | `content_scale_factor=1.45` + `content_scale_aspect=EXPAND`；相机按 1/1.45 反向补偿，世界可视单位 = 物理屏幕像素（1080p 手机 2400×1080 战场，无黑边）；顶栏取消布景让位、快捷附魔按钮移到面板下方；底栏预留手势区内边距；属性抽屉留白 90→56 | `autoloads/window_settings.gd`、`scripts/player/player_controller.gd`、`scripts/ui/battle_hud.gd` |
| P3 触屏 | 武器条自动化编辑与施法徽章在移动端关闭（不再创建 10 个 `WeaponCastModeIcon`）；属性行二次点按关闭 tooltip；键鼠操作提示行隐藏 | `scripts/ui/esc_overlay.gd`、`scripts/ui/shop_popup.gd`、`scripts/ui/active_combat_weapon_bar.gd` |
| 银行 | 手机跳过 1920×1080 场景拼版，改走紧凑弹窗（拼版按 viewport/1920 缩面板但字号是绝对值，抬升后面板会被文字挤爆） | `scripts/ui/finance_scene_layout.gd` |
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
| goblin_loan_test | 0 | **7**（且断言数 73→56） | 借贷浮层 |
| battle_settings_test | 0 | **4** | 设置面板 |
| run_settlement_test | 0 | **4** | 结算面板 |
| goblin_trade_test | 0 | **3** | 交易卡 |
| interest_arrival_test | 0 | **3** | 利息回执 |
| wave_challenge_test | 0 | **2** | 波次挑战 |
| battle_specialization_test | 0 | **1** | 专精面板 |
| humanity_economy_test | 1 | 3 | |
| combat_guide_test | 18 | 22 | 桌面基线本就失败 |
| capitalist_character_test | 33 | 35 | 桌面基线本就失败 |
| active_combat_integration_test | 6 | 0 | 桌面为既有 headless 时序失败 |
| window_settings_test | 1 | 1 | 既有 headless 窗口限制（已 stash 复测确认） |

## 待办（按收益排序）

1. **浮层/面板在 1324×745 逻辑视口下的排版**：上表 45 条移动端新增失败集中在同一族
   问题——按 `viewport/1920` 等比缩面板，但字号是绝对值。要么给这些面板加最小宽度与
   换行，要么像银行一样为移动端准备紧凑排版。
2. **商店弹窗与 ESC 覆盖层的截图核对**：目前只出过战斗 HUD、属性抽屉、银行三张。
3. **哥布林对白气泡定位**：银行里会压住第一张卡牌（打字机动画本身正常）。
4. 桌面基线里 `combat_guide_test`(18) / `capitalist_character_test`(33) 的失败与本分支
   无关，但需要单独确认是否也是 headless 环境所致。

## 已知取舍

- 位移武器在移动端**不生成也不保留**（用户确认），数据文件未改动，全部由 `MobileProfile.weapon_available()` 在运行时过滤，因此与 master 的 `characters.json` / `weapons.json` 无冲突。
- 移动端世界视野 = 物理屏幕像素：竖向与桌面一致（1080），横向随屏幕变宽（20:9 多 25%）。
- 掌机手势条按 16 逻辑像素预留，真机实测后可调 `MobileProfile.BOTTOM_INSET`。
