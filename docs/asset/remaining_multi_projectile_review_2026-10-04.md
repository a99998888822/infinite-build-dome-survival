# 其余五把武器的多投射物实机审阅

本页保留 R01 记录。后续动作节奏与炉灯火焰调整见 [R02 修订](remaining_multi_projectile_tuning_2026-10-05.md)；榴弹继续沿用本页最终规则。

2026-10-04。使用真实 GameRoot、正式武器运行节点、伤害和动画，在独立主动战斗审阅入口录制。固定高生命敌人、停止随机刷怪、关闭本组武器附魔，冷却使用审阅值；本批不代表整局数值已经平衡。

## 本次规则

| 武器 | 1／3／5 投射物 | 范围与显示 |
|---|---|---|
| 营地短刀 | 1／3／5 次完整斩击，基础总时长 0.24／0.72／1.20 秒 | 一个 130° 扇面；每次完整播放前摇、斩击与收刀，不按数量压缩。使用已存在的独立审阅调度，正式旧调度尚未迁移。 |
| 流星摆锤 | 1／3／5 次完整挥击，基础总时长 0.88／2.64／4.40 秒 | 一个 130° 扇面；左右交替，每次收招后接下一次。共享运行时已更新，分裂追击排在全部主挥击后依次完成。 |
| 赤铜炉灯 | 单束持续 1.8／5.4／9 秒 | 基础 60° 不随投射物数量展开；每个额外投射物增加基础 1.8 秒。单跳伤害、跳伤频率不因投射物数量增加。 |
| 铸铁榴弹炮 | 同时抛出 1／3／5 枚榴弹，各自独立爆炸 | 一个射程椭圆加每枚对应的爆炸椭圆；鼠标越界时限制整个落点范围。5 枚片段使用越界鼠标位置。 |
| 坤舆秘仪书 | 一个固定法阵依次点名 3／5／7 次 | 保留原版星形符阵、边缘粒子与点名爆纹；3 投射物片段只有一个存活目标，展示连续重复点名 5 次。 |

炉灯和秘仪书按数字键立即施放；炉灯片头的浅蓝扇面标注为“范围说明”，仅帮助审阅，不表示正式操作需要先瞄准。其他三把先展示指示器，释放成功后退出瞄准，全部动作结束后显示独立冷却。榴弹审阅调度已修正为飞行与爆炸动画结束后开始冷却。

实机检查还修正了榴弹越界时落点挤成一团的问题：先将瞄准中心限制到最大距离，再展开各枚落点并逐一限制边界。鼠标沿同一方向继续远离时，多个落点保持稳定，完整爆炸椭圆仍在射程内。修正后的榴弹单独补录，导出记录保留两次 GPU 运行的来源与桌面核验。

炉灯持续时间在开火时取值，喷射中属性改变不伸缩当前时长。原有移动方向跟随、静止保持上次方向、暂停冻结保留；范围属性和分裂侧火流沿用各自规则。弹跳复演同步延长炉灯寿命，并让摆锤完成整个连续挥击队列。

## 预览与复现

- [营地短刀](../../artifacts/previews/active_combat/remaining_multi_r01/weapon_camp_dagger.gif)
- [流星摆锤](../../artifacts/previews/active_combat/remaining_multi_r01/weapon_meteor_flail.gif)
- [赤铜炉灯](../../artifacts/previews/active_combat/remaining_multi_r01/weapon_copper_lamp.gif)
- [铸铁榴弹炮](../../artifacts/previews/active_combat/remaining_multi_r01/weapon_iron_grenade_cannon.gif)
- [坤舆秘仪书](../../artifacts/previews/active_combat/remaining_multi_r01/weapon_kunyu_ritual_tome.gif)

入口：`scenes/tests/remaining_multi_projectile_review.tscn`。检查加 `--art-check`，截图加 `--art-capture --capture-dir=<绝对路径>`；可追加 `--review-weapon=<武器ID>` 单独运行。使用 `--fixed-fps 60 --transient-session`。GPU 录制通过 `scripts/tools/run_godot_background.py` 的私有 Windows 桌面执行。

原始截图和日志：`tmp/multi_projectile_review/remaining_r01/`。GIF 由 `scripts/tools/encode_multi_projectile_review.py` 编码，只缩放与调色板量化；按实际物理帧时间播放，累计补偿 GIF 的 10 毫秒精度，不插值、不加速。短刀采样密度高于长喷射，完整保留所有数量档的攻击过程。

## 检查

- 8 组无界面测试共 901 项功能断言通过：攻击范围修订与新增多投射物、摆锤、三武器、弹跳、叠加附魔、附魔顺序、短刀、五武器审阅。
- 重点核对炉灯的单束角度、每跳伤害不叠加、时长快照、暂停与冷却边界；摆锤完整连续命中与收招；秘仪书准确点名预算；实际攻击时长与预期相符。
- 短刀旧用例仍要求 64 像素图标，已按项目安装的 128 像素图标修正；刀身保持 32 像素。短刀、叠加附魔原有测试退出时仍有资源未释放提示，日志保留；本轮功能断言无失败。
- 无界面编辑器加载通过；默认主场景启动退出码为 0，退出时也保留 2 项资源未释放提示。没有脚本解析、编译或运行异常。
- 两次 GPU 录制合计 1369 项检查通过（含帧保存），最终交付选取 1114 张真实帧；两次均核对引擎位于私有桌面，`foreground_samples=0`。五段时长约为短刀 4.7 秒、摆锤 11.7 秒、炉灯 21.1 秒、榴弹 6.7 秒、秘仪书 14.95 秒，均包含 1／3／5 档的片头范围说明与收尾冷却。
- [无界面检查记录](../../artifacts/previews/active_combat/remaining_multi_r01/headless_checks.json)、[实机记录](../../artifacts/previews/active_combat/remaining_multi_r01/review_report.json)、[导出核验](../../artifacts/previews/active_combat/remaining_multi_r01/verification.json)。

正式主战斗的主动输入、设置、清剿和整局数值仍按根目录方案接入。多榴弹重叠伤害、长喷射期间的走位成本，以及完整连击结束后才冷却的收益，需要在该阶段统一评估。
