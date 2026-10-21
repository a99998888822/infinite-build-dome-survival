# 当前战斗操作与施放

正式战斗由 `BattleRoot`、`ActiveCombatController`、`ActiveWeaponCasting` 和 `WeaponLoadout` 连接输入、武器动作、命中与冷却。现有 14 把武器，具体基础值维护于 [weapons.json](../../data_config/weapons.json)。

## 操作

- 移动可选鼠标右键或 WASD／方向键。鼠标模式下 S 停止并清除目的地；键盘模式下 S 向下移动。
- 每把武器独立选择自动或手动。新配置默认攻击自动、位移手动，选择按武器类型保存，升级、换位和重新装备不会丢失。
- 手动技能通过数字键或战斗栏选择、左键确认；快捷施法开启时直接释放。键盘移动模式还支持滚轮切换手动技能。
- 自动位移保留手动操作入口，手动瞄准期间让出自动决策。具体规则见[逐技能自动释放](per_skill_auto_cast.md)。
- GUI 优先接收输入；暂停、失焦、死亡与场景切换处理输入和施放状态，暂停时冻结动作与冷却。

## 动作、冷却与命中

同一武器实例不能重入，不同武器可以同时执行。通常在动作结束后开始冷却，弹体不必先消失；移星秘典从首次闪现开始冷却，返回与冷却共用计时。

施放时保存属性、附魔及范围快照。攻击速度影响冷却，保留各武器自身动作和持续伤害节奏。`active_cooldown_ms` 为主动冷却，`attack_interval_ms` 同时承担升级比例基准；实际公式由武器实例代码维护。

投射物体积与伤害范围同步增长，接触按敌人实际碰撞体判断。射程、位移距离、伤害范围分别使用各自规则，见[命中判定](weapon_contact_rules_2026-10-19.md)与[位移武器](mobility_weapons_implementation.md)。

武器详情与附魔文案共用正式 UI 构建函数，见[武器提示](weapon_tooltip_inventory.md)和[附魔提示](enchantment_tooltip_inventory.md)。波末进入夜幕撤离，详见[当前游戏流程](run_flow.md)。
