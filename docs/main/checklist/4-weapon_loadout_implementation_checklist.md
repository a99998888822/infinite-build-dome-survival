# 局内武器模块实施 Checklist

本文档记录“局内武器模块”MVP 实施状态。当前目标只覆盖：能加载、能升级、能算伤害、能强校验负载。

## 1. 当前状态

模块 MVP 代码已完成，等待 Godot 启动验证。

## 2. 已完成事项

- [x] 新增武器运行实例：`scripts/weapons/weapon_instance.gd`
- [x] 新增武器负载管理器：`scripts/weapons/weapon_loadout.gd`
- [x] 新增伤害事件对象：`scripts/weapons/damage_event.gd`
- [x] 新增最近敌人索敌服务占位：`scripts/weapons/targeting_service.gd`
- [x] 新增武器管理场景：`scenes/weapons/weapon_loadout.tscn`
- [x] 支持从玩家开局武器 ID 初始化武器
- [x] 支持装备与购买时负载强校验
- [x] 支持购买新武器超载失败
- [x] 支持武器升级并应用 `stat` 与 `attack_interval_ms`
- [x] 支持 `attack_speed` 攻击间隔计算
- [x] 支持 `use_cooldown_reduction_only` 冷却型武器计算
- [x] 支持近战、远程、混伤拆段伤害计算
- [x] 支持 `hit_radius` 基础半径、`area_size` 最终范围加成、`projectile_speed`、`spread_angle` 运行字段读取
- [x] 在 `bootstrap.gd` 中加入武器模块自测

## 3. 待你验证事项

- [ ] 在 Godot 中启动项目，确认控制台出现 `[Bootstrap] weapon checks`
- [ ] 确认武器相关自测全部输出 `passed`
- [ ] 若出现配置校验错误，先反馈控制台完整错误信息

## 4. Godot 启动验证标准

启动项目后，控制台至少应看到以下内容：

```text
[Bootstrap] weapon checks
[Bootstrap] - weapon test scene instantiate: passed
[Bootstrap] - weapon loadout initialize: passed
[Bootstrap] - weapon load cost: passed
[Bootstrap] - weapon config runtime fields: passed
[Bootstrap] - weapon area_size radius: passed
[Bootstrap] - weapon attack interval base: passed
[Bootstrap] - weapon attack_speed interval: passed
[Bootstrap] - weapon upgrade: passed
[Bootstrap] - weapon damage event: passed
[Bootstrap] - weapon mixed damage split: passed
[Bootstrap] - weapon cooldown only interval: passed
[Bootstrap] - weapon purchase load limit: passed
```

## 5. 后续非阻塞事项

- [ ] 接入真实敌人查询与受击接口
- [ ] 接入投射物场景与边界销毁
- [ ] 接入近战/范围命中判定
- [ ] 接入武器商店 UI
- [ ] 接入武器升级选项 UI
- [ ] 接入武器特效与音效

## 6. 结项判断

本模块 MVP 的结项条件是：

1. Godot 启动自测全部通过。
2. 默认武器能从玩家开局武器列表初始化。
3. 武器升级、伤害计算、负载校验结果符合设计文档。
