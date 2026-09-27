# 距离与范围遗物图标

本组10件遗物已接入正式遗物配置、商店和奖励候选池。此处只保留审阅总览；独立图标位于 `assets/ui/icons/relics/`。
原图均为32×32透明PNG，透明度仅0/255；放大请使用最近邻采样。
图标按项目既有像素绘图流程逐像素构建，绘制源文件为 `scripts/tools/source_art/range_relics.py`。
运行 `python scripts/tools/source_art/range_relics.py` 可重建原图与总览。

| 图标 | 名称 / 稀有度 | 正式配置属性 |
|---|---|---|
| [PNG](../../../assets/ui/icons/relics/relic_old_brass_telescope.png) | 旧铜望远镜 / 普通 | 攻击距离 +15，远程伤害 +1。 |
| [PNG](../../../assets/ui/icons/relics/relic_cracked_bronze_bell.png) | 裂纹铜铃 / 普通 | 伤害范围 +15，元素伤害 +1。 |
| [PNG](../../../assets/ui/icons/relics/relic_long_focus_eyepiece.png) | 长焦目镜 / 优秀 | 攻击距离 +35，远程伤害 +3，攻击速度 −8。 |
| [PNG](../../../assets/ui/icons/relics/relic_diffusion_nozzle.png) | 扩散喷口 / 优秀 | 伤害范围 +30，伤害加成 +15，攻击速度 −6。 |
| [PNG](../../../assets/ui/icons/relics/relic_range_tripod.png) | 定距脚架 / 稀有 | 攻击速度 +12；连续静止1秒后，额外攻击距离 +40、伤害加成 +20；移动立即取消额外加成。 |
| [PNG](../../../assets/ui/icons/relics/relic_aftershock_hourglass.png) | 余震沙漏 / 稀有 | 伤害范围 +20，伤害加成 +12；获得后每完成一波，伤害范围再 +2。 |
| [PNG](../../../assets/ui/icons/relics/relic_golden_rangefinder.png) | 黄金测距仪 / 史诗 | 每满100本金：攻击距离 +3、伤害加成 +3，随当前本金变化。 |
| [PNG](../../../assets/ui/icons/relics/relic_abyssal_echo_shell.png) | 深海回声螺 / 史诗 | 伤害范围 +40，元素伤害 +8，理智值 −15。 |
| [PNG](../../../assets/ui/icons/relics/relic_folded_star_chart.png) | 折叠星图 / 史诗 | 攻击距离 +25，伤害范围 +25，伤害加成 +20，侵蚀度 +5。 |
| [PNG](../../../assets/ui/icons/relics/relic_horizon_orrery.png) | 地平线星仪 / 神话 | 攻击距离 +40，伤害加成 +30；每满10点正攻击距离加成，额外伤害范围 +5。 |

白色两件各限持3件，其余各限持1件。
定距脚架仅取消静止触发的额外加成；黄金测距仪随当前本金变化；星仪包含自身攻击距离加成。
