# 基础数值模块素材清单

本文档用于跟踪“基础数值与数据配置模块”相关的最小素材需求。当前项目尚未创建 `assets/` 目录，因此所有素材的“是否存在”暂标为“否”。后续生成素材并放入对应路径后，可只更新“是否存在”字段。

## 字段说明

| 字段 | 说明 |
| ---- | ---- |
| 模块 | 使用该素材的主要模块 |
| 素材ID | 稳定素材标识，建议与配置表引用保持一致 |
| 建议路径 | 建议放置到 Godot 项目内的资源路径 |
| 类型 | 精灵图、图标、音频、背景图、字体等 |
| 格式 | 推荐文件格式；未知时标为“未知” |
| 内容 | 素材应该表达的内容 |
| 是否必需 | MVP是否必须准备 |
| 是否存在 | 当前项目内是否已存在该文件 |
| 备注 | 生成或使用建议 |

## 1. 基础占位素材

| 模块 | 素材ID | 建议路径 | 类型 | 格式 | 内容 | 是否必需 | 是否存在 | 备注 |
| ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| 基础数据/UI兜底 | `placeholder_icon` | `res://assets/ui/icons/placeholder_icon.png` | 图标 | PNG | 通用未知图标，占位用问号/虚空符号 | 是 | 是 | 所有未配置图标的兜底资源 |
| 基础数据/UI兜底 | `placeholder_sprite` | `res://assets/sprites/placeholder/placeholder_sprite.png` | 精灵图 | PNG | 通用实体占位，32x32或48x48像素 | 否 | 否 | 角色/敌人/召唤物临时占位 |
| 基础数据/UI兜底 | `placeholder_projectile` | `res://assets/sprites/placeholder/placeholder_projectile.png` | 精灵图 | PNG | 通用投射物占位，建议16x16像素 | 否 | 否 | 武器投射物临时占位 |
| 基础数据/UI兜底 | `placeholder_panel_bg` | `res://assets/ui/panels/placeholder_panel_bg.png` | UI背景 | PNG | 简单深色半透明面板背景 | 否 | 否 | 调试面板/弹窗可先用Godot默认StyleBox替代 |

## 2. 属性图标素材

| 模块 | 素材ID | 建议路径 | 类型 | 格式 | 内容 | 是否必需 | 是否存在 | 备注 |
| ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| 基础属性/UI | `stat_icon_max_hp` | `res://assets/ui/icons/stats/stat_max_hp.png` | 图标 | PNG | 最大生命图标，心脏/生命容器 | 建议 | 否 | 用于属性调试、角色面板 |
| 基础属性/UI | `stat_icon_hp_regen` | `res://assets/ui/icons/stats/stat_hp_regen.png` | 图标 | PNG | 生命恢复图标，绿色恢复符号 | 可选 | 否 | 可暂用生命图标代替 |
| 基础属性/UI | `stat_icon_shield` | `res://assets/ui/icons/stats/stat_shield.png` | 图标 | PNG | 护盾图标 | 可选 | 否 | 后续HUD/营地升级项使用 |
| 基础属性/UI | `stat_icon_armor` | `res://assets/ui/icons/stats/stat_armor.png` | 图标 | PNG | 护甲图标，甲片/护符 | 建议 | 否 | 用于生存属性与减伤显示 |
| 基础属性/UI | `stat_icon_damage_taken` | `res://assets/ui/icons/stats/stat_damage_taken.png` | 图标 | PNG | 受到伤害百分比图标，破盾/受击 | 可选 | 否 | 可暂用护甲图标代替 |
| 基础属性/UI | `stat_icon_move_speed` | `res://assets/ui/icons/stats/stat_move_speed.png` | 图标 | PNG | 移速图标，靴子/风线 | 建议 | 否 | 用于角色与营地升级项显示 |
| 基础属性/UI | `stat_icon_melee_damage` | `res://assets/ui/icons/stats/stat_melee_damage.png` | 图标 | PNG | 近战伤害图标，剑刃/爪痕 | 建议 | 否 | 近战武器、遗物、modifier调试通用 |
| 基础属性/UI | `stat_icon_ranged_damage` | `res://assets/ui/icons/stats/stat_ranged_damage.png` | 图标 | PNG | 远程伤害图标，飞弹/弩箭 | 建议 | 否 | 远程武器、投射物、modifier调试通用 |
| 基础属性/UI | `stat_icon_summon_damage` | `res://assets/ui/icons/stats/stat_summon_damage.png` | 图标 | PNG | 眷族伤害图标，仆从爪印/外神印记 | 可选 | 否 | 召唤物与眷族模块后续使用 |
| 基础属性/UI | `stat_icon_damage_percent` | `res://assets/ui/icons/stats/stat_damage_percent.png` | 图标 | PNG | 通用伤害加成图标，裂痕/爆发 | 建议 | 否 | 通用百分比伤害加成显示 |
| 基础属性/UI | `stat_icon_attack_speed` | `res://assets/ui/icons/stats/stat_attack_speed.png` | 图标 | PNG | 攻速图标，快速刀痕/沙漏 | 可选 | 否 | 可暂用伤害图标代替 |
| 基础属性/UI | `stat_icon_cooldown` | `res://assets/ui/icons/stats/stat_cooldown.png` | 图标 | PNG | 冷却缩减图标，时钟/回转箭头 | 可选 | 否 | 武器升级显示用 |
| 基础属性/UI | `stat_icon_crit_chance` | `res://assets/ui/icons/stats/stat_crit_chance.png` | 图标 | PNG | 暴击率图标，爆裂星芒 | 可选 | 否 | 可与暴击伤害共用 |
| 基础属性/UI | `stat_icon_crit_damage` | `res://assets/ui/icons/stats/stat_crit_damage.png` | 图标 | PNG | 暴击伤害图标，破碎星芒 | 可选 | 否 | 可暂空 |
| 基础属性/UI | `stat_icon_projectile_count` | `res://assets/ui/icons/stats/stat_projectile_count.png` | 图标 | PNG | 投射物数量图标，多枚弹体 | 可选 | 否 | 武器面板使用 |
| 基础属性/UI | `stat_icon_pierce_count` | `res://assets/ui/icons/stats/stat_pierce_count.png` | 图标 | PNG | 穿透图标，箭穿多个目标 | 可选 | 否 | 武器升级显示用 |
| 基础属性/UI | `stat_icon_area_size` | `res://assets/ui/icons/stats/stat_area_size.png` | 图标 | PNG | 范围图标，扩散圆环 | 建议 | 否 | 羁绊/武器范围效果常用 |
| 基础属性/UI | `stat_icon_control_power` | `res://assets/ui/icons/stats/stat_control_power.png` | 图标 | PNG | 控制强度图标，束缚符文/锁链 | 可选 | 否 | 替代异常状态触发概率 |
| 基础属性/UI | `stat_icon_pickup_radius` | `res://assets/ui/icons/stats/stat_pickup_radius.png` | 图标 | PNG | 拾取范围图标，磁铁/吸附 | 建议 | 否 | Roguelite常用属性 |
| 基础属性/UI | `stat_icon_exp_gain` | `res://assets/ui/icons/stats/stat_exp_gain.png` | 图标 | PNG | 经验获取加成图标，星点/晶体 | 建议 | 否 | 营地常用 |
| 基础属性/UI | `stat_icon_drop_rate` | `res://assets/ui/icons/stats/stat_drop_rate.png` | 图标 | PNG | 掉落率图标，宝袋/光点 | 可选 | 否 | 后续掉落模块使用 |
| 基础属性/UI | `stat_icon_luck` | `res://assets/ui/icons/stats/stat_luck.png` | 图标 | PNG | 幸运图标，幸运星/棱晶 | 建议 | 否 | 用于幸运属性显示 |
| 基础属性/UI | `stat_icon_currency_gain` | `res://assets/ui/icons/stats/stat_currency_gain.png` | 图标 | PNG | 货币获取图标，星币/残片 | 可选 | 否 | 局外奖励显示 |
| 基础属性/UI | `stat_icon_load_capacity` | `res://assets/ui/icons/stats/stat_load_capacity.png` | 图标 | PNG | 负载上限图标，机械核心/重量 | 是 | 否 | 核心武器负载系统必备 |
| 基础属性/UI | `stat_icon_summon_count` | `res://assets/ui/icons/stats/stat_summon_count.png` | 图标 | PNG | 召唤数量图标，小型仆从群 | 可选 | 否 | 召唤物模块后续使用 |
| 基础属性/UI | `stat_icon_humanity` | `res://assets/ui/icons/stats/stat_humanity.png` | 图标 | PNG | 理智值/人性图标，烛火/人形轮廓 | 可选 | 否 | 精神/外神属性显示 |
| 基础属性/UI | `stat_icon_divinity` | `res://assets/ui/icons/stats/stat_divinity.png` | 图标 | PNG | 侵蚀度/神性图标，外神眼/虚空晶核 | 可选 | 否 | 精神/外神属性显示 |

## 3. 配置类型图标素材

| 模块 | 素材ID | 建议路径 | 类型 | 格式 | 内容 | 是否必需 | 是否存在 | 备注 |
| ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| DataRegistry/调试UI | `config_icon_weapon` | `res://assets/ui/icons/config/config_weapon.png` | 图标 | PNG | 武器配置类型图标 | 可选 | 否 | 调试配置浏览器使用 |
| DataRegistry/调试UI | `config_icon_relic` | `res://assets/ui/icons/config/config_relic.png` | 图标 | PNG | 遗物配置类型图标 | 可选 | 否 | 可暂用placeholder |
| DataRegistry/调试UI | `config_icon_bond` | `res://assets/ui/icons/config/config_bond.png` | 图标 | PNG | 羁绊配置类型图标 | 可选 | 否 | 可暂用placeholder |
| DataRegistry/调试UI | `config_icon_character` | `res://assets/ui/icons/config/config_character.png` | 图标 | PNG | 角色配置类型图标 | 可选 | 否 | 可暂用placeholder |
| DataRegistry/调试UI | `config_icon_enemy` | `res://assets/ui/icons/config/config_enemy.png` | 图标 | PNG | 敌人配置类型图标 | 可选 | 否 | 可暂用placeholder |
| DataRegistry/调试UI | `config_icon_camp` | `res://assets/ui/icons/config/config_camp.png` | 图标 | PNG | 营地建筑配置类型图标 | 可选 | 否 | 可暂用placeholder |
| DataRegistry/调试UI | `config_icon_wave` | `res://assets/ui/icons/config/config_wave.png` | 图标 | PNG | 波次配置类型图标 | 可选 | 否 | 可暂用placeholder |
| DataRegistry/调试UI | `config_icon_drop_table` | `res://assets/ui/icons/config/config_drop_table.png` | 图标 | PNG | 掉落表配置类型图标 | 可选 | 否 | 可暂用placeholder |
| DataRegistry/调试UI | `config_icon_modifier` | `res://assets/ui/icons/config/config_modifier.png` | 图标 | PNG | modifier配置/效果图标 | 可选 | 否 | modifier来源查看使用 |

## 4. 调试面板UI素材

| 模块 | 素材ID | 建议路径 | 类型 | 格式 | 内容 | 是否必需 | 是否存在 | 备注 |
| ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| 调试UI | `debug_panel_bg` | `res://assets/ui/debug/debug_panel_bg.png` | UI背景 | PNG | 半透明深色调试面板背景 | 可选 | 否 | 可用Godot StyleBoxFlat替代 |
| 调试UI | `debug_button_normal` | `res://assets/ui/debug/debug_button_normal.png` | UI按钮 | PNG | 调试按钮普通态 | 可选 | 否 | 可暂空 |
| 调试UI | `debug_button_hover` | `res://assets/ui/debug/debug_button_hover.png` | UI按钮 | PNG | 调试按钮悬停态 | 可选 | 否 | 可暂空 |
| 调试UI | `debug_button_pressed` | `res://assets/ui/debug/debug_button_pressed.png` | UI按钮 | PNG | 调试按钮按下态 | 可选 | 否 | 可暂空 |
| 调试UI | `debug_error_icon` | `res://assets/ui/debug/debug_error_icon.png` | 图标 | PNG | 配置错误图标，红色警告 | 可选 | 否 | 后续配置校验面板使用 |
| 调试UI | `debug_warning_icon` | `res://assets/ui/debug/debug_warning_icon.png` | 图标 | PNG | 配置警告图标，黄色警告 | 可选 | 否 | 后续配置校验面板使用 |
| 调试UI | `debug_info_icon` | `res://assets/ui/debug/debug_info_icon.png` | 图标 | PNG | 配置信息图标，蓝色提示 | 可选 | 否 | 后续配置校验面板使用 |

## 5. 音频素材

基础数值模块不依赖音频。以下音频只在未来调试UI或系统反馈中可能使用，可全部暂空。

| 模块 | 素材ID | 建议路径 | 类型 | 格式 | 内容 | 是否必需 | 是否存在 | 备注 |
| ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| 调试UI/系统反馈 | `sfx_ui_confirm` | `res://assets/audio/sfx/ui_confirm.wav` | 音频 | WAV/OGG | 确认/保存成功音效 | 否 | 否 | 非基础数值必需 |
| 调试UI/系统反馈 | `sfx_ui_error` | `res://assets/audio/sfx/ui_error.wav` | 音频 | WAV/OGG | 配置错误/操作失败音效 | 否 | 否 | 非基础数值必需 |
| 调试UI/系统反馈 | `sfx_ui_warning` | `res://assets/audio/sfx/ui_warning.wav` | 音频 | WAV/OGG | 配置警告提示音效 | 否 | 否 | 非基础数值必需 |
| 调试UI/系统反馈 | `sfx_ui_tick` | `res://assets/audio/sfx/ui_tick.wav` | 音频 | WAV/OGG | 列表切换/选择音效 | 否 | 否 | 非基础数值必需 |

## 6. 背景图素材

基础数值模块不依赖背景图。以下背景图只用于未来调试面板或数据浏览器，可全部暂空。

| 模块 | 素材ID | 建议路径 | 类型 | 格式 | 内容 | 是否必需 | 是否存在 | 备注 |
| ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| 调试UI | `debug_background` | `res://assets/ui/debug/debug_background.png` | 背景图 | PNG | 数据调试界面背景，深紫虚空风格 | 否 | 否 | 可用纯色Control背景替代 |
| 调试UI | `config_browser_background` | `res://assets/ui/debug/config_browser_background.png` | 背景图 | PNG | 配置浏览器背景 | 否 | 否 | 可暂空 |
| 调试UI | `modifier_stack_background` | `res://assets/ui/debug/modifier_stack_background.png` | 背景图 | PNG | modifier来源树背景 | 否 | 否 | 可暂空 |

## 7. 字体素材

| 模块 | 素材ID | 建议路径 | 类型 | 格式 | 内容 | 是否必需 | 是否存在 | 备注 |
| ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| 全局UI | `font_default_cn` | `res://assets/font/default_cn.ttf` | 字体 | TTF/OTF | 支持中文的默认UI字体 | 建议 | 否 | 如果使用Godot默认字体，中文显示可能不稳定 |
| 调试UI | `font_mono_debug` | `res://assets/font/debug_mono.ttf` | 字体 | TTF/OTF | 等宽字体，用于配置/数值调试 | 可选 | 否 | 可暂用默认字体 |

## 8. 推荐最小准备清单

如果只为了推进基础数值模块开发，最小只建议准备以下素材：

| 优先级 | 素材ID | 建议路径 | 是否存在 | 说明 |
| ---- | ---- | ---- | ---- | ---- |
| P0 | `placeholder_icon` | `res://assets/ui/icons/placeholder_icon.png` | 是 | 所有缺失图标兜底 |
| P1 | `stat_icon_max_hp` | `res://assets/ui/icons/stats/stat_max_hp.png` | 否 | 常用属性图标 |
| P1 | `stat_icon_move_speed` | `res://assets/ui/icons/stats/stat_move_speed.png` | 否 | 常用属性图标 |
| P1 | `stat_icon_melee_damage` | `res://assets/ui/icons/stats/stat_melee_damage.png` | 否 | 常用攻击属性图标 |
| P1 | `stat_icon_ranged_damage` | `res://assets/ui/icons/stats/stat_ranged_damage.png` | 否 | 常用攻击属性图标 |
| P1 | `stat_icon_damage_percent` | `res://assets/ui/icons/stats/stat_damage_percent.png` | 否 | 通用伤害加成图标 |
| P1 | `stat_icon_load_capacity` | `res://assets/ui/icons/stats/stat_load_capacity.png` | 否 | 玩家负载上限核心图标 |
| P2 | `font_default_cn` | `res://assets/font/default_cn.ttf` | 否 | 中文UI建议准备 |

## 9. 更新规则

1. 生成素材后，将文件放入“建议路径”对应位置。
2. 告诉Codex已放入哪些文件。
3. Codex检查文件是否存在后，只更新本表格中的“是否存在”字段。
4. 如果实际路径与建议路径不同，需要同步更新“建议路径”和相关配置引用。
5. 如果素材内容发生变化，但文件仍存在，不需要改“是否存在”，只在“备注”中补充版本说明。



