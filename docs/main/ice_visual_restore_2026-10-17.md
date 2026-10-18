# 结霜、冻结外观恢复与雷火确认

最新状态：下述冰系修正与雷火版本均已保留为正式效果，其余获批组合反应也已默认启用。详见[正式替换清单](effects_production_install_2026-10-17.md)。下文为本轮恢复时的审阅记录。

按本轮反馈恢复原有六瓣雪花和冰壳，不继续使用此前重画的连片冰板、方形冰壳。

- 冰场和风冰扩张重新使用原始 `ice_d*`、`frost_front_d1` 图集；审阅开关也不再将它们替换成冰板。
- 受冻怪物恢复原来的 `slowed` 雪花与 `ice_shell` 冰壳图集。保留圆形/胶囊体型识别、稳定附着位置与最终像素对齐，避免重新引入动画画布导致的异常放大。
- 解冻时三颗冰晶的宽高均缩到上一版的三分之一；数量、路径、持续时间保持原值。小冰晶使用 1px 网格，保持硬边。
- 用户确认的不规则黄白雷火保留原形状，单独启用为正式效果；其余尚未确认的组合候选默认开关仍关闭。
- 保留已修正的角色动画更新及怪物自身 1/3 受击震动。

新动图：[结霜、冻结/解冻与小 Boss](D:/project/useless/review-archives/ice-art-restore-20261017/ice-restored.webp)。均为 1080p 实机的真实武器命中，仅裁切画面，没有平滑缩放。

验证：Godot headless editor 通过；像素对齐 24 项、雷火候选/正式开关 10 项、通用受击 110 项、雷火密度预算 40 项通过，无脚本或测试退出错误。四段 GPU 录制通过，包括关闭候选总开关后触发正式雷火；每段角色攻击均播放并回到待机。私有桌面核验一致，`foreground_samples=0`。

录像及状态记录：[verification.json](D:/project/useless/review-archives/ice-art-restore-20261017/verification.json)。雷火密度检查：[thunder_fire_lod_test.json](D:/project/useless/review-archives/ice-art-restore-20261017/thunder_fire_lod_test.json)。
