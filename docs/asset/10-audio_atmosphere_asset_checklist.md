# 音频与氛围表现模块素材 Checklist

本文档只记录第 10 模块实际需要的三类 BGM 和三把现有武器的命中音效。其他非必要音效、环境氛围音和稀有度提示音均不准备。

## 1. 统一音频规范

| 项目 | 约定 |
|---|---|
| 整体风格 | 清新、克制、轻微神秘，不使用脏乱、刺耳或过度恐怖的声音 |
| BGM 格式 | OGG，立体声，支持无缝循环 |
| 命中音效格式 | OGG 或 WAV，短促干净，建议不超过 1 秒 |
| 采样率 | 建议 44.1kHz |
| 命名 | 小写英文、数字和下划线，不使用空格和中文 |
| 缺失处理 | 文件不存在时静默处理，不影响战斗 |

## 2. BGM 素材

| 状态 | 素材名 | 文件名 | 最终路径 | 格式 | 内容 | 是否存在 |
|---|---|---|---|---|---|---|
| 未知 | 菜单 BGM | `bgm_menu.ogg` | `assets/audio/bgm/bgm_menu.ogg` | OGG，循环 | 角色选择和通用菜单使用，平静、清新、轻微神秘 | 未知 |
| 未知 | 营地 BGM | `bgm_camp.ogg` | `assets/audio/bgm/bgm_camp.ogg` | OGG，循环 | 森林、篝火、河流营地使用，安静舒缓 | 未知 |
| 未知 | 战斗 BGM | `bgm_battle.ogg` | `assets/audio/bgm/bgm_battle.ogg` | OGG，循环 | 普通战斗使用，节奏稳定，有轻微紧张感 | 未知 |

## 3. 武器命中音效

| 状态 | 绑定武器 | 文件名 | 最终路径 | 格式 | 内容 | 播放规则 | 是否存在 |
|---|---|---|---|---|---|---|---|
| 未知 | 小飞刃 `weapon_void_blade` | `sfx_weapon_void_blade_hit.ogg` | `assets/audio/sfx/weapons/sfx_weapon_void_blade_hit.ogg` | OGG/WAV，短音效 | 小型飞刃命中目标的轻锐金属反馈 | 每个投射物第一次命中播放一次 | 未知 |
| 未知 | 砍刀 `weapon_mutated_cleaver` | `sfx_weapon_mutated_cleaver_hit.ogg` | `assets/audio/sfx/weapons/sfx_weapon_mutated_cleaver_hit.ogg` | OGG/WAV，短音效 | 砍刀命中的短促挥砍反馈，不使用血腥撕裂声 | 每次近战攻击命中后最多播放一次 | 未知 |
| 未知 | 穹顶震波器 `weapon_dome_shockwave` | `sfx_weapon_dome_shockwave_hit.ogg` | `assets/audio/sfx/weapons/sfx_weapon_dome_shockwave_hit.ogg` | OGG/WAV，短音效 | 圆形能量震波命中的低频能量反馈 | 每次范围攻击命中后最多播放一次 | 未知 |

## 4. 明确不准备的素材

以下音效不在当前模块范围内：

1. 玩家攻击启动音效。
2. 敌人死亡音效。
3. 经验球和血包拾取音效。
4. 角色升级音效。
5. 波次开始和结束音效。
6. UI 确认、取消和错误音效。
7. 建筑升级、商店刷新和奖励获得音效。
8. 森林、河流、篝火、夜晚、低语等环境氛围音。
9. 白、绿、蓝、紫、橙、红稀有度提示音。

## 5. 放置目录

1. BGM：`assets/audio/bgm/`
2. 武器命中音效：`assets/audio/sfx/weapons/`

## 6. 状态字段说明

| 状态 | 含义 |
|---|---|
| 未知 | 尚未确认是否存在 |
| 未存在 | 已确认缺少该文件 |
| 已存在 | 文件已放入目标路径，等待 Godot 导入验证 |
| 已接入 | 已在武器配置和代码中使用 |
| 需重出 | 文件格式、时长、音质或循环不符合约定 |
