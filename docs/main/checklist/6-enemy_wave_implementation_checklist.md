# 敌人与波次模块实施 Checklist

本文档记录“敌人与波次模块”当前实施状态、待验证事项与后续非阻塞内容。

## 1. 当前状态

模块 MVP 编码已完成，等待在 Godot 中启动验证控制台输出。

## 2. 实施目标

- [x] 能读取 `enemies.json` 与 `waves.json`
- [x] 能实例化敌人场景
- [x] 能按 `duration_seconds` 单波计时刷怪
- [x] 能在玩家周围 1000~1500 范围内生成敌人
- [x] 能处理敌人追踪玩家
- [x] 能处理敌人一次碰撞伤害与弹开
- [x] 能处理敌人受击与死亡
- [x] 能在敌人死亡时引用掉落表并掉落经验球
- [x] 能在波次结束后统一吸取经验球并清场
- [x] 能在角色升级时触发一次共享奖励/商店页事件
- [x] 能在 `bootstrap.gd` 中打印自测结果

## 3. 已确认规则

1. 目前只做普通怪。
2. 波次不使用 `time_start/time_end`，改为每波独立 `duration_seconds`。
3. 波次时间使用 `min(15 + 5 * wave_index, 50)`，第 1 波为 20 秒，最高 50 秒。
4. 刷怪区域在玩家周围 1000~1500 距离环内。
5. 波次结束后清空场上敌人。
6. 敌人碰撞玩家后立刻弹开；敌人与玩家拉开距离后重置碰撞状态，之后可再次造成一次独立碰撞伤害。
7. 敌人死亡后掉落经验球，拾取后获得经验和等额基础金币。
8. 波次结束后统一吸取并结算场上所有经验球。
9. 达到升级条件后立即触发一次无须花费的商店购买。
10. 复杂精英/Boss 机制暂不做。

## 4. Godot 验证步骤

1. 使用 Godot 打开项目并运行 `bootstrap.tscn`。
2. 确认控制台出现下方自测输出。
3. 若 `validation errors` 或敌人与波次检查出现 failed，则先暂停后续模块，回到本模块修复。

## 5. 建议自测输出

```text
[Bootstrap] enemy wave checks
[Bootstrap] - enemy wave test scene instantiate: passed
[Bootstrap] - enemy config load: passed
[Bootstrap] - wave config load: passed
[Bootstrap] - wave duration formula: passed
[Bootstrap] - enemy instantiate: passed
[Bootstrap] - enemy contact damage knockback: passed
[Bootstrap] - enemy damage and death: passed
[Bootstrap] - enemy drop table link: passed
[Bootstrap] - wave collect exp orbs: passed
[Bootstrap] - shared reward/shop trigger: passed
```

## 6. 后续非阻塞项

- [ ] 精英怪词缀
- [ ] Boss 阶段技
- [ ] 寻路系统
- [ ] 对象池优化
- [ ] 屏幕外休眠

## 7. 结项判断

本模块可正式结项的条件是：

1. Godot 启动后能读取敌人和波次配置。
2. 能按波次持续刷出敌人。
3. 敌人能朝玩家移动并受击死亡。
4. 敌人死亡后能正确关联掉落表。
5. 控制台能输出自测通过结果。
