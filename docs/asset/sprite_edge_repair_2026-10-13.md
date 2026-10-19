# 立绘与场景轮廓修复审阅

2026-10-19：独立桌子已按后续审阅要求从正式资源、素材索引及修复安装流程中删除，宽屏理财背景保留。下文独立桌子的图片与采用说明仅为历史记录。

后续战场审阅已明确删除 P01–P05 五项石材（弧形残墙、斜坡断墙、石块、断裂长石柱、砖石残墙）。对应工作目录原图、处理图、正式资源及清单条目均已清理；下文为最初修复批次的历史记录，已删除条目的旧图片链接不再有效。当前战场资源以 `docs/asset/cavern_battle_current_review.md` 和最新障碍物图册为准。

用户已确认采用石材、哥布林、桌子柜台和两名玩家的修复版本；四类怪物及动作不采用，已恢复修复前的正式资源、图集引用、缩放及发射点配置。本轮使用本地像素修整，没有调用图片生成模型。

正式启用 19 组审阅资源。`production_selection.json` 记录采用范围和恢复文件，页面及 `runtime_approved/` 展示当前实机。清理后已移除怪物候选、旧试装截图及重复原图副本；保留正式资源、原始输入、207 个回退备份文件和最终校验日志。

按采用范围恢复后，Godot 无界面导入通过；骑士／蠕虫 73、蝙蝠 35、冥狼 73，共 181 项相关回归通过。实机捕获后保留 32 张与已采用素材、整场景及窗口尺寸有关的截图，捕获及两次 GPU 回归的 `foreground_samples` 均为 0。日志为 `tests/approved_*.log`，捕获记录为 `approved_capture.json`。

## 审阅入口

- 本地服务：<http://127.0.0.1:8784/>
- 可直接打开的页面：`artifacts/previews/edge_repair_20261013/index.html`
- 页面按 **原图／可追溯源 → 原正式素材 → 修复后素材 → 修复后实机** 展示已采用的 19 组资源；玩家动画可以逐帧对照。
- `review/catalog.json` 记录每组文件、来源及哈希；`before_manifest.json` 记录修复前的不可变备份。

以下路径均相对于 `artifacts/previews/edge_repair_20261013/`：

| 类别 | 四阶段对照 | 实机整图 |
| --- | --- | --- |
| 10 种石柱／石墙 | `review/stone_1.png`、`review/stone_2.png` | `runtime_approved/stone_*.png`，覆盖当前配置引用的 5 种 |
| 哥布林五种表情 | `review/goblin_1.png` | `runtime_approved/goblin_0.png` 至 `goblin_4.png` |
| 独立桌子、宽屏柜台 | `review/finance_1.png` | `runtime_approved/finance_960.png`、`finance_1280.png` |
| 初心者、资本家 | `review/player_1.png` | `runtime_approved/*_walk_*.png`，附 `review/*_runtime.gif` |

上表实机路径统一使用 `runtime_approved/`；旧 `runtime_delivery/` 已清理。原版怪物仍可在整场景截图中查看。

### 来源缺口

- 石材高清原图未留存。第一列是从 Git `f1f746e` 恢复的 128×128 历史像素源，明确标注为历史源。
- 小窗口独立桌子的来源清单仍有 `finance_bank_desktop.png`，但文件已缺失。原图列留空，保留原正式素材、修复后素材和实机列。
- 玩家原始动作输入仍在，但旧逐帧映射记录未留存；第一列作为角色原始输入参考，不宣称与每一帧精确对应。完整原始输入位于项目 `artifacts/sources/`，`source_integrity.json` 记录清理前后的完整性核验。
- 当前未被战场配置引用的另外 5 种石材已修整，实机列明确标为备用，不伪造其自然出现场景。

## 修复内容与原因

原素材的外轮廓存在浅色断点；玩家、怪物的非整数显示缩放还会采样掉细线。修复同时处理素材轮廓和正式显示尺寸。

- 石材：加强外轮廓，保留内部裂纹及落地苔藓的颜色与形状。
- 哥布林：修补外边缘，保留五种表情的眼口内部、透明轮廓与手部细节。“欣喜”原素材已满足本轮轮廓要求，PNG 未改；其余四张已修复。同步可编辑网格、理财图集和结算图集。
- 桌子：补齐独立桌子的外边缘，以及宽屏柜台木结构线。宽屏背景在原 688×384 可编辑像素底稿上修整，按原方式合成卷轴，保持 2752×1536 最终画布。
- 玩家：正式启用 `assets/sprites/display_clarity/player/` 中的 80px 显示帧，把原 1.2 倍显示比例转入像素素材，常规节点缩放为 1。这些是显示适配产物，不是新高清原画；保持动作时序与碰撞逻辑，轮廓边界的栅格取整偏差不超过 1.6 个世界像素。
- 怪物：蠕虫、蝙蝠、钢甲骑士和冥狼全部恢复原正式素材与显示契约。未采用的候选帧已清理，维护脚本不再生成或安装怪物修复稿。
- 理财立绘：最终显示尺寸和位置取整，减少落在半像素位置造成的边缘不稳定。

## 验证

- Godot 4.7.2 无界面编辑器导入通过，无 Parse／Compile／SCRIPT ERROR。环境仍提示 Android build-tools 目录不可用，与本轮资源无关。
- 已采用的 28 帧通过色数、二值透明度、画布裁切与轮廓体型检查；财务宽屏含高清卷轴的合成图不套用整图 16 色规则。
- 采用范围调整后的 181 项相关回归通过。
- 保留的实机截图含 1152×648、1280×720、1536×864，以及理财紧凑布局 960×540。截图读取正式游戏视口；审阅场景固定姿态、暂停刷怪，未补画或改色，不作为帧率测试。
- 实机运行使用 `run_godot_background.py` 的独立 Windows 桌面，实际桌面核验一致，`foreground_samples=0`，未抢占用户焦点。
- 正式文件与安装候选哈希一致，修复前备份完整；原动作输入、旧玩家与怪物源文件保持完整，可编辑网格与最终 PNG 一致。

最终校验见 `delivery_validation.json`；清理文件清单及释放空间见 `cleanup_report.json`。清理未修改正式游戏资源或原始输入，回退备份哈希全部通过。

## 复现

在项目根目录执行：

```powershell
# 从不可变备份重建候选；不会覆盖正式资源。
python scripts/tools/repair_sprite_edges.py
# 仅安装用户已采用的类别，跳过怪物；同步图集与来源清单。
python scripts/tools/repair_sprite_edges.py --install
# 更新审阅图和页面，要求 runtime_approved 已有实机截图。
python scripts/tools/build_sprite_edge_review.py
# 核对交付包、正式资源、来源与可编辑网格。
python artifacts/previews/edge_repair_20261013/validate_delivery.py
```

捕获场景：`scenes/tests/sprite_edge_review.tscn`；通过 `scripts/tools/run_godot_background.py` 执行并传入 `--capture-dir=artifacts/previews/edge_repair_20261013/runtime_approved`。捕获器查询正式场景的确定性生成位置，再移动相机拍摄全部在用石材。
