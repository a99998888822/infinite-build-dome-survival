# R03：短刀连续衔接、摆锤 0.6 秒、秘仪书间隔 0.35 秒

按用户最新要求，继续在独立主动战斗审阅场景调试三把武器，分别录制 1／3／5 投射物的原速实机动图。

| 武器 | 本版节奏 | 连续攻击 |
|---|---|---|
| 营地短刀 | 起手 0.075 秒，每刀挥动 0.125 秒，末尾收刀 0.1 秒 | 只起手一次、收刀一次，中间直接反手衔接；1／3／5 刀共 0.30／0.55／0.80 秒 |
| 流星摆锤 | 每次完整动作 0.6 秒：0.13 秒前摇、0.37 秒挥击、0.10 秒收招 | 1／3／5 次共 0.6／1.8／3.0 秒 |
| 坤舆秘仪书 | 点名间隔 0.35 秒；保留首次 0.22 秒延迟和最终 0.3 秒收尾 | 3／5／7 次点名共约 1.22／1.92／2.62 秒；空阵等待另计 |

短刀保留 R02 挥刀本身的速度，去掉的是刀与刀之间的停顿。连续段不收刀、不淡出、不重新起手；前一刀终点就是下一刀起点，每刀仍独立命中。分裂追斩在主连击后连续追加，最后一次追斩才收刀，不挤进前面的主斩击。

短刀由审阅入口显式开启连续模式，默认旧主战斗调用暂不切换；摆锤使用共享运行时的新时长，秘仪书新间隔作用于主动法阵。原指示器、秘仪书原版法阵、空阵等待、重复点名、动作结束后冷却规则保留。炉灯继续使用 R02。

## 动图与复现

- [营地短刀](../../artifacts/previews/active_combat/remaining_multi_r03/weapon_camp_dagger.gif)
- [流星摆锤](../../artifacts/previews/active_combat/remaining_multi_r03/weapon_meteor_flail.gif)
- [坤舆秘仪书](../../artifacts/previews/active_combat/remaining_multi_r03/weapon_kunyu_ritual_tome.gif)

入口仍为 `scenes/tests/remaining_multi_projectile_review.tscn`。原始 GPU 帧和日志在 `tmp/multi_projectile_review/remaining_r03/`；通过私有 Windows 桌面运行，GIF 仅缩放、量化颜色并按真实物理帧时间编码。

重点检查短刀衔接处的时间、刀刃位置与透明度连续，真实伤害次数、暂停与分裂追斩，以及摆锤完整动作时长、秘仪书 350 毫秒点名间隔和动作后冷却。

## 验证记录

- 6 组、581 项无界面功能检查通过，覆盖新增连续短刀及分裂追斩、原短刀、摆锤、弹跳、秘仪书／钱袋和审阅场景。
- GPU 实机检查 560 项通过，包含 494 张截图保存；各数量档位的实际时长与本版定义一致。真实命中次数符合预期，秘仪书分别完成 3／5／7 次点名。
- 实际引擎桌面与私有桌面一致，`foreground_samples=0`；实机录制无脚本异常及资源退出提示。
- 编辑器无界面导入、默认主场景启动、UTF-8 和差异格式检查通过。部分无界面功能测试仍有退出资源提示，记录保留，不影响功能断言。
- [功能检查](../../artifacts/previews/active_combat/remaining_multi_r03/headless_checks.json)、[实机记录](../../artifacts/previews/active_combat/remaining_multi_r03/review_report.json)、[导出核验](../../artifacts/previews/active_combat/remaining_multi_r03/verification.json)。
