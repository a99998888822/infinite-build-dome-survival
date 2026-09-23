**遗物效果修复与验收 · 2026-09-23**

按用户最新确认实施。数值以当前 [augmentations_list.md](D:/project/useless/resources/infinite-build-dome-survival/augmentations_list.md) 为基准；本次未改写该设计清单。

**设计结论**

- [x] 生命之种：保留复活次数耗尽后，通过获取其他遗物/刷新遗物修饰器补回复活次数的行为，作为明确的设计规则加入回归测试。
- [x] 近战伤害：现有两把远程武器继续只吃远程加成；未将近战加成强行计入远程伤害。
- [x] 高利契约：未满足波前手动存款门槛时，阻止该波末的普通、周期分红和年金追加结息。手动结息入口不属于波末限制。
- [x] 复利宝典：每次实际获得正利息都增加利率，包括年金、周期分红、普通波末和手动结息；失败或零收益不增长。
- [x] 蜡烛：保留获取之前已经存在的理智加成；禁止之后的新理智收益，包含石雕派生增长；已降低的石雕收益也不能重新增长恢复。

**数值同步**

用户更新 MD 后，原 8 项差异中的 6 项已经对齐；新一轮核对只需修改下面 3 件。每件同时调整 `effects` 与 `description`，无需在代码里重复硬编码遗物数值。

| 遗物 | 修改前配置 | 最新 MD / 修改后配置 |
|---|---|---|
| 生命力药瓶 | 每秒回血 +1 | 每秒回血 +0.5 |
| 龟壳吊坠 | 最大生命 +1 | 最大生命 +2 |
| 观星者的镜片 | 幸运 +12 | 幸运 +18 |

- [x] 重新扫描全部 72 条：原清单与配置描述的有符号数值序列一致。
- [x] 三件更改均通过真实获取后的属性断言。

**运行与展示修复**

| 已完成 | 审计编号 | 行为与验收结果 |
|---|---|---|
| ☑ | R07 | 遗物重建期间推迟生命值截断和动态计算，完成后按最终生命上限校正。止血布条满血13，获取存钱罐后仍13/13；受伤时不额外回血；福利削减真实降低上限时仍正确截断。复活次数刷新规则保持原行为。 |
| ☑ | R02 | 零散射角也为每颗投射物生成一个角度。默认武器与等离子炮在投射物数1/2/3时，都生成对应数量的发射角。 |
| ☑ | R04 / R05 | 门槛0/49/50三种情况覆盖普通、周期和两次年金共4次结息：不足50全部拦截，达到50全部成功，宝典增加0.8个百分点。 |
| ☑ | R08 / R09 | 原有人性护符理智110，获取蜡烛后仍110；新护符、守心铜鉴波末增长和新增石雕收益被拦截。旧石雕收益保留，但不能随侵蚀上涨继续增加。 |
| ☑ | R10 | 按属性依赖顺序计算动态效果。石雕→理智、胫环→移速、无影胫甲→护甲均在依赖数据完成后计算；已验证三种不同获取顺序得到同样结果。 |
| ☑ | R11 | 财务系统监听最终属性更新，实时重算侵蚀派生利率。侵蚀0→5后利率立即5%→5.5%，本金1000的首次结息为55；破盾增长跨过阈值也立即生效。 |
| ☑ | R12 | 经验和金币各自保留小数余量，跨波延续、新局重置。100颗基础值1的球，在+8%经验/+5%金币时合计108经验/105金币；净-15%金币时合计85。 |
| ☑ | U01 | 属性抽屉与财务弹窗使用同一有效利率，计入宝典累计成长与神性融合派生。 |
| ☑ | U02 | 属性抽屉显示乘算后的有效折扣；两件传单广告显示15.36%，原价10000实际价格8464。折扣与涨价混合时可显示小数负折扣。 |
| ☑ | U03 | 购买预览在脱离场景树的玩家/财务副本上执行真实获取流程，覆盖静态、条件、派生、理智限制、羁绊及获取即发的本金。付费预览使用扣除价格后的金币，免费奖励按免费处理。不会消耗真实金币或改变真实玩家与随机数状态。 |

实现入口：[玩家属性与动态效果](D:/project/useless/resources/infinite-build-dome-survival/scripts/player/player_controller.gd)、[遗物重建](D:/project/useless/resources/infinite-build-dome-survival/scripts/relics/relic_bond_system.gd)、[财务结息](D:/project/useless/resources/infinite-build-dome-survival/scripts/rewards/battle_finance_system.gd)、[收益累计](D:/project/useless/resources/infinite-build-dome-survival/scripts/waves/wave_manager.gd)、[投射物](D:/project/useless/resources/infinite-build-dome-survival/scripts/weapons/weapon_instance.gd)、[购买预览](D:/project/useless/resources/infinite-build-dome-survival/scripts/ui/stat_preview_builder.gd)、[属性抽屉](D:/project/useless/resources/infinite-build-dome-survival/scripts/ui/battle_hud.gd)。

原审计 R03（疾风轮盘负数伤害的属性下限）及 S 类设计口径未在本次确认中指定调整，仍沿用现有规则；不应把本次验收理解为修改了所有历史建议。

**验证记录**

- [x] Godot 4.7.2 headless editor 最终检查通过，无 Parse / Compile / SCRIPT ERROR。
- [x] [专项回归](D:/project/useless/resources/infinite-build-dome-survival/scripts/tests/relic_consistency_test.gd)：50项检查全部通过，其中一项汇总对比72件遗物×有无蜡烛两种状态，共144次预览与真实获取；无预览副作用、无结果差异。
- [x] Bootstrap 自检通过。旧有神性融合断言已更新为即时生效，并继续验证跨波后的利率正确。
- [x] 现有 finance_preparation_test 通过，`FINANCE_PREPARATION_DONE failures=0`。该界面测试退出时仍输出 Canvas/ObjectDB/资源未释放的清理告警；功能检查和脚本执行没有失败。本次未扩展修复这些退出清理问题。
- [x] UTF-8、替换字符/连续问号乱码检查及 `git diff --check` 通过；保留修改前的行尾格式。
- [x] 全部运行测试在独立项目副本、独立用户目录 `CodexRelicFix20260923` 中执行，避免影响现有游戏进度。

日志：[专项回归](D:/project/useless/resources/infinite-build-dome-survival/artifacts/relic_fixes_20260923/relic_test.log)、[Bootstrap](D:/project/useless/resources/infinite-build-dome-survival/artifacts/relic_fixes_20260923/bootstrap.log)、[准备界面](D:/project/useless/resources/infinite-build-dome-survival/artifacts/relic_fixes_20260923/finance_preparation.log)、[最终编辑器检查](D:/project/useless/resources/infinite-build-dome-survival/artifacts/relic_fixes_20260923/editor_final.log)。

复运行命令：在隔离副本使用 Godot `--headless --path <副本目录> --scene res://scenes/tests/relic_consistency_test.tscn --quit-after 120`。测试以 `RELIC_TEST_COMPLETE checks=50 failures=0` 和退出码0为成功标志。
