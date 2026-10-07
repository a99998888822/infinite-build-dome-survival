# 小Boss胶囊与利息结算审阅

正式GameRoot场景使用临时进度，截图由Godot实际渲染；未改动玩家存档。运行通过 `scripts/tools/run_godot_background.py` 在私有Windows桌面完成，没有切换桌面或抢占前台。

- `boss_capsule_detail.png`：原图与实际胶囊轮廓的局部并排放大，最近邻3倍。绿色线仅存在于审阅脚本中，形状和位置直接读取正式碰撞体。
- `interest_receipt_detail.png`：普通窗口结算弹窗裁切，保留原始像素。
- `interest_receipt.png`、`interest_receipt_640.png`：1152×648及640×360完整截图。图标20×20，首字对齐，上下留白各6像素。
- `headless_summary.json`：编辑器检查及195项回归通过。
- `gpu.json`、`gpu.log`：GPU审阅全部通过，真实引擎窗口所属桌面与私有桌面一致，`foreground_samples=0`。

审阅脚本固定持有复利宝典和永续年金卷轴，展示稳定的三行结算；长明细滚动由正式 `interest_arrival_test` 另外覆盖。
