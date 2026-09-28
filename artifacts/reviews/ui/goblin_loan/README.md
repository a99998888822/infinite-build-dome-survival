# 哥布林贷款 · 美术和 UI 审阅

贷款现已正式接入。以下三张来自真实理财流程：点击资金不足的禁用购买按钮三次，选择借款，再将借款存入银行。

- [实机贷款弹窗](loan_live_popup.png)：三档条款、逐字台词与即时可点的按钮。
- [实机银行贷款栏](loan_live_bank.png)：借 500 后存入，钱包归零，本金由 800 变为 1300，底部显示应还 600。
- [实机 640×360 银行](loan_live_small.png)：完整购买按钮、日志、刷新、开战和贷款栏。

另保留已审阅的图标和贷款栏状态总览，重复原型截图与动图已清理。

- [贷款栏状态对比](loan_hud_states.png)：关闭后的入口、已贷款、复利后的欠款和可主动还清。
- [像素素材](asset_board.png)：三档贷款图标、借据状态、复利状态，均有透明 PNG 原件。

三档基础条款为 100→140、200→260、500→600。现有遗物使预计新增利息超过融资成本时，首次报价会上调利率，之后锁定。下一波全部结息完成后检查钱包：足够则整笔还款，不足不扣钱、欠款计复利；可手动还清。死亡／通关的最终结算不额外追债，不抵扣营地币。

完整设计与已确认规则：[`docs/asset/goblin_loan_visual_review.md`](../../../../docs/asset/goblin_loan_visual_review.md)。

## 重建

绘图：`python -X utf8 scripts/tools/source_art/goblin_loan_art.py`。

实机验证与截图：运行 `scenes/tests/goblin_loan_test.tscn`，附加 `-- --transient-session --capture-dir=<临时目录>/live`。无图形模式验证规则和交互，有图形模式额外保存三张真实视口截图。Windows 图形验证使用 `--rendering-method gl_compatibility --rendering-driver opengl3_angle`。

运行 `scenes/tests/goblin_loan_visual_review.tscn`，附加 `-- --transient-session --capture-dir=<临时目录>/captures --movie-dir=<临时目录>/frames`。在有图形渲染的环境中捕获视口；传入 `--interactive` 可手动查看原型。图形驱动可按环境选择 OpenGL 或 ANGLE。

组装：`python -X utf8 scripts/tools/assemble_goblin_loan_review.py <临时目录>`。本目录只保留成品，原始帧和运行日志位于系统临时目录。
