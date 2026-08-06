# 工程基础设施模块实施 Checklist

本文档记录“工程基础设施模块”实施状态。该模块目标是提供稳定的工程入口、全局状态、对象池与启动自检承载能力，不直接承载玩法规则。

## 1. 当前状态

模块 MVP 已完成，当前可作为后续模块的稳定基础设施。

## 2. 已完成事项

- [x] 注册 `DataRegistry` Autoload
- [x] 注册 `GameGlobal` Autoload
- [x] 注册 `ObjectPool` Autoload
- [x] 建立 `scenes/core/bootstrap.tscn` 作为启动入口
- [x] 建立 `scripts/core/bootstrap.gd` 启动自测脚本
- [x] 支持基础数据模块自测输出
- [x] 支持后续模块追加 Bootstrap 自测
- [x] 保持工程基础设施与具体玩法逻辑解耦

## 3. 待你验证事项

- [ ] 在 Godot 中启动项目，确认 Autoload 无报错
- [ ] 确认 Bootstrap 能正常输出各模块自测结果

## 4. 后续非阻塞事项

- [ ] 根据模块增长拆分更细的测试场景
- [ ] 接入正式主菜单后，再决定是否保留 Bootstrap 为开发入口
- [ ] 如对象池使用频率提升，再补充对象池性能与泄漏检查

## 5. 结项判断

本模块的结项条件是：

1. 项目启动无 Autoload 报错。
2. Bootstrap 自测能正常执行。
3. 后续模块可以通过 Bootstrap 追加自测，不需要修改工程入口结构。

