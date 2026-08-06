# 玩家与角色模块实施 Checklist

本文档记录“玩家与角色模块”当前实施状态、待验证事项与后续非阻塞事项。

## 1. 当前状态

模块 MVP 代码已完成，除正式素材替换与 Godot 启动验证外，可视为待验收状态。

## 2. 已完成事项

- [x] 新增玩家根场景：`scenes/player/player_root.tscn`
- [x] 新增玩家控制脚本：`scripts/player/player_controller.gd`
- [x] 从 `characters.json` 初始化角色基础属性
- [x] 接入 `ModifierStack`，支持局外、局内、临时 modifier 扩展
- [x] 预留角色被动加载入口：`passive_modifiers`
- [x] 读取并保存开局武器 ID 列表
- [x] 实现键盘移动控制
- [x] 实现左右朝向翻转
- [x] 实现生命、护盾、护甲减伤、受击、短暂无敌与死亡信号
- [x] 实现 `PickupArea` 拾取范围同步
- [x] 在 `bootstrap.gd` 中加入玩家初始化与受击自测
- [x] 更新玩家与角色模块设计文档实现状态

## 3. 待你完成事项

- [ ] 在 Godot 中启动项目，确认控制台出现 `[Bootstrap] player checks`
- [ ] 确认玩家相关自测全部输出 `passed`
- [ ] 生成正式玩家右向基础精灵图
- [ ] 生成正式玩家右向行走 spritesheet
- [ ] 生成角色选择头像与角色小图标
- [ ] 将正式素材放入素材清单指定路径
- [ ] 需要时告知我更新素材清单中的“是否存在/状态”字段

## 4. Godot 启动验证标准

启动项目后，控制台至少应看到以下内容：

```text
[Bootstrap] player checks
[Bootstrap] - player scene instantiate: passed
[Bootstrap] - player initialize character: passed
[Bootstrap] - player max_hp: passed
[Bootstrap] - player move_speed: passed
[Bootstrap] - player start weapons: passed
[Bootstrap] - player pickup radius: passed
[Bootstrap] - player armor damage: passed
```

若以上全部通过，本模块可正式标记为 MVP 结项。

## 5. 后续非阻塞事项

- [ ] 接入正式动画状态机
- [ ] 接入角色选择 UI
- [ ] 接入营地到战斗的数据流转
- [ ] 接入拾取物吸附与结算
- [ ] 接入武器实例化与挂载
- [ ] 扩展复杂角色被动效果注册器

## 6. 结项判断

本模块的结项条件是：

1. Godot 启动自测全部通过。
2. 正式或临时玩家素材可被 Godot 正常导入。
3. 后续武器、敌人、掉落模块可以通过玩家公开接口读取属性与位置。

