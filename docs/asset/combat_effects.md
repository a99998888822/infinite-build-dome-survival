# 当前战斗特效

效果沿用已确认的大色块像素风格。投射物、接触区、伤害时序由武器与效果代码决定，拖尾、光晕和结束残留不自动构成伤害，见[命中规则](../main/weapon_contact_rules_2026-10-19.md)。

## 资源与绘制

- 武器块状动画位于 `assets/sprites/weapons/effects/block_vfx/`；手炮喷焰使用 `shaders/effects/cannon_jet_flame.gdshader`。`build_weapon_block_vfx.py` 保留对应确定性绘制源。
- 三种位移武器复用 `assets/sprites/weapons/mobility/` 中的预加载动画；世界中没有悬浮武器本体。
- 黑洞保留球体与独立弯曲吸入细线，水流为连片水体，风刃为中宽两尖的刀锋。相关正式入口包含 `shaders/effects/enchantment_blocks.gdshader`；光辉剑保留确认外观。
- 元素反应复用正式效果脚本、像素图集和批次绘制，修改时同时检查冻结、解冻、导电与雷火等组合路径。
- 敌人使用阶梯边缘地面阴影，纹理由 `scripts/effects/enemy_ground_shadow.gd` 共享生成；跳跃时影子留在地面并调整大小与透明度。
- 绘制分为地面、角色局部状态、快速攻击/短时反馈与信息层。燃烧和冰壳覆盖所属身体，并随角色脚底排序；解冻碎冰在前景。具体最终 Z、喷火拆分和粒子分组见[当前层级表](combat_effect_layers_20261023.md)。

## 维护

以正式 PNG、同名可编辑源和运行脚本为入口，安装说明见[素材工具](../../scripts/tools/ASSET_INSTALLERS.md)。接入效果必须保持施放快照、命中集合、伤害次数、元素状态及随机数行为。

运行时复用预加载图集与缓存几何，复杂受击、跳字及反射使用现有批次调度。修改效果时分别核对画面和完整帧时间；具体限制见[性能说明](../../battle_performance_optimization_checklist.md)。音频事件维护于正式音频脚本与 `assets/audio/`，播放和淡出需遵守暂停及场景生命周期。
