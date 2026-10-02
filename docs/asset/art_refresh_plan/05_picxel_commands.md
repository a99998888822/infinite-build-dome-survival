# 高清稿通过后的处理指令

本页区分两种“命令”：发给Codex的完整工作指令，以及确实存在的Picxel终端命令。日常推荐前者：Codex负责看图、标注、抠图和像素修整；你负责两次审美审阅。

最新执行顺序：先制作新美术，再按确认稿对齐工程格式。下述命令中的工程适配属于新稿完成后的预接入，不提前转换旧素材；大幅背景见08。

实际使用项目技能 `.agents/skills/picxel-external-images/SKILL.md`，不是全局Picxel生图入口。输入由豆包/Nano Banana等外部来源提供，因此处理阶段不再触发图像模型。本页提供通用命令，实际制作进度见README。

## 高清稿通过后复制给 Codex

### 命令A：单张或同批标准图标

下面只需补充“原图位置”和“任务键”。首张示例任务键为 `relic_piggy_bank`；其他键见 `icon_manifest.json`。

> 请按 `docs/asset/art_refresh_plan/` 的更新方案，使用项目 `picxel-external-images` 技能处理我已经审阅通过的高清稿。原图位置：【填写本地路径或使用本轮附件】；任务键：【填写英文任务键】。先读取对应提示词和icon_manifest，再观察原图，确认透明度、完整轮廓、最重要的识别特征。按技能打开本地面板，读取并尊重已有任务；使用新的修订目录，不覆盖已有确认稿。为实际原图创建anchor，必要时先抠图；从高清原图独立导出32×32、最多16色、硬透明、无抖色的像素图。武器只有本轮要求详情版时再独立导出64×64。观察原尺寸和4倍最近邻，对细杆、眼口、空隙和视觉重量做必要局部修整，逐张select并finish。交付像素原尺寸、放大图、亮暗背景及在项目实际槽位中的临时预览；记录原图哈希、色板、包围框与使用尺寸，等待我第二次审阅。暂不替换正式assets。

多张时一次最多20张；不同目标尺寸/动画不要混在同一批命令中。按 `icon_manifest.json` 的 `batch` 分组亦可；开始下一批前先完成或明确结束当前面板任务。

### 命令B：角色、怪物与动画工程导出

> 请按 `docs/asset/art_refresh_plan/02_doubao_recipes.md` 与 `07_standard_animation_frames.md` 处理已经批准的【角色/怪物名称】高清原图，位置【路径】。推荐玩家/天外幼体使用64×64、骑士使用128×128单帧，先完成新美术，不提前迁移旧素材。使用项目Picxel技能处理单帧并局部修整，锁定该角色的完整数值色板、主体尺度、画布、脚底/握持锚点和动作留白。默认逐图适配主体会造成动画大小跳变，必须采用经过验证的统一几何处理；不要把各帧分别放满64/128画布。保留每步来源和参数，对所有帧检查眼口、循环、镜像、持物、动作相位与接地，按原帧数/FPS组装动作图集。新稿完成后，根据实际资源的尺寸和锚点在审阅副本对齐工程裁框与显示位置，不将新稿直接塞入旧裁框。输出到新staging目录，附静态与实际动画预览；只处理本次已提供并确认的动作，不编造缺失帧，待我审阅后再正式替换。

64/128标准化可省去特殊帧尺寸导出，但动画固定几何仍需实现和检查。如果这一批明确保留旧54/86/160合同，再走“Picxel样板和色板＋固定几何的兼容导出”，不得编造 `--sizes 54` 等参数。07中的裁切坐标只适用于已测量的当前素材，不可直接套到新高清稿。

### 命令C：哥布林五表情与柜台

> 请使用项目Picxel外部图流程处理已确认的哥布林五表情及柜台，原图位置【路径】。五表情输出128×128，固定同一头部尺度、身体、双手接触线、视线和16色色板；逐图检查真实表情，不把同一张脸复制到五张图。当前状态顺序为neutral、downcast、displeased、smile、delighted，文件名按06约定。柜台最终128×64，从高清稿独立保留比例导出，不能把128方图纵向压扁；若从方形工作稿裁切，先证明只去掉透明区。检查银行中的HAND_CONTACT=(64,119)、柜台接触线24和底线56是否仍适用，必要时仅在审阅副本调整并记录。使用现有安装工具的组装函数预生成银行与结算图集，真实预览五种表情和柜台组合。完成导出后等待我的最终审阅，不覆盖正式资源。

### 命令D：仅属性栏大底图

> 请按09的范围处理已审阅通过的属性栏高清稿，原图位置【路径】，任务键 `ui_stats_drawer`。使用项目Picxel外部图片流程，保留金属包边、少量皮带和低对比内板；完整大底图保留竖向比例，明确记录本地矩形像素导出方法，不压成128方图或虚构CLI矩形参数。先依据实际原图确定像素网格和色板，新稿完成后再决定边框拆分和工程尺寸。提供原尺寸、放大图和仅替换属性栏底图的临时实机预览；日志按钮、顶部guide_bar、底部按钮、页签、独立拉手和理财框保持原样。当前320总宽包含28px拉手区、实际皮肤292宽仅作为工程现状参考，不提前迁移。等待像素审阅后再定向接入，不覆盖正式资源。

### 命令E：矩形背景、石台与天空

> 请按更新方案处理已确认的【首页背景/石台/天空】，原图位置【路径】。先核对现有场景的用途、视角和可行走区域。当前Picxel标准入口只有32/64/128方形输出，不要把横向背景拉成方图。保留原始宽高比，按方案和当前渲染基准建立矩形、分层的本地像素导出步骤，使用与Picxel相同的有限色板、网格化和局部修整原则。首页候选逻辑稿1152×648；石台当前1024×575、显示0.64倍，需在审阅副本比较原尺寸保持与按实际显示尺寸直接重采样两种方案，避免重复缩放；天空当前256×16加Shader，先从确认稿提炼色带，不直接拿全景图替代动态天空。独立保留天空、远景、前景与装饰，检查接地、地平线、砖缝颗粒、UI留白和亮暗可读性。新导出步骤需记录色板、矩形尺寸、层级、源图哈希及实际方法。输出审阅成品与临时实机预览，待我确认后接入。

### 命令F：30个湿地场景件

> 请按04中的英文任务键处理这批已批准的湿地高清原图，位置【路径】，每批最多20张。使用项目Picxel流程独立输出128×128、16色以内、硬透明，并检查每件的地面/立体观察角度。新图片通过后测量新的content_rect，暂时保留 `data_config/battle_scenery.json` 的world_extent及当前远近关系，不因透明画布相同而把所有物件显示成一样大。准备新路径/哈希/可见区域的审阅清单，测试远景入水、倒影、湿地撒点、遮挡和重复密度。当前环境安装器会重写默认尺寸并清理旧文件，先检查其行为，按确认范围接入，不能无条件运行。最终审阅前只写staging和临时预览。

## 标准 Picxel 终端步骤

以下是“猪猪存钱罐一张高清PNG→32像素审阅稿”的真实命令示例。其他标准方形素材只需换任务键、目标尺寸与anchor。**anchor必须在观察实际原图后创建；没有图片和anchor时，build不能运行。**

### 1. 路径和目录

```powershell
Set-Location 'D:\project\useless\resources\infinite-build-dome-survival'
$skillPath = Join-Path (Get-Location) '.agents\skills\picxel-external-images'
$taskPath = Join-Path (Get-Location) 'artifacts\previews\art_refresh_v1\relic_piggy_bank\r01'
New-Item -ItemType Directory -Force -Path (Join-Path $taskPath 'refs'), (Join-Path $taskPath 'prepared') | Out-Null
```

把已确认高清原图放到 `refs/relic_piggy_bank.png`。如已有r01的输出，使用r02；不要删除旧审阅结果后重跑。可编辑原图和输入副本保留。

### 2. 准备面板并读取现有任务

```powershell
$panelInfo = (& python -B "$skillPath/vendor/picxel/scripts/start_panel.py" --port 8771 --no-open | ConvertFrom-Json)
$pxPython = $panelInfo.python
$panelInfo.url
& $pxPython -B "$skillPath/vendor/picxel/scripts/picxel.py" job show
```

由Codex使用返回URL打开并验证面板；手工操作时可在浏览器打开该URL。端口不是固定结果，以返回值为准。有用户当前任务时先沿用其选择，不能用示例目录覆盖。面板启动不代表已完成转换。

### 3. 观察、抠图、创建anchor

Codex创建 `refs/relic_piggy_bank.anchor.json`。下列结构仅是填写示例，不能用它替代对真实输入的检查：

```json
{
  "subject": "已确认的猪形陶制存钱罐",
  "kind": "item",
  "size": 32,
  "keep": ["猪耳与鼻部轮廓", "圆腹与投币口", "确认稿的主体朝向"],
  "drop": ["纯色背景", "细小表面纹理"],
  "colors": ["实际确认稿中的灰陶色", "深色轮廓", "少量旧金"],
  "regions": [],
  "faces": []
}
```

需要共享色板时，另写完整16个 `#rrggbb` 数值的 `palette` 数组；这里只写文字不会锁色。复杂眼口应根据真实原图填写区域/视线，不能预先套用固定坐标。

抠图后写 `prepared/relic_piggy_bank.png`，尽量保持原画布。真实透明原稿可以省略prepared步骤。不要用原生棋盘格当透明通道，也不要全图删掉与主体同色的背景色。

### 4. 执行一次转换

已生成prepared透明PNG时：

```powershell
& $pxPython -B "$skillPath/scripts/external_pixel.py" build "$taskPath/refs" -o "$taskPath/work" --sizes 32 --prepared-dir "$taskPath/prepared" --background none
if ($LASTEXITCODE -ne 0) { throw 'Pixel build failed; inspect the report.' }
```

原图已有真实透明、未生成prepared时：

```powershell
& $pxPython -B "$skillPath/scripts/external_pixel.py" build "$taskPath/refs" -o "$taskPath/work" --sizes 32 --background none
```

上面两条是互斥选项，只运行一条。均匀底也可在确认算法适合后用 `--background auto`，有手臂/把手封闭空隙时仍需人工判断遮罩。

输出包括 `.pxg`、`.pal`、PNG、`review-*.png` 与 `batch-report.json`；此时是底稿，尚未完成视觉审阅。

### 5. 检查、修整、选择版本

```powershell
& $pxPython -B "$skillPath/vendor/picxel/scripts/picxel.py" show "$taskPath/work/relic_piggy_bank-32.pxg"
& $pxPython -B "$skillPath/vendor/picxel/scripts/picxel.py" check "$taskPath/work/relic_piggy_bank-32.pxg"
```

同时打开原尺寸和4倍图。需要修整时保存新`.pxg`，例如`relic_piggy_bank-32-refined.pxg`；不重跑build覆盖整批。下面以**观察后确认底稿无需修整**为例，若修整了就把`--sheet`改成真实最终文件：

```powershell
& $pxPython -B "$skillPath/scripts/external_pixel.py" select "$taskPath/work" --name relic_piggy_bank --size 32 --sheet "$taskPath/work/relic_piggy_bank-32.pxg" --note "Inspected native size, silhouette, palette and alpha."
if ($LASTEXITCODE -ne 0) { throw 'Selection failed.' }
```

程序check不代替眼睛判断；`select`的说明必须与实际检查一致。多图、多尺寸逐个登记，不能只选一张后假称整批完成。

### 6. 导出审阅成品并结束任务

```powershell
& $pxPython -B "$skillPath/scripts/external_pixel.py" finish "$taskPath/work"
if ($LASTEXITCODE -ne 0) { throw 'Finish failed; review missing selections.' }
```

成品位于work内的“成品图”目录，附原尺寸与放大预览。finish只是技术交付与结束面板任务；随后交给用户进行最终审阅，不自动安装进assets。

若因实际问题中止：

```powershell
& $pxPython -B "$skillPath/scripts/external_pixel.py" stop "$taskPath/work" --note "Stopped: input or visual defects require revision."
```

只对当前实际任务执行stop，保留已完成文件，不让面板一直转圈。

## 标准命令与特殊处理的分界

| 类型 | 已有CLI直接支持 | 必须额外完成 |
|---|---|---|
| 单张32/64/128图标 | build/select/finish | 视觉修整、目标槽位审阅 |
| 128湿地件 | 同上 | content_rect、world_extent、远近与入水验证 |
| 128表情 | 同上 | 同一几何基准、逐表情修脸、图集组装 |
| 32不透明平铺底纹 | `kind=tile`、方形源图 | 接缝与重复节奏修整 |
| 推荐64/128动画 | 支持单帧尺寸 | 先迁移工程合同；统一主体尺度与锚点，再组装动作图集 |
| 保留旧54/86/160动画 | 不直接支持这些尺寸 | 仅兼容旧接口时额外导出；不能逐帧自动适配 |
| 长条UI/矩形背景 | 不直接支持 | 拆件/分层、矩形导出、九宫格/平铺与实际布局 |

命令B～F就是这些步骤的下一轮完整工作任务。方案没有预先虚构未看到的手指、脚底或边框裁切坐标。
