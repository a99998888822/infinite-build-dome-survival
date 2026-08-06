# 局内遗物与羁绊模块实施 Checklist

本文档记录“局内遗物与羁绊模块”当前实施状态、待验证事项与后续非阻塞内容。

## 1. 当前状态

模块设计已完成，等待进入编码实现。

## 2. 实施目标

- [ ] 能读取 `relics.json` 与 `bonds.json`
- [ ] 能记录局内遗物持有数量
- [ ] 能按 `max_stack` 限制同名遗物刷新
- [ ] 能统计武器 + 遗物标签
- [ ] 能计算羁绊层数并应用阈值效果
- [ ] 能把遗物效果与羁绊效果提交到 `ModifierStack`
- [ ] 能在 `bootstrap.gd` 中打印自测结果

## 3. 待确认规则

1. 羁绊统计范围：武器标签 + 遗物标签。
2. 同名遗物允许重复获得，受 `max_stack` 限制。
3. 当前阶段不做解锁、装填、互斥切换。
4. 特殊效果只记录，不执行。

## 4. 建议自测输出

```text
[Bootstrap] relic bond checks
[Bootstrap] - relic config load: passed
[Bootstrap] - relic max_stack limit: passed
[Bootstrap] - relic add modifier: passed
[Bootstrap] - bond tag count: passed
[Bootstrap] - bond threshold apply: passed
[Bootstrap] - special effects reserved: passed
```

## 5. 后续非阻塞项

- [ ] 遗物选择 UI
- [ ] 图鉴界面
- [ ] 稀有度权重系统
- [ ] 特殊效果执行器
- [ ] 羁绊界面预览

## 6. 结项判断

本模块可正式结项的条件是：

1. Godot 启动后能读取遗物与羁绊配置。
2. 能正确限制同名遗物最大数量。
3. 能正确统计标签并生效羁绊。
4. 能正确输出自测结果。
