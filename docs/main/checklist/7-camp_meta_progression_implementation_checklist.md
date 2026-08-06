# 局外营地与成长模块实施 Checklist

本文档记录“局外营地与成长模块”当前实施状态、待验证事项与后续非阻塞内容。

## 1. 当前状态

模块设计已完成，等待进入编码实现。

## 2. 实施目标

- [ ] 能读取 `camp_buildings.json`
- [ ] 能读取营地存档中的建筑等级与升级项等级
- [ ] 能在营地主界面展示 8 个建筑入口
- [ ] 能按解锁状态在“废墟 / 正式建筑”之间切换
- [ ] 能展示建筑等级效果与升级项列表
- [ ] 能购买局外升级项并写回存档
- [ ] 能把建筑升级效果转换为运行时属性或解锁状态
- [ ] 能把战斗结算结果回流到营地资源
- [ ] 能在 `bootstrap.gd` 中打印自测结果

## 3. 已确认规则

1. 营地采用固定场景，不做自由摆放。
2. 建筑只使用双态显示：未解锁显示废墟，已解锁显示正式建筑。
3. 营地建筑分为“建筑等级型”和“升级选项型”两类。
4. 建筑升级项只负责定义规则，当前购买等级写入存档。
5. 建筑升级项的属性必须对应 `StatDefinitions` 中已有字段。
6. 后续若新增建筑，只需补配置、补素材、补场景节点，不需要重写整套流程。

## 4. 建议自测输出

```text
[Bootstrap] camp meta progression checks
[Bootstrap] - camp config load: passed
[Bootstrap] - camp save load: passed
[Bootstrap] - camp ruins/unlocked swap: passed
[Bootstrap] - camp building levels: passed
[Bootstrap] - camp upgrade options: passed
[Bootstrap] - camp modifier sync: passed
[Bootstrap] - camp unlock sync: passed
```

## 5. 后续非阻塞项

- [ ] 营地主界面布局美化
- [ ] 建筑进入动画
- [ ] 建筑升级提示弹窗
- [ ] 局外资源统计面板
- [ ] 结算奖励回流提示

## 6. 结项判断

本模块可正式结项的条件是：

1. Godot 启动后能读取营地建筑配置与存档。
2. 营地里能按解锁状态切换废墟和正式建筑。
3. 能查看和购买建筑升级项。
4. 建筑升级效果能正确进入运行时数值或解锁状态。
5. 控制台能输出自测通过结果。
