# 哥布林立绘256版接入

## 当前正式版本：分层阴影 r8

2026-10-04，用户审阅五种表情的实机截图后批准替换正式资源。当前版本为 `20261004-shaded-all-r8`：脸部、帽子、衣服沿用 face-r7 样例的分层像素阴影，手部保持原样。五张均为256×256、RGBA、二值透明、最多16色；PNG、PXG、PAL已同步安装到 `assets/ui/finance/portraits/`。

默认表情保持 face-r7 确认稿逐字节不变，SHA-256为 `efbf56a01bbfb1739d4ed148ea1540c77372439e31254d076152e57b176374dd`。其余表情分别定位脸部与衣料光影；为保留16色限制，合并少量近黑色和非张嘴表情中的零散暗红色，欣喜表情保留口腔暗红。当前每张色板以同名PAL为准，来源清单保留原始裁切信息。

银行和结算图集与已审阅图集逐字节一致，帧序、尺寸、上下位移和UI布局沿用原设置。银行、借贷和结算均通过原有正式资源路径加载，无需审阅纹理替换脚本。重建命令仍为下文安装器命令，输入当前正式立绘目录。

当前来源、裁切和正式PNG／PXG／PAL哈希见 [source_manifest.json](../../../assets/ui/finance/portraits/source_manifest.json)。2026-10-05按用户要求清理 `artifacts/previews/goblin_expressions/` 中的中间稿、重复资源及安装日志，本文保留必要安装和验证结论。正式资源实机复验保存到 `C:/Users/mi/.codex/visualizations/2026/10/04/01a104c9-baaa-7751-9d04-db1d997cefc6/goblin-shaded-official/`。

正式资源复验通过：headless editor导入与实际界面检查均退出0，无错误或警告；私有桌面实机捕获11张截图，实际引擎桌面验证一致，`foreground_samples=0`。从GPU读回的正式图集alpha及所有可见像素与确认稿一致，借贷和结算确认引用正式图集。验证记录为同目录 `official-verification.json`，完整截图见输出目录的 `review.md`。

## 首次256版接入记录（阴影更新前）

2026-10-04，按用户确认的鼻口描线修整方案完成五种表情并替换正式资源。来源为 `artifacts/sources/goblin/gobline_face.png`；采用项目 Picxel 外部图片流程，原图抠图、限色、网格化，再分别提取原图鼻口描线做局部修整，没有使用图片生成API。

默认表情PNG保持用户确认稿逐字节不变，SHA-256为 `d8f35997455a49133721b127e83f36cce5b0c833463c6388d53c4fac0a7a0279`。另外四张分别保留失落、咬牙不悦、不对称微笑和张嘴欣喜；各张均为256×256、RGBA、二值透明、最多16色。沿用确认稿15种实际使用颜色，张嘴欣喜额外使用暗红口腔色。

正式PNG、PXG、PAL位于 `assets/ui/finance/portraits/`，来源、裁切和哈希见该目录的 `source_manifest.json`。可从当前编辑源继续修整，不依赖中间审阅稿。图集重建：

```powershell
python scripts/tools/install_goblin_portraits.py --source assets/ui/finance/portraits
python scripts/tools/install_goblin_portraits.py --check
```

银行图集为1280×256，依次为默认、失落、不悦、微笑、欣喜。结算图集为1024×1024，行表情索引仍为 `[4,2,3,1]`，每行四帧上下偏移为 `[0,-2,0,2]`。银行、借贷和结算根据图集尺寸裁切，保留原有UI显示大小、位置和逻辑；借贷取微笑帧。PNG四周透明余量容纳结算位移，安装器验证没有裁掉不透明像素。

验证结果：

- Godot 4.7.2 headless editor导入退出0，无解析、编译或导入错误。
- `finance_preparation_test` 全部断言通过；日志有4次 `weapon_instance.gd:700` 武器提示字符串格式错误，来自本轮未修改的武器逻辑，未将其计为立绘验证通过的证据。
- `finance_scene_regression_test` 38项、`goblin_loan_test` 73项、`run_settlement_test` 153项全部通过，后三组无错误或警告。
- 私有Windows桌面实机捕获11张1280×720截图：银行五表情、附魔、真实借贷弹窗、四种结算。截图脚本核对正式图集尺寸、逐帧裁切及实际界面状态；实机日志无错误或警告，退出0，`foreground_samples=0`，实际引擎桌面与私有桌面一致。
- 审阅脚本使用临时存档会话；银行通过原有反应函数切换表情，结算通过原有呈现函数显示四种报告。全部截图为实际视口渲染。

本轮实机截图与验证日志：`C:/Users/mi/.codex/visualizations/2026/10/04/01a104c9-baaa-7751-9d04-db1d997cefc6/goblin-256/`，完整截图入口为 `review.md`。
