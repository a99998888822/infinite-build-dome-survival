# 当前素材入口

本页列出正式素材的维护位置；逐件尺寸和原图裁切信息由[图标索引](icon_manifest.json)维护，规则见[素材规范](asset_rules_summary.md)。

| 内容 | 正式位置与维护方式 |
| --- | --- |
| 武器图标 | `assets/ui/icons/weapons/`，14 张主图及 1 张返程图，36×36，PNG/PXG/PAL 同步 |
| 遗物图标 | `assets/ui/icons/relics/`，101 张，36×36，PNG/PXG/PAL 同步 |
| 附魔图标 | `assets/ui/icons/augmentations/`，19 张，32×32，PNG/PXG/PAL 同步 |
| 初心者动作 | `assets/sprites/player/actions/novice_96/`，7 张图集；前后跳共用 jump |
| 其他角色与敌人 | `assets/sprites/player/`、`assets/sprites/enemies/`，按各自帧表与来源清单维护 |
| 武器与命中特效 | `assets/sprites/weapons/`、`scripts/effects/`、`shaders/effects/` |
| 地表、草簇、障碍与远景 | `assets/sprites/background/`，由当前战场配置和场景引用 |
| HUD 与理财界面 | `assets/ui/hud/`、`assets/ui/finance/`、`assets/ui/stats_drawer/` |
| 音频与字体 | `assets/audio/`、`assets/font/`，按正式播放配置及字库说明维护 |

当前显示与碰撞见[精灵规范](combat_sprite_clarity.md)，界面样式见[HUD](hud_style.md)，场景分层见[战场环境](battle_environment.md)。

完整原图、像素网格与重建入口由 `artifacts/sources/`、`artifacts/editable/` 和 [素材安装工具](../../scripts/tools/ASSET_INSTALLERS.md)管理。原始外部风格参考和地面原图保留在 `artifacts/reference/documentation_sources/`；它们不由正式场景加载。
