# Godot 手动场景搭建与组件排布 Checklist

本文档记录当前项目中需要在 Godot 编辑器里手动检查、替换素材、微调节点或补充布局的事项。代码和配置可以先推进，等具备 Godot 调试条件后，再按本文档逐条操作。

## 1. 操作前准备

1. 使用 Godot 打开项目根目录下的 `project.godot`。
2. 优先运行 `scenes/core/bootstrap.tscn`。
3. 确认控制台没有 `validation errors` 或明显脚本报错。
4. 若启动失败，先暂停场景排布，回到对应模块修复代码或配置。

## 2. 基础设施场景

### 2.1 `scenes/core/bootstrap.tscn`

用途：项目启动、自检入口。

需要操作：

- [x] 打开场景并确认根节点存在。
- [x] 运行该场景，确认控制台能输出各模块自测信息。
- [x] 不需要添加美术节点。
- [x] 不需要修改节点位置。

注意：

1. 该场景主要用于验证配置、脚本和模块接口。
2. 后续新增模块时，会继续在 `bootstrap.gd` 中追加自测输出。

## 3. 玩家与角色场景

### 3.1 `scenes/player/player_root.tscn`

用途：玩家实体根场景。

需要操作：

- [x] 打开场景，确认根节点是 `CharacterBody2D`。
- [x] 确认存在 `VisualAnchor`。
- [x] 确认 `VisualAnchor/Sprite2D` 存在。
- [x] 把玩家正式精灵图挂到 `Sprite2D.texture`。
- [x] 检查 `Sprite2D` 的大小、偏移和朝向。
- [x] 确认 `PickupArea/CollisionShape2D` 存在。
- [x] 根据玩家体型微调主碰撞体大小。
- [x] 根据拾取范围确认拾取碰撞体半径是否合理。

不要轻易修改：

1. 根节点类型。
2. `PickupArea` 节点名。
3. `VisualAnchor` 节点名。

## 4. 局内武器场景

### 4.1 `scenes/weapons/weapon_loadout.tscn`

用途：武器管理逻辑容器。

需要操作：

- [x] 打开场景，确认根节点存在。
- [x] 确认 `TargetingService` 节点存在或运行时能自动创建。
- [x] 不需要摆放美术。
- [x] 不需要调整位置。

注意：

1. 武器图标、投射物、刀光、范围特效由素材文件和武器模块使用。
2. 该场景主要是逻辑容器，不是表现节点。

## 5. 敌人与波次场景

### 5.1 `scenes/enemy/mutated_grub.tscn`

用途：普通小怪实体。

需要操作：

- [x] 打开场景，确认根节点是 `CharacterBody2D`。
- [x] 把敌人正式图片挂到 `Sprite2D.texture`。
- [x] 检查敌人图片朝向。
- [x] 根据图片大小微调 `Sprite2D.scale`。
- [x] 根据敌人体型微调 `CollisionShape2D` 半径。
- [x] 运行自测，确认敌人能被实例化。

不要轻易修改：

1. 根节点类型。
2. `CollisionShape2D` 节点名。
3. 脚本绑定。

### 5.2 `scenes/pickups/exp_orb.tscn`

用途：经验球拾取物。

需要操作：

- [x] 打开场景，确认根节点是 `Area2D`。
- [x] 把经验球正式图片挂到 `Sprite2D.texture`。
- [x] 检查 `CollisionShape2D` 是否覆盖经验球图标。
- [x] 运行自测，确认经验球能被统一吸取和结算。

不要轻易修改：

1. 根节点类型。
2. `CollisionShape2D` 节点名。
3. 脚本绑定。

### 5.3 `scenes/waves/wave_manager.tscn`

用途：波次管理逻辑容器。

需要操作：

- [x] 打开场景，确认根节点存在。
- [x] 确认 `EnemyRoot` 存在。
- [x] 确认 `PickupRoot` 存在。
- [x] 不需要摆放美术。
- [x] 不需要调整位置。

注意：

1. `EnemyRoot` 用于承载运行时生成的敌人。
2. `PickupRoot` 用于承载运行时生成的经验球等拾取物。

## 6. 局外营地场景

### 6.1 `scenes/camp/camp_root.tscn`

用途：营地主场景。

当前状态：

1. 已有 `BuildingLayer`。
2. 已能运行时生成 8 个建筑位。
3. 还需要你在 Godot 中搭建营地背景和装饰层。

如果你已经准备好一张很大的草地，建议把它当作纯背景处理：

1. 草地只负责显示，放在 `BackgroundLayer` 下，通常只需要 `Sprite2D`，不要加碰撞。
2. 河流、树木、石头分成两类处理。
3. 只是装饰的，直接用 `Sprite2D`。
4. 需要阻挡玩家的，使用 `StaticBody2D + CollisionShape2D + Sprite2D`。
5. 玩家是否能被挡住，最终取决于碰撞层和遮罩是否对上，不是图片本身。
6. 如果要让玩家“不可触碰”，不要只靠 `Area2D`，它只能检测，不能阻挡移动。
7. 建议把障碍节点放进单独的 `PropLayer`，避免和建筑位混在一起。

建议节点结构：

```text
CampRoot
├─ BackgroundLayer
│  ├─ GrassSprite
│  └─ RiverSprite
├─ PropLayer
│  ├─ TreeGroup
│  ├─ RockGroup
│  ├─ FlowerGroup
│  └─ Campfire
├─ BuildingLayer
└─ UILinkLayer
```

需要操作：

- [x] 新增 `BackgroundLayer`。
- [x] 在 `BackgroundLayer` 下放置草地素材。
- [x] 在 `BackgroundLayer` 下放置河流素材。
- [x] 新增 `PropLayer`。
- [x] 在 `PropLayer` 下摆放树木、石头、花草。
- [x] 在营地中心附近摆放篝火。
- [x] 检查 `BuildingLayer` 是否在背景层和装饰层之上。
- [x] 运行场景，确认 8 个建筑位正常显示。
- [x] 根据实际画面调整 8 个建筑位置。

不要轻易修改：

1. `BuildingLayer` 节点名。
2. `CampRoot` 脚本绑定。

### 6.2 `scenes/camp/camp_building_slot.tscn`

用途：单个营地建筑位。

当前规则：

1. 未解锁建筑显示 `RuinsSprite2D`。
2. 已解锁建筑显示 `BuildingSprite2D`。
3. 初始自带建筑直接显示 `BuildingSprite2D`。

需要操作：

- [x] 打开场景，确认根节点是 `Area2D`。
- [x] 确认 `RuinsSprite2D` 存在。
- [x] 确认 `BuildingSprite2D` 存在。
- [x] 确认 `CollisionShape2D` 覆盖可点击区域。
- [x] 确认 `NameLabel` 位置不遮挡建筑。
- [x] 如建筑图较大，微调两个 `Sprite2D` 的 scale。
- [x] 如点击范围不合适，微调 `CollisionShape2D` 半径。

不要轻易修改：

1. `RuinsSprite2D` 节点名。
2. `BuildingSprite2D` 节点名。
3. `CollisionShape2D` 节点名。
4. 脚本绑定。

## 7. UI 交互模块场景

当前状态：

1. 已有 UI 模块设计文档。
2. 已创建奖励 / 商店候选项共用 prefab：`scenes/ui/rewards/reward_option.tscn`。
3. 还没有正式创建 HUD、完整弹窗页和营地 UI 的 `.tscn`。

后续需要在 Godot 中新建：

- [ ] 战斗 HUD 场景。
- [ ] 共享奖励/商店页场景。
- [x] 共享奖励/商店候选项 prefab：`scenes/ui/rewards/reward_option.tscn`。
- [ ] 武器购买失败提示弹窗。
- [ ] 营地建筑详情面板。
- [ ] 暂停菜单。

建议节点结构：

```text
UIRoot
├─ HUDLayer
├─ PopupLayer
├─ FadeLayer
└─ DebugLayer
```

奖励 / 商店候选项 prefab 约定：

```text
RewardOption (PanelContainer + StyleBoxFlat)
└─ Content (VBoxContainer)
   ├─ TopRarityLine (ColorRect)
   ├─ TypeLabel (Label: 武器升级 / 新武器 / 遗物)
   ├─ IconFrame (PanelContainer)
   ├─ NameLabel (Label)
   ├─ DescriptionLabel (Label)
   ├─ BottomRarityLine (ColorRect)
   └─ SelectButton (Button: 选择 / 具体花费金额)
```

通用弹窗底板、奖励/商店页底板和奖励卡底优先使用 Godot `PanelContainer` + `StyleBoxFlat`，MVP 阶段不需要专门的底板 PNG。

## 8. 当前最需要手动处理的场景

优先级从高到低：

1. `scenes/camp/camp_root.tscn`：搭建草地、河流、树木、石头、花草、篝火。
2. `scenes/player/player_root.tscn`：替换玩家正式精灵图并检查碰撞。
3. `scenes/enemy/mutated_grub.tscn`：替换敌人图并检查碰撞。
4. `scenes/pickups/exp_orb.tscn`：替换经验球图并检查拾取碰撞。
5. UI 模块相关场景：后续进入 UI 实现时再集中搭建。

## 9. 每次手动调整后的验证

每次完成一批场景调整后，建议执行：

1. 运行 `scenes/core/bootstrap.tscn`。
2. 看控制台是否存在 failed。
3. 如果只是图片缺失，确认是否允许占位。
4. 如果是节点找不到，优先检查节点名是否被改动。
5. 如果是碰撞异常，优先检查 `CollisionShape2D` 是否存在且启用。
