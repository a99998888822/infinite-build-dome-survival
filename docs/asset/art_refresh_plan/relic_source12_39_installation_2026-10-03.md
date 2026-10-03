# 遗物原色 12 色色板版：39 件正式接入（2026-10-03）

用户在比较新版与正式资源后明确要求全部替换。本次将 `relic_flat_review/r02/delivery/png64` 的 39 张确认稿接入正式遗物目录，规格均为 64×64、实际 10–12 色、二值透明。PNG 与确认稿哈希相同，可编辑 PXG 内嵌同一套使用色值，逐像素渲染一致。

本次采用原图取色、轻度纹理合并、主要明暗与关键图案保留的 r02 版。正式文件沿用原 ID 与路径；列表／商店 32px、百科 64px、奖励 48px 的最近邻显示契约继续生效。

## 接入清单

| ID | 遗物 | 实际用色 |
|---|---|---|
| `relic_compound_interest_tome` | 复利宝典 | 12 |
| `relic_periodic_dividend_clock` | 周期分红钟 | 11 |
| `relic_quant_trading` | 量化操盘 | 12 |
| `relic_steel_vault` | 钢铁保险柜 | 12 |
| `relic_dividend_check` | 分红支票 | 12 |
| `relic_finance_manager` | 理财经理 | 12 |
| `relic_fixed_deposit_certificate` | 定期存单 | 12 |
| `relic_high_yield_contract` | 高利契约 | 12 |
| `relic_hostile_takeover` | 恶意收购 | 12 |
| `relic_tip_tray` | 小费托盘 | 12 |
| `relic_coin_heart` | 金币心脏 | 12 |
| `relic_frenzied_dividend` | 狂热分红 | 12 |
| `relic_gilded_trigger` | 镀金扳机 | 12 |
| `relic_golden_sarcophagus` | 黄金棺椁 | 12 |
| `relic_guarding_heart_copper_mirror` | 守心铜鉴 | 11 |
| `relic_hoarders_ring` | 囤积者戒指 | 12 |
| `relic_lucid_vow` | 清醒誓言 | 12 |
| `relic_old_brass_telescope` | 旧铜望远镜 | 12 |
| `relic_reincarnation_hellfire_candle` | 轮回业火之烛 | 12 |
| `relic_runaway_amplifier` | 失控增幅器 | 12 |
| `relic_sleepless_ledger` | 无眠账簿 | 12 |
| `relic_abyssal_echo_shell` | 深海回声螺 | 12 |
| `relic_aftershock_hourglass` | 余震沙漏 | 12 |
| `relic_diffusion_nozzle` | 扩散喷口 | 12 |
| `relic_divine_fusion` | 神性融合 | 12 |
| `relic_folded_star_chart` | 折叠星图 | 10 |
| `relic_goblin_central_bank_printer` | 哥布林金币铸造机 | 12 |
| `relic_golden_rangefinder` | 黄金测距仪 | 11 |
| `relic_horizon_orrery` | 地平线星仪 | 12 |
| `relic_long_focus_eyepiece` | 长焦目镜 | 12 |
| `relic_merger_reorg` | 并购重组 | 12 |
| `relic_range_tripod` | 定距脚架 | 12 |
| `relic_annual_leave_cutback` | 年假削减方案 | 12 |
| `relic_bankruptcy_reorg` | 破产重组 | 12 |
| `relic_flyer_ad` | 传单广告 | 12 |
| `relic_medical_cutback` | 医疗削减方案 | 12 |
| `relic_perpetual_annuity_scroll` | 永续年金卷轴 | 11 |
| `relic_salary_adjustment` | 薪酬调整方案 | 12 |
| `relic_welfare_cutback` | 福利削减方案 | 12 |

## 验证

- Godot 4.7.2 无窗口编辑器导入通过，未发现 Parse/Compile/SCRIPT ERROR。
- 现有遗物界面测试分 7 组覆盖全部 39 件，headless 和 GPU 均为 `failures=0`，覆盖列表、商店、百科、收款与奖励卡。
- GPU 截图使用私有 Windows 桌面；7 组均验证实际引擎桌面，`foreground_samples=0`。
- 316 处实际图标采样覆盖全部 39 件，前景像素与正式 PNG 最近邻采样完全一致，最大 RGB 误差为 0。
- 人工检查商店、百科及奖励卡截图中的图标清晰度、背景对比和留白。
- 此次正式资源仅修改 39 PNG 与 39 PXG；全部 `.png.import` 的 UID 和设置、其他遗物文件及原图保持一致。清单同步本批状态、尺寸和安装哈希。

## 追溯

- [确认稿总览](../../../artifacts/previews/relic_flat_review/r02/delivery/overview64.png)
- [安装文件及替换前后哈希](../../../artifacts/previews/relic_flat_review/r02/installation/assets.json)
- [完整校验记录](../../../artifacts/previews/relic_flat_review/r02/installation/validation.json)
- [实际画面像素核验](../../../artifacts/previews/relic_flat_review/r02/installation/pixel_checks.json)
- [替换前备份](../../../artifacts/previews/relic_flat_review/r02/installation/previous/)
- [商店截图](../../../artifacts/previews/relic_flat_review/r02/installation/captures-1/shop_1152x648.png)

原审阅包及其校验记录保留为接入前快照；其中“正式资源未改动”描述对应审阅阶段。本记录代表本次接入后的状态。
