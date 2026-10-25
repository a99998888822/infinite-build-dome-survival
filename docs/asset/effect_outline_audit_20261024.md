# 附魔与武器特效外框检查 · 2026-10-24

检查范围：当前配置的 19 种附魔与 14 种武器，包括配置中暂未开放的武器。核对生产脚本、地面着色器和相关图集；落雷另做实际战场录制，其他效果为源码与素材检查。

## 本次已修改：落雷

黄色椭圆来自两处显式绘制：

1. `electric_spark_effect.gd` 调用通用 `spell_ground_area`，给内部填色与外沿设置不同的颜色。着色器把外沿约 2 像素绘制成亮黄色，因此形成连续椭圆描边。
2. `lightning_particle_effect.gd::_draw_ground_impact()` 在落地后又调用 `GROUND.arc(..., 0, TAU, ...)` 绘制完整椭圆冲击环。

两处已处理：预警填色与外沿改用同一淡黄色，删除落地后的椭圆描边调用。保留黄色电火花、地面淡色填充、主雷柱、分叉与命中闪光。碰撞形状、0.5 秒蓄力和伤害时序保持原值。

## 附魔检查结果

| 附魔 | 外框情况 | 建议与定位 |
| --- | --- | --- |
| 落雷 | 原有预警描边和落地冲击环，本次均移除 | `electric_spark_effect.gd::_sync_warning`、`lightning_particle_effect.gd::_draw_ground_impact` |
| 光辉剑 | **已按用户后续要求去掉完整椭圆描边**；保留独立的分段像素落点标记 | `light_sword_effect.gd::_sync_ground_area` 的边缘色已改为填充色，蓄力与落地阶段均生效。保留小型 `sword_mark` 定位图案与落地裂纹。 |
| 结霜 | 没有单独描边，边缘与内部同色；仍有淡蓝底色 | `ice_field_effect.gd::_sync_ground_area`，符合当前要求 |
| 火焰 | 地面填色和描边均透明，由火焰形状表现范围 | `fire_patch.gd::_sync_ground_area`，无此类外框 |
| 水流 | 水体外沿有明亮浪花，部分阶段轮廓接近椭圆 | `enchantment_blocks.gdshader::water`；是随水体生长的颜色层次，不是额外范围线，建议保留 |
| 震荡 | 有向外扩张的灰白环状冲击波 | `enchantment_blocks.gdshader::shock`；这是震荡主体，建议保留 |
| 黑洞 | 球体轮廓和分段内卷气流，无完整地面范围描边 | `black_hole_effect.gd::_draw_vortex`、`enchantment_blocks.gdshader::hole` |
| 电火花 | 闪电链与接触火花，无地面椭圆外框 | `lightning_particle_effect.gd` 的链分支 |
| 风刃 | 弯曲刃体及其明暗边缘，无额外范围外框 | `enchantment_blocks.gdshader::wind` |
| 巨力、智慧、多投、领域、会心、致命、迅捷 | 数值或攻击参数修饰，没有独立外框绘制 | 附魔“领域”与下表武器的法阵是不同来源 |
| 弹跳、分裂、穿透 | 复用武器或投射物表现，没有独立范围外框 | 不额外删除武器本体或命中特效 |

## 武器检查结果

| 武器 | 环形或外框表现 | 判断 |
| --- | --- | --- |
| 裂地战锤 | 锤体、地裂、命中碎屑 | 未发现独立椭圆范围框；附魔落雷曾叠加的框已移除 |
| 木质弓箭、守夜长枪、巨型手持火炮 | 箭矢、直刺、弹丸和喷焰 | 未发现独立范围外框 |
| 电浆炮 | 球体明暗、电弧、椭圆阴影与淡光 | 阴影和光晕为填充，不是描边框 |
| 流星摆锤、营地短刀 | 摆动尾迹、扇形斩击 | 武器运动轨迹，不是额外边框 |
| 坤舆秘仪书 | **持续的椭圆点状粒子边界**，以及低透明度中心符文 | `ritual_domain.gd::_draw_domain`；表示领域范围。若要进一步降低圈感，可减少边界粒子密度，建议保留基本范围识别 |
| 移星秘典 | **分段多边形回返标记、分段环形落地冲击波** | `star_anchor.png` / `star_shockwave.png`；分别表示回返位置与冲击，建议保留 |
| 突进短刃 | **环绕的弧形斩击** | `dash_circle.png`；实体刃光，不是范围框，建议保留 |
| 铸铁榴弹炮 | 飞行期间有四点落点标记，爆炸为块状图集 | 四个点不构成连续外框 |
| 食利者钱袋、赤铜炉灯、异化触手 | 钱币与命中图案、火焰、触手本体 | 未发现独立椭圆范围描边 |

手动施法指示器也有圆形、椭圆形、扇形或多边形边界，由 `weapon_attack_indicator.gd` / `mobility_weapon_indicator.gd` 绘制，承担瞄准和可释放范围提示；与用户此前要求保留施法指示器一致，本次保留。冥狼攻击预警、角色脚下标记也未改动。

## 验证与预览

- 无界面编辑器校验通过；落雷原有 286 项时序、暂停、清理与伤害检查通过。
- 私有桌面实际战场录制通过，退出码 0，实际桌面匹配，`foreground_samples=0`。
- 人工查看 `frame_045.png`（蓄力）、`frame_074.png`（回闪）、`frame_182.png`（密集落雷），确认连续椭圆描边消失，黄色碎粒保留。
- 新预览目录：`artifacts/previews/ground_lightning_no_outline_20261024/`。视频 `ground_lightning_no_outline.mp4` 为 1920×1080、60 fps、7 秒，音效 100、背景音乐 0、无新增字幕。
- `outline_asset_audit.png` 展示光辉剑落点标记、移星回返标记、移星冲击波与突进刃光的实际图集样本。
- 光辉剑后续修改已通过无界面编辑器校验、`spell_terminal_range_test` 的 173 项检查，以及私有桌面战场运行。检查 `artifacts/previews/light_sword_no_outline_20261024/frame_045.png`（蓄力）与 `frame_090.png`（落地），确认完整椭圆外框消失；运行退出码 0、`foreground_samples=0`。
