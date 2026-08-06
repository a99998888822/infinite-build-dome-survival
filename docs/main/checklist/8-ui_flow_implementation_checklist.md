# UI 交互模块实施 Checklist

本文档记录“UI 交互模块”当前实施状态、待验证事项与后续非阻塞内容。

## 1. 当前状态

模块设计已完成，等待进入编码实现。

## 2. 实施目标

- [ ] 能显示战斗 HUD
- [ ] 能显示升级三选一弹窗
- [ ] 能显示武器购买失败提示
- [ ] 能显示结算弹窗
- [ ] 能显示营地主界面
- [ ] 能显示建筑详情面板
- [ ] 能切换战斗 / 营地 / 结算 UI
- [ ] 能通过信号刷新 HUD
- [ ] 能在 `bootstrap.gd` 中打印 UI 自测结果

## 3. 已确认规则

1. UI 只读状态，不直接修改战斗规则。
2. 弹窗互斥，不叠加多层模态。
3. 战斗层和局外层分离。
4. 升级、购买、结算都通过 UI 事件驱动。

## 4. 建议自测输出

```text
[Bootstrap] ui flow checks
[Bootstrap] - hud scene instantiate: passed
[Bootstrap] - upgrade popup open/close: passed
[Bootstrap] - settlement popup open/close: passed
[Bootstrap] - camp ui open/close: passed
[Bootstrap] - signal binding refresh: passed
```

## 5. 后续非阻塞项

- [ ] 过渡动画
- [ ] 图鉴分页
- [ ] 多语言
- [ ] UI 主题皮肤
- [ ] 高级拖拽交互

## 6. 结项判断

本模块可正式结项的条件是：

1. 战斗和营地界面能正常切换。
2. HUD 和弹窗能正确响应业务信号。
3. 控制台能输出自测通过结果。
