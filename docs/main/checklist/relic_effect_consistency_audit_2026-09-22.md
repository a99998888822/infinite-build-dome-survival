**遗物效果一致性检查清单 · 2026-09-22**

> 2026-09-23 状态更新：下文保留为修改前的历史审计。用户已确认 R01（远程不吃近战加成）、R06（刷新补回生命之种复活次数）符合设计；本次按最新 MD 同步数值，并完成 R02、R04、R05、R07—R12、U01—U03 的修复。最新行为及验证结果见 [修复验收记录](D:/project/useless/resources/infinite-build-dome-survival/docs/main/checklist/relic_effect_fixes_2026-09-23.md)。历史源码行号仅对应审计时版本。

结论：`augmentations_list.md` 与当前项目并非完全一致。72 件遗物中，8 件存在明确的文档数值差异；另外确认了 12 类运行逻辑问题和 3 类展示问题。问题编号按原因计数，同一件遗物可能涉及多个问题，不能把这些数量相加当作问题遗物总数。

本次核对的是仓库根目录的 [augmentations_list.md](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md)，不是一个名为 `augmentations/_list.md` 的子目录文件。该文件列的是遗物，对应运行配置为 [relics.json](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json)；[augmentations.json](D:/project/useless/resources/infinite-build-dome-survival/data_config/augmentations.json) 是另一套附魔配置。

检查基于工作区当时内容，HEAD 为 `e12ffffb6502beaab152d4458867de3bc737f3c1`，包含已有未提交改动。本次只新增检查文档与复现记录，没有修改游戏配置或实现。

**检查范围与已确认项目**

- [x] 原清单 72 条、配置 72 条，ID 一一对应，无缺项、多项或重复条目。
- [x] 72 件名称、稀有度枚举、持有上限均与原清单一致。白/绿/蓝/紫/橙/红分别对应 common/uncommon/rare/epic/mythic/legendary；此项核对数据映射，不包含图标画面或边框配色的视觉验收。
- [x] 65 件配置为 `max_stack=0`（不限持有数量）；6 件上限 1；传单广告上限 3。7 件有限上限均已运行验证，超限获取被拒绝。
- [x] 所有图标路径存在；4 件削减/调整方案的“剩余价值”羁绊关联一致。但该羁绊的配置 `thresholds={}`，当前没有任何阈值奖励，见 S08。
- [x] 对全部 72 件逐件运行静态属性检查：单件获取后的静态属性与 JSON 的 `effects` 一致。动态属性另按触发逻辑审查，不能把“静态属性检查通过”理解成“完整效果正确”。
- [x] 逐项追踪 `runtime_effects` 的获取、波初、波末、击杀、利息、复活、破盾和动态派生处理入口。
- [x] 商店/准备卡片、奖励卡片、ESC 遗物悬停文本均直接使用 JSON 的 `description`，不是从实际逻辑自动生成。8 处文档差异会直接反映为“原清单与游戏文字不同”。

文字来源：[商店候选生成:95](D:/project/useless/resources/infinite-build-dome-survival/scripts/ui/shop_offer_generator.gd:95)、[准备卡片:102](D:/project/useless/resources/infinite-build-dome-survival/scripts/ui/preparation_offer_card.gd:102)、[奖励卡片:410](D:/project/useless/resources/infinite-build-dome-survival/scripts/ui/reward_option.gd:410)、[ESC 悬停:493](D:/project/useless/resources/infinite-build-dome-survival/scripts/ui/esc_overlay.gd:493)。

**A. 必须统一的 8 处数值差异**

下表每一项都是“配置字段、配置描述、正常单件属性”彼此一致，但与原清单不同。当前实现究竟应跟哪一版数值，需按策划基准决定；本次没有擅自选定或修改。

| 待办 | 编号 | 遗物 | 原清单 | 当前配置、游戏说明及属性 | 原清单位置 | 配置位置 |
|---|---|---|---|---|---|---|
| ☐ | D01 | 生命力药瓶 | 每秒回血 +0.5 | 每秒回血 +1 | [33](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:33) | [680](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:680) |
| ☐ | D02 | 龟壳吊坠 | 最大生命 +2 | 最大生命 +1 | [35](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:35) | [712](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:712) |
| ☐ | D03 | 残缺的占卜骰子 | 幸运 +6 | 幸运 +9 | [77](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:77) | [1226](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1226) |
| ☐ | D04 | 被亵渎的祈福铜钱 | 幸运 +12 | 幸运 +18 | [79](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:79) | [1258](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1258) |
| ☐ | D05 | 馈赠印记 | 幸运 +28 | 幸运 +42 | [84](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:84) | [1337](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1337) |
| ☐ | D06 | 虚空收纳匣 | 幸运 +12 | 幸运 +18 | [85](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:85) | [1352](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1352) |
| ☐ | D07 | 轮回业火之烛 | 幸运 +50 | 幸运 +75 | [86](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:86) | [1369](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1369) |
| ☐ | D08 | 守心铜鉴 | 幸运 +12 | 幸运 +18 | [87](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:87) | [1387](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1387) |

**B. 已确认的运行逻辑问题**

P1 表示建议优先修复的核心收益丢失、额外收益或状态错误；P2 表示特定组合或结算边界问题。以下 R01—R12 均有针对当前代码的隔离运行复现，具体日志见文末。

| 待办 | 编号 / 优先级 | 涉及遗物 | 实际情况、复现与影响 | 代码依据 / 建议验收 |
|---|---|---|---|---|
| ☐ | R01 / P1 | 磨损格斗拳套、嗜血皮带、狂战士铜质徽章、屠戮者臂铠；疾风轮盘的近战惩罚 | 近战属性能写入，但当前两把武器均走远程伤害，`get_attack_kind()` 也固定返回 ranged。屠戮者臂铠把近战属性加到 10 后，固定暴击伤害仍为 8→8；其移速惩罚照常生效。四件近战增伤遗物在当前武器系统中没有增伤收益。 | [武器伤害:391](D:/project/useless/resources/infinite-build-dome-survival/scripts/weapons/weapon_instance.gd:391)、[类型:415](D:/project/useless/resources/infinite-build-dome-survival/scripts/weapons/weapon_instance.gd:415)、[攻击分派:249](D:/project/useless/resources/infinite-build-dome-survival/scripts/weapons/weapon_loadout.gd:249)。应接入近战玩法，或调整这些遗物的效果/投放范围。 |
| ☐ | R02 / P1 | 分裂晶石弹头 | 等离子炮的散射角为 0。持有弹头后投射物属性为 2，生成角度数组却仍只有 `[0]`，主攻击只发 1 发；通用伤害 -30 正常生效。 | [角度生成:362](D:/project/useless/resources/infinite-build-dome-survival/scripts/weapons/weapon_instance.gd:362)、[实际生成:272](D:/project/useless/resources/infinite-build-dome-survival/scripts/weapons/weapon_loadout.gd:272)。验收零散射与非零散射武器都按投射物数量生成。 |
| ☐ | R03 / P2 | 疾风轮盘 | 初始玩家远程加成为 0；遗物的 -2 先在玩家属性层被下限 0 截掉，再与武器伤害相加。默认武器基础伤害实际为 5→5，未变成 3。只有已有足够正向远程加成时，-2 才能抵扣加成。近战 -2 还受 R01 影响。 | [属性下限:122](D:/project/useless/resources/infinite-build-dome-survival/scripts/data/stat_definitions.gd:122)、[玩家/武器合成:153](D:/project/useless/resources/infinite-build-dome-survival/scripts/weapons/weapon_instance.gd:153)。明确“-2”是最终基础伤害惩罚还是仅抵扣正向加成。 |
| ☐ | R04 / P1 | 高利契约 + 永续年金卷轴 | 未完成 50 金币手动存入门槛时，普通波末结息被拦截，年金的 `annuity_extra` 未被拦截。复现：本金 100、利率 9%，同一波普通收益 0，年金收益 +9，与“当前回合结束时无法收获利息”不符。 | [拦截来源:370](D:/project/useless/resources/infinite-build-dome-survival/scripts/rewards/battle_finance_system.gd:370)、[波末调度:241](D:/project/useless/resources/infinite-build-dome-survival/scripts/rewards/battle_finance_system.gd:241)。应覆盖全部受契约约束的结算来源。 |
| ☐ | R05 / P2 | 复利宝典 + 永续年金卷轴；手动结息入口 | 宝典只对 `wave_end` 和 `periodic` 追加利率，成功的年金结息、手动结息不增长。复现：宝典+年金，一波两次正收益 5、6，利率只增加 0.2，而非按“每成功结算一次”增加 0.4。 | [成功结息处理:376](D:/project/useless/resources/infinite-build-dome-survival/scripts/rewards/battle_finance_system.gd:376)、[来源白名单:558](D:/project/useless/resources/infinite-build-dome-survival/scripts/rewards/battle_finance_system.gd:558)。手动入口已静态确认，复现重点验证了当前可组合的年金来源。 |
| ☐ | R06 / P1 | 代价生命之种 | 复活用完后，获取任意其他遗物或刷新武器关联会重建全部遗物修饰器：先清掉复活配置，再重新加回。被当成新增复活次数，导致已消耗次数恢复。复现：种子复活后剩余 0，获取猪猪存钱罐后变为 1。 | [整体重建:185](D:/project/useless/resources/infinite-build-dome-survival/scripts/relics/relic_bond_system.gd:185)、[次数同步:489](D:/project/useless/resources/infinite-build-dome-survival/scripts/player/player_controller.gd:489)。验收遗物/武器刷新前后已用次数保持不变。 |
| ☐ | R07 / P1 | 所有提高最大生命的遗物；获取其他遗物也能触发 | 重建期间临时移除全部最大生命加成，立即把当前生命压到临时上限；重新加回最大生命时不会恢复已截掉的生命。复现：止血布条后满血 13/13，获得存钱罐后变为 10/13。购买一件无伤害代价的遗物却实际掉血。 | [整体重建:185](D:/project/useless/resources/infinite-build-dome-survival/scripts/relics/relic_bond_system.gd:185)、[生命截断:495](D:/project/useless/resources/infinite-build-dome-survival/scripts/player/player_controller.gd:495)。应在完整重建结束后统一同步生命/复活状态。 |
| ☐ | R08 / P1 | 轮回业火之烛 + 人性护符/刺鼻香包/黄铜怀表/真银护甲等 | 获取蜡烛时触发全部遗物重建，原有正向理智修饰器先被移除，再因“不能增长”被拒绝重加。复现：先人性护符，理智 110；再蜡烛，理智降到 100。文字只承诺不能回复，并未说明会移除已有加成。 | [增加拦截:135](D:/project/useless/resources/infinite-build-dome-survival/scripts/player/player_controller.gd:135)、[遗物重加:193](D:/project/useless/resources/infinite-build-dome-survival/scripts/relics/relic_bond_system.gd:193)。区分既有加成重建和新产生的回复/增长。 |
| ☐ | R09 / P2 | 轮回业火之烛 + 守魂人面石雕 | 石雕的动态理智修饰器直接写入 `modifier_stack`，绕过玩家的禁止增长检查。复现：持有蜡烛与石雕，侵蚀 +10 时理智仍从 100 升到 110。与蜡烛对护符、守心铜鉴等的拦截口径不一致。 | [动态直接写入:530](D:/project/useless/resources/infinite-build-dome-survival/scripts/player/player_controller.gd:530)、[拦截入口:135](D:/project/useless/resources/infinite-build-dome-survival/scripts/player/player_controller.gd:135)。需明确派生理智能否豁免；若豁免，应写进说明。 |
| ☐ | R10 / P2 | 迷途者胫环 + 守魂人面石雕；无影遁形胫甲与动态移速效果也有同类依赖 | 动态修饰器全部清空后按遗物获取顺序只算一遍，先判断条件、后更新其依赖属性会留下旧结论。复现：基础理智 50、侵蚀 20，胫环→石雕得到理智 70/移速 240；石雕→胫环得到理智 70/移速 252。最终状态相同，效果却依赖获取顺序。 | [动态重算:501](D:/project/useless/resources/infinite-build-dome-survival/scripts/player/player_controller.gd:501)、[实例遍历:126](D:/project/useless/resources/infinite-build-dome-survival/scripts/relics/relic_bond_system.gd:126)。依赖项先计算，或使用稳定状态重算；本次运行复现的是胫环+石雕组合。 |
| ☐ | R11 / P2 | 神性融合 + 波末/破盾/复活侵蚀增长 | 侵蚀派生利率仅在财务 `_emit_changed()` 时刷新。玩家自身侵蚀变化不会同步通知财务。复现：本金 1000、融合持有者侵蚀从 0 到 5，利率仍 5%，第一次结息 +50 后才更新到 5.5%，而非本次就 +55；结算结果中的 `interest_rate_after` 也仍记录旧值。 | [刷新入口:431](D:/project/useless/resources/infinite-build-dome-survival/scripts/rewards/battle_finance_system.gd:431)、[侵蚀派生:459](D:/project/useless/resources/infinite-build-dome-survival/scripts/rewards/battle_finance_system.gd:459)、[空 tick:97](D:/project/useless/resources/infinite-build-dome-survival/scripts/rewards/battle_finance_system.gd:97)。波初会补刷新，但战斗中数值与首次使用仍可能滞后。 |
| ☐ | R12 / P1 | 吸金罗盘、淘金者的手套、商旅账本、丰收的牺牲祭器、观星者的镜片、轮回业火之烛、守心铜鉴、薪酬调整方案等 | 经验/金币百分比在每颗球上直接四舍五入，没有小数累计。小怪球基础 1：+5%、+8%、+10%、+12%、+35% 单独使用时每次仍为 1，收集很多次也不产生累计额外收益；-20% 单独使用仍为 1。复现了 +5%金币/+8%经验和净 -15%金币均被舍掉。精英/大额球或叠加到取整阈值后才可能有变化。 | [每球结算:271](D:/project/useless/resources/infinite-build-dome-survival/scripts/waves/wave_manager.gd:271)、[取整:513](D:/project/useless/resources/infinite-build-dome-survival/scripts/waves/wave_manager.gd:513)、[小怪掉落:15](D:/project/useless/resources/infinite-build-dome-survival/data_config/drop_tables.json:15)。建议累计小数余量或采用符合长期期望值的随机取整。 |

**C. 展示与实际数值的 3 类问题**

- [ ] **U01：复利宝典增长未计入属性抽屉的利率。** 财务系统保存 `interest_rate_bonus`，实际利率通过 `finance.get_interest_rate()` 合成；属性抽屉却直接读 `player.get_stat("interest_rate")`。复现为财务有效 5.2%，抽屉数据源仍为 5。财务弹窗读取快照，能够显示 5.2%。应统一“当前有效利率”的数据源。[财务利率:301](D:/project/useless/resources/infinite-build-dome-survival/scripts/rewards/battle_finance_system.gd:301)、[抽屉:1028](D:/project/useless/resources/infinite-build-dome-survival/scripts/ui/battle_hud.gd:1028)、[财务弹窗:77](D:/project/useless/resources/infinite-build-dome-survival/scripts/ui/finance_popup.gd:77)。
- [ ] **U02：叠加折扣的价格计算正确，属性抽屉却显示加总值。** 两件广告实际倍率 `0.92²=0.8464`，即有效折扣 15.36%；属性 `shop_price_percent` 显示 16。广告与薪酬调整混用时也有同类问题。应显示有效折扣/最终价格倍率，或明确这里展示的是未乘算的各层数值之和。[折扣层:176](D:/project/useless/resources/infinite-build-dome-survival/scripts/player/player_controller.gd:176)、[乘算公式:465](D:/project/useless/resources/infinite-build-dome-survival/scripts/data/stat_definitions.gd:465)、[抽屉:1028](D:/project/useless/resources/infinite-build-dome-survival/scripts/ui/battle_hud.gd:1028)。
- [ ] **U03：购买属性预览只应用静态 effects，未模拟触发/派生/禁止增长/羁绊。** 理智 50 时预览迷途者胫环显示移速 252，实买是 240；蜡烛持有者预览人性护符显示理智 60，实买仍为 50。钢铁保险柜、量化操盘、恶意收购等纯运行派生效果没有对应属性预览；并购重组的预览也只含静态 +10，忽略本金派生。应使用与实际获取一致的完整模拟，或明确标注只预览静态部分。[预览构造:7](D:/project/useless/resources/infinite-build-dome-survival/scripts/ui/stat_preview_builder.gd:7)、[悬停接入:195](D:/project/useless/resources/infinite-build-dome-survival/scripts/ui/finance_popup.gd:195)。

**D. 需要补充口径的文案与边界条件**

以下不能仅凭当前清单认定应改代码还是改文字，建议确定设计语义后再统一。

- [ ] **S01 破产重组：实际本局只触发一次。** `_bankruptcy_triggered` 首次触发后永久设真，并要求 `has_principal_ever`。第二次本金归零不会再次给本金或复活；初始一直为 0 也不触发。文档和 description 都只写“本金归零时触发”，持有上限 1 不等于触发次数上限 1。运行复现第一次 +2200 本金、再次取光后保持 0。建议写“本局首次在曾有本金后归零时”。[触发条件:500](D:/project/useless/resources/infinite-build-dome-survival/scripts/rewards/battle_finance_system.gd:500)。
- [ ] **S02 周期分红钟：按整局波数取模，不从获取时开始计数。** 第 3/6/9…波结束触发；第 3 波前刚获得也能马上触发。多件在同一波各加一次结息。本次已运行复现。若设计是“持有后每经过 3 波”，当前实现不符。[波计数:114](D:/project/useless/resources/infinite-build-dome-survival/scripts/rewards/battle_finance_system.gd:114)、[周期调度:241](D:/project/useless/resources/infinite-build-dome-survival/scripts/rewards/battle_finance_system.gd:241)。
- [ ] **S03 死寂护盾徽章、虚空触手：“开局”实际指每波开始。** 每波先清空上波累积护盾，再叠加 10/20 点波初护盾；获得遗物本身不立即发盾。静态 shield 字段和波初 grant_shield 不会重复发两份。建议明确“每波开始获得”。[波初调度:121](D:/project/useless/resources/infinite-build-dome-survival/scripts/waves/wave_manager.gd:121)、[护盾重置:334](D:/project/useless/resources/infinite-build-dome-survival/scripts/player/player_controller.gd:334)。
- [ ] **S04 小费托盘：叠加增加单次掉落价值，不增加概率或独立抽取次数。** N 件仍只抽一次 10%，命中后生成一颗基础值 N 的经验球；球同时给等额基础金币。多件时与“N 次独立 10% 各掉一球”分布不同。建议在叠加说明里写清楚。[抽取:265](D:/project/useless/resources/infinite-build-dome-survival/scripts/rewards/battle_finance_system.gd:265)、[生成:483](D:/project/useless/resources/infinite-build-dome-survival/scripts/waves/wave_manager.gd:483)、[经验金币同发:77](D:/project/useless/resources/infinite-build-dome-survival/scripts/pickups/exp_orb.gd:78)。
- [ ] **S05 分红支票：原清单备注正确，游戏说明缺少叠加规则。** N 件仍为一次 20% 概率，收益乘 N+1；两件是 20% 概率三倍，不是两次独立抽取，也不是四倍。JSON description 只说“有20%的概率翻倍”，ESC 悬停不会附带原清单备注。建议同步补充。[倍率:355](D:/project/useless/resources/infinite-build-dome-survival/scripts/rewards/battle_finance_system.gd:355)、[悬停:493](D:/project/useless/resources/infinite-build-dome-survival/scripts/ui/esc_overlay.gd:493)。
- [ ] **S06 “攻速/通用伤害/经验/金币/暴击”等数值单位应统一。** `attack_speed +8` 是攻速百分比加成增加 8 点，通用伤害 -30 是 -30 个百分点；经验/金币/掉落率是百分比加成，近战/远程伤害是固定数值。掉落率 +5 是把原始概率乘 1.05，例如 2%→2.1%，不是加到 7%。利率 +1.5% 是 5%→6.5%，不是 5%×1.015。多处 description 和属性抽屉只显示裸数字，建议标单位。[属性定义:142](D:/project/useless/resources/infinite-build-dome-survival/scripts/data/stat_definitions.gd:142)、[掉落概率:28](D:/project/useless/resources/infinite-build-dome-survival/scripts/rewards/drop_reward_system.gd:28)、[抽屉格式:1043](D:/project/useless/resources/infinite-build-dome-survival/scripts/ui/battle_hud.gd:1043)。
- [ ] **S07 控制强度、幸运的通用解释比当前消费范围更宽。** 阻滞配重石确实增加 control_power 6，但当前主要被闪电链的跳跃次数公式消费；冰/水减速倍率没有读取它。幸运确实影响商店品质权重和升级门槛，敌人掉落概率只读取 drop_rate_percent，随机掉落遗物也未按幸运加权。应收窄通用描述或补齐消费逻辑；不要把“属性加上了”等同于所有相关玩法都受益。[控制消费:92](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/lightning_particle_effect.gd:92)、[冰减速:71](D:/project/useless/resources/infinite-build-dome-survival/scripts/effects/ice_field_effect.gd:71)、[幸运权重:139](D:/project/useless/resources/infinite-build-dome-survival/scripts/ui/shop_offer_generator.gd:139)、[掉落抽取:192](D:/project/useless/resources/infinite-build-dome-survival/scripts/rewards/drop_reward_system.gd:192)。
- [ ] **S08 “剩余价值”目前只有归属，没有套装奖励。** 医疗、福利、年假、薪酬四件均正确关联 `bond_surplus_value`，但 thresholds 为空。原清单只指定羁绊名称，未指定奖励，所以不算数值冲突；若希望凑齐后有额外效果，还没有实现。[羁绊配置:142](D:/project/useless/resources/infinite-build-dome-survival/data_config/bonds.json:142)。

另外已核实的统一规则：负回血抵扣正回血，净值为负时不会自动掉血；利息与铸造机赠送本金向上取整；本金/侵蚀/移速派生按 `floor` 取整；无影胫甲按总移速计算而非仅遗物新增移速；迷途者胫环低理智时是取消自身 +12，净加成为 0；代价生命之种的侵蚀 +20 绑定任意复活事件，持有期间其他来源复活也会触发。以上是代码边界说明，不单独认定为错误。

**E. 72 件逐项核对表**

“一致”表示该遗物自身的常规效果、配置和描述未发现独立差异，并不代表所有跨遗物组合都已穷举。所有条目共同受到 R07 等全量重建问题的影响；涉及最大生命或理智的条目在下表额外提示。D/R/U/S 编号对应前面的待办。

**财务类（22件）**

| 序号 | 遗物 / 原清单 | 当前配置与游戏说明 | 检查结论 |
|---|---|---|---|
| 01 | [猪猪存钱罐](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:3) | 每波开始自动本金 + 15（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:3)） | 一致；波初免费本金 15×持有数，准备阶段获取后等下次开波。 |
| 02 | [理财经理](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:4) | 利率 + 1.5%（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:23)） | 一致；利率加 1.5 个百分点/件。 |
| 03 | [分红支票](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:5) | 每次结算利息的时候有20%的概率翻倍（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:47)） | 数值/逻辑一致；20% 一次抽取，N件倍率 N+1；游戏漏写叠加规则 S05。 |
| 04 | [定期存单](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:6) | 本金立刻 + （50*波次）（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:66)） | 一致；获取时免费增加 50×当前波号，波号最小按1计；不会重新发放旧件获取奖励。 |
| 05 | [传单广告](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:7) | 商店折扣 + 8%（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:86)） | 价格逻辑一致，叠加倍率 0.92^N；上限3；属性抽屉 U02。 |
| 06 | [钢铁保险柜](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:8) | 每 50 本金 +1 护甲（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:110)） | 派生一致：floor(本金/50)×件数；动态预览缺失 U03。 |
| 07 | [量化操盘](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:9) | 每 50 本金 +1 攻速（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:131)） | 派生一致：floor(本金/50)×件数；动态预览缺失 U03；+1攻速是百分比属性点。 |
| 08 | [恶意收购](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:10) | 每 100 本金提供通用伤害加成 + 1%（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:152)） | 派生一致：floor(本金/100)×件数；动态预览缺失 U03。 |
| 09 | [吸金罗盘](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:11) | 拾取范围 +40；金币获取 +5%（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:173)） | 静态值一致；低额金币收益取整 R12。 |
| 10 | [小费托盘](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:12) | 击杀敌人时 10% 概率额外掉落 1 经验球（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:207)） | 单件一致；叠加一次10%生成一颗N值球，且带金币，见 S04。 |
| 11 | [复利宝典](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:13) | 每成功结算一次利息，利率 + 0.2%（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:227)） | 普通波末/周期结息有效，年金/手动漏触发 R05；属性抽屉利率 U01。 |
| 12 | [高利契约](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:14) | 利率 + 4%；但是每波结束时，若你回合开始前未存入本金（至少50），则当前回合结束时无法收获利息（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:246)） | 静态+4、手动存50条件已接入；年金绕过限制 R04。免费赠送本金不计门槛。 |
| 13 | [并购重组](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:15) | 负载上限 + 10；每 500 本金再 + 5（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:276)） | 运行一致：10+floor(本金/500)×5；上限1；预览只显示+10，见 U03。 |
| 14 | [周期分红钟](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:16) | 每经过 3 波，额外触发一次利息结算（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:308)） | 波次口径 S02：整局第3/6/9…波，每件追加一次，非持有满3波。 |
| 15 | [医疗削减方案](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:17) | 获得时：本金 +150；利率 +2%；回血 -0.5；血包恢复量 -1（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:327)） | 自身数值一致；血包加成可负、最终治疗最低0；剩余价值暂无阈值 S08。 |
| 16 | [福利削减方案](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:18) | 获得时：本金 +150；利率 +2%；最大生命值 -5；护甲 - 10（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:380)） | 自身数值一致；剩余价值暂无阈值 S08；全量重建生命副作用 R07。 |
| 17 | [年假削减方案](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:19) | 获得时：本金 +100；利率 +2%；攻击速度 -12（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:433)） | 自身数值一致；攻速-12是百分比属性点；剩余价值暂无阈值 S08。 |
| 18 | [薪酬调整方案](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:20) | 获得时：本金 +100；利率 +2%；金币获取 -20%；商店价格 +20%（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:476)） | 本金/利率一致，涨价逐层×1.2；金币惩罚取整 R12，折扣面板 U02；S08。 |
| 19 | [神性融合](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:21) | 每 5 侵蚀度提供利率 + 0.5%；每波开始时侵蚀度 + 1（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:529)） | 波初侵蚀+1按件叠加；派生公式正确但侵蚀变化后刷新滞后 R11；预览 U03。 |
| 20 | [哥布林金币铸造机](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:22) | 利率 + 5%；每波开始自动注入你当前持有金币 10% 的免费本金（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:554)） | 一致；波初赠 ceil(持有金币×10%)，不扣金币；利率+5，上限1。 |
| 21 | [永续年金卷轴](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:23) | 每个回合结息次数 + 1（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:585)） | 每件每波追加一次确实生效；与高利契约/复利宝典组合 R04/R05。 |
| 22 | [破产重组](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:24) | 本金归零时触发：立即获得当前金币 ×2 的本金，并获得复活次数 + 1（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:603)） | 触发赠款×2及复活+1已接入；隐藏“本局仅一次”限制 S01。 |

**生存类（23件）**

| 序号 | 遗物 / 原清单 | 当前配置与游戏说明 | 检查结论 |
|---|---|---|---|
| 23 | [磨损的止血布条](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:29) | 最大生命值 + 3（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:622)） | 静态+3一致；满血后刷新丢当前生命 R07。 |
| 24 | [负重铁皮护腕](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:30) | 护甲 + 8；移动速度 - 5（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:636)） | 一致；护甲+8、移速-5。 |
| 25 | [刺鼻香包](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:31) | 每秒回血 + 0.2；理智值 + 1（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:651)） | 单独持有一致；与蜡烛组合已有理智加成被移除 R08。 |
| 26 | [残破晶石](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:32) | 生命值低于 50% 时，护甲 + 25（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:666)） | 条件与+25一致，严格低于50%才生效；购买预览不计算条件 U03。 |
| 27 | [生命力药瓶](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:33) | 每秒回血 + 1；每波过后，侵蚀度 + 1（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:680)） | 文档回血+0.5，配置/实值+1，D01；波末侵蚀每件+1正确。 |
| 28 | [死寂护盾徽章](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:34) | 战斗开局生成 10 点护盾（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:696)） | 每波开始每件+10，非获取即发；“开局”口径 S03。 |
| 29 | [龟壳吊坠](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:35) | 护甲 + 10；最大生命值 + 1（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:712)） | 文档最大生命+2，配置/实值+1，D02；另受 R07 影响。 |
| 30 | [监狱铜制脚环](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:36) | 最大生命值 + 3；移动速度 + 10；理智值 - 5（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:727)） | 自身数值一致；生命刷新问题 R07。 |
| 31 | [黄铜怀表](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:37) | 护甲 + 8；理智值 + 2（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:743)） | 单独持有一致；与蜡烛组合 R08。 |
| 32 | [血肉肩甲](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:38) | 最大生命值 + 5、护甲 + 15；每秒回血 - 0.2；侵蚀度 + 2；理智值 - 2（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:758)） | 自身五项数值一致；负回血仅抵扣；生命刷新问题 R07。 |
| 33 | [梦魇治愈圣壶](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:39) | 每秒回血 + 0.5；每波过后，理智值 - 1（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:776)） | 一致；回血+0.5，波末理智每件-1。 |
| 34 | [屏障结晶](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:40) | 每两秒生成 1 点护盾；侵蚀度 + 5（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:792)） | 一致；shield_regen=0.5，累计2秒发1盾；多件累加速率，侵蚀+5。 |
| 35 | [密教圣盾](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:41) | 护甲 + 20；侵蚀度 + 5（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:807)） | 一致；护甲+20、侵蚀+5。 |
| 36 | [迷途者胫环](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:42) | 护甲 + 8；移动速度 + 12；理智值低于 60 后，移动速度 - 12（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:822)） | 单独低理智时净移速加成0；与石雕组合顺序 R10，预览 U03。 |
| 37 | [守魂人面石雕](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:43) | 生命值 + 5；侵蚀度每有一点，理智值也获得同等数值（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:839)） | 单独按侵蚀派生理智正确；蜡烛绕过 R09、组合顺序 R10、预览 U03、生命 R07。 |
| 38 | [苦痛祭皿](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:44) | 每秒回血 + 0.8；最大生命值 - 1；理智值 - 3（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:855)） | 自身数值一致；每秒回血+0.8，最大生命-1按属性下限处理。 |
| 39 | [真银护甲](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:45) | 最大生命值 + 10；护甲 + 5；理智值 + 2（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:871)） | 文档“生命+10”实现为最大生命+10；理智与蜡烛 R08，生命刷新 R07。 |
| 40 | [圣质银杯](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:46) | 每秒回血 + 3；利率 - 1%（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:887)） | 一致；回血+3，利率减1个百分点，最终利率最低0。 |
| 41 | [受难甲壳](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:47) | 最大生命值 + 12；护甲 + 8；移动速度 - 15（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:902)） | 文档“生命+12”实现为最大生命+12；生命刷新 R07。 |
| 42 | [代价生命之种](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:48) | 每秒回血 + 1；复活次数 + 1；复活之后侵蚀度 + 20（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:918)） | 回血/复活/侵蚀字段一致，任意复活后+20；次数消耗被刷新恢复 R06。 |
| 43 | [无影遁形胫甲](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:49) | 移动速度 + 32；每10点移速提供护甲+1（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:935)） | 移速+32、floor(总移速/10)护甲正确；动态依赖顺序风险 R10，预览 U03。 |
| 44 | [苦难前行之枷锁](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:50) | 护甲 + 15；每点侵蚀度提供 1 点护甲（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:951)） | 自身一致：护甲15+floor(侵蚀)，按件叠加；派生预览 U03。 |
| 45 | [虚空触手](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:51) | 开局护盾 + 20；每秒护盾 + 1；且护盾被击碎时恢复 3 生命值并增加 1 点侵蚀度（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:967)） | 波初20盾、每秒1盾、破盾回复3/侵蚀+1已接入；波初口径 S03，护盾持续生成无上限。 |

**战斗类（15件）**

| 序号 | 遗物 / 原清单 | 当前配置与游戏说明 | 检查结论 |
|---|---|---|---|
| 46 | [磨损格斗拳套](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:56) | 近战伤害 + 1；护甲 - 3（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:986)） | 近战收益无消费者 R01，护甲-3生效。 |
| 47 | [裂痕石子弹](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:57) | 远程伤害 + 1；拾取范围 - 10（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1001)） | 一致；远程+1实际进入伤害，拾取半径-10。 |
| 48 | [急促弹簧扳机](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:58) | 攻击速度 + 8；移动速度 - 5（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1016)） | 一致；攻速+8、移速-5。 |
| 49 | [粗糙研磨透镜](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:59) | 暴击几率 + 3；暴击伤害 + 10（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1031)） | 一致；暴击率+3个百分点，暴击倍率+10个百分点。 |
| 50 | [阻滞配重石](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:60) | 控制强度 + 6（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1046)） | 属性+6一致；当前控制强度主要作用于闪电链跳数，见 S07。 |
| 51 | [嗜血皮带](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:61) | 近战伤害 + 3；每秒回血 - 0.5（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1060)） | 近战收益无消费者 R01；回血-0.5抵扣正回血。 |
| 52 | [毒雾投囊](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:62) | 远程伤害 + 3；每秒回血 - 0.5（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1075)） | 一致；远程+3，回血-0.5抵扣正回血。 |
| 53 | [震颤握柄](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:63) | 攻击速度 + 18；通用伤害 - 5（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1090)） | 一致；攻速+18、通用伤害-5个百分点。 |
| 54 | [黑斑鹰眼水晶](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:64) | 暴击几率 + 7（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1105)） | 一致；暴击率+7个百分点，最终暴击率上限100。 |
| 55 | [狂战士铜质徽章](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:65) | 近战伤害 + 8；护甲 - 10（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1119)） | 近战收益无消费者 R01；护甲-10生效。 |
| 56 | [蚀腐吹管](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:66) | 远程伤害 + 6；最大生命 - 3（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1134)） | 自身一致；远程+6、最大生命-3。 |
| 57 | [疾风轮盘](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:67) | 攻击速度 + 30；近战伤害 - 2；远程伤害 - 2（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1149)） | 攻速+30生效；近战未使用 R01，远程-2在零加成时被截掉 R03。 |
| 58 | [屠戮者臂铠](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:68) | 近战伤害 + 10；移速 - 20（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1165)） | 近战收益无消费者 R01；移速-20生效。 |
| 59 | [裁决之眼吊坠](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:69) | 暴击几率 + 12、暴击伤害 + 35；通用伤害 - 12（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1180)） | 一致；暴击率+12、暴击伤害+35、通用伤害-12均为百分比属性点。 |
| 60 | [分裂晶石弹头](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:70) | 投射物数量 + 1；通用伤害 - 30（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1196)） | 属性+1/-30一致；等离子炮零散射时不多发子弹 R02。 |

**成长/理智/侵蚀类（12件）**

| 序号 | 遗物 / 原清单 | 当前配置与游戏说明 | 检查结论 |
|---|---|---|---|
| 61 | [淘金者的手套](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:76) | 拾取范围 + 10；经验获取 + 8（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1211)） | 静态值一致；小额经验收益取整 R12。 |
| 62 | [残缺的占卜骰子](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:77) | 幸运 + 9；掉落率 + 5（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1226)） | 幸运6→9，D03；掉落率+5是相对概率加成，S06；幸运范围 S07。 |
| 63 | [商旅账本](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:78) | 金币获取 + 10；获取时本金 + 20；负载 - 5（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1241)） | 自身静态/获取本金正确；低额金币收益 R12；“负载-5”实际为负载上限-5。 |
| 64 | [被亵渎的祈福铜钱](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:79) | 幸运 + 18；理智值 - 3（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1258)） | 幸运12→18，D04；理智-3正确。 |
| 65 | [扩容背包束带](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:80) | 负载 + 10；移动速度 - 12；拾取范围 - 10（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1273)） | 一致；“负载+10”实际为负载上限+10，移速-12、拾取-10。 |
| 66 | [观星者的镜片](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:81) | 幸运 + 12；经验获取 + 12；掉落率 + 12；理智值 - 5（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1289)） | 四项静态值一致；低额经验收益 R12；掉落率/幸运口径 S06/S07。 |
| 67 | [丰收的牺牲祭器](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:82) | 金币获取 + 10；经验获取 + 10；最大生命值 - 5（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1306)） | 自身静态值一致；低额经验/金币收益 R12。 |
| 68 | [人性护符](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:83) | 理智值 + 10；幸运 - 5（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1322)） | 单独持有属性一致，幸运最低0；蜡烛移除旧加成 R08、购买预览 U03。 |
| 69 | [馈赠印记](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:84) | 幸运 + 42；侵蚀度 + 10（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1337)） | 幸运28→42，D05；侵蚀+10正确。 |
| 70 | [虚空收纳匣](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:85) | 幸运 + 18；负载 + 10；拾取范围 + 10；侵蚀度 + 10（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1352)） | 幸运12→18，D06；负载上限/拾取/侵蚀三项一致。 |
| 71 | [轮回业火之烛](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:86) | 幸运 + 75；经验获取 + 35；理智值无法再回复；侵蚀度每波 + 1（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1369)） | 幸运50→75，D07；理智禁止增长存在 R08/R09；经验收益 R12；侵蚀按波末+1。 |
| 72 | [守心铜鉴](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md:87) | 幸运 + 18；理智值每波 + 1；金币获取 + 35（[配置](D:/project/useless/resources/infinite-build-dome-survival/data_config/relics.json:1387)） | 幸运12→18，D08；波末理智+1会被蜡烛拦截；低额金币收益 R12。 |

**F. 验证记录与限制**

- [x] 使用已解析桌面快捷方式目标的 Godot 4.7.2，在独立项目副本运行；副本使用 `CodexRelicAudit20260922` 独立用户目录。
- [x] Headless editor 导入/解析检查完成，最终运行没有 Parse/Compile/SCRIPT ERROR。初次副本漏复制 shaders 导致的资源错误已通过补齐副本消除，不计入项目缺陷。
- [x] 专项审计：72 件单件静态属性、7 件持有上限以及本文所述组合复现完成；日志结尾 `AUDIT COMPLETE unexpected=0`。`CONFIRMED` 的含义是“确认了被测试的当前行为”，其中包括已确认的错误行为，不是说游戏全部正确。
- [x] 原有 Bootstrap 自检输出 `data self-test passed`，配置验证 warnings=0/errors=0。该自检仍有重复装备的预期拒绝警告，以及退出时 4 个 ObjectDB 实例、2 个资源未释放的清理警告/错误；不能宣称全程日志完全无错误。这些退出清理信息不影响上述独立审计的复现结果。
- [x] 检查文档按 UTF-8 保存，并校验无替换字符、连续问号乱码和无效源码链接。
- [ ] 未逐一人工观看游戏窗口或图标；展示结论基于当前 UI 数据源、格式化代码和预览函数运行结果。
- [ ] 未穷举所有堆叠数量、全部获取顺序和其他系统的任意组合；“无独立差异”不作这类保证。

复现与验证日志：[专项审计记录](D:/project/useless/resources/infinite-build-dome-survival/artifacts/relic_audit_20260922/audit_engine.log)、[Bootstrap 记录](D:/project/useless/resources/infinite-build-dome-survival/artifacts/relic_audit_20260922/bootstrap_engine.log)、[最终编辑器检查](D:/project/useless/resources/infinite-build-dome-survival/artifacts/relic_audit_20260922/editor_engine.log)。

**建议执行顺序**：先处理 R06/R07 的全量重建副作用，再处理 R01/R02/R04/R12 的收益问题，随后统一理智与派生计算（R08—R11）、结息来源（R05）、预览与面板（U01—U03），最后按确定的策划基准统一 D01—D08 和 S01—S08 文案。
