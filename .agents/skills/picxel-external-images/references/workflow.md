# 操作参考：外部原图处理

## 面板设置与状态

只打开／初始化时，启动并展示项目面板、执行 `picxel.py job show` 后结束，不处理历史输入。实际制作时优先沿用本轮对话及对应面板的选择；缺少的信息才询问。面板只保存设置和展示产物，需要聊天指令驱动助手。

项目面板和全局面板使用不同任务文件。用户本次在全局面板选好图时，可以复制选择，不让用户重选：

```powershell
python -B <skill>/scripts/external_pixel.py adopt-job <global-job.json> -o <new-work>
```

`<global-job.json>` 通常是用户目录下 `.picxel/current-job.json`，也可为用户明确交给本任务的其他兼容任务文件。先读两个任务，核对确属本次选择；项目当前正在运行／等待答复时优先继续原任务，不自动中断。`adopt-job` 保留文件列表和尺寸，使用新的独立输出目录，原任务文件、原输出和状态不变。向用户说明实际输出位置。复制的是设置，不会导入旧成品或开始转换。

输入已在聊天里给出时，可在 UTF-8 脚本内导入本技能 `vendor/picxel/scripts/panel.py`，调用 `panel.save_job({"import": ..., "export": ..., "mode": ..., "files": [...], "sizes": [...]})`。不要导入全局安装。`save_job` 会拒绝覆盖活动任务；即使状态为等待，仍检查是否有需要保留的旧产物。`build` 使用新修订目录，明确传入选择的尺寸；若 refs 有其他 anchor，使用 `--only` 对齐面板文件列表。

| 阶段 | 状态操作 |
|---|---|
| 配置输入 | `save_job` 或 `adopt-job`；保持 waiting |
| 首次转换 | `external_pixel.py build` 内部保存任务并启动；不要预先 `job start` |
| 等待必要信息 | 项目 `picxel.py job ask --note "..."`，停止转圈 |
| 恢复已有底稿的修整 | 项目 `picxel.py job start`；不重建任务，保留 started |
| 接着创建新的修订任务 | 先完成或停止旧任务，再 `build`，不要覆盖 running／asking |
| 交付 | `external_pixel.py finish` 核验并结束；不能用 `job done` 绕过它 |
| 失败／中断 | `external_pixel.py stop <work> --note "..."`，保留现有报告和图 |

产物齐全且经过助手看图检查后即可 `finish`，不必等用户审美确认才结束面板。若任务只要求打开面板，就不调用以上制作状态命令。

## Anchor 与输入准备

`refs/hero.png` 配套 `refs/hero.anchor.json`。使用 JSON UTF-8，最小示例：

```json
{
  "subject": "对实际输入的简短描述",
  "kind": "sprite",
  "size": 128,
  "keep": ["可辨识轮廓", "原始姿势和比例", "关键配饰"],
  "drop": ["背景", "高频织物纹理"],
  "colors": ["按实际图片填写材质色系"],
  "regions": [],
  "faces": []
}
```

根据原图填写，不将示例当作默认观察。完整字段见 [anchor 规范](../vendor/picxel/references/anchor.md)。`palette` 是最多 16 个小写 `#rrggbb`；放入完整 16 色可固定整批色板。只有命名 `colors` 并不会锁色。少于 16 个 palette 项是保留色，程序仍会补足其他颜色。

复杂脸需 `faces`，记录原图眼睑开合、瞳孔相对眼白的位置、眉形和嘴形。`faces[].box`、`regions[].box` 是高清图的归一化坐标；最终像素坐标必须重新观察，不能直接乘 128。保留不同表情原本的姿势差异。

选图尽量来自同一目录，一次最多 20 张；同名不同扩展名在原图副本中改成唯一名称。依据本次用途从现有素材找参照，不将某个历史哥布林色板默认用于所有角色。确认样例应使用实际还存在的文件路径；旧文档中的历史输出路径可能已经清理。

## 抠图与尺度

- `--background none` 保留已有 alpha；`auto` 从边缘连通区域去除近似底色，不识别复杂背景，也不会主动删除封闭的手臂／把手空隙。
- `key:#rrggbb` 会移除内部技术底色并处理窄边溢色；仅用于确认不在主体内的颜色。
- 需要局部遮罩时，用 Pillow 对原尺寸图绘制或修改 alpha，输出到 `prepared/`。每张图检查实际背景种子；不要复制哥布林的手臂空隙坐标到别的角色。
- prepared 尽量保留原始画布，避免 anchor 权重坐标失配；如果裁切、旋转、改变姿势，必须同步坐标和来源记录。
- Picxel 会根据可见主体范围留出输出边距，以每格色彩投票得到像素。半透明输入在网格阶段二值化。此方法不会执行语义重绘。
- 同一角色若要求动画帧严格对齐，应另外记录统一画布、缩放和锚点；默认逐图按主体范围适配，不能把其结果直接宣称为无抖动动画。用户只要表情图时不自动制作动画。

## 局部修改

先查看需要的窗口：

```powershell
python -B <skill>/vendor/picxel/scripts/picxel.py show <work>/hero-128.pxg --box 46,44,80,60
```

Python 局部修整示例（坐标与颜色必须来自实际观察）：

```python
import sys
from pathlib import Path
sys.path.insert(0, str(skill / "vendor/picxel/scripts"))
from px import Grid
from picxel import load, render, check

grid, meta, colors = Grid.load(work / "hero-128.pxg")
symbols = {hex_color: symbol for symbol, hex_color in colors.items()}
# 根据观察使用 grid.replace(..., box)、grid.line(...) 或 grid.put(...)。
# 不同文件的符号顺序可能不同，不能硬编码某个字母表示金色。
target = work / "hero-128-detail.pxg"
grid.write(target, target.stem, "sprite", colors, palette=meta["palette"])
sheet = load(target)
assert not check(sheet)[0]
render(sheet, work)
```

眼口局部修整使用 [faces 规则与 patch 格式](../vendor/picxel/references/faces.md)：

```powershell
python -B <skill>/vendor/picxel/scripts/picxel.py face <work>/hero-128-detail.pxg --anchor <refs>/hero.anchor.json --patch <work>/hero.face.json
```

该命令输出 `hero-128-detail-face.pxg` 和 PNG，限制修改范围与透明轮廓。修改后看原图与结果，只有实际核对后才调用 `external_pixel.py select`。复杂脸也可能不需要修改；看清楚后可直接选择底稿。

`select` 保存底稿到 `work/base/`，把所选版本渲染成面板需要的 `hero-128.png`／`@4x.png`。它不会自动推断视觉质量，`--note` 应记录实际检查结果。若重新修改了选定网格，需重新登记；不要重跑 `build` 覆盖整批。

`show` 不带参数只打印摘要；`--box` 的列号从所选窗口的 x0 开始，不能把左边第一列当作全图 0。只有确实需要整张网格时使用 `--full`。形状修改优先使用 `Grid` 的 `rect`、`disc`、`line`、`put` 等方法；描边在关键小细节之前完成，或保护这些色号。当前 `select` 要求所选图纸遵守本资产 `.pal`，补眼口颜色也必须在此色板内；需要重新取色时建立新修订，不绕过登记检查。

只重做实际有问题的资产：

```powershell
python -B <skill>/scripts/external_pixel.py build <refs> -o <new-work> --sizes 128 64 --only hero potion
python -B <skill>/scripts/external_pixel.py review <work>
```

`--only` 按原图文件名去掉扩展名匹配，每次最多处理 20 项；仅记录所选输入的哈希。子集报告不是原批次的完成报告，不把新结果覆盖进旧任务目录。`review` 根据报告中已登记的版本刷新总览，不转换图片、不改变验收状态。修整完先 `select` 再刷新，无需重跑 batch 或另写总览生成器。

## 验证与展示

程序检查：文件尺寸、最多 16 色、palette 成员、透明角与轮廓边距、alpha 0/255、原图哈希、PNG 与所选网格一致。孤立颜色是提醒而非失败。

视觉检查：原尺寸能否辨认，眼白是否变成发光眼，瞳孔方向是否移动，笑容是否变成怒容，细链是否断开，手指是否黏连，主体是否残留背景，暗色衣服是否失去材质。不要在修眼后全图平滑。

单张优先展示原尺寸和 4 倍最近邻预览；多表情可提供带标签的对照图。主图必须来自实际 PNG，不能用另外生成的示意图代替。说明 checkerboard 只用于预览底，PNG 本体透明。`work/<name>.concept.png` 是兼容面板的文件名，含义是“外部原图的预处理版本”，不是生成模型的产物。

失败时保留报告和已完成文件，停止面板任务。不要把 `base-ready`、色数合格或 `finish` 当作用户已经批准美术风格。

## Windows 与依赖

核心只需 Python 与 Pillow。`start_panel.py` 会先检查依赖，需要时只在该运行库 `.venv` 安装 Pillow；使用它返回的 Python。开发测试可用 `python -B <skill>/scripts/test_external_pixel.py`，其输出和面板状态隔离在临时目录中。

含中文的新文件用 `apply_patch` 或明确 UTF-8 文件写入；PowerShell 读取加 `-Encoding UTF8`。避免含中文的内联脚本和 shell here-string。检查替代字符，不单凭终端显示判断编码。此技能本体与依赖都用相对位置解析，不依赖某个用户名、D 盘路径或全局 Picxel 安装。
