# 资产总清单汇总

> 汇总来源：`assets/` 实际源素材 + 已迁移的原分模块 asset checklist 目标清单；后续只维护本文档和 `asset_rules_summary.md`。
> 判定规则：已存在表按磁盘上实际在用的文件列出，缺失表按清单目标路径列出；`.import`、“节点实现/无需 PNG”条目不纳入文件表。
> 文件表范围：只收 `assets/` 下的 PNG 与音频（OGG/WAV）；字体（`assets/font/`）、`.svg`、`.aseprite`、`.tres` 和说明性 `.md` 不纳入。
> 补充说明：第 13 组可选区域素材原文未给固定文件名，此处按 `zones.json` ID 和现有目录规则补了建议命名。
> 尺寸说明：已存在条目的尺寸列按磁盘 PNG 实际像素读取；遗物图标当前实际为 `32x32`（原清单按 `128x128` 规划）。
> 生成日期：2026-09-21。
> 磁盘核对：`assets/` 下 PNG + 音频共 118 个，已全部登记在第 1 节与第 4 节（2026-09-21 已清理 5 个冗余文件）。
> 表格结构：已存在素材、未存在的必需素材、未存在的可选素材、动效与音频。

## 1. 已存在的素材（113 个）

| 状态 | 素材名 | 文件名 | 路径 | 尺寸/比例/格式 | 提示词 |
|---|---|---|---|---|---|
| 已存在 | background1 | `background1.png` | `assets/sprites/camp/background1.png` | 512x512 / 1:1 / PNG |  |
| 已存在 | background2 | `background2.png` | `assets/sprites/camp/background2.png` | 512x512 / 1:1 / PNG |  |
| 已存在 | 遗物档案馆建筑 | `camp_relic_archive.png` | `assets/sprites/camp/buildings/unlocked/camp_relic_archive.png` | 256x256 / 1:1 / PNG |  |
| 已存在 | stone1 | `stone1.png` | `assets/sprites/camp/stone1.png` | 128x128 / 1:1 / PNG |  |
| 已存在 | stone2 | `stone2.png` | `assets/sprites/camp/stone2.png` | 256x128 / 2:1 / PNG |  |
| 已存在 | stone3 | `stone3.png` | `assets/sprites/camp/stone3.png` | 128x128 / 1:1 / PNG |  |
| 已存在 | stone4 | `stone4.png` | `assets/sprites/camp/stone4.png` | 128x128 / 1:1 / PNG |  |
| 已存在 | thicket1 | `thicket1.png` | `assets/sprites/camp/thicket1.png` | 64x64 / 1:1 / PNG |  |
| 已存在 | tree1 | `tree1.png` | `assets/sprites/camp/tree1.png` | 256x256 / 1:1 / PNG |  |
| 已存在 | tree2 | `tree2.png` | `assets/sprites/camp/tree2.png` | 256x256 / 1:1 / PNG |  |
| 已存在 | tree3 | `tree3.png` | `assets/sprites/camp/tree3.png` | 256x256 / 1:1 / PNG |  |
| 已存在 | tree4 | `tree4.png` | `assets/sprites/camp/tree4.png` | 256x256 / 1:1 / PNG |  |
| 已存在 | tree5 | `tree5.png` | `assets/sprites/camp/tree5.png` | 256x256 / 1:1 / PNG |  |
| 已存在 | tree6 | `tree6.png` | `assets/sprites/camp/tree6.png` | 256x256 / 1:1 / PNG |  |
| 已存在 | tree7 | `tree7.png` | `assets/sprites/camp/tree7.png` | 256x256 / 1:1 / PNG |  |
| 已存在 | tree8 | `tree8.png` | `assets/sprites/camp/tree8.png` | 256x256 / 1:1 / PNG |  |
| 已存在 | wood1 | `wood1.png` | `assets/sprites/camp/wood1.png` | 128x128 / 1:1 / PNG |  |
| 已存在 | wood2 | `wood2.png` | `assets/sprites/camp/wood2.png` | 128x128 / 1:1 / PNG |  |
| 已存在 | 经验球 | `pickup_exp_orb.png` | `assets/sprites/pickups/pickup_exp_orb.png` | 16x16 / 1:1 / PNG |  |
| 已存在 | 血包 | `pickup_health_pack.png` | `assets/sprites/pickups/pickup_health_pack.png` | 16x16 / 1:1 / PNG |  |
| 已存在 | 玩家右向基础单帧 | `void_hunter_idle_right.png` | `assets/sprites/player/void_hunter_idle_right.png` | 256x256 / 1:1 / PNG |  |
| 已存在 | 玩家右向行走帧表 | `void_hunter_walk_right_spritesheet.png` | `assets/sprites/player/void_hunter_walk_right_spritesheet.png` | 1024x256 / 4:1 / PNG |  |
| 已存在 | 角色小图标 | `icon_void_hunter.png` | `assets/ui/icons/characters/icon_void_hunter.png` | 128x128 / 1:1 / PNG |  |
| 已存在 | HUD 血条图标 | `icon_hud_hp.png` | `assets/ui/icons/hud/icon_hud_hp.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | HUD 护盾图标 | `icon_hud_shield.png` | `assets/ui/icons/hud/icon_hud_shield.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | placeholder_icon | `placeholder_icon.png` | `assets/ui/icons/placeholder_icon.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 年假削减方案遗物图标 | `relic_annual_leave_cutback.png` | `assets/ui/icons/relics/relic_annual_leave_cutback.png` | 32x32 / 1:1 / PNG，透明背景 | 紫稀有度；被撕掉休假页、排满加班日期的年度排班表，像素风，轮廓清晰，透明背景。 |
| 已存在 | 破产重组遗物图标 | `relic_bankruptcy_reorg.png` | `assets/ui/icons/relics/relic_bankruptcy_reorg.png` | 32x32 / 1:1 / PNG，透明背景 | 红稀有度；破产重组主题图标，像素风，轮廓清晰，透明背景。 |
| 已存在 | 复利宝典遗物图标 | `relic_compound_interest_tome.png` | `assets/ui/icons/relics/relic_compound_interest_tome.png` | 32x32 / 1:1 / PNG，透明背景 | 紫稀有度；复利宝典主题图标，像素风，轮廓清晰，透明背景。 |
| 已存在 | 分红支票遗物图标 | `relic_dividend_check.png` | `assets/ui/icons/relics/relic_dividend_check.png` | 32x32 / 1:1 / PNG，透明背景 | 绿稀有度；分红支票主题图标，像素风，轮廓清晰，透明背景。 |
| 已存在 | 神性融合遗物图标 | `relic_divine_fusion.png` | `assets/ui/icons/relics/relic_divine_fusion.png` | 32x32 / 1:1 / PNG，透明背景 | 橙稀有度；神性融合主题图标，像素风，轮廓清晰，透明背景。 |
| 已存在 | 理财经理遗物图标 | `relic_finance_manager.png` | `assets/ui/icons/relics/relic_finance_manager.png` | 32x32 / 1:1 / PNG，透明背景 | 白稀有度；理财经理主题图标，像素风，轮廓清晰，透明背景。 |
| 已存在 | 定期存单遗物图标 | `relic_fixed_deposit_certificate.png` | `assets/ui/icons/relics/relic_fixed_deposit_certificate.png` | 32x32 / 1:1 / PNG，透明背景 | 绿稀有度；定期存单主题图标，像素风，轮廓清晰，透明背景。 |
| 已存在 | 传单广告遗物图标 | `relic_flyer_ad.png` | `assets/ui/icons/relics/relic_flyer_ad.png` | 32x32 / 1:1 / PNG，透明背景 | 绿稀有度；传单广告主题图标，像素风，轮廓清晰，透明背景。 |
| 已存在 | 哥布林金币铸造机遗物图标 | `relic_goblin_central_bank_printer.png` | `assets/ui/icons/relics/relic_goblin_central_bank_printer.png` | 32x32 / 1:1 / PNG，透明背景 | 橙稀有度；哥布林金币铸造机主题图标，像素风，轮廓清晰，透明背景。 |
| 已存在 | 吸金罗盘遗物图标 | `relic_gold_compass.png` | `assets/ui/icons/relics/relic_gold_compass.png` | 32x32 / 1:1 / PNG，透明背景 | 蓝稀有度；吸金罗盘主题图标，像素风，轮廓清晰，透明背景。 |
| 已存在 | 高利契约遗物图标 | `relic_high_yield_contract.png` | `assets/ui/icons/relics/relic_high_yield_contract.png` | 32x32 / 1:1 / PNG，透明背景 | 紫稀有度；高利契约主题图标，像素风，轮廓清晰，透明背景。 |
| 已存在 | 恶意收购遗物图标 | `relic_hostile_takeover.png` | `assets/ui/icons/relics/relic_hostile_takeover.png` | 32x32 / 1:1 / PNG，透明背景 | 蓝稀有度；恶意收购主题图标，像素风，轮廓清晰，透明背景。 |
| 已存在 | 医疗削减方案遗物图标 | `relic_medical_cutback.png` | `assets/ui/icons/relics/relic_medical_cutback.png` | 32x32 / 1:1 / PNG，透明背景 | 紫稀有度；盖着红章、被裁去福利条款的医疗报销单，像素风，轮廓清晰，透明背景。 |
| 已存在 | 并购重组遗物图标 | `relic_merger_reorg.png` | `assets/ui/icons/relics/relic_merger_reorg.png` | 32x32 / 1:1 / PNG，透明背景 | 紫稀有度；并购重组主题图标，像素风，轮廓清晰，透明背景。 |
| 已存在 | 周期分红钟遗物图标 | `relic_periodic_dividend_clock.png` | `assets/ui/icons/relics/relic_periodic_dividend_clock.png` | 32x32 / 1:1 / PNG，透明背景 | 紫稀有度；周期分红钟主题图标，像素风，轮廓清晰，透明背景。 |
| 已存在 | 永续年金卷轴遗物图标 | `relic_perpetual_annuity_scroll.png` | `assets/ui/icons/relics/relic_perpetual_annuity_scroll.png` | 32x32 / 1:1 / PNG，透明背景 | 橙稀有度；永续年金卷轴主题图标，像素风，轮廓清晰，透明背景。 |
| 已存在 | 猪猪存钱罐遗物图标 | `relic_piggy_bank.png` | `assets/ui/icons/relics/relic_piggy_bank.png` | 32x32 / 1:1 / PNG，透明背景 | 白稀有度；猪猪存钱罐主题图标，像素风，轮廓清晰，透明背景。 |
| 已存在 | 量化操盘遗物图标 | `relic_quant_trading.png` | `assets/ui/icons/relics/relic_quant_trading.png` | 32x32 / 1:1 / PNG，透明背景 | 蓝稀有度；量化操盘主题图标，像素风，轮廓清晰，透明背景。 |
| 已存在 | 薪酬调整方案遗物图标 | `relic_salary_adjustment.png` | `assets/ui/icons/relics/relic_salary_adjustment.png` | 32x32 / 1:1 / PNG，透明背景 | 紫稀有度；薪资条上覆盖“结构性调整”红章的工资单，像素风，轮廓清晰，透明背景。 |
| 已存在 | 钢铁保险柜遗物图标 | `relic_steel_vault.png` | `assets/ui/icons/relics/relic_steel_vault.png` | 32x32 / 1:1 / PNG，透明背景 | 蓝稀有度；钢铁保险柜主题图标，像素风，轮廓清晰，透明背景。 |
| 已存在 | 小费托盘遗物图标 | `relic_tip_tray.png` | `assets/ui/icons/relics/relic_tip_tray.png` | 32x32 / 1:1 / PNG，透明背景 | 蓝稀有度；小费托盘主题图标，像素风，轮廓清晰，透明背景。 |
| 已存在 | 福利削减方案遗物图标 | `relic_welfare_cutback.png` | `assets/ui/icons/relics/relic_welfare_cutback.png` | 32x32 / 1:1 / PNG，透明背景 | 紫稀有度；被剪去彩带、盖着“优化福利”印章的员工福利手册，像素风，轮廓清晰，透明背景。 |
| 已存在 | 人性护符遗物图标 | `relic_amulet_of_humanity.png` | `assets/ui/icons/relics/relic_amulet_of_humanity.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 屏障结晶遗物图标 | `relic_barrier_crystal.png` | `assets/ui/icons/relics/relic_barrier_crystal.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 狂战士铜质徽章遗物图标 | `relic_berserker_copper_badge.png` | `assets/ui/icons/relics/relic_berserker_copper_badge.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 黑斑鹰眼水晶遗物图标 | `relic_black_spot_eagle_eye.png` | `assets/ui/icons/relics/relic_black_spot_eagle_eye.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 阻滞配重石遗物图标 | `relic_blocking_counterweight.png` | `assets/ui/icons/relics/relic_blocking_counterweight.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 嗜血皮带遗物图标 | `relic_bloodstained_belt.png` | `assets/ui/icons/relics/relic_bloodstained_belt.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 黄铜怀表遗物图标 | `relic_brass_pocket_watch.png` | `assets/ui/icons/relics/relic_brass_pocket_watch.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 残破晶石遗物图标 | `relic_broken_crystal.png` | `assets/ui/icons/relics/relic_broken_crystal.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 苦难前行之枷锁遗物图标 | `relic_chain_of_hardship.png` | `assets/ui/icons/relics/relic_chain_of_hardship.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 蚀腐吹管遗物图标 | `relic_corroded_blowpipe.png` | `assets/ui/icons/relics/relic_corroded_blowpipe.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 代价生命之种遗物图标 | `relic_costly_seed_of_life.png` | `assets/ui/icons/relics/relic_costly_seed_of_life.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 裂痕石子弹遗物图标 | `relic_cracked_stone_bullet.png` | `assets/ui/icons/relics/relic_cracked_stone_bullet.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 密教圣盾遗物图标 | `relic_cultic_holy_shield.png` | `assets/ui/icons/relics/relic_cultic_holy_shield.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 死寂护盾徽章遗物图标 | `relic_dead_shield_badge.png` | `assets/ui/icons/relics/relic_dead_shield_badge.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 被亵渎的祈福铜钱遗物图标 | `relic_defiled_blessing_coin.png` | `assets/ui/icons/relics/relic_defiled_blessing_coin.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 屠戮者臂铠遗物图标 | `relic_executioner_bracer.png` | `assets/ui/icons/relics/relic_executioner_bracer.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 扩容背包束带遗物图标 | `relic_expanded_backpack_strap.png` | `assets/ui/icons/relics/relic_expanded_backpack_strap.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 血肉肩甲遗物图标 | `relic_flesh_pauldron.png` | `assets/ui/icons/relics/relic_flesh_pauldron.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 疾风轮盘遗物图标 | `relic_gale_roulette.png` | `assets/ui/icons/relics/relic_gale_roulette.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 馈赠印记遗物图标 | `relic_gift_mark.png` | `assets/ui/icons/relics/relic_gift_mark.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 淘金者的手套遗物图标 | `relic_gold_digger_gloves.png` | `assets/ui/icons/relics/relic_gold_digger_gloves.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 守心铜鉴遗物图标 | `relic_guarding_heart_copper_mirror.png` | `assets/ui/icons/relics/relic_guarding_heart_copper_mirror.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 丰收的牺牲祭器遗物图标 | `relic_harvest_sacrificial_vessel.png` | `assets/ui/icons/relics/relic_harvest_sacrificial_vessel.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 急促弹簧扳机遗物图标 | `relic_hasty_spring_trigger.png` | `assets/ui/icons/relics/relic_hasty_spring_trigger.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 圣质银杯遗物图标 | `relic_holy_silver_cup.png` | `assets/ui/icons/relics/relic_holy_silver_cup.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 残缺的占卜骰子遗物图标 | `relic_incomplete_divination_dice.png` | `assets/ui/icons/relics/relic_incomplete_divination_dice.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 裁决之眼吊坠遗物图标 | `relic_judgment_eye_pendant.png` | `assets/ui/icons/relics/relic_judgment_eye_pendant.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 负重铁皮护腕遗物图标 | `relic_load_iron_bracer.png` | `assets/ui/icons/relics/relic_load_iron_bracer.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 迷途者胫环遗物图标 | `relic_lost_wayfarer_greave.png` | `assets/ui/icons/relics/relic_lost_wayfarer_greave.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 梦魇治愈圣壶遗物图标 | `relic_nightmare_healing_urn.png` | `assets/ui/icons/relics/relic_nightmare_healing_urn.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 苦痛祭皿遗物图标 | `relic_pain_vessel.png` | `assets/ui/icons/relics/relic_pain_vessel.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 毒雾投囊遗物图标 | `relic_poison_mist_pouch.png` | `assets/ui/icons/relics/relic_poison_mist_pouch.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 监狱铜制脚环遗物图标 | `relic_prison_copper_anklet.png` | `assets/ui/icons/relics/relic_prison_copper_anklet.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 刺鼻香包遗物图标 | `relic_pungent_sachet.png` | `assets/ui/icons/relics/relic_pungent_sachet.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 轮回业火之烛遗物图标 | `relic_reincarnation_hellfire_candle.png` | `assets/ui/icons/relics/relic_reincarnation_hellfire_candle.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 粗糙研磨透镜遗物图标 | `relic_rough_grinding_lens.png` | `assets/ui/icons/relics/relic_rough_grinding_lens.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 无影遁形胫甲遗物图标 | `relic_shadowless_greave.png` | `assets/ui/icons/relics/relic_shadowless_greave.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 守魂人面石雕遗物图标 | `relic_soul_keeper_face_stone.png` | `assets/ui/icons/relics/relic_soul_keeper_face_stone.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 分裂晶石弹头遗物图标 | `relic_split_crystal_warhead.png` | `assets/ui/icons/relics/relic_split_crystal_warhead.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 观星者的镜片遗物图标 | `relic_stargazers_lens.png` | `assets/ui/icons/relics/relic_stargazers_lens.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 受难甲壳遗物图标 | `relic_suffering_carapace.png` | `assets/ui/icons/relics/relic_suffering_carapace.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 商旅账本遗物图标 | `relic_travelers_ledger.png` | `assets/ui/icons/relics/relic_travelers_ledger.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 震颤握柄遗物图标 | `relic_tremor_grip.png` | `assets/ui/icons/relics/relic_tremor_grip.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 真银护甲遗物图标 | `relic_true_silver_armor.png` | `assets/ui/icons/relics/relic_true_silver_armor.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 龟壳吊坠遗物图标 | `relic_turtle_shell_pendant.png` | `assets/ui/icons/relics/relic_turtle_shell_pendant.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 生命力药瓶遗物图标 | `relic_vitality_potion.png` | `assets/ui/icons/relics/relic_vitality_potion.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 虚空收纳匣遗物图标 | `relic_void_storage_casket.png` | `assets/ui/icons/relics/relic_void_storage_casket.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 虚空触手遗物图标 | `relic_void_tentacle.png` | `assets/ui/icons/relics/relic_void_tentacle.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 磨损格斗拳套遗物图标 | `relic_worn_fighting_gloves.png` | `assets/ui/icons/relics/relic_worn_fighting_gloves.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 磨损的止血布条遗物图标 | `relic_worn_hemostatic_cloth.png` | `assets/ui/icons/relics/relic_worn_hemostatic_cloth.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | tree1_shader | `tree1_shader.png` | `assets/sprites/camp/tree1_shader.png` | 256x256 / 1:1 / PNG |  |
| 已接入 | 天外幼体待机帧 | `enemy_gloom_mite_idle.png` | `assets/sprites/enemies/enemy_gloom_mite_idle.png` | 128x128 / 1:1 / PNG | 已采用原稿微调版；透明背景；旧 PNG 与 Aseprite 源文件以 `_legacy` 后缀保留在同目录 |
| 已接入 | 天外幼体行走帧 | `enemy_gloom_mite_move.png` | `assets/sprites/enemies/enemy_gloom_mite_move.png` | 384x128 / 3:1 / PNG | 三帧，首帧与待机一致；旧 PNG 以 `_legacy` 后缀保留在同目录 |
| 已存在 | 木质弓箭弹道贴图 | `projectile_wood_arrow.png` | `assets/sprites/weapons/projectiles/projectile_wood_arrow.png` | 24x24 / 1:1 / PNG |  |
| 已存在 | 爆裂卷轴图标 | `scroll_explosion.png` | `assets/ui/icons/augmentations/scroll_explosion.png` | 16x16 / 1:1 / PNG |  |
| 已存在 | 火焰卷轴图标 | `scroll_fire.png` | `assets/ui/icons/augmentations/scroll_fire.png` | 16x16 / 1:1 / PNG |  |
| 已存在 | 结霜卷轴图标 | `scroll_ice.png` | `assets/ui/icons/augmentations/scroll_ice.png` | 16x16 / 1:1 / PNG |  |
| 已存在 | 连锁主宰卷轴图标 | `scroll_lightning.png` | `assets/ui/icons/augmentations/scroll_lightning.png` | 16x16 / 1:1 / PNG |  |
| 已存在 | 穿透卷轴图标 | `scroll_pierce.png` | `assets/ui/icons/augmentations/scroll_pierce.png` | 16x16 / 1:1 / PNG |  |
| 已存在 | 分裂卷轴图标 | `scroll_split.png` | `assets/ui/icons/augmentations/scroll_split.png` | 16x16 / 1:1 / PNG |  |
| 已存在 | 电浆炮武器图标 | `weapon_plasma_cannon.png` | `assets/ui/icons/weapons/weapon_plasma_cannon.png` | 32x32 / 1:1 / PNG |  |
| 已存在 | 木质弓箭武器图标 | `weapon_wood_arrow.png` | `assets/ui/icons/weapons/weapon_wood_arrow.png` | 64x64 / 1:1 / PNG |  |
| 已存在 | 主菜单背景 | `bg_main_menu.png` | `assets/ui/main_menu/bg_main_menu.png` | 1920x1080 / 16:9 / PNG |  |
| 已存在 | 主菜单按钮底图 | `button_main_menu.png` | `assets/ui/main_menu/button_main_menu.png` | 600x186 / PNG |  |
| 已存在 | 主菜单标题图 | `title_main_menu.png` | `assets/ui/main_menu/title_main_menu.png` | 350x80 / PNG |  |

## 2. 未存在的必需素材（10 个）

| 状态 | 素材名 | 文件名 | 路径 | 尺寸/比例/格式 | 提示词 |
|---|---|---|---|---|---|
| 未存在 | HUD 金币图标 | `icon_hud_coin.png` | `assets/ui/icons/hud/icon_hud_coin.png` | 1:1，64x64 或 128x128 / PNG，透明背景 | 生成一张清新干净的中高精度像素风 UI 图标，表示金币，图形简洁、偏暖金色，轮廓清楚，透明背景，PNG，不要文字，不要噪点 |
| 未存在 | HUD 负载图标 | `icon_hud_load.png` | `assets/ui/icons/hud/icon_hud_load.png` | 1:1，64x64 或 128x128 / PNG，透明背景 | 生成一张清新干净的中高精度像素风 UI 图标，表示武器负载或容量，图形可以是小背包、能量槽或秤重符号，轮廓清楚，透明背景，PNG，不要文字，不要噪点 |
| 未存在 | HUD 波次图标 | `icon_hud_wave_time.png` | `assets/ui/icons/hud/icon_hud_wave_time.png` | 1:1，64x64 或 128x128 / PNG，透明背景 | 生成一张清新干净的中高精度像素风 UI 图标，表示波次计时，图形可以是小沙漏或计时圆环，轮廓清楚，透明背景，PNG，不要文字，不要噪点 |
| 未存在 | HUD 武器图标 | `icon_hud_weapon.png` | `assets/ui/icons/hud/icon_hud_weapon.png` | 1:1，64x64 或 128x128 / PNG，透明背景 | 生成一张清新干净的中高精度像素风 UI 图标，表示当前装备武器，图形可以是简化武器轮廓或小武器槽，轮廓清楚，透明背景，PNG，不要文字，不要噪点 |
| 未存在 | HUD 羁绊图标 | `icon_hud_relic.png` | `assets/ui/icons/hud/icon_hud_relic.png` | 1:1，64x64 或 128x128 / PNG，透明背景 | 生成一张清新干净的中高精度像素风 UI 图标，表示遗物或羁绊统计，图形可以是小徽记或简化符文，轮廓清楚，透明背景，PNG，不要文字，不要噪点 |
| 未存在 | 理财弹窗主面板装饰 | `ui_finance_panel_frame.png` | `assets/ui/panels/finance/ui_finance_panel_frame.png` | 9-slice PNG / Godot StyleBox 可替代 | 当前实现先使用 `PanelContainer` |
| 未存在 | 当前金币图标 | `ui_finance_gold_icon.png` | `assets/ui/icons/finance/ui_finance_gold_icon.png` | 64x64 / 1:1 / PNG，透明背景 | 可复用局内金币图标 |
| 未存在 | 本金图标 | `ui_finance_principal_icon.png` | `assets/ui/icons/finance/ui_finance_principal_icon.png` | 64x64 / 1:1 / PNG，透明背景 | 建议金币堆 + 银行章 |
| 未存在 | 利率图标 | `ui_finance_interest_icon.png` | `assets/ui/icons/finance/ui_finance_interest_icon.png` | 64x64 / 1:1 / PNG，透明背景 | 建议百分号 + 金币光效 |
| 未存在 | 本金锁定提示 | `ui_finance_lock_icon.png` | `assets/ui/icons/finance/ui_finance_lock_icon.png` | 64x64 / 1:1 / PNG，透明背景 | 定期存单锁定状态 |

## 3. 未存在的可选素材（25 个）

| 状态 | 素材名 | 文件名 | 路径 | 尺寸/比例/格式 | 提示词 |
|---|---|---|---|---|---|
| 未存在 | 武器商店卡片底图 | `card_weapon_shop_clean.png` | `assets/ui/icons/weapons/card_weapon_shop_clean.png` | 4:5，512x640 / PNG，透明或干净底 | 生成一张清新干净的像素风武器商店卡片底图，适合穹顶生存轻克苏鲁题材，柔和深蓝绿色背景，浅金色边框，中央留出武器图标空间，下方留出名称和数值文本空间，不要文字，不要肮脏噪点，不要血腥恐怖，PNG |
| 未存在 | 武器负载图标 | `icon_weapon_load.png` | `assets/ui/icons/weapons/icon_weapon_load.png` | 1:1，64x64 或 128x128 / PNG，透明背景 | 生成一张清新干净的中高精度像素风 UI 图标，表示武器负载，图形是小背包或能量槽，浅绿色和暖黄色配色，轮廓清晰，小尺寸可读，透明背景，PNG，不要文字，不要肮脏噪点，不要血腥恐怖 |
| 未存在 | 武器升级箭头 | `icon_weapon_upgrade.png` | `assets/ui/icons/weapons/icon_weapon_upgrade.png` | 1:1，64x64 或 128x128 / PNG，透明背景 | 生成一张清新干净的中高精度像素风 UI 图标，表示武器升级，图形是向上箭头和小星光，浅绿色、淡蓝色、暖黄色配色，轮廓清晰，小尺寸可读，透明背景，PNG，不要文字，不要肮脏噪点，不要血腥恐怖 |
| 未存在 | 羁绊徽记基础底图 | `bond_mark_base.png` | `assets/ui/icons/bonds/bond_mark_base.png` | 1:1，建议 128x128 / PNG，透明背景 | 生成一张清新干净的中高精度像素风 UI 底图，主题是羁绊徽记基础框，图形简洁、圆角、带少量淡金色与浅绿光泽，适合放置羁绊名称和层数，不要文字，不要肮脏噪点，不要血腥，不要复杂背景，透明背景，PNG |
| 未存在 | 大力羁绊徽记 | `bond_mighty.png` | `assets/ui/icons/bonds/bond_mighty.png` | 1:1，建议 128x128 / PNG，透明背景 | 生成一张清新干净的中高精度像素风羁绊徽记，主题是“大力”，图形偏向肌肉、拳头或重锤的简洁符号，浅红棕与暖金配色，轮廓清晰，适合 2D 游戏 UI 小图标，透明背景，PNG，不要文字，不要肮脏噪点，不要血腥 |
| 未存在 | 神射手羁绊徽记 | `bond_sharpshooter.png` | `assets/ui/icons/bonds/bond_sharpshooter.png` | 1:1，建议 128x128 / PNG，透明背景 | 生成一张清新干净的中高精度像素风羁绊徽记，主题是“神射手”，图形偏向箭矢、准星或拉弓符号，浅蓝色与金色配色，轮廓清晰，适合 2D 游戏 UI 小图标，透明背景，PNG，不要文字，不要肮脏噪点，不要血腥 |
| 未存在 | 神选者羁绊徽记 | `bond_chosen.png` | `assets/ui/icons/bonds/bond_chosen.png` | 1:1，建议 128x128 / PNG，透明背景 | 生成一张清新干净的中高精度像素风羁绊徽记，主题是“神选者”，图形偏向第三只眼、星环或虚空纹章，浅紫色与蓝绿色配色，带轻微神秘光芒，轮廓清晰，适合 2D 游戏 UI 小图标，透明背景，PNG，不要文字，不要肮脏噪点，不要血腥 |
| 未存在 | 波次开始提示图标 | `icon_wave_start.png` | `assets/ui/icons/waves/icon_wave_start.png` | 1:1，建议 128x128 / PNG，透明背景 | 生成一张清新干净的中高精度像素风 UI 图标，主题是“波次开始”，图形为小旗帜、钟表或向前箭头，淡蓝绿色和暖金配色，轮廓清晰，透明背景，PNG，不要文字，不要肮脏噪点，不要血腥 |
| 未存在 | 营地 UI 图标 | `icon_camp.png` | `assets/ui/icons/camp/icon_camp.png` | 128x128 / PNG | 生成一个像素风营地图标，主题是“营地 / 篝火 / 小屋”，清新、简洁、透明背景，适合作为 UI 入口按钮。 |
| 未存在 | 通用关闭按钮 | `icon_close.png` | `assets/ui/icons/system/icon_close.png` | 1:1，64x64 或 128x128 / PNG，透明背景 | 生成一张清新干净的中高精度像素风 UI 图标，表示关闭，使用简洁叉号或圆角关闭符号，轮廓清楚，透明背景，PNG，不要文字，不要噪点 |
| 未存在 | 返回按钮 | `icon_back.png` | `assets/ui/icons/system/icon_back.png` | 1:1，64x64 或 128x128 / PNG，透明背景 | 生成一张清新干净的中高精度像素风 UI 图标，表示返回，使用简洁左箭头或折返符号，轮廓清楚，透明背景，PNG，不要文字，不要噪点 |
| 未存在 | 确认按钮 | `icon_confirm.png` | `assets/ui/icons/system/icon_confirm.png` | 1:1，64x64 或 128x128 / PNG，透明背景 | 生成一张清新干净的中高精度像素风 UI 图标，表示确认，使用简洁对勾或确认符号，轮廓清楚，透明背景，PNG，不要文字，不要噪点 |
| 未存在 | 刷新按钮 | `icon_refresh.png` | `assets/ui/icons/system/icon_refresh.png` | 1:1，64x64 或 128x128 / PNG，透明背景 | 生成一张清新干净的中高精度像素风 UI 图标，表示刷新，使用简洁环形箭头或重抽符号，轮廓清楚，透明背景，PNG，不要文字，不要噪点 |
| 未存在 | 暂停按钮 | `icon_pause.png` | `assets/ui/icons/system/icon_pause.png` | 1:1，64x64 或 128x128 / PNG，透明背景 | 生成一张清新干净的中高精度像素风 UI 图标，表示暂停，使用简洁暂停符号，轮廓清楚，透明背景，PNG，不要文字，不要噪点 |
| 未存在 | 继续按钮 | `icon_resume.png` | `assets/ui/icons/system/icon_resume.png` | 1:1，64x64 或 128x128 / PNG，透明背景 | 生成一张清新干净的中高精度像素风 UI 图标，表示继续或恢复游戏，使用简洁播放符号或前进符号，轮廓清楚，透明背景，PNG，不要文字，不要噪点 |
| 未存在 | 模式选择图标 | `icon_mode_select.png` | `assets/ui/icons/system/icon_mode_select.png` | 1:1，128x128 / PNG，透明背景 | 生成一张清新干净的中高精度像素风 UI 图标，表示模式选择，使用简洁分支或选择符号，轮廓清楚，透明背景，PNG，不要文字，不要噪点 |
| 未存在 | 图鉴图标 | `icon_gallery.png` | `assets/ui/icons/system/icon_gallery.png` | 1:1，128x128 / PNG，透明背景 | 生成一张清新干净的中高精度像素风 UI 图标，表示图鉴，使用书本、卡册或资料页符号，轮廓清楚，透明背景，PNG，不要文字，不要噪点 |
| 未存在 | 建筑卡片底图 | `card_building_detail.png` | `assets/ui/panels/camp/card_building_detail.png` | 4:5，512x640 / PNG，透明或半透明底 | 生成一张清新干净的像素风建筑详情卡片底图，适合营地界面，顶部留出建筑名称区域，中部留出建筑图像区域，底部留出升级信息区域，边框简洁，PNG，不要文字，不要噪点 |
| 未存在 | 角色选择卡片底图 | `card_character_select.png` | `assets/ui/panels/system/card_character_select.png` | 4:5，512x640 / PNG，透明或半透明底 | 生成一张清新干净的像素风角色选择卡片底图，适合角色头像和文字说明，边框简洁，留白充足，PNG，不要文字，不要噪点 |
| 未存在 | 金币图标 | `icon_currency_gold.png` | `assets/ui/icons/rewards/icon_currency_gold.png` | 1:1，64x64 或 128x128 / PNG，透明背景 | 生成一张清新干净的中高精度像素风 UI 图标，主题是“金币 / 货币”，小型金色硬币或能量币，轮廓清晰，小尺寸可读，透明背景，PNG，不要文字，不要肮脏噪点，不要血腥 |
| 未存在 | 区域图标-近弦战场 | `zone_nearstring_battlefield.png` | `assets/ui/icons/zones/zone_nearstring_battlefield.png` | 1:1, 128x128 / PNG | 生成：简洁的近战倾向图标 / 区域选择页识别 / PNG |
| 未存在 | 区域图标-流星高塔 | `zone_meteor_tower.png` | `assets/ui/icons/zones/zone_meteor_tower.png` | 1:1, 128x128 / PNG | 生成：简洁的远程倾向图标 / 区域选择页识别 / PNG |
| 未存在 | 区域图标-神选之地 | `zone_chosen_land.png` | `assets/ui/icons/zones/zone_chosen_land.png` | 1:1, 128x128 / PNG | 生成：简洁的理智/侵蚀倾向图标 / 区域选择页识别 / PNG |
| 未存在 | 福缘收割提示图标 | `icon_fortune_harvest.png` | `assets/ui/icons/zones/icon_fortune_harvest.png` | 1:1, 128x128 / PNG | 生成：福袋、收割、光点一类提示符号 / 切区收割结果页 / PNG |
| 未存在 | 区域卡片底纹 | `card_zone_pattern.png` | `assets/ui/panels/zones/card_zone_pattern.png` | 4:5, 512x640 / PNG | 生成：低对比、干净的卡片纹理 / 区域选择页背景强化 / PNG |

## 4. 动效与音频（32 个文件 + 3 条节点实现）


| 状态 | 素材名 | 文件名 | 路径 | 尺寸/比例/格式 | 提示词 |
|---|---|---|---|---|---|
| 未存在 | UI 弹窗关闭音效 | `sfx_ui_modal_close.ogg` | `assets/audio/sfx/ui/sfx_ui_modal_close.ogg` | OGG/WAV，短音效 | 比打开音效更轻、更短的收束提示音 |
| 未存在 | UI 弹窗打开音效 | `sfx_ui_modal_open.ogg` | `assets/audio/sfx/ui/sfx_ui_modal_open.ogg` | OGG/WAV，短音效 | 深沉、克制的面板展开提示音，适合区域、ESC、营地详情等弹窗 |
| 未存在 | UI 确认音效 | `sfx_ui_confirm.ogg` | `assets/audio/sfx/ui/sfx_ui_confirm.ogg` | OGG/WAV，短音效 | 清晰短促的确认反馈，不要过亮 |
| 未存在 | 区域选择音效 | `sfx_ui_zone_select.ogg` | `assets/audio/sfx/ui/sfx_ui_zone_select.ogg` | OGG/WAV，短音效 | 带有方向感和轻微能量感的区域确认音 |
| 未存在 | 奖励揭示音效 | `sfx_ui_reward_reveal.ogg` | `assets/audio/sfx/ui/sfx_ui_reward_reveal.ogg` | OGG/WAV，短音效 | 金色奖励出现时的短促上扬提示音 |
| 未存在 | UI 购买成功音效 | `sfx_ui_purchase_success.ogg` | `assets/audio/sfx/ui/sfx_ui_purchase_success.ogg` | OGG/WAV，短音效 | 营地升级或购买成功的金币确认声 |
| 未存在 | UI 购买失败音效 | `sfx_ui_purchase_error.ogg` | `assets/audio/sfx/ui/sfx_ui_purchase_error.ogg` | OGG/WAV，短音效 | 低调、短促的错误提示音，不要刺耳 |
| 未存在 | 经验球吸取音效 | `sfx_exp_orb_collect.ogg` | `assets/audio/sfx/pickups/sfx_exp_orb_collect.ogg` | OGG/WAV，短音效 | 清脆、轻盈、带一点星光感的经验吸取提示音，支持高频重复播放 |
| 未存在 | 波次结束安全提示音 | `sfx_wave_end_safe.ogg` | `assets/audio/sfx/ui/sfx_wave_end_safe.ogg` | OGG/WAV，短音效 | 温和舒缓的安全阶段提示音，避免过强警报感 |
| 未存在 | 武器命中橙黄色像素火花 | 无需文件，使用 CPUParticles2D | 节点实现 | 橙黄色像素颗粒四散炸开，单次生命周期约 0.2 秒 |
| 未存在 | 低血量暗红边缘渐变 | 无需文件，使用 CanvasItem Shader | 节点实现 | 玩家生命低于 30% 时显示，随生命比例增强并缓慢呼吸 |
| 未存在 | 波末经验球汇聚轨迹 | 无需文件，使用 ExpOrb 动画 | 节点实现 | 经验球带轻微弧线、旋转并向玩家汇聚 |
| 已存在 | 菜单 BGM | `bgm_menu.ogg` | `assets/audio/bgm/bgm_menu.ogg` | OGG，循环 | 生成：角色选择和通用菜单使用，平静、清新、轻微神秘 / OGG，循环 |
| 未存在 | 营地 BGM | `bgm_camp.ogg` | `assets/audio/bgm/bgm_camp.ogg` | OGG，循环 | 生成：森林、篝火、河流营地使用，安静舒缓 / OGG，循环 |
| 已存在 | 战斗 BGM | `bgm_battle.ogg` | `assets/audio/bgm/bgm_battle.ogg` | OGG，循环 | 生成：普通战斗使用，节奏稳定，有轻微紧张感 / OGG，循环 |
| 未存在 | 小飞刃 `weapon_void_blade` | `sfx_weapon_void_blade_hit.ogg` | `assets/audio/sfx/weapons/sfx_weapon_void_blade_hit.ogg` | OGG/WAV，短音效 | 生成：小型飞刃命中目标的轻锐金属反馈 / OGG/WAV，短音效 |
| 未存在 | 利息结算动效 | `ui_finance_settlement_fx.png` | `assets/ui/effects/finance/ui_finance_settlement_fx.png` | Sprite sheet / 粒子素材，透明背景 | 金币流入本金池 |
| 未存在 | 理财页开关动效 | `ui_finance_mode_switch_fx.png` | `assets/ui/effects/finance/ui_finance_mode_switch_fx.png` | Sprite sheet / 粒子素材，透明背景 | 用于波前理财弹窗切换 |
| 未存在 | 小飞刀命中特效 | `effect_void_blade_hit.png` | `assets/sprites/weapons/effects/effect_void_blade_hit.png` | 1:1，128x128 / PNG，透明背景 | 生成一张清新干净的中高精度像素风命中特效，小型淡紫色星光爆点，中心明亮，边缘有少量像素粒子，适合飞刀命中敌人时播放，透明背景，PNG，不要血腥，不要肮脏噪点，不要复杂背景，不要文字 |
| 未存在 | 暴击命中特效 | `effect_critical_hit.png` | `assets/sprites/weapons/effects/effect_critical_hit.png` | 1:1，128x128 / PNG，透明背景 | 生成一张清新干净的中高精度像素风暴击特效，明亮金黄色和淡紫色混合闪光，星形爆点，轮廓清晰，适合 2D 游戏中作为暴击反馈，透明背景，PNG，不要血腥，不要肮脏噪点，不要复杂背景，不要文字 |
| 未存在 | 遗物获得闪光 | `effect_relic_get.png` | `assets/sprites/relics/effects/effect_relic_get.png` | 1:1，128x128 / PNG，透明背景 | 生成一张清新干净的中高精度像素风获取特效，小型淡金色与浅紫色闪光，星点环绕，适合作为遗物获得时的 UI 反馈，透明背景，PNG，不要肮脏噪点，不要血腥，不要复杂背景，不要文字 |
| 未存在 | 敌人受击闪光 | `effect_enemy_hit.png` | `assets/sprites/enemies/effects/effect_enemy_hit.png` | 1:1，建议 128x128 / PNG，透明背景 | 生成一张清新干净的中高精度像素风受击特效，小型淡黄色和浅紫色闪光，中心明亮，边缘有少量像素星点，适合敌人受击瞬间播放，透明背景，PNG，不要血腥，不要肮脏噪点，不要文字 |
| 未存在 | 敌人死亡消散 | `effect_enemy_death.png` | `assets/sprites/enemies/effects/effect_enemy_death.png` | 1:1，建议 128x128 / PNG，透明背景 | 生成一张清新干净的中高精度像素风敌人死亡消散特效，淡紫色与蓝绿色粒子向外散开，带少量柔和星点，适合 2D 游戏怪物死亡反馈，透明背景，PNG，不要血腥，不要腐烂，不要肮脏噪点，不要文字 |
| 未存在 | 存入本金 | `vfx_finance_deposit_coin_stream.png` | `assets/ui/effects/finance/vfx_finance_deposit_coin_stream.png` | Sprite sheet / 粒子素材，透明背景 | 金币从金币栏飞向本金图标 |
| 未存在 | 取出本金 | `vfx_finance_withdraw_coin_stream.png` | `assets/ui/effects/finance/vfx_finance_withdraw_coin_stream.png` | Sprite sheet / 粒子素材，透明背景 | 金币从本金图标飞回金币栏 |
| 未存在 | 利息结算 | `vfx_interest_settle_burst.png` | `assets/ui/effects/finance/vfx_interest_settle_burst.png` | Sprite sheet / 粒子素材，透明背景 | 金色数字上浮 + 光圈扩散 |
| 未存在 | 投机筹码翻倍 | `vfx_speculative_double.png` | `assets/ui/effects/finance/vfx_speculative_double.png` | Sprite sheet / 粒子素材，透明背景 | 筹码旋转后金光爆开 |
| 未存在 | 投机筹码失败 | `vfx_speculative_zero.png` | `assets/ui/effects/finance/vfx_speculative_zero.png` | Sprite sheet / 粒子素材，透明背景 | 筹码暗淡、灰烟散开 |
| 未存在 | 存入音效 | `sfx_finance_deposit.ogg` | `assets/audio/sfx/finance/sfx_finance_deposit.ogg` | OGG/WAV，短音效 | 清脆金币入袋声 |
| 未存在 | 取出音效 | `sfx_finance_withdraw.ogg` | `assets/audio/sfx/finance/sfx_finance_withdraw.ogg` | OGG/WAV，短音效 | 金币倒出声 |
| 未存在 | 利息结算音效 | `sfx_interest_settle.ogg` | `assets/audio/sfx/finance/sfx_interest_settle.ogg` | OGG/WAV，短音效 | 柔和金币叮声 |
| 未存在 | 本金锁定提示 | `sfx_finance_lock.ogg` | `assets/audio/sfx/finance/sfx_finance_lock.ogg` | OGG/WAV，短音效 | 轻微冰封/锁扣声 |
| 已存在 | 闪电附魔音效 1 | `lighting_1.wav` | `assets/audio/sfx/effects/lighting_1.wav` | WAV | lightning 附魔随机音效 |
| 已存在 | 闪电附魔音效 2 | `lighting_2.wav` | `assets/audio/sfx/effects/lighting_2.wav` | WAV | lightning 附魔随机音效 |
| 已存在 | 电火花附魔音效 | `thunder_1.wav` | `assets/audio/sfx/effects/thunder_1.wav` | WAV | electric_spark 附魔音效 |
