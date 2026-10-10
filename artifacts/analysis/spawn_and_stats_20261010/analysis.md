# 刷怪与玩家属性实装核查（2026-10-10）

核查当前工作区代码与配置，包含尚未提交的改动。本次只生成分析产物，不修改玩法。

后续状态：下文保留实装前的审计快照。控制、护盾和侵蚀数量已按后续要求补全，最新规则见 [实装说明](D:/project/useless/resources/infinite-build-dome-survival/docs/main/player_stat_implementation_2026-10-10.md)。侵蚀度为 0 的基础刷怪曲线仍适用。

结论：共 34 项玩家属性，均能追踪到至少一个实际玩法用途，未发现完全闲置的属性。**控制强度的主要描述尚未落实**：现在增加雷电连锁目标数，不会增强减速、冻结或眩晕。另有理财、护盾、货币获取加成、侵蚀度等属性存在必须明确的生效范围。

## 刷怪曲线

![当前刷怪曲线](D:/project/useless/resources/infinite-build-dome-survival/artifacts/analysis/spawn_and_stats_20261010/spawn_curves.png)

曲线采用 `scenes/tests/spawn_density_test.tscn` 的生产调度器采样，3 档难度 × 20 波，60 Hz，无营地数量加成、侵蚀度为 0、无交易/挑战。每帧清除敌人，排除同屏上限对供给的截断，因此这是能持续清怪时的基准供给，不是任意玩家实战都必然遇到的数量。精英配额采样种子为 20261009。检查结果：223 项通过，0 失败。

| 波次 | 持续时间 | 难度 1：整波总数 / 每秒供给 | 难度 2：整波总数 / 每秒供给 | 难度 3：整波总数 / 每秒供给 |
|---|---:|---:|---:|---:|
| 1 | 30 秒 | 32 / 1.11 | 56 / 1.99 | 80 / 2.84 |
| 5 | 50 秒 | 99 / 2.05 | 140 / 2.89 | 208 / 4.29 |
| 10 | 60 秒 | 192 / 3.30 | 299 / 5.14 | 399 / 6.84 |
| 15 | 60 秒 | 192 / 3.31 | 352 / 6.02 | 494 / 8.52 |
| 20 | 60 秒 | 255 / 4.35 | 363 / 6.26 | 593 / 10.26 |

整波总数包含替换生成的精英。每秒供给是 `Σ(每批数量 ÷ 每批间隔)` 的理论持续值；整波采样还包含开局延迟、整批计时与结束边界，所以不能直接乘波长得到相同总数。第 20 波本次采样普通怪分别为 252、360、590，其余均为 3 个精英。

### 频率、数量及限制

- 每波有两组独立计时器，约第 2 秒和第 2.6 秒开始刷怪。
- 第 1 波持续 30 秒，之后每波增加 5 秒，第 7 波起固定 60 秒。
- 同屏常规敌人上限：难度 1 为 48，难度 2 为 72，难度 3 为 96；这个上限包含替换生成的精英。额外挑战精英和债务挑战目标单独处理。
- 满员时仍消耗本次计划的刷怪数量；超额整数丢弃，不等空位出现后补刷。
- 刷新间隔并不是逐波一直缩短。前段变快，后段经过密度曲线调节基本稳定或略回升；后期供给增长主要来自每批数量增加。
- 每批数量先经过难度缩放并向上取整，因而供给呈阶梯变化；标准难度第 10–15 波附近存在平台，不是连续光滑增长。
- 配置的普通刷怪组先生成基础怪，再按变体权重选择普通怪种类；变体选择不会增加本批数量。

| 难度 | 第 1 波：组 1 / 组 2 | 第 20 波：组 1 / 组 2 |
|---|---|---|
| 1 | 每 1.507 秒 1 只 / 每 2.260 秒 1 只 | 每 1.396 秒 4 只 / 每 2.021 秒 3 只 |
| 2 | 每 1.340 秒 2 只 / 每 2.009 秒 1 只 | 每 1.241 秒 5 只 / 每 1.797 秒 4 只 |
| 3 | 每 1.172 秒 2 只 / 每 1.758 秒 2 只 | 每 1.086 秒 7 只 / 每 1.572 秒 6 只 |

精英不是每隔固定秒数无限刷：每波开始计算有限配额。第 1 波没有常规精英，第 2 波起，期望数量为：

```text
min(3, max(1, 波次 / 8) × (1 + clamp(侵蚀度 / 100, 0, 1)) × 难度精英倍率)
```

难度精英倍率分别是 1、1.15、1.3。小数配额在相邻整数之间随机，例如期望 2.5 就抽 2 或 3 个。约第 5 秒起，在前半波的常规刷怪中替换为精英；满员或错过窗口可能影响实际出现数量。侵蚀度提高这一配额以及怪物血量、伤害、护甲，并不扩大常规批次总数。

### 当前公式与 +20% 属性

令 `i = 波次 - 1`，`p = enemy_spawn_rate_percent`：

```text
基础批量 = ceil(waves.json 中的 count_per_spawn × 难度数量倍率 × (1 + 0.06 × i))
期望批量 = 基础批量 × (1 + p / 100)
刷新间隔 = max(300 ms,
    waves.json 中的 spawn_interval_ms × 难度间隔倍率
    / (1 + 0.025 × i) / 密度曲线[i])
```

难度数量倍率为 0.15 / 0.22 / 0.30，间隔倍率为 2.70 / 2.40 / 2.10。密度曲线第 1–5 波为 2.15，之后逐步降至第 20 波的 1.20；当前额外数量乘数均为 1。

`怪物数量增幅 +20` 已实装，交易/挑战中的“怪物频率 +20%，存活后本金 +150”也接入了这个属性。它增加每批数量，间隔保持不变。所有组共享本波的小数余量，按百分之一整数累计。例如每批基础数量为 1 时，+20 后实际依次是 1、1、1、1、2。波次开始时余量清零。

假设整个波次始终为 +20%、未触发同屏上限、同样的调度时刻，则整波总数为 `floor(原总数 × 1.2)`。标准难度第 1 波从 32 变为 38，第 20 波从 255 变为 306；额外整数仍来自常规批次，精英配额不会因此同步乘 1.2。这是按已验证余量公式推算，曲线本身展示 +0% 的引擎采样。

关键代码：[批量与间隔](D:/project/useless/resources/infinite-build-dome-survival/scripts/waves/wave_manager.gd:855)、[实际调度与上限](D:/project/useless/resources/infinite-build-dome-survival/scripts/waves/wave_manager.gd:701)、[难度配置](D:/project/useless/resources/infinite-build-dome-survival/scripts/data/battle_difficulty.gd:4)。

## 全部 34 项玩家属性

“已接入”表示存在实际玩法消费者，并不表示每把武器、每种奖励或每个时点都必然受影响。此表通过属性定义、玩家修改器、武器继承、伤害/效果执行、掉落和经济消费者逐项核对；不是仅按文本搜索出现次数判断。武器会在 `WeaponInstance.get_stat()` 合并玩家属性，施法快照也会保留这些值。

| # | 属性（ID） | 核查结果与实际用途 | 主要消费代码 |
|---:|---|---|---|
| 1 | 最大生命 `max_hp` | 已接入：初始化生命、治疗上限、复活生命和生命裁剪。 | `player_controller.gd:158,456,999` |
| 2 | 每秒回血 `hp_regen` | 已接入：战斗中按秒累积小数，整点回血；负值抵扣正向加成，但不会直接掉血。 | `player_controller.gd:683` |
| 3 | 护盾 `shield` | 已接入，有时点限制：角色与营地初始属性在开局快照，每波重置发放；遗物另走波初 `grant_shield` 事件。见下文。 | `player_controller.gd:151,411,474,485` |
| 4 | 每秒护盾 `shield_regen` | 已接入：按秒积累并发放护盾，先补当前护盾，超出现有容量后一起提高容量。 | `player_controller.gd:694` |
| 5 | 额外复活 `revive_count` | 已接入：初始化和属性增加时提供次数，死亡时消耗；重建修改器不重复补回已用次数。 | `player_controller.gd:797,999` |
| 6 | 击杀回血 `on_kill_heal` | 已接入：击杀结算时治疗玩家。 | `wave_manager.gd:983` |
| 7 | 护甲 `armor` | 已接入：换算成受到伤害倍率；当前作用在扣除护盾后剩余的生命伤害。 | `modifier_stack.gd:124`; `player_controller.gd:419` |
| 8 | 受到伤害百分比 `damage_taken_percent` | 已接入：与护甲曲线组合，进入实际生命伤害计算。 | `modifier_stack.gd:124`; `player_controller.gd:419` |
| 9 | 移动速度 `move_speed` | 已接入：玩家常规移动速度。 | `player_controller.gd:531` |
| 10 | 近战伤害 `melee_damage` | 已接入：对应武器的基础伤害，按武器配置的玩家加成系数合入。 | `weapon_instance.gd:676,805` |
| 11 | 远程伤害 `ranged_damage` | 已接入：对应武器的基础伤害。 | `weapon_instance.gd:676,805` |
| 12 | 元素伤害 `element_damage` | 已接入：元素原生攻击，以及附魔/反应的元素基础伤害。 | `weapon_instance.gd:797`; `damage_event.gd` |
| 13 | 伤害加成 `damage_percent` | 已接入：构建武器伤害事件时乘算。 | `weapon_instance.gd:782` |
| 14 | 攻击速度 `attack_speed` | 已接入：缩短攻击/主动冷却；不直接加快动作动画或喷射节拍。 | `weapon_instance.gd:730`; `stat_definitions.gd:435` |
| 15 | 暴击率 `crit_chance` | 已接入：伤害事件中的暴击概率。 | `weapon_instance.gd:783` |
| 16 | 暴击伤害 `crit_damage` | 已接入：暴击时的伤害倍率。 | `weapon_instance.gd:785` |
| 17 | 投射物数量 `projectile_count` | 已接入：弹数/角度；部分武器映射为攻击段数、目标数，例如突进短刃落地斩击段数。 | `weapon_instance.gd:744`; `mobility_weapon_runtime.gd:88` |
| 18 | 攻击距离 `area_size` | 已接入：攻击/索敌距离及适用效果传播距离；通常每 100 点对应 50% 距离增幅。 | `weapon_instance.gd:540,602`; `effect_parameter_resolver.gd:11` |
| 19 | 伤害范围 `damage_area_size` | 已接入：适用攻击的命中半径/宽度、爆炸半径、元素效果范围和视觉缩放；通常每 100 点对应 50% 范围增幅。 | `weapon_instance.gd:516,702,795`; `effect_parameter_resolver.gd:12` |
| 20 | 控制强度 `control_power` | **描述部分未实装**：用于雷电连锁目标数及挑战准备期战力评估；未接入减速比例、冻结/眩晕时长。 | `lightning_particle_effect.gd:88`; `wave_challenge_system.gd:131` |
| 21 | 拾取范围 `pickup_radius` | 已接入：拾取区域以及经验球、血包、遗物/附魔拾取物吸附判断。 | `player_controller.gd:961`; `scripts/pickups/` |
| 22 | 经验获取加成 `exp_gain_percent` | 已接入：实际发放拾取经验时应用百分比。 | `wave_manager.gd:542` |
| 23 | 掉落率加成 `drop_rate_percent` | 已接入：普通掉落概率；附魔另走有上限的递减收益公式。 | `drop_reward_system.gd:82,98,133` |
| 24 | 血包恢复量加成 `health_pack_heal_plus` | 已接入：血包拾取时的固定治疗量加成，可以为负。 | `health_pack.gd:56` |
| 25 | 幸运 `luck` | 已接入：共享奖励/商店稀有度权重、升级稀有度门槛、附魔掉落概率。 | `main_flow_coordinator.gd:1072`; `shop_offer_generator.gd:115,143`; `drop_reward_system.gd:127` |
| 26 | 货币获取加成 `currency_gain_percent` | 已接入，有范围限制：拾取金币乘算，按分累计余数；不直接乘利息、固定交易奖励或最终营地币总额。 | `wave_manager.gd:541`; `run_settlement.gd:13` |
| 27 | 理财 `finance` | 已接入，有时点限制：开局转换为本金；后续余额由独立 `principal` 维护。 | `battle_finance_system.gd:107` |
| 28 | 利率 `interest_rate` | 已接入：计算名义利息，再经理智修正和小数余量结算至随身金币。 | `battle_finance_system.gd:491,499,503` |
| 29 | 商店折扣 `shop_price_percent` | 已接入：各来源折扣逐层相乘，进入实际报价。 | `player_controller.gd:268`; `shop_offer_generator.gd:392` |
| 30 | 商店选择数量加成 `shop_offer_count_bonus` | 已接入：共享奖励和商店候选数；购买货架通常至少 3 件，单格交易可强制为 1。 | `main_flow_coordinator.gd:990` |
| 31 | 负载上限 `load_capacity` | 已接入：装备负载校验和新武器候选资格。 | `weapon_loadout.gd:608`; `shop_offer_generator.gd` |
| 32 | 怪物数量增幅 `enemy_spawn_rate_percent` | 已接入：增加常规每批怪物数量，小数余量跨批累计；不改变刷新间隔。 | `wave_manager.gd:855,864` |
| 33 | 人性/理智 `humanity` | 已接入：影响购买价格、出售收益和利息；达到 100 后经济惩罚归零，超过 100 不继续提供这三项加成。 | `humanity_economy.gd:6`; `battle_finance_system.gd:507`; `inventory_trade_service.gd` |
| 34 | 侵蚀度 `divinity` | 已接入，有范围限制：波初快照影响敌人血量/伤害/护甲和精英配额，部分遗物读取它计算利率；普通批次总数和间隔不变。 | `wave_manager.gd:270,788,879`; `enemy_wave_pressure.gd:19`; `battle_finance_system.gd:747` |

## 需要区分的实装边界

### 控制强度：有用途，但没有实现描述中的控制增强

属性描述写的是“影响减速、定身等控制效果强度”。实际执行链是：玩家属性 → 武器属性 → 效果上下文 → 雷电连锁数量。

`lightning_particle_effect.gd:88` 使用 `round(chain_count + control_power / 10)` 计算连锁额度。常见整数连锁基础值下，每 10 点控制强度增加约 1 个连锁目标；由于四舍五入，会在中间档位提前跳档。挑战的准备期收益评估也读取它。

冰冻、减速、湿润、眩晕实际使用附魔自身参数和敌人控制抗性，没有读取玩家控制强度。敌人的 `get_control_multiplier()` 是敌人自身的控制易感系数，不能视为玩家属性已经接入。

证据：[雷电连锁](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/lightning_particle_effect.gd:88)、[冰场控制参数](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/ice_field_effect.gd:115)、[敌人减速/冻结](D:/project/useless/resources/infinite-build-dome-survival/scripts/enemies/enemy_controller.gd:283)、[眩晕](D:/project/useless/resources/infinite-build-dome-survival/scripts/enemies/enemy_controller.gd:443)。

### 护盾：单纯新增局内 shield 修改器不等于发护盾

营地/角色护盾在初始化时存入 `_initial_wave_shield`；每波开始使用这个快照。已有护盾遗物（例如死者护盾徽记、虚空触手）同时配置 `wave_start → grant_shield`，因此它们实际能发放护盾。单独在局内增加 `shield` 属性却不发事件，不会自动提高当前护盾或更新开局快照。这个限制是新增奖励时容易踩到的接入点，不能据此认定已有护盾遗物失效。

证据：[初始护盾快照](D:/project/useless/resources/infinite-build-dome-survival/scripts/player/player_controller.gd:148)、[波初发放](D:/project/useless/resources/infinite-build-dome-survival/scripts/waves/wave_manager.gd:266)、[已有遗物配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:712)。

### 理财：属性值是初始本金来源，实际余额是另一份状态

`finance` 在理财系统初始化时读取一次，之后存取、奖励和交易修改 `BattleFinanceSystem.principal`。局内直接增加 `finance` 修改器不会自动入账。本金关联武器也从当前本金回调取值，而非读取这个静态天赋属性。现有营地理财用途已实现；描述“每波开始前可存入或取出的本金”没有明确表达这个区分。

证据：[初始本金](D:/project/useless/resources/infinite-build-dome-survival/scripts/rewards/battle_finance_system.gd:107)、[武器读取实时本金](D:/project/useless/resources/infinite-build-dome-survival/scripts/weapons/weapon_instance.gd:669)。

### 货币加成：直接作用于拾取收入

金币拾取入口会乘算此属性，利息和固定奖励走各自结算。最终营地币按击杀、战斗金币、波次、利息分别折算，再乘难度系数，没有把此属性再次乘到营地币总额上；此前已经提高的战斗金币会间接提高营地币中的金币贡献。属性描述“局内或结算货币”容易让人误以为所有入账都受加成。

### 侵蚀度：“数量”体现为精英配额

侵蚀度不会让普通批次刷出更多敌人，也不加快刷新；它会让常规生成槽位中更多位置变成精英，同时增强敌人属性。波初固定本波侵蚀度快照，波中变化通常在下一波刷新时影响这些参数。

## 产物与复现

- [原始引擎采样 JSON](D:/project/useless/resources/infinite-build-dome-survival/artifacts/analysis/spawn_and_stats_20261010/spawn_baseline.json)
- [60 行数值表 CSV](D:/project/useless/resources/infinite-build-dome-survival/artifacts/analysis/spawn_and_stats_20261010/spawn_table.csv)
- [曲线 PNG](D:/project/useless/resources/infinite-build-dome-survival/artifacts/analysis/spawn_and_stats_20261010/spawn_curves.png)
- [矢量曲线 SVG](D:/project/useless/resources/infinite-build-dome-survival/artifacts/analysis/spawn_and_stats_20261010/spawn_curves.svg)
- [绘图脚本](D:/project/useless/resources/infinite-build-dome-survival/artifacts/analysis/spawn_and_stats_20261010/plot_snapshot.py)

属性核查为逐项源码执行链审计，不宣称对全部属性的所有组合进行了运行时穷举。`stat_reference_inventory.json` 仅为定位辅助，结论以本文记录的实际消费者为准。
