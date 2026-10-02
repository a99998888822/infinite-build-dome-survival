# 项目录制图片与动图清单（2026-09-29）

盘点范围：当前工作区（包含被 Git 忽略的截图目录）及本项目已知的系统临时录制目录。所有现存链接均已核实文件存在；这是文件盘点，没有重新录制，也没有恢复已删除资源。

正式 assets 精灵图、外部参考图、Picxel 转换过程稿不算实机录制。其审阅拼图在附录单列。历史录像可能使用旧角色外观或旧武器参数，不能等同于当前版本。

现存可播放文件：**12 个（6 GIF＋6 MP4，约 9 组内容）**。原始录制帧：**2328 张，13 组**。截图及录制对照图：**264 张**（包含多分辨率、历史版本及临时副本，未按画面去重）。

## 一、可直接播放的录制

| 内容 | 文件 | 说明 |
| --- | --- | --- |
| 短刀：基础攻击（调整攻击距离前） | [camp-dagger-base.gif](<C:/Users/mi/AppData/Local/Temp/camp-dagger-qa/camp-dagger-base.gif>) | 6 秒；初版基础攻击 |
| 短刀：分裂＋火焰（调整攻击距离前） | [camp-dagger-split-fire.gif](<C:/Users/mi/AppData/Local/Temp/camp-dagger-qa/camp-dagger-split-fire.gif>) | 6 秒；火焰与分裂追斩 |
| 短刀：基础攻击距离 80 | [camp-dagger-range-80.gif](<C:/Users/mi/AppData/Local/Temp/weapon-range-qa/camp-dagger-range-80.gif>) | 3.5 秒；较新的距离调整版 |
| 守夜长枪：正式实战 | [nightwatch-spear-gameplay.gif](<C:/Users/mi/AppData/Local/Temp/nightwatch-qa/nightwatch-spear-gameplay.gif>) | 6 秒；正式接入时的实战录制 |
| 守夜长枪：正式实战（视频） | [nightwatch-spear-gameplay.mp4](<C:/Users/mi/AppData/Local/Temp/nightwatch-qa/nightwatch-spear-gameplay.mp4>) | 同组录制的视频格式 |
| 守夜长枪：六种附魔组合 | [nightwatch_enchantments.mp4](<C:/Users/mi/AppData/Local/Temp/dome_artifact_audit/converted/nightwatch_enchantments.mp4>) | 3.6 秒；历史原型，分裂、冰霜、火焰、分裂＋火焰、连锁闪电、分裂＋连锁闪电 |
| 流星锤：基础／分裂 | [meteor_flail.mp4](<C:/Users/mi/AppData/Local/Temp/dome_artifact_audit/converted/meteor_flail.mp4>) | 8 秒；历史录制，临时目录仍有视频 |
| 流星锤：分裂＋闪电／分裂＋火焰 | [meteor_flail_enchantments.mp4](<C:/Users/mi/AppData/Local/Temp/dome_artifact_audit/converted/meteor_flail_enchantments.mp4>) | 8 秒；历史附魔录制 |
| 直线落雷：间距 36（旧版） | [lightning-line.gif](<C:/Users/mi/AppData/Local/Temp/lightning-line-review/lightning-line.gif>) | 6 秒；空地演示＋固定目标受击 |
| 直线落雷：间距 36（完整视频） | [lightning-line-full.mp4](<C:/Users/mi/AppData/Local/Temp/lightning-line-review/lightning-line-full.mp4>) | 旧版完整视口，无音轨 |
| 直线落雷：间距 64（最新审阅版） | [lightning-line-spacing64.gif](<C:/Users/mi/AppData/Local/Temp/lightning-line-spacing64-review/lightning-line-spacing64.gif>) | 6 秒；黄色预警圈分开，0.1 秒推进／0.5 秒预警 |
| 直线落雷：间距 64（完整视频） | [lightning-line-full.mp4](<C:/Users/mi/AppData/Local/Temp/lightning-line-spacing64-review/lightning-line-full.mp4>) | 最新完整视口，无音轨 |

## 二、原始录制帧

同组逐帧图片按序列合并列出，首帧和末帧可直接打开。完整逐文件路径另见 CSV。

| 内容／目录 | 帧序列 | 数量 | 核对说明 |
| --- | --- | --- | --- |
| 武器／守夜长枪实战<br>[base](<C:/Users/mi/AppData/Local/Temp/nightwatch-qa/base>) | [frame_0000.png](<C:/Users/mi/AppData/Local/Temp/nightwatch-qa/base/frame_0000.png>) ～ [frame_0179.png](<C:/Users/mi/AppData/Local/Temp/nightwatch-qa/base/frame_0179.png>) | 180 | 编号连续 |
| 武器／守夜长枪实战<br>[split-fire](<C:/Users/mi/AppData/Local/Temp/nightwatch-qa/split-fire>) | [frame_0000.png](<C:/Users/mi/AppData/Local/Temp/nightwatch-qa/split-fire/frame_0000.png>) ～ [frame_0179.png](<C:/Users/mi/AppData/Local/Temp/nightwatch-qa/split-fire/frame_0179.png>) | 180 | 编号连续；旧测试，capture.json 的 valid=false，不能作为通过验收的版本 |
| 武器／短刀基础与分裂火焰<br>[base](<C:/Users/mi/AppData/Local/Temp/camp-dagger-qa/base>) | [frame_0000.png](<C:/Users/mi/AppData/Local/Temp/camp-dagger-qa/base/frame_0000.png>) ～ [frame_0179.png](<C:/Users/mi/AppData/Local/Temp/camp-dagger-qa/base/frame_0179.png>) | 180 | 编号连续 |
| 武器／短刀基础与分裂火焰<br>[split_fire](<C:/Users/mi/AppData/Local/Temp/camp-dagger-qa/split_fire>) | [frame_0000.png](<C:/Users/mi/AppData/Local/Temp/camp-dagger-qa/split_fire/frame_0000.png>) ～ [frame_0179.png](<C:/Users/mi/AppData/Local/Temp/camp-dagger-qa/split_fire/frame_0179.png>) | 180 | 编号连续 |
| 武器／短刀攻击距离调整<br>[dagger-review](<C:/Users/mi/AppData/Local/Temp/weapon-range-qa/dagger-review>) | [frame_0000.png](<C:/Users/mi/AppData/Local/Temp/weapon-range-qa/dagger-review/frame_0000.png>) ～ [frame_0179.png](<C:/Users/mi/AppData/Local/Temp/weapon-range-qa/dagger-review/frame_0179.png>) | 180 | 编号连续 |
| 界面／哥布林借贷<br>[frames](<C:/Users/mi/AppData/Local/Temp/codex_goblin_loan_review/frames>) | [frame_0000.png](<C:/Users/mi/AppData/Local/Temp/codex_goblin_loan_review/frames/frame_0000.png>) ～ [frame_0239.png](<C:/Users/mi/AppData/Local/Temp/codex_goblin_loan_review/frames/frame_0239.png>) | 240 | 编号连续 |
| 界面／紧凑难度显示<br>[compact_difficulty_frames](<C:/Users/mi/AppData/Local/Temp/compact_difficulty_frames>) | [frame_000.png](<C:/Users/mi/AppData/Local/Temp/compact_difficulty_frames/frame_000.png>) ～ [frame_107.png](<C:/Users/mi/AppData/Local/Temp/compact_difficulty_frames/frame_107.png>) | 108 | 编号连续 |
| 界面／难度专属显示<br>[difficulty_exclusive_frames](<C:/Users/mi/AppData/Local/Temp/difficulty_exclusive_frames>) | [frame_000.png](<C:/Users/mi/AppData/Local/Temp/difficulty_exclusive_frames/frame_000.png>) ～ [frame_107.png](<C:/Users/mi/AppData/Local/Temp/difficulty_exclusive_frames/frame_107.png>) | 108 | 编号连续 |
| 角色与敌人／初心者、小怪、小Boss实机<br>[live](<C:/Users/mi/AppData/Local/Temp/combat-picxel-install-uf3m5m64/live>) | [frame_0000.png](<C:/Users/mi/AppData/Local/Temp/combat-picxel-install-uf3m5m64/live/frame_0000.png>) ～ [frame_0419.png](<C:/Users/mi/AppData/Local/Temp/combat-picxel-install-uf3m5m64/live/frame_0419.png>) | 420 | 编号连续；小Boss出现、追击、蓄力、冲刺、恢复、死亡与掉落；60FPS，7秒 |
| 角色与敌人／初心者、小怪、小Boss实机<br>[live](<C:/Users/mi/AppData/Local/Temp/combat-picxel-install-uf3m5m64/live>) | [sprites_0000.png](<C:/Users/mi/AppData/Local/Temp/combat-picxel-install-uf3m5m64/live/sprites_0000.png>) ～ [sprites_0143.png](<C:/Users/mi/AppData/Local/Temp/combat-picxel-install-uf3m5m64/live/sprites_0143.png>) | 144 | 编号连续；初心者左右行走＋小怪移动，144帧 |
| 角色／初心者与资本家<br>[capitalist](<C:/Users/mi/AppData/Local/Temp/player-picxel-captures/capitalist>) | [walk_000.png](<C:/Users/mi/AppData/Local/Temp/player-picxel-captures/capitalist/walk_000.png>) ～ [walk_047.png](<C:/Users/mi/AppData/Local/Temp/player-picxel-captures/capitalist/walk_047.png>) | 48 | 编号连续 |
| 附魔原型／直线落雷间距36<br>[frames](<C:/Users/mi/AppData/Local/Temp/lightning-line-review/frames>) | [frame_0000.png](<C:/Users/mi/AppData/Local/Temp/lightning-line-review/frames/frame_0000.png>) ～ [frame_0179.png](<C:/Users/mi/AppData/Local/Temp/lightning-line-review/frames/frame_0179.png>) | 180 | 编号连续 |
| 附魔原型／直线落雷间距64<br>[frames](<C:/Users/mi/AppData/Local/Temp/lightning-line-spacing64-review/frames>) | [frame_0000.png](<C:/Users/mi/AppData/Local/Temp/lightning-line-spacing64-review/frames/frame_0000.png>) ～ [frame_0179.png](<C:/Users/mi/AppData/Local/Temp/lightning-line-spacing64-review/frames/frame_0179.png>) | 180 | 编号连续 |

## 三、截图与录制对照图

这里含武器与附魔静帧、角色界面、Boss分阶段拼图、银行／交易／HUD／结算截图。每一张都列出可打开的路径。

### 临时目录散图／界面与动画对照 · 11 张

目录：[Temp](<C:/Users/mi/AppData/Local/Temp>)

- [bank-hand-states.png](<C:/Users/mi/AppData/Local/Temp/bank-hand-states.png>)
- [bank-hands-detail.png](<C:/Users/mi/AppData/Local/Temp/bank-hands-detail.png>)
- [bank-proportion-before.png](<C:/Users/mi/AppData/Local/Temp/bank-proportion-before.png>)
- [difficulty_exclusive_audit.png](<C:/Users/mi/AppData/Local/Temp/difficulty_exclusive_audit.png>)
- [difficulty_final_gif_audit.png](<C:/Users/mi/AppData/Local/Temp/difficulty_final_gif_audit.png>)
- [difficulty_gif_audit.png](<C:/Users/mi/AppData/Local/Temp/difficulty_gif_audit.png>)
- [goblin_hands_compare.png](<C:/Users/mi/AppData/Local/Temp/goblin_hands_compare.png>)
- [goblin_reprint_contact.png](<C:/Users/mi/AppData/Local/Temp/goblin_reprint_contact.png>)
- [iron_knight_fast_qa.png](<C:/Users/mi/AppData/Local/Temp/iron_knight_fast_qa.png>)
- [iron_knight_gif_check.png](<C:/Users/mi/AppData/Local/Temp/iron_knight_gif_check.png>)
- [knight_gait_qa.png](<C:/Users/mi/AppData/Local/Temp/knight_gait_qa.png>)

### 场景／中心、湿地、外围 · 4 张

目录：[battle_environment_before](<C:/Users/mi/AppData/Local/Temp/battle_environment_before>)

- [01_center.png](<C:/Users/mi/AppData/Local/Temp/battle_environment_before/01_center.png>)
- [02_wetland.png](<C:/Users/mi/AppData/Local/Temp/battle_environment_before/02_wetland.png>)
- [03_outskirts.png](<C:/Users/mi/AppData/Local/Temp/battle_environment_before/03_outskirts.png>)
- [04_return.png](<C:/Users/mi/AppData/Local/Temp/battle_environment_before/04_return.png>)

### 效果层级／冰霜、冰霜风场、等离子、废墟（微调后） · 4 张

目录：[grounding_tuned](<C:/Users/mi/AppData/Local/Temp/grounding_tuned>)

- [frost.png](<C:/Users/mi/AppData/Local/Temp/grounding_tuned/frost.png>)
- [frost_wind.png](<C:/Users/mi/AppData/Local/Temp/grounding_tuned/frost_wind.png>)
- [plasma.png](<C:/Users/mi/AppData/Local/Temp/grounding_tuned/plasma.png>)
- [ruins.png](<C:/Users/mi/AppData/Local/Temp/grounding_tuned/ruins.png>)

### 效果层级／冰霜、冰霜风场、等离子、废墟（调整前） · 4 张

目录：[grounding_before](<C:/Users/mi/AppData/Local/Temp/grounding_before>)

- [frost.png](<C:/Users/mi/AppData/Local/Temp/grounding_before/frost.png>)
- [frost_wind.png](<C:/Users/mi/AppData/Local/Temp/grounding_before/frost_wind.png>)
- [plasma.png](<C:/Users/mi/AppData/Local/Temp/grounding_before/plasma.png>)
- [ruins.png](<C:/Users/mi/AppData/Local/Temp/grounding_before/ruins.png>)

### 效果层级／冰霜、冰霜风场、等离子、废墟（调整后） · 4 张

目录：[grounding_after](<C:/Users/mi/AppData/Local/Temp/grounding_after>)

- [frost.png](<C:/Users/mi/AppData/Local/Temp/grounding_after/frost.png>)
- [frost_wind.png](<C:/Users/mi/AppData/Local/Temp/grounding_after/frost_wind.png>)
- [plasma.png](<C:/Users/mi/AppData/Local/Temp/grounding_after/plasma.png>)
- [ruins.png](<C:/Users/mi/AppData/Local/Temp/grounding_after/ruins.png>)

### 武器与附魔／历史录像解码截图 · 3 张

目录：[dome_artifact_audit](<C:/Users/mi/AppData/Local/Temp/dome_artifact_audit>)

- [meteor_flail_decoded.png](<C:/Users/mi/AppData/Local/Temp/dome_artifact_audit/meteor_flail_decoded.png>)
- [meteor_flail_enchantments_decoded.png](<C:/Users/mi/AppData/Local/Temp/dome_artifact_audit/meteor_flail_enchantments_decoded.png>)
- [nightwatch_enchantments_decoded.png](<C:/Users/mi/AppData/Local/Temp/dome_artifact_audit/nightwatch_enchantments_decoded.png>)

### 武器／守夜长枪实战 · 1 张

目录：[nightwatch-qa](<C:/Users/mi/AppData/Local/Temp/nightwatch-qa>)

- [contact-sheet.png](<C:/Users/mi/AppData/Local/Temp/nightwatch-qa/contact-sheet.png>)

### 武器／短刀基础与分裂火焰 · 3 张

目录：[camp-dagger-qa](<C:/Users/mi/AppData/Local/Temp/camp-dagger-qa>)

- [contact-sheet.png](<C:/Users/mi/AppData/Local/Temp/camp-dagger-qa/contact-sheet.png>)
- [final-detail.png](<C:/Users/mi/AppData/Local/Temp/camp-dagger-qa/final-detail.png>)
- [fire-contact-sheet.png](<C:/Users/mi/AppData/Local/Temp/camp-dagger-qa/fire-contact-sheet.png>)

### 武器／短刀攻击距离调整 · 2 张

目录：[weapon-range-qa](<C:/Users/mi/AppData/Local/Temp/weapon-range-qa>)

- [dagger-range-review.png](<C:/Users/mi/AppData/Local/Temp/weapon-range-qa/dagger-range-review.png>)
- [final-range-detail.png](<C:/Users/mi/AppData/Local/Temp/weapon-range-qa/final-range-detail.png>)

### 界面与战斗／射程和面积属性 · 6 张

目录：[stat_range_review](<C:/Users/mi/AppData/Local/Temp/stat_range_review>)

- [area_0.png](<C:/Users/mi/AppData/Local/Temp/stat_range_review/area_0.png>)
- [area_50.png](<C:/Users/mi/AppData/Local/Temp/stat_range_review/area_50.png>)
- [range_0.png](<C:/Users/mi/AppData/Local/Temp/stat_range_review/range_0.png>)
- [range_50.png](<C:/Users/mi/AppData/Local/Temp/stat_range_review/range_50.png>)
- [stats_lower.png](<C:/Users/mi/AppData/Local/Temp/stat_range_review/stats_lower.png>)
- [stats_upper.png](<C:/Users/mi/AppData/Local/Temp/stat_range_review/stats_upper.png>)

### 界面与战斗／射程遗物与效果范围 · 21 张

目录：[range_relic_review](<C:/Users/mi/AppData/Local/Temp/range_relic_review>)

- [area_after.png](<C:/Users/mi/AppData/Local/Temp/range_relic_review/area_after.png>)
- [area_before.png](<C:/Users/mi/AppData/Local/Temp/range_relic_review/area_before.png>)
- [bank_preview.png](<C:/Users/mi/AppData/Local/Temp/range_relic_review/bank_preview.png>)
- [inventory.png](<C:/Users/mi/AppData/Local/Temp/range_relic_review/inventory.png>)
- [range_after.png](<C:/Users/mi/AppData/Local/Temp/range_relic_review/range_after.png>)
- [range_before.png](<C:/Users/mi/AppData/Local/Temp/range_relic_review/range_before.png>)
- [relic_abyssal_echo_shell.png](<C:/Users/mi/AppData/Local/Temp/range_relic_review/relic_abyssal_echo_shell.png>)
- [relic_aftershock_hourglass.png](<C:/Users/mi/AppData/Local/Temp/range_relic_review/relic_aftershock_hourglass.png>)
- [relic_cracked_bronze_bell.png](<C:/Users/mi/AppData/Local/Temp/range_relic_review/relic_cracked_bronze_bell.png>)
- [relic_diffusion_nozzle.png](<C:/Users/mi/AppData/Local/Temp/range_relic_review/relic_diffusion_nozzle.png>)
- [relic_folded_star_chart.png](<C:/Users/mi/AppData/Local/Temp/range_relic_review/relic_folded_star_chart.png>)
- [relic_golden_rangefinder.png](<C:/Users/mi/AppData/Local/Temp/range_relic_review/relic_golden_rangefinder.png>)
- [relic_horizon_orrery.png](<C:/Users/mi/AppData/Local/Temp/range_relic_review/relic_horizon_orrery.png>)
- [relic_long_focus_eyepiece.png](<C:/Users/mi/AppData/Local/Temp/range_relic_review/relic_long_focus_eyepiece.png>)
- [relic_old_brass_telescope.png](<C:/Users/mi/AppData/Local/Temp/range_relic_review/relic_old_brass_telescope.png>)
- [relic_range_tripod.png](<C:/Users/mi/AppData/Local/Temp/range_relic_review/relic_range_tripod.png>)
- [shop_bottom.png](<C:/Users/mi/AppData/Local/Temp/range_relic_review/shop_bottom.png>)
- [shop_top.png](<C:/Users/mi/AppData/Local/Temp/range_relic_review/shop_top.png>)
- [tripod_active.png](<C:/Users/mi/AppData/Local/Temp/range_relic_review/tripod_active.png>)
- [tripod_before.png](<C:/Users/mi/AppData/Local/Temp/range_relic_review/tripod_before.png>)
- [tripod_moving.png](<C:/Users/mi/AppData/Local/Temp/range_relic_review/tripod_moving.png>)

### 界面／像素属性面板R02临时截图 · 4 张

目录：[captures](<C:/Users/mi/AppData/Local/Temp/stats-pixel-r02-1790668209/captures>)

- [01_original_stats.png](<C:/Users/mi/AppData/Local/Temp/stats-pixel-r02-1790668209/captures/01_original_stats.png>)
- [02_pixel_stats.png](<C:/Users/mi/AppData/Local/Temp/stats-pixel-r02-1790668209/captures/02_pixel_stats.png>)
- [03_finance_pixel_stats.png](<C:/Users/mi/AppData/Local/Temp/stats-pixel-r02-1790668209/captures/03_finance_pixel_stats.png>)
- [04_finance_original_stats.png](<C:/Users/mi/AppData/Local/Temp/stats-pixel-r02-1790668209/captures/04_finance_original_stats.png>)

### 界面／像素属性面板R03临时截图 · 4 张

目录：[captures](<C:/Users/mi/AppData/Local/Temp/stats-pixel-r03-1790669266/captures>)

- [01_vertical_r02.png](<C:/Users/mi/AppData/Local/Temp/stats-pixel-r03-1790669266/captures/01_vertical_r02.png>)
- [02_horizontal_r03.png](<C:/Users/mi/AppData/Local/Temp/stats-pixel-r03-1790669266/captures/02_horizontal_r03.png>)
- [03_finance_horizontal.png](<C:/Users/mi/AppData/Local/Temp/stats-pixel-r03-1790669266/captures/03_finance_horizontal.png>)
- [04_finance_vertical.png](<C:/Users/mi/AppData/Local/Temp/stats-pixel-r03-1790669266/captures/04_finance_vertical.png>)

### 界面／六种武器详情与武器栏 · 12 张

目录：[weapon_details_review](<C:/Users/mi/AppData/Local/Temp/weapon_details_review>)

- [bank_weapon_iron_grenade_cannon.png](<C:/Users/mi/AppData/Local/Temp/weapon_details_review/bank_weapon_iron_grenade_cannon.png>)
- [bank_weapon_kunyu_ritual_tome.png](<C:/Users/mi/AppData/Local/Temp/weapon_details_review/bank_weapon_kunyu_ritual_tome.png>)
- [bank_weapon_meteor_flail.png](<C:/Users/mi/AppData/Local/Temp/weapon_details_review/bank_weapon_meteor_flail.png>)
- [bank_weapon_plasma_cannon.png](<C:/Users/mi/AppData/Local/Temp/weapon_details_review/bank_weapon_plasma_cannon.png>)
- [bank_weapon_rentier_purse.png](<C:/Users/mi/AppData/Local/Temp/weapon_details_review/bank_weapon_rentier_purse.png>)
- [bank_weapon_void_blade.png](<C:/Users/mi/AppData/Local/Temp/weapon_details_review/bank_weapon_void_blade.png>)
- [strip_weapon_iron_grenade_cannon.png](<C:/Users/mi/AppData/Local/Temp/weapon_details_review/strip_weapon_iron_grenade_cannon.png>)
- [strip_weapon_kunyu_ritual_tome.png](<C:/Users/mi/AppData/Local/Temp/weapon_details_review/strip_weapon_kunyu_ritual_tome.png>)
- [strip_weapon_meteor_flail.png](<C:/Users/mi/AppData/Local/Temp/weapon_details_review/strip_weapon_meteor_flail.png>)
- [strip_weapon_plasma_cannon.png](<C:/Users/mi/AppData/Local/Temp/weapon_details_review/strip_weapon_plasma_cannon.png>)
- [strip_weapon_rentier_purse.png](<C:/Users/mi/AppData/Local/Temp/weapon_details_review/strip_weapon_rentier_purse.png>)
- [strip_weapon_void_blade.png](<C:/Users/mi/AppData/Local/Temp/weapon_details_review/strip_weapon_void_blade.png>)

### 界面／压力、难度密度与利息结算 · 22 张

目录：[pressure_ui_review](<C:/Users/mi/AppData/Local/Temp/pressure_ui_review>)

- [density_1_1.png](<C:/Users/mi/AppData/Local/Temp/pressure_ui_review/density_1_1.png>)
- [density_1_10.png](<C:/Users/mi/AppData/Local/Temp/pressure_ui_review/density_1_10.png>)
- [density_1_20.png](<C:/Users/mi/AppData/Local/Temp/pressure_ui_review/density_1_20.png>)
- [density_2_1.png](<C:/Users/mi/AppData/Local/Temp/pressure_ui_review/density_2_1.png>)
- [density_2_10.png](<C:/Users/mi/AppData/Local/Temp/pressure_ui_review/density_2_10.png>)
- [density_2_20.png](<C:/Users/mi/AppData/Local/Temp/pressure_ui_review/density_2_20.png>)
- [density_3_1.png](<C:/Users/mi/AppData/Local/Temp/pressure_ui_review/density_3_1.png>)
- [density_3_10.png](<C:/Users/mi/AppData/Local/Temp/pressure_ui_review/density_3_10.png>)
- [density_3_20.png](<C:/Users/mi/AppData/Local/Temp/pressure_ui_review/density_3_20.png>)
- [empty_1152.png](<C:/Users/mi/AppData/Local/Temp/pressure_ui_review/empty_1152.png>)
- [empty_640.png](<C:/Users/mi/AppData/Local/Temp/pressure_ui_review/empty_640.png>)
- [receipt_00.png](<C:/Users/mi/AppData/Local/Temp/pressure_ui_review/receipt_00.png>)
- [receipt_01.png](<C:/Users/mi/AppData/Local/Temp/pressure_ui_review/receipt_01.png>)
- [receipt_02.png](<C:/Users/mi/AppData/Local/Temp/pressure_ui_review/receipt_02.png>)
- [receipt_03.png](<C:/Users/mi/AppData/Local/Temp/pressure_ui_review/receipt_03.png>)
- [receipt_04.png](<C:/Users/mi/AppData/Local/Temp/pressure_ui_review/receipt_04.png>)
- [receipt_05.png](<C:/Users/mi/AppData/Local/Temp/pressure_ui_review/receipt_05.png>)
- [receipt_06.png](<C:/Users/mi/AppData/Local/Temp/pressure_ui_review/receipt_06.png>)
- [receipt_07.png](<C:/Users/mi/AppData/Local/Temp/pressure_ui_review/receipt_07.png>)
- [receipt_08.png](<C:/Users/mi/AppData/Local/Temp/pressure_ui_review/receipt_08.png>)
- [receipt_closed.png](<C:/Users/mi/AppData/Local/Temp/pressure_ui_review/receipt_closed.png>)
- [selection.png](<C:/Users/mi/AppData/Local/Temp/pressure_ui_review/selection.png>)

### 界面／哥布林五笔交易 · 12 张

目录：[codex-trade-cleanup-f9eeea7c17304f01a5d55e1088111d81](<C:/Users/mi/AppData/Local/Temp/codex-trade-cleanup-f9eeea7c17304f01a5d55e1088111d81>)

- [01_deposit_offer.png](<C:/Users/mi/AppData/Local/Temp/codex-trade-cleanup-f9eeea7c17304f01a5d55e1088111d81/01_deposit_offer.png>)
- [01_deposit_offer_finance.png](<C:/Users/mi/AppData/Local/Temp/codex-trade-cleanup-f9eeea7c17304f01a5d55e1088111d81/01_deposit_offer_finance.png>)
- [04_cash_offer.png](<C:/Users/mi/AppData/Local/Temp/codex-trade-cleanup-f9eeea7c17304f01a5d55e1088111d81/04_cash_offer.png>)
- [04_cash_offer_finance.png](<C:/Users/mi/AppData/Local/Temp/codex-trade-cleanup-f9eeea7c17304f01a5d55e1088111d81/04_cash_offer_finance.png>)
- [04_small_cash_offer.png](<C:/Users/mi/AppData/Local/Temp/codex-trade-cleanup-f9eeea7c17304f01a5d55e1088111d81/04_small_cash_offer.png>)
- [06_spending_offer.png](<C:/Users/mi/AppData/Local/Temp/codex-trade-cleanup-f9eeea7c17304f01a5d55e1088111d81/06_spending_offer.png>)
- [06_spending_offer_finance.png](<C:/Users/mi/AppData/Local/Temp/codex-trade-cleanup-f9eeea7c17304f01a5d55e1088111d81/06_spending_offer_finance.png>)
- [08_interest_offer.png](<C:/Users/mi/AppData/Local/Temp/codex-trade-cleanup-f9eeea7c17304f01a5d55e1088111d81/08_interest_offer.png>)
- [08_interest_offer_finance.png](<C:/Users/mi/AppData/Local/Temp/codex-trade-cleanup-f9eeea7c17304f01a5d55e1088111d81/08_interest_offer_finance.png>)
- [11_principal_offer.png](<C:/Users/mi/AppData/Local/Temp/codex-trade-cleanup-f9eeea7c17304f01a5d55e1088111d81/11_principal_offer.png>)
- [11_principal_offer_finance.png](<C:/Users/mi/AppData/Local/Temp/codex-trade-cleanup-f9eeea7c17304f01a5d55e1088111d81/11_principal_offer_finance.png>)
- [five_trades_overview.png](<C:/Users/mi/AppData/Local/Temp/codex-trade-cleanup-f9eeea7c17304f01a5d55e1088111d81/five_trades_overview.png>)

### 界面／哥布林借贷 · 8 张

目录：[captures](<C:/Users/mi/AppData/Local/Temp/codex_goblin_loan_review/captures>)

- [loan_popup.png](<C:/Users/mi/AppData/Local/Temp/codex_goblin_loan_review/captures/loan_popup.png>)
- [loan_portrait.png](<C:/Users/mi/AppData/Local/Temp/codex_goblin_loan_review/captures/loan_portrait.png>)
- [loan_small.png](<C:/Users/mi/AppData/Local/Temp/codex_goblin_loan_review/captures/loan_small.png>)
- [loan_small_hud.png](<C:/Users/mi/AppData/Local/Temp/codex_goblin_loan_review/captures/loan_small_hud.png>)
- [state_available.png](<C:/Users/mi/AppData/Local/Temp/codex_goblin_loan_review/captures/state_available.png>)
- [state_borrowed.png](<C:/Users/mi/AppData/Local/Temp/codex_goblin_loan_review/captures/state_borrowed.png>)
- [state_compound.png](<C:/Users/mi/AppData/Local/Temp/codex_goblin_loan_review/captures/state_compound.png>)
- [state_ready.png](<C:/Users/mi/AppData/Local/Temp/codex_goblin_loan_review/captures/state_ready.png>)

### 界面／哥布林借贷 · 3 张

目录：[live](<C:/Users/mi/AppData/Local/Temp/codex_goblin_loan_review/live>)

- [loan_live_bank.png](<C:/Users/mi/AppData/Local/Temp/codex_goblin_loan_review/live/loan_live_bank.png>)
- [loan_live_popup.png](<C:/Users/mi/AppData/Local/Temp/codex_goblin_loan_review/live/loan_live_popup.png>)
- [loan_live_small.png](<C:/Users/mi/AppData/Local/Temp/codex_goblin_loan_review/live/loan_live_small.png>)

### 界面／银行HUD与完整属性说明 · 41 张

目录：[bank_hud_complete](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete>)

- [armor.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/armor.png>)
- [armor_first.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/armor_first.png>)
- [bank_overview.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/bank_overview.png>)
- [bank_small.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/bank_small.png>)
- [divinity.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/divinity.png>)
- [divinity_first.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/divinity_first.png>)
- [drawer_bottom.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/drawer_bottom.png>)
- [drawer_top.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/drawer_top.png>)
- [humanity.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/humanity.png>)
- [humanity_first.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/humanity_first.png>)
- [ordinary_area_size.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_area_size.png>)
- [ordinary_attack_speed.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_attack_speed.png>)
- [ordinary_control_power.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_control_power.png>)
- [ordinary_crit_chance.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_crit_chance.png>)
- [ordinary_crit_damage.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_crit_damage.png>)
- [ordinary_currency_gain_percent.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_currency_gain_percent.png>)
- [ordinary_damage_area_size.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_damage_area_size.png>)
- [ordinary_damage_percent.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_damage_percent.png>)
- [ordinary_drop_rate_percent.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_drop_rate_percent.png>)
- [ordinary_element_damage.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_element_damage.png>)
- [ordinary_enemy_spawn_rate_percent.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_enemy_spawn_rate_percent.png>)
- [ordinary_exp_gain_percent.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_exp_gain_percent.png>)
- [ordinary_health_pack_heal_plus.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_health_pack_heal_plus.png>)
- [ordinary_hp_regen.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_hp_regen.png>)
- [ordinary_interest_rate.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_interest_rate.png>)
- [ordinary_load_capacity.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_load_capacity.png>)
- [ordinary_luck.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_luck.png>)
- [ordinary_max_hp.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_max_hp.png>)
- [ordinary_melee_damage.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_melee_damage.png>)
- [ordinary_move_speed.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_move_speed.png>)
- [ordinary_on_kill_heal.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_on_kill_heal.png>)
- [ordinary_pickup_radius.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_pickup_radius.png>)
- [ordinary_projectile_count.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_projectile_count.png>)
- [ordinary_ranged_damage.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_ranged_damage.png>)
- [ordinary_revive_count.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_revive_count.png>)
- [ordinary_shield_regen.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_shield_regen.png>)
- [ordinary_shop_offer_count_bonus.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_shop_offer_count_bonus.png>)
- [ordinary_shop_price_percent.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/ordinary_shop_price_percent.png>)
- [relic_after_1s.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/relic_after_1s.png>)
- [relic_first.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/relic_first.png>)
- [relic_unavailable.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_complete/relic_unavailable.png>)

### 界面／银行HUD早期审阅 · 8 张

目录：[bank_hud_review](<C:/Users/mi/AppData/Local/Temp/bank_hud_review>)

- [armor.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_review/armor.png>)
- [armor_first.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_review/armor_first.png>)
- [bank.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_review/bank.png>)
- [bank_small.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_review/bank_small.png>)
- [divinity.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_review/divinity.png>)
- [divinity_first.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_review/divinity_first.png>)
- [humanity.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_review/humanity.png>)
- [humanity_first.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_review/humanity_first.png>)

### 界面／银行、出售、人性与经济 · 5 张

目录：[bank_hud_economy_capture](<C:/Users/mi/AppData/Local/Temp/bank_hud_economy_capture>)

- [01_finance_humanity_50.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_economy_capture/01_finance_humanity_50.png>)
- [02_sale_humanity_50.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_economy_capture/02_sale_humanity_50.png>)
- [03_bank_640.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_economy_capture/03_bank_640.png>)
- [03_bank_960.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_economy_capture/03_bank_960.png>)
- [04_humanity_hover.png](<C:/Users/mi/AppData/Local/Temp/bank_hud_economy_capture/04_humanity_hover.png>)

### 界面／附魔品质与说明 · 6 张

目录：[augmentation_rarity_review](<C:/Users/mi/AppData/Local/Temp/augmentation_rarity_review>)

- [ground.png](<C:/Users/mi/AppData/Local/Temp/augmentation_rarity_review/ground.png>)
- [inventory.png](<C:/Users/mi/AppData/Local/Temp/augmentation_rarity_review/inventory.png>)
- [scroll_explosion.png](<C:/Users/mi/AppData/Local/Temp/augmentation_rarity_review/scroll_explosion.png>)
- [scroll_fire.png](<C:/Users/mi/AppData/Local/Temp/augmentation_rarity_review/scroll_fire.png>)
- [scroll_lightning.png](<C:/Users/mi/AppData/Local/Temp/augmentation_rarity_review/scroll_lightning.png>)
- [scroll_split.png](<C:/Users/mi/AppData/Local/Temp/augmentation_rarity_review/scroll_split.png>)

### 角色与敌人／初心者、小怪、小Boss实机 · 1 张

目录：[combat-picxel-install-uf3m5m64](<C:/Users/mi/AppData/Local/Temp/combat-picxel-install-uf3m5m64>)

- [contact.png](<C:/Users/mi/AppData/Local/Temp/combat-picxel-install-uf3m5m64/contact.png>)

### 角色／初心者与资本家 · 3 张

目录：[beginner](<C:/Users/mi/AppData/Local/Temp/player-picxel-captures/beginner>)

- [01_battle_damage.png](<C:/Users/mi/AppData/Local/Temp/player-picxel-captures/beginner/01_battle_damage.png>)
- [02_attribute_sections.png](<C:/Users/mi/AppData/Local/Temp/player-picxel-captures/beginner/02_attribute_sections.png>)
- [03_attribute_scroll.png](<C:/Users/mi/AppData/Local/Temp/player-picxel-captures/beginner/03_attribute_scroll.png>)

### 角色／初心者与资本家 · 5 张

目录：[capitalist](<C:/Users/mi/AppData/Local/Temp/player-picxel-captures/capitalist>)

- [bank.png](<C:/Users/mi/AppData/Local/Temp/player-picxel-captures/capitalist/bank.png>)
- [battle.png](<C:/Users/mi/AppData/Local/Temp/player-picxel-captures/capitalist/battle.png>)
- [selection.png](<C:/Users/mi/AppData/Local/Temp/player-picxel-captures/capitalist/selection.png>)
- [traits.png](<C:/Users/mi/AppData/Local/Temp/player-picxel-captures/capitalist/traits.png>)
- [walk-contact.png](<C:/Users/mi/AppData/Local/Temp/player-picxel-captures/capitalist/walk-contact.png>)

### 附魔原型／直线落雷间距36 · 1 张

目录：[lightning-line-review](<C:/Users/mi/AppData/Local/Temp/lightning-line-review>)

- [lightning-line-still.png](<C:/Users/mi/AppData/Local/Temp/lightning-line-review/lightning-line-still.png>)

### 附魔原型／直线落雷间距64 · 1 张

目录：[lightning-line-spacing64-review](<C:/Users/mi/AppData/Local/Temp/lightning-line-spacing64-review>)

- [review-still.png](<C:/Users/mi/AppData/Local/Temp/lightning-line-spacing64-review/review-still.png>)

### 项目内／完整游戏界面实机审计 · 16 张

目录：[runtime_1152x648](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1152x648>)

- [battle_characters.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1152x648/battle_characters.png>)
- [battle_characters_drawer.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1152x648/battle_characters_drawer.png>)
- [battle_esc_overlay.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1152x648/battle_esc_overlay.png>)
- [battle_hud.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1152x648/battle_hud.png>)
- [battle_hud_stats_drawer.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1152x648/battle_hud_stats_drawer.png>)
- [battle_mobile_joystick.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1152x648/battle_mobile_joystick.png>)
- [finance_enchant.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1152x648/finance_enchant.png>)
- [finance_populated.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1152x648/finance_populated.png>)
- [finance_popup.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1152x648/finance_popup.png>)
- [interest_settlement.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1152x648/interest_settlement.png>)
- [main_menu.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1152x648/main_menu.png>)
- [main_menu_battle_result.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1152x648/main_menu_battle_result.png>)
- [main_menu_character_select.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1152x648/main_menu_character_select.png>)
- [main_menu_settings.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1152x648/main_menu_settings.png>)
- [rewards_relic_cards.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1152x648/rewards_relic_cards.png>)
- [shop_relic_cards.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1152x648/shop_relic_cards.png>)

### 项目内／完整游戏界面实机审计 · 16 张

目录：[runtime_1920x1080](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1920x1080>)

- [battle_characters.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1920x1080/battle_characters.png>)
- [battle_characters_drawer.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1920x1080/battle_characters_drawer.png>)
- [battle_esc_overlay.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1920x1080/battle_esc_overlay.png>)
- [battle_hud.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1920x1080/battle_hud.png>)
- [battle_hud_stats_drawer.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1920x1080/battle_hud_stats_drawer.png>)
- [battle_mobile_joystick.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1920x1080/battle_mobile_joystick.png>)
- [finance_enchant.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1920x1080/finance_enchant.png>)
- [finance_populated.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1920x1080/finance_populated.png>)
- [finance_popup.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1920x1080/finance_popup.png>)
- [interest_settlement.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1920x1080/interest_settlement.png>)
- [main_menu.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1920x1080/main_menu.png>)
- [main_menu_battle_result.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1920x1080/main_menu_battle_result.png>)
- [main_menu_character_select.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1920x1080/main_menu_character_select.png>)
- [main_menu_settings.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1920x1080/main_menu_settings.png>)
- [rewards_relic_cards.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1920x1080/rewards_relic_cards.png>)
- [shop_relic_cards.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/runtime_1920x1080/shop_relic_cards.png>)

### 项目内／新版界面与属性面板实机 · 4 张

目录：[1152x648](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_composition/r01/captures/1152x648>)

- [01_stats.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_composition/r01/captures/1152x648/01_stats.png>)
- [02_shop.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_composition/r01/captures/1152x648/02_shop.png>)
- [03_enchant.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_composition/r01/captures/1152x648/03_enchant.png>)
- [04_bank_form.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_composition/r01/captures/1152x648/04_bank_form.png>)

### 项目内／新版界面与属性面板实机 · 4 张

目录：[1920x1080](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_composition/r01/captures/1920x1080>)

- [01_stats.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_composition/r01/captures/1920x1080/01_stats.png>)
- [02_shop.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_composition/r01/captures/1920x1080/02_shop.png>)
- [03_enchant.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_composition/r01/captures/1920x1080/03_enchant.png>)
- [04_bank_form.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_composition/r01/captures/1920x1080/04_bank_form.png>)

### 项目内／新版界面与属性面板实机 · 4 张

目录：[captures](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r01/captures>)

- [01_original_stats.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r01/captures/01_original_stats.png>)
- [02_pixel_stats.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r01/captures/02_pixel_stats.png>)
- [03_finance_pixel_stats.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r01/captures/03_finance_pixel_stats.png>)
- [04_finance_original_stats.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r01/captures/04_finance_original_stats.png>)

### 项目内／新版界面与属性面板实机 · 4 张

目录：[captures](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r02/captures>)

- [01_original_stats.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r02/captures/01_original_stats.png>)
- [02_pixel_stats.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r02/captures/02_pixel_stats.png>)
- [03_finance_pixel_stats.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r02/captures/03_finance_pixel_stats.png>)
- [04_finance_original_stats.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r02/captures/04_finance_original_stats.png>)

### 项目内／新版界面与属性面板实机 · 4 张

目录：[captures](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r03/captures>)

- [01_vertical_r02.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r03/captures/01_vertical_r02.png>)
- [02_horizontal_r03.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r03/captures/02_horizontal_r03.png>)
- [03_finance_horizontal.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r03/captures/03_finance_horizontal.png>)
- [04_finance_vertical.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r03/captures/04_finance_vertical.png>)

### 项目内／旧版界面视觉审计 · 13 张

目录：[1152x648](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/ui_visual_audit/1152x648>)

- [battle_esc_overlay.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/ui_visual_audit/1152x648/battle_esc_overlay.png>)
- [battle_hud.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/ui_visual_audit/1152x648/battle_hud.png>)
- [battle_hud_stats_drawer.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/ui_visual_audit/1152x648/battle_hud_stats_drawer.png>)
- [battle_mobile_joystick.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/ui_visual_audit/1152x648/battle_mobile_joystick.png>)
- [camp_talents.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/ui_visual_audit/1152x648/camp_talents.png>)
- [finance_popup.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/ui_visual_audit/1152x648/finance_popup.png>)
- [interest_settlement.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/ui_visual_audit/1152x648/interest_settlement.png>)
- [main_menu.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/ui_visual_audit/1152x648/main_menu.png>)
- [main_menu_battle_result.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/ui_visual_audit/1152x648/main_menu_battle_result.png>)
- [main_menu_character_select.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/ui_visual_audit/1152x648/main_menu_character_select.png>)
- [main_menu_settings.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/ui_visual_audit/1152x648/main_menu_settings.png>)
- [rewards_relic_cards.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/ui_visual_audit/1152x648/rewards_relic_cards.png>)
- [shop_relic_cards.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/ui_visual_audit/1152x648/shop_relic_cards.png>)

## 四、Git 记录存在、工作区中已删除的旧动图／录像

下列路径由 `git ls-files --deleted` 核对，不把它们当作现存文件提供点击链接。

| 旧路径 | 当前情况 |
| --- | --- |
| `artifacts/previews/combat_picxel_3838180/animations.gif` | 旧成片已删除；相关实机逐帧图仍在，见第二节（不代表与旧GIF完全相同） |
| `artifacts/previews/combat_picxel_3838180/beginner.gif` | 旧成片已删除；相关实机逐帧图仍在，见第二节（不代表与旧GIF完全相同） |
| `artifacts/previews/combat_picxel_3838180/boss_attack.gif` | 旧成片已删除；相关实机逐帧图仍在，见第二节（不代表与旧GIF完全相同） |
| `artifacts/previews/combat_picxel_3838180/boss_walk.gif` | 旧成片已删除；相关实机逐帧图仍在，见第二节（不代表与旧GIF完全相同） |
| `artifacts/previews/combat_picxel_3838180/enemy_walk.gif` | 旧成片已删除；相关实机逐帧图仍在，见第二节（不代表与旧GIF完全相同） |
| `artifacts/previews/combat_picxel_3838180/integration/walk.gif` | 旧成片已删除；相关实机逐帧图仍在，见第二节（不代表与旧GIF完全相同） |
| `artifacts/previews/nightwatch_spear/enchantments.mp4` | 原路径已删除，六组合临时视频见第一节 |
| `artifacts/previews/nightwatch_spear/hitbox.gif` | 原路径已删除，本次未找到同名现存成片 |
| `artifacts/previews/nightwatch_spear/kite.mp4` | 原路径已删除，本次未找到同名现存成片 |
| `artifacts/previews/nightwatch_spear/line.gif` | 原路径已删除，本次未找到同名现存成片 |
| `artifacts/reviews/characters/capitalist/walk.gif` | 旧成片已删除；相关实机逐帧图仍在，见第二节（不代表与旧GIF完全相同） |
| `artifacts/reviews/effects/iron_knight/game.gif` | 旧成片已删除；相关实机逐帧图仍在，见第二节（不代表与旧GIF完全相同） |
| `artifacts/reviews/effects/relic_pickup/game.gif` | 原路径已删除，本次未找到同名现存成片 |
| `artifacts/reviews/effects/water.gif` | 原路径已删除，本次未找到同名现存成片 |
| `artifacts/reviews/ui/goblin_trade/strong_refresh_button.gif` | 原路径已删除，本次未找到同名现存成片 |
| `artifacts/reviews/ui/wave_pressure/interest_hold.gif` | 原路径已删除，本次未找到同名现存成片 |
| `artifacts/reviews/weapons/grenade.gif` | 原路径已删除，本次未找到同名现存成片 |
| `artifacts/reviews/weapons/grenade_fire.gif` | 原路径已删除，本次未找到同名现存成片 |
| `artifacts/reviews/weapons/grenade_split.gif` | 原路径已删除，本次未找到同名现存成片 |
| `artifacts/reviews/weapons/meteor_flail.mp4` | 原路径已删除，临时目录仍有同类视频，见第一节 |
| `artifacts/reviews/weapons/meteor_flail_enchantments.mp4` | 原路径已删除，临时目录仍有同类视频，见第一节 |
| `artifacts/reviews/weapons/plasma.mp4` | 原路径已删除，本次未找到同名现存成片 |
| `artifacts/reviews/weapons/purse.mp4` | 原路径已删除，本次未找到同名现存成片 |
| `artifacts/reviews/weapons/tome.mp4` | 原路径已删除，本次未找到同名现存成片 |

其他查找结果：水流及水系组合、榴弹炮基础／火焰／分裂、等离子完整录像、法典、钱袋、遗物拾取旧成片均未在本次扫描的现存目录中找到；相应代码／文档记录不算录像文件。弓箭未找到独立攻击成片，其他战斗录像可能含背景攻击。

## 五、补充：美术审阅图（非实机录制）

这些是素材拼图、设计稿或像素处理审阅图；与第三节的游戏截图区分使用。

### 武器、附魔、遗物、场景与UI素材总览

目录：[art_audit_2026-09-29](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29>)

- [augmentations_1.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/augmentations_1.png>)
- [relics_1.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/relics_1.png>)
- [relics_2.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/relics_2.png>)
- [relics_3.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/relics_3.png>)
- [ui_materials.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/ui_materials.png>)
- [weapons_1.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/weapons_1.png>)
- [world_samples.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_audit_2026-09-29/world_samples.png>)

### 主菜单设计稿

目录：[main_menu](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/main_menu>)

- [background-native-640x360.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/main_menu/background-native-640x360.png>)
- [homepage-preview-v2.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/main_menu/homepage-preview-v2.png>)
- [menu-overlay-v2.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/main_menu/menu-overlay-v2.png>)

### 短刀未接入的紧凑图标

目录：[r01](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/camp_dagger/r01>)

- [camp_dagger_icon_32.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/camp_dagger/r01/camp_dagger_icon_32.png>)

### 旧小Boss的待机、移动、蓄力、冲刺、恢复、死亡素材验证

目录：[iron_knight](<C:/Users/mi/AppData/Local/Temp/dome_artifact_audit/tool_validation/iron_knight>)

- [knight_dash.png](<C:/Users/mi/AppData/Local/Temp/dome_artifact_audit/tool_validation/iron_knight/knight_dash.png>)
- [knight_death.png](<C:/Users/mi/AppData/Local/Temp/dome_artifact_audit/tool_validation/iron_knight/knight_death.png>)
- [knight_idle.png](<C:/Users/mi/AppData/Local/Temp/dome_artifact_audit/tool_validation/iron_knight/knight_idle.png>)
- [knight_move.png](<C:/Users/mi/AppData/Local/Temp/dome_artifact_audit/tool_validation/iron_knight/knight_move.png>)
- [knight_recover.png](<C:/Users/mi/AppData/Local/Temp/dome_artifact_audit/tool_validation/iron_knight/knight_recover.png>)
- [knight_windup.png](<C:/Users/mi/AppData/Local/Temp/dome_artifact_audit/tool_validation/iron_knight/knight_windup.png>)

### 玩家像素化与造型对照

目录：[player-picxel-review](<C:/Users/mi/AppData/Local/Temp/player-picxel-review>)

- [animation-check.png](<C:/Users/mi/AppData/Local/Temp/player-picxel-review/animation-check.png>)
- [beginner-sample.png](<C:/Users/mi/AppData/Local/Temp/player-picxel-review/beginner-sample.png>)
- [capitalist-sample.png](<C:/Users/mi/AppData/Local/Temp/player-picxel-review/capitalist-sample.png>)
- [cutouts.png](<C:/Users/mi/AppData/Local/Temp/player-picxel-review/cutouts.png>)
- [sample-review.png](<C:/Users/mi/AppData/Local/Temp/player-picxel-review/sample-review.png>)
- [swords.png](<C:/Users/mi/AppData/Local/Temp/player-picxel-review/swords.png>)

### UI设计审阅 · r01

目录：[review](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_buttons/r01/review>)

- [button_states_review.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_buttons/r01/review/button_states_review.png>)
- [native_masters.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_buttons/r01/review/native_masters.png>)

### UI设计审阅 · r01

目录：[review](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_panel_master/r01/review>)

- [text_overlay_example.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_panel_master/r01/review/text_overlay_example.png>)
- [ui_panel_review.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_panel_master/r01/review/ui_panel_review.png>)

### UI设计审阅 · pixel_r01

目录：[review](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r01/review>)

- [alpha_dark.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r01/review/alpha_dark.png>)
- [alpha_light.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r01/review/alpha_light.png>)
- [base_288x504.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r01/review/base_288x504.png>)
- [base_4x.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r01/review/base_4x.png>)
- [in_game_comparison.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r01/review/in_game_comparison.png>)
- [pixel_review.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r01/review/pixel_review.png>)
- [refined_288x504.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r01/review/refined_288x504.png>)
- [refined_4x.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r01/review/refined_4x.png>)

### UI设计审阅 · pixel_r02

目录：[review](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r02/review>)

- [alpha_dark.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r02/review/alpha_dark.png>)
- [alpha_light.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r02/review/alpha_light.png>)
- [base_handle.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r02/review/base_handle.png>)
- [base_panel.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r02/review/base_panel.png>)
- [base_review.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r02/review/base_review.png>)
- [in_game_comparison.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r02/review/in_game_comparison.png>)
- [pixel_review.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r02/review/pixel_review.png>)
- [refined_handle.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r02/review/refined_handle.png>)
- [refined_panel.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r02/review/refined_panel.png>)
- [refined_review.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r02/review/refined_review.png>)

### UI设计审阅 · pixel_r03

目录：[review](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r03/review>)

- [asset_comparison.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r03/review/asset_comparison.png>)
- [contact_shadow_mask.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r03/review/contact_shadow_mask.png>)
- [in_game_comparison.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r03/review/in_game_comparison.png>)
- [joint_comparison_4x.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r03/review/joint_comparison_4x.png>)
- [ui_stats_drawer_fit_288x520.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r03/review/ui_stats_drawer_fit_288x520.png>)
- [wood_mask.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r03/review/wood_mask.png>)

### UI设计审阅 · pixel_r04

目录：[review](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r04/review>)

- [handle_8x.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r04/review/handle_8x.png>)
- [handle_comparison.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/pixel_r04/review/handle_comparison.png>)

### UI设计审阅 · r01

目录：[review](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/r01/review>)

- [bottom_clean_3x.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/r01/review/bottom_clean_3x.png>)
- [bottom_source_3x.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/r01/review/bottom_source_3x.png>)
- [cleanup_mask.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/r01/review/cleanup_mask.png>)
- [hd_cleanup_comparison.jpg](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/r01/review/hd_cleanup_comparison.jpg>)
- [wood_clean_detail.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/r01/review/wood_clean_detail.png>)

### UI设计审阅 · r02

目录：[review](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/r02/review>)

- [handle_size_preview.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/r02/review/handle_size_preview.png>)
- [hd_review_board.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/r02/review/hd_review_board.png>)
- [panel_with_leather_handle_hd.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_stats_drawer/r02/review/panel_with_leather_handle_hd.png>)

### UI设计审阅 · r01

目录：[review](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_wood_tile/r01/review>)

- [repeat_3x3_4x.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_wood_tile/r01/review/repeat_3x3_4x.png>)
- [repeat_3x3_native.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_wood_tile/r01/review/repeat_3x3_native.png>)
- [text_overlay.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_wood_tile/r01/review/text_overlay.png>)
- [ui_wood_tile_review.png](<D:/project/useless/resources/infinite-build-dome-survival/artifacts/previews/art_refresh_v1/ui_wood_tile/r01/review/ui_wood_tile_review.png>)

## 六、完整逐文件索引

- [CSV：包含每一张录制帧、截图和成片的绝对路径](<C:/Users/mi/AppData/Local/Temp/recorded-media-inventory/media-files.csv>)
- [JSON：同一份逐文件索引](<C:/Users/mi/AppData/Local/Temp/recorded-media-inventory/media-files.json>)

临时目录中的文件可能被系统后续清理；本清单记录的是 2026-09-29 本次核查时的状态。
