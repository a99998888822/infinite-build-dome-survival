# UI 交互模块实施 Checklist

本文档记录“UI 交互模块”当前实施状态、待验证事项与后续非阻塞内容。

## 1. 当前状态

模块设计已完成，等待进入编码实现。

## 2. 实施目标

- [ ] 能显示战斗 HUD
- [ ] 能显示共享奖励/商店页
- [x] 能实例化共享奖励 / 商店候选项 `reward_option.tscn`
- [ ] 能显示武器购买失败提示
- [ ] 能显示营地主界面
- [ ] 能显示建筑详情面板
- [ ] 能切换战斗 / 营地 / 共享奖励/商店 UI
- [ ] 能通过信号刷新 HUD
- [ ] 能在 `bootstrap.gd` 中打印 UI 自测结果
- [x] 能在 `bootstrap.gd` 中自测奖励选项按钮文案

## 3. 已确认规则

1. UI 只读状态，不直接修改战斗规则。
2. 弹窗互斥，不叠加多层模态。
3. 战斗层和局外层分离。
4. 升级、购买、波次结束都通过 UI 事件驱动。
5. 商店只提供新武器、遗物和武器升级，不提供单独属性购买。
6. 新武器不可重复获得；负载不足时仍可刷新，但购买必须失败并提示原因。
7. 免费奖励入口和付费商店入口共用同一套候选池、稀有度权重、类型权重和去重规则。
8. 同一轮商店不得重复出现同一把武器的同一级升级项。
9. 通用弹窗底板和奖励/商店页底板优先使用 Godot `PanelContainer` + `StyleBoxFlat`，不依赖单独底板 PNG。
10. 奖励选项统一使用 `scenes/ui/rewards/reward_option.tscn`，通过文本区分 `武器升级`、`新武器`、`遗物`。
11. 奖励选项通过边框颜色区分稀有度；免费入口按钮显示“选择”，商店入口按钮显示具体花费金额。

## 4. 商店实现范围

- [ ] 构建新武器、遗物、武器升级三类候选池
- [ ] 实现 `luck` 到六档稀有度权重的转换
- [ ] 实现剩余负载对新武器类型权重的修正
- [ ] 实现武器升级未出现时的权重积累与出现后清零
- [ ] 实现同一轮武器升级选项去重
- [ ] 免费奖励页与商店复用同一刷新服务
- [ ] 过滤已拥有武器和达到 `max_stack` 的遗物
- [x] 奖励选项 prefab 支持免费 / 商店两种按钮文案
- [x] 奖励选项 prefab 支持稀有度边框颜色
- [x] 奖励选项 prefab 不依赖独立卡底 PNG

## 5. 建议自测输出

```text
[Bootstrap] ui flow checks
[Bootstrap] - hud scene instantiate: passed
[Bootstrap] - shared reward/shop page open/close: passed
[Bootstrap] - reward option scene instantiate: passed
[Bootstrap] - reward option free button text: passed
[Bootstrap] - reward option shop button text: passed
[Bootstrap] - camp ui open/close: passed
[Bootstrap] - signal binding refresh: passed
```

## 6. 后续非阻塞项

- [ ] 过渡动画
- [ ] 图鉴分页
- [ ] 多语言
- [ ] UI 主题皮肤
- [ ] 高级拖拽交互

## 7. 结项判断

本模块可正式结项的条件是：

1. 战斗和营地界面能正常切换。
2. HUD 和弹窗能正确响应业务信号。
3. 控制台能输出自测通过结果。

## 8. 下一模块

- [ ] 第 10 模块：音频与氛围表现
