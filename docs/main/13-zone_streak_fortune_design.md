# 区域驻守与福缘收割模块详细设计方案

本模块承载“连续驻守同一区域，承压积累收益；切换区域时主动收割”的局内核心博弈。它借鉴“福星”类风险收益节奏，但触发权完全交给玩家：玩家在波次间选择区域，决定继续加压积累，还是换区兑现奖励。

## 1. 已确认规则

1. 区域选择页固定放在：`理财后 -> 下一波前`。
2. 第 1 波开始前不选区；第 1 波结束、第 2 波开始前进行首次选区。
3. 死亡或通关时，未收割的福缘不自动兑现；福缘是单局有效属性，本局结束后自然失效。
4. MVP 先做 3 个区域：`近弦战场`、`流星高塔`、`神选之地`。
5. 连驻层数无上限，不设置硬性最大层数。
6. 区域倾向会影响遗物、羁绊、武器，同时区域连驻会给敌人上 buff、给玩家加 debuff。

## 2. 模块目标

1. 让每波结束后的休整不只是购买成长，也包含“继续贪收益 / 及时收菜”的决策。
2. 让区域选择影响后续遗物、羁绊标签和武器方向，强化构筑方向感。
3. 通过连驻惩罚制造风险：敌人更强、玩家承受额外压力，但储备奖励与定向倾向同步增强。
4. 保持 MVP 简洁：先做 3 个固定区域、连驻层数、福缘储备、换区收割、区域倾向和波次压力上下文。
5. 与主流程、掉落奖励、武器、遗物羁绊模块解耦，避免区域系统直接生成复杂奖励或直接改写其他模块数据。

## 3. 模块边界

### 3.1 本模块负责

- 记录当前驻守区域、连驻层数、福缘储备值和当前区域倾向。
- 在波次结束后根据当前连驻层数增加福缘储备。
- 在玩家选择相同区域时提升连驻层数。
- 在玩家选择不同区域时触发福缘收割，并清空旧区域的连驻状态与持续惩罚。
- 输出敌人强化、玩家削弱、奖励倾向和收割奖励上下文。
- 向 UI 提供区域卡、风险预览、倾向预览和收割预览数据。

### 3.2 本模块不负责

- 不直接生成遗物、武器或金币实体；具体奖励仍交给掉落与奖励模块。
- 不直接修改玩家最终属性；惩罚统一转换为 `ModifierStack` 或波次上下文。
- 不负责商店候选的完整生成逻辑，只提供区域倾向和福缘收割上下文。
- 不负责正式存档；本模块状态属于单局临时状态，死亡或通关后清空。
- 不负责区域美术场景切换；MVP 先用 UI 卡片表达区域。

## 4. 与主流程的关系

区域选择页作为第 12 模块主流程的扩展阶段，固定插入在：

```text
波次结束
-> 吸收经验
-> 补共享奖励/商店页
-> 利息
-> 商店
-> 理财
-> 区域选择 / 福缘收割
-> 下一波战斗准备
```

说明：

1. 不打乱已经确认的“吸收经验 -> 补奖励 -> 利息 -> 商店 -> 理财”固定顺序。
2. 区域选择发生在理财之后、下一波开始之前。
3. 第 1 波开始前不强制选区，避免破坏已确认的“选角色 -> 直接进第 1 波”流程。
4. 第 1 波结束、第 2 波开始前首次选区；首次选区只设置区域，不触发收割、不增加福缘储备。
5. 从后续继续选择同一区域开始提升连驻层数；当层数达到储备阈值后，每成功守住一波才增加福缘储备。

## 5. 核心循环

### 5.1 首次选区

1. 玩家完成第 1 波后的固定休整流程。
2. 弹出区域选择页。
3. 玩家选择任一区域。
4. `current_zone_id` 设置为该区域。
5. `streak_count = 1`。
6. `fortune_storage = 0`。
7. 下一波开始时应用该区域的基础倾向，但不施加强连驻惩罚。

### 5.2 继续驻守同一区域

1. 玩家在区域选择页选择当前区域。
2. `streak_count += 1`，无硬上限。
3. 下一波开始时根据新层数应用更强敌人 buff 与玩家 debuff。
4. 区域倾向强度提升，用于影响遗物、羁绊和武器候选权重。
5. 福缘储备不会在选择时增加，而是在成功守住下一波后结算。

### 5.3 切换到不同区域

1. 玩家在区域选择页选择非当前区域。
2. 如果 `fortune_storage > 0`，立即触发福缘收割。
3. 掉落与奖励模块根据收割上下文生成局内金币、定向遗物、定向武器/升级候选和稀有奖励。
4. 旧区域的连驻层数、福缘储备、持续 debuff 全部清零。
5. 新区域成为当前区域，`streak_count = 1`。
6. 下一波按新区域的基础倾向开始。

### 5.4 死亡与通关

死亡或通关时，未收割的福缘储备不自动兑现。

原因：

1. 福缘是单局内的风险储备，不属于局外资源。
2. 本局结束后福缘自然失效，自动收割没有实际意义。
3. 这能保持“主动换区收菜”的决策压力。

## 6. 区域配置表设计

建议新增配置表：`data_config/zones.json`。

MVP 先做 3 个固定区域，全部默认开放。区域名称可调整，但 `id` 应保持稳定。

### 6.1 配置结构示例

```json
[
  {
    "id": "zone_nearstring_battlefield",
    "display_name": "近弦战场",
    "description": "断裂弦音回荡的近身战场，适合近战构筑继续深耕。",
    "tendency_tags": ["melee"],
    "enemy_pressure_per_streak": {
      "max_hp_percent": 10,
      "damage_percent": 5
    },
    "player_pressure_per_streak": {
      "damage_taken_percent": 3
    },
    "fortune_gain": {
      "start_streak": 2,
      "base": 10,
      "per_extra_streak": 8,
      "wave_bonus": 2
    },
    "reward_bias": {
      "target_pools": ["relic", "bond", "weapon"],
      "tag_weight_per_streak": 20,
      "rarity_bonus_per_streak": 2
    }
  }
]
```

### 6.2 字段说明

| 字段 | 类型 | 必填 | 说明 |
|---|---:|---:|---|
| `id` | String | 是 | 稳定区域 ID，代码和单局状态只引用该字段 |
| `display_name` | String | 是 | UI 显示名称 |
| `description` | String | 是 | UI 描述 |
| `tendency_tags` | Array[String] | 是 | 区域倾向标签，用于影响遗物、羁绊和武器候选权重 |
| `enemy_pressure_per_streak` | Dictionary | 是 | 每层连驻带来的敌人 buff，按整数百分比表达 |
| `player_pressure_per_streak` | Dictionary | 是 | 每层连驻带来的玩家 debuff，按整数数值表达 |
| `fortune_gain` | Dictionary | 是 | 福缘储备增长参数 |
| `reward_bias.target_pools` | Array[String] | 是 | 区域倾向影响的候选池，MVP 使用 `relic`、`bond`、`weapon` |
| `reward_bias.tag_weight_per_streak` | Int | 是 | 每层连驻带来的标签权重加成 |
| `reward_bias.rarity_bonus_per_streak` | Int | 是 | 每层连驻带来的稀有度加成 |

说明：不再配置 `max_streak`，连驻层数无硬上限。

### 6.3 MVP 默认区域

| 区域 ID | 名称 | 倾向标签 | 玩法倾向 |
|---|---|---|---|
| `zone_nearstring_battlefield` | 近弦战场 | `melee` | 更容易追近战遗物、近战羁绊、近战武器或近战武器升级 |
| `zone_meteor_tower` | 流星高塔 | `ranged` | 更容易追远程遗物、远程羁绊、远程武器或远程武器升级 |
| `zone_chosen_land` | 神选之地 | `elect`、`humanity`、`divinity` | 更容易追神选者、理智/人性、侵蚀度相关构筑 |

说明：

1. `melee`、`ranged`、`elect` 可直接对应当前已有武器、遗物、羁绊标签。
2. `humanity`、`divinity` 对应基础数值模块里的理智/人性、侵蚀度属性。
3. 区域不等于地图场景，MVP 只是休整期选择项。
4. 后续可以扩展更多区域，例如生存、防御、召唤、经济、控制类区域。

## 7. 单局运行状态

建议运行时维护一个 `ZoneStreakState`，MVP 可以先用 Dictionary 承载。

```gdscript
{
  "current_zone_id": "zone_nearstring_battlefield",
  "streak_count": 3,
  "fortune_storage": 42,
  "last_harvest": {},
  "pending_harvest": false
}
```

字段说明：

| 字段 | 说明 |
|---|---|
| `current_zone_id` | 当前驻守区域；空字符串表示尚未选区 |
| `streak_count` | 当前区域连驻层数，首次选择为 1，无硬上限 |
| `fortune_storage` | 当前尚未收割的福缘储备值 |
| `last_harvest` | 最近一次收割结果快照，供 UI 展示 |
| `pending_harvest` | 是否有待展示的收割结果页 |

本状态只属于单局，不写入正式存档。

## 8. 连驻压力规则

### 8.1 层数计算

- 选择第一个区域：`streak_count = 1`。
- 继续选择同一区域：`streak_count += 1`。
- 选择不同区域：先结算旧区域收割，再设置新区域 `streak_count = 1`。
- 层数无上限，但 UI 预览要明确展示下一波风险，避免玩家误以为高层安全。

### 8.2 敌人 buff

敌人 buff 在下一波开始时应用，建议转成波次上下文，不直接改 `enemies.json`。

示例公式：

```text
effective_enemy_max_hp_percent = (streak_count - 1) * zone.enemy_pressure_per_streak.max_hp_percent
effective_enemy_damage_percent = (streak_count - 1) * zone.enemy_pressure_per_streak.damage_percent
```

说明：

1. 第 1 层不强化敌人。
2. 第 2 层开始产生压力。
3. 所有百分比均使用整数，例如 `20` 表示敌人生命提高 20%。
4. 因为层数无上限，敌人 buff 会持续增长；后续若数值失控，可只调整配置曲线或追加软上限，不改变模块结构。

### 8.3 玩家 debuff

玩家 debuff 建议通过 `ModifierStack` 注入临时 modifier，并在换区收割后移除。

示例：

```text
effective_damage_taken_percent_bonus = (streak_count - 1) * zone.player_pressure_per_streak.damage_taken_percent
```

如果第 3 层、每层 `damage_taken_percent +3`，则玩家受到伤害百分比额外增加 `6`。

说明：

1. 这里的 `damage_taken_percent` 仍遵循基础数值模块的整数约定。
2. 它是额外承伤压力，不替代护甲曲线。
3. MVP 先只做少量通用压力，避免区域机制过重。

## 9. 福缘储备规则

### 9.1 储备增加时机

福缘储备只在“成功守住一波”后增加。

前提：

1. 当前已有驻守区域。
2. 当前连驻层数 `streak_count >= fortune_gain.start_streak`。
3. 玩家未死亡。

### 9.2 储备增长公式

MVP 建议公式：

```text
fortune_gain = base + max(streak_count - start_streak, 0) * per_extra_streak + wave_index * wave_bonus
fortune_storage += fortune_gain
```

示例：

- `base = 10`
- `start_streak = 2`
- `per_extra_streak = 8`
- `wave_bonus = 2`
- 第 5 波，当前 3 层：`10 + (3 - 2) * 8 + 5 * 2 = 28`

说明：

1. 层数越高，单波储备越多。
2. 波次越靠后，储备价值越高。
3. 储备本身只是积分，不直接等于金币或遗物数量。
4. 因为层数无上限，储备增长会持续变大；后续主要通过压力增长来制衡。

## 10. 福缘收割规则

### 10.1 触发条件

玩家在区域选择页选择与 `current_zone_id` 不同的区域时触发。

如果 `fortune_storage = 0`，则只切换区域，不展示大收割页。

### 10.2 收割上下文

区域模块不直接生成奖励，而是输出如下上下文给掉落与奖励模块：

```gdscript
{
  "source_zone_id": "zone_nearstring_battlefield",
  "next_zone_id": "zone_meteor_tower",
  "streak_count": 4,
  "fortune_storage": 86,
  "tendency_tags": ["melee"],
  "target_pools": ["relic", "bond", "weapon"],
  "rarity_bonus": 8
}
```

### 10.3 奖励生成建议

掉落与奖励模块可以基于 `fortune_storage` 生成：

1. 局内金币。
2. 定向遗物候选。
3. 定向武器或武器升级候选。
4. 对应羁绊标签的构筑权重加成。
5. 高稀有度奖励概率加成。
6. 后续扩展的稀有道具。

MVP 建议先做：

```text
gold_gain = fortune_storage
extra_offer_count = floor(fortune_storage / 50)
rarity_bonus = streak_count * reward_bias.rarity_bonus_per_streak
```

说明：

1. 金币是稳定收益。
2. 定向候选是情绪爆点。
3. 稀有度加成通过已有幸运/稀有度权重函数或后续奖励模块接口吸收。
4. 具体奖励数值后续在掉落与奖励模块里细调。

## 11. 区域倾向规则

区域倾向影响“更容易刷到什么”，不保证必出。

### 11.1 倾向强度

```text
tag_weight_bonus = streak_count * reward_bias.tag_weight_per_streak
```

示例：

- `tendency_tags = ["melee"]`
- `tag_weight_per_streak = 20`
- 第 3 层时，近战标签候选权重额外增加 `60`

### 11.2 作用对象

MVP 优先作用于：

1. 遗物候选池：提高带对应标签或对应属性效果的遗物权重。
2. 羁绊追构筑：提高能补足目标羁绊标签的遗物权重。
3. 武器候选池：提高对应标签的新武器权重。
4. 武器升级候选池：提高对应标签已装备武器的升级选项权重。
5. 福缘收割：提高定向奖励中对应标签候选的出现概率。

暂不作用于：

1. 区域地图视觉变化。
2. 区域专属敌人池。
3. 正式局外营地成长。

原因：先保证“区域 -> 构筑方向”的核心反馈清晰，避免早期系统耦合过多。

## 12. UI 表现设计

### 12.1 区域选择页

区域选择页建议展示 3 张区域卡：

每张卡显示：

1. 区域名称。
2. 区域描述。
3. 主要倾向标签。
4. 如果选择后会继续连驻：显示下一层压力和倾向增强。
5. 如果选择后会换区：显示预计触发福缘收割。
6. 当前福缘储备值。
7. 当前连驻层数，并明确“无上限”。

### 12.2 收割结果页

当切换区域且 `fortune_storage > 0` 时展示：

1. 本次收割来源区域。
2. 连驻层数。
3. 福缘储备值。
4. 获得金币。
5. 获得遗物、武器或升级候选。
6. “确认”按钮，确认后进入下一波准备。

### 12.3 MVP 美术要求

MVP 不强制新增区域背景图。

可先使用：

1. Godot `PanelContainer` + `StyleBoxFlat` 区域卡。
2. 现有奖励卡样式复用。
3. 简单文字标签表达 `melee`、`ranged`、`elect`、`humanity`、`divinity`。

后续如果要补素材，再追加区域图标和区域卡背景。

## 13. 与其他模块接口

### 13.1 主流程模块

主流程需要新增或预留：

- `zone_select`：理财后进入区域选择。
- `zone_harvest_result`：换区后展示收割结果。

推荐流程：

```text
finance_popup -> zone_select -> zone_harvest_result(可选) -> battle_prepare
```

### 13.2 敌人与波次模块

波次开始前读取区域压力上下文：

```gdscript
{
  "enemy_max_hp_percent": 20,
  "enemy_damage_percent": 10,
  "player_damage_taken_percent": 6
}
```

敌人模块只消费这些数值，不关心它们来自哪个区域。

### 13.3 掉落与奖励模块

奖励模块读取：

- `get_zone_runtime_context()` 输出的统一区域运行时上下文。
- `build_harvest_context(next_zone_id)` 输出的切区收割上下文。
- `tendency_tags`
- `target_pools`
- `tag_weight_bonus`
- `fortune_storage`
- `rarity_bonus`
- `source_zone_id`

奖励模块负责把它们转成具体商店候选、遗物候选、武器候选或收割奖励。

### 13.4 武器模块

武器模块不直接读取区域状态。

区域倾向只通过奖励模块影响“新武器出现概率”和“已装备武器升级出现概率”，不改变武器实际战斗公式。

### 13.5 遗物与羁绊模块

遗物与羁绊模块不直接读取区域状态。

区域倾向只通过奖励模块影响“遗物出现概率”和“补羁绊标签概率”，不改变已拥有遗物或已激活羁绊。

### 13.6 基础数据模块

基础数据模块后续需要加载 `zones.json`，并校验：

1. `id` 唯一。
2. `tendency_tags` 非空。
3. 所有数值字段为整数。
4. 不允许出现 `max_streak` 这类硬上限字段，避免和“连驻层数无上限”冲突。
5. 压力字段只能引用已定义或允许的上下文字段。

## 14. MVP 实施范围

MVP 只做：

1. `zones.json` 3 个区域配置。
2. 单局区域状态 `current_zone_id / streak_count / fortune_storage`。
3. 波次结束后根据当前区域与层数增加福缘储备。
4. 理财后弹出区域选择页。
5. 选择同区域提升连驻层数。
6. 选择不同区域触发收割并重置旧区域状态。
7. 输出区域压力上下文给波次模块。
8. 输出区域倾向上下文给奖励模块。
9. 区域倾向影响遗物、羁绊和武器候选权重。
10. `bootstrap` 自测区域状态、储备增长、换区收割和重置。

暂不做：

1. 区域专属事件。
2. 区域地图视觉切换。
3. 区域专属敌人池。
4. 终局自动收割。
5. 稀有道具的完整实现。
6. 区域解锁与局外营地联动。

## 15. 后续只需调参的内容

以下不是设计阻塞点，后续编码或测试时可继续调：

1. 每层敌人生命/伤害 buff 数值。
2. 每层玩家承伤 debuff 数值。
3. 福缘储备增长公式中的 `base`、`per_extra_streak`、`wave_bonus`。
4. 区域倾向权重 `tag_weight_per_streak`。
5. 福缘收割时金币、额外候选数量和稀有度加成的换算比例。

## 16. 验收标准

1. 第 1 波结束后才会首次出现区域选择。
2. 第一次选区只建立当前区域，不触发收割。
3. 连续选择同一区域会提升层数，层数无硬上限。
4. 成功守波后，满足阈值时增加福缘储备。
5. 选择不同区域会一次性生成收割上下文，随后清空旧区域储备与压力。
6. 区域压力能作为独立上下文传给波次模块。
7. 区域倾向能作为独立上下文传给奖励模块，并影响遗物、羁绊和武器候选。
8. 死亡或通关时未收割福缘不会自动兑现，且本局结束后自然失效。
9. 所有数值使用整数，符合基础数值模块约定。
10. 本模块运行状态不会写入正式存档。
