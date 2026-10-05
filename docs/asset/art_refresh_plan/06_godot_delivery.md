# 从像素审阅稿到 Godot 正式素材

本页定义交付合同，不表示已经执行安装。先在独立 staging／审阅副本完成像素成品、布局适配与实机预览；用户确认这一批后，再覆盖正式文件。不要把 Picxel 的 `finish` 当作用户确认。

**角色尺寸方案更新：** 推荐按 [07 标准动画帧迁移](07_standard_animation_frames.md) 将玩家/普通怪改为64帧、骑士改为128帧。本页54/86/160表格保留为尚未迁移的当前事实，不再要求重绘继续沿用；正式迁移完成后再更新本页的当前合同。

## 每批交付目录

```text
artifacts/previews/art_refresh_v1/<batch>/r01/
  refs/                 原始高清图副本、来源、anchor
  prepared/             按需抠图，保留原始画布
  work/                 Picxel 网格、色板、报告、成品图
  export/               特殊尺寸导出脚本、几何参数、逐帧图
  staging/              sprites/... 与 ui/...，相对于 assets 的目录结构
  review/               原尺寸、4倍图、亮暗底、动画、实际界面截图
  delivery.json         这批真正交付的文件与审阅状态
```

`delivery.json` 在实际制作时记录：任务键、原图/最终图 SHA-256、对应配置 ID、高清/像素画布尺寸、alpha 可见包围框、色板数值、脚底/握持锚点、帧数/FPS/循环、正式目标路径、显示大小与缩放链、实际局部修整、用户确认范围。标准 Picxel 报告和特殊导出记录分别保存，不伪造转换过程。

角色动画帧可以使用 `walk_00.png` 至 `walk_07.png` 等临时英文文件名；正式安装只使用以下明确的图集名称。缺帧则继续绘制该动作，不能复制相同帧冒充动作完成。

## 当前尺寸与引用合同

以下路径均相对于 `assets/`。它们是保留当前工程布局时的规格。若需要迁移画布/显示档位，必须在同一批交付里同步改引用、裁切、位置和测试，不能只换图片。

### 图标

| 类别 | 当前资源 | 本方案目标 | 接入要求 |
|---|---|---|---|
| 遗物 | `ui/icons/relics/`，90张32×32 | 保留32×32 | 名称、配置 ID、透明边距和同屏视觉重量一致 |
| 武器 | `ui/icons/weapons/`，7张64×64 | 32×32主图；有需求才从高清独立出64×64详情图 | 同步原26/34/36等显示槽位；32px图不要再在34px槽位重采样 |
| 附魔 | `ui/icons/augmentations/`，10张16×16 | 32×32 | 原20px等显示槽位同步调整；功能颜色和轮廓双重区分 |
| 角色头像 | `ui/icons/characters/icon_void_hunter.png`、`icon_capitalist.png`，128×128 | 保留128×128 | 与战斗角色同身份；角色展示256版可明确采用128最近邻2倍放大 |

逐项真实文件名、ID和旧尺寸见 [icon_manifest.json](icon_manifest.json)。`weapon_void_blade` 是木弓的历史配置 ID，图标为 `weapon_wood_arrow.png`，不要因 ID 改画成剑。`scroll_lightning` 与 `scroll_electric_spark` 两条配置共用 `scroll_lightning.png`，保留此关系，除非用户另行要求分开设计。

### 玩家与普通怪

| 对象 | 正式文件 | 尺寸 / 动作 |
|---|---|---|
| 初心者待机 | `sprites/player/combat/void_hunter_idle_right.png` | 54×54，面向右 |
| 初心者移动 | `sprites/player/combat/void_hunter_walk_right_spritesheet.png` | 432×54，横排8帧，每帧54×54，7FPS |
| 资本家待机 | `sprites/player/combat/capitalist_idle_right.png` | 54×54，面向右 |
| 资本家移动 | `sprites/player/combat/capitalist_walk_right_spritesheet.png` | 216×54，横排4帧，每帧54×54，6FPS |
| 两玩家展示 | `sprites/player/void_hunter_idle_right.png`、`capitalist_idle_right.png` | 各256×256，与对应头像/战斗稿保持一致 |
| 天外幼体待机 | `sprites/enemies/combat/enemy_gloom_mite_idle.png` | 86×86 |
| 天外幼体移动 | `sprites/enemies/combat/enemy_gloom_mite_move.png` | 602×86，横排7帧，每帧86×86，每帧0.125秒 |

玩家54px帧以当前脚底基准 y=52 对照；最终脚底、主体高度与透明边距需一同核验。每个动作使用同一数值色板、同一缩放和画布，允许姿势改变包围框，禁止逐帧紧裁后各自放满画布。普通怪同时核对 `scenes/enemy/mutated_grub.tscn` 与动画裁切逻辑。左右镜像需检查持物和动作方向。

54/86不是标准 Picxel 网格，推荐按07迁移为64，再执行05命令B；只有需要保留旧接口时才另做54/86兼容导出。角色身份、服装错误退回高清阶段；最终小尺寸缺一格轮廓、眼口不清才属于局部像素修整。

### 钢甲骑士

目录 `sprites/enemies/iron_knight/`；每帧160×160，横排，统一脚底锚点 `(80,128)`。

| 文件 | 图集尺寸 | 帧数 | FPS | 循环 |
|---|---|---:|---:|---|
| `knight_idle.png` | 160×160 | 1 | 1 | 是 |
| `knight_move.png` | 1760×160 | 11 | 11 | 是 |
| `knight_windup.png` | 1120×160 | 7 | 8.75 | 否 |
| `knight_dash.png` | 320×160 | 2 | 12.5 | 否 |
| `knight_recover.png` | 320×160 | 2 | 4 | 否 |

当前死亡处理为定格当前姿势并淡出，无需凭空加一组死亡帧。盾与单手锤是当前身份；蓄力、冲刺与收招要对齐攻击时序。安装工具会重建 `iron_knight_sprite_frames.tres` 和 `manifest.json`。当前160是含透明留白的画布，全部动作可按07固定裁入128并补偿显示位置，无需缩小可见像素；后续重绘推荐直接采用128合同。

### 银行与结算

五张输入均为256×256 RGBA：`goblin_neutral.png`、`goblin_downcast.png`、`goblin_displeased.png`、`goblin_smile.png`、`goblin_delighted.png`，顺序索引0至4。2026-10-04按已确认鼻口描线方案更新，原有UI显示尺寸保持不变。

- 银行：`ui/finance/goblin_banker_states.png`，1280×256，横排五表情。
- 结算：`ui/settlement/goblin_reactions.png`，1024×1024；四行对应表情索引 `[4,2,3,1]`，每行四帧上下位移 `[0,-2,0,2]`。头顶/底部必须留出这2px活动余量，显示缩放后维持原有呼吸幅度。
- 柜台：`ui/finance/bank_counter_desk_picxel.png`，128×64，单独导出，不能压扁方形图。
- `scripts/ui/bank_counter_portrait.gd` 当前人物接触点 `(64,119)`、桌面接触线 y=24、桌底 y=56、人物相对比例0.60；重绘后观察手是否真实搭在桌沿上。五张人物保持同一身体尺度，标准流程逐图自动紧裁可能破坏接触线，需在最终组装前统一画布与锚点。

### UI与首页

最新UI范围见 [09](09_ui_scope_and_stats_redraw.md)。取消统一面板／按钮主题的安装建议，不新增全UI共用母板。当前只制作属性栏专用大底图，保留金属包边和少量皮带；新高清稿与像素稿审阅后，再依据装饰分布确定固定边角、延展区或分层方案。

属性栏总宽320含28px拉手区域，皮肤实际宽292，原美术基准313px。这些是现状，不提前迁移。日志按钮、顶部guide_bar、底部按钮、页签和独立拉手保留原样；不得通过全局 `FinanceUIStyle` 或共享主题扩大替换范围。理财大框后续单独确认。属性文字、贷款金额和按钮文案继续由Godot绘制。

首页 `ui/main_menu/bg_main_menu.png` 当前1920×1080，候选重绘交付为1152×648逻辑背景；最终按P0的窗口/视口决策确定。标题 `title_main_menu.png` 使用可校验中文排版；按钮 `button_main_menu.png` 保留原样。标题、按钮、装饰和背景分层，避免背景里烘焙文字。

### 战场、武器实物与特效

| 素材 | 当前合同 | 接入关注 |
|---|---|---|
| `sprites/background/wetland/` | 30张128×128 | 重算新alpha内容范围 `content_rect` 与 SHA-256；保留已确认 `world_extent`，不能按同画布就统一物理大小 |
| `sprites/background/background-stone-brick-floor.png` | 1024×575，现显示比例0.64 | 宽高比、石台外缘、可行走区域与碰撞一致；P0比较保持画布与按实际显示尺寸导出，避免重复非整数缩放 |
| `sprites/background/background-sky-Recovered.png` | 256×16色带，供现有Shader使用 | 保留动态天空；概念全景不能直接替换色带 |
| `sprites/weapons/weapon_nightwatch_spear.png` | 248×28 | 朝向、握点、枪尖与命中范围对应；与图标是两个文件 |
| `sprites/weapons/projectiles/projectile_wood_arrow.png` | 24×24 | 箭尖前向、旋转轴与弹道一致 |
| `sprites/weapons/meteor_flail/` | 头40×40、柄12×32、链节9×7 | 三个部件分别导出；链节连接与握柄位置正确 |
| `sprites/weapons/rentier_coin_spin.png` | 128×16，8帧16×16 | 同轴旋转、不跳尺寸；每帧从确认母稿/局部像素绘制完成 |
| `sprites/weapons/weapon_kunyu_ritual_tome_animated.png` | 256×64，4帧64×64，预览原型资源 | 正式战斗不显示书本，仅预览脚本仍引用；P6按需统一，不为重绘恢复书本显示 |
| `sprites/weapons/kunyu_domain_rune.png` | 现有领域符文，正式战斗使用 | 与书本封印图案统一，保留领域Shader/程序绘制的时序和透明变化 |

这些矩形和小部件不接受虚构的Picxel `--width/--height` 参数。固定尺寸导出需记录输入、色板、几何参数和检查结果；极小链节等可按确认母稿直接进行像素绘制。`build_nightwatch_spear_art.py` 是旧设计绘制器，不是新高清稿安装器，不能用它安装新枪稿。

现有脚本绘制的闪电、爆炸、光晕和粒子优先统一色彩、形状与颗粒尺度。硬透明规则适用于本体像素图；Shader生成的发光/雾需要单独验收，不能简单删除所有半透明效果。

## 安装工具与使用条件

从项目根目录执行。当前工具说明在 [ASSET_INSTALLERS.md](../../../scripts/tools/ASSET_INSTALLERS.md)。以下检查命令只读，按本批涉及的类别选择：

```powershell
python -B scripts/tools/install_player_picxel_assets.py --check
python -B scripts/tools/install_iron_knight_assets.py --check
python -B scripts/tools/install_goblin_portraits.py --check
```

前两类安装器的 `--source` 输入布局以 `assets/` 为根，例：`<staging>/sprites/player/combat/void_hunter_idle_right.png`，不要再套一层 `assets`。玩家工具要求两个角色的完整8个文件；综合工具要求玩家、普通怪和骑士全部15个文件；不完整的首批样板不能直接传给这些完整批次入口。

用户确认后，完整批次可按需执行下列**对应的一条**，`<...>`由实际目录替换：

```powershell
python -B scripts/tools/install_player_picxel_assets.py --source '<approved_staging>'
python -B scripts/tools/install_iron_knight_assets.py --source '<approved_staging>'
python -B scripts/tools/install_goblin_portraits.py --source '<approved_five_portraits>'
```

哥布林输入目录直接含五张单图，其余图集由安装器组装。若要先做审阅图集，调用其 `install_assets(source, asset_root=<独立staging>)`，不能把默认写正式资源的CLI当成预览命令。柜台图片另行接入。

部分角色批次由Codex调用 `install_combat_picxel_assets.py` 中的 `validated_assets(subjects=(...), source_root=...)` 先检查指定对象；确认后调用 `install_assets(subjects=(...), source=..., asset_root=...)`。`subjects`仅用实际已完成的 `beginner/capitalist/enemy/boss`。若只批准待机样板，先保留在审阅区；不要把未批准动作混进安装批次。

环境工具当前接口为：

```text
python -B scripts/tools/install_battle_environment_assets.py <package_root>
```

其输入要求 `<package_root>/128px/01_*.png` 至 `30_*.png`，编号对应脚本 `SPECS`。**此工具会重写配置里的默认世界尺寸、来源字段，并清理指定旧文件。** 当前方案要求保留已确认物理尺寸，因此应先调整为保留这些字段的安装流程，或仅针对批准文件复制并更新 `content_rect/hash`；不要直接运行上面示意命令。04和覆盖表保留当前世界尺寸供对照。

图标、UI和首页没有同等通用安装器：按批准范围核验PNG、目标路径与消费端，然后定向更新。保留现有 `.import`，新增图让Godot正常导入，不手写 `.gd.uid`。若首次迁移32px档位或九宫格，必须包括相关 `.gd/.tscn/.tres/.json` 的小范围修改。

## 画清楚还需要显示清楚

P0记录完整链条：原始像素画布 → alpha可见范围 → Sprite/Control显示尺寸 → Camera/Canvas缩放 → 逻辑视口 → 窗口/系统缩放。当前1152×648逻辑画面到1920×1080约1.667倍，即使用最近邻也可能出现像素宽度不均；开启最近邻不能消除非整数缩放。

在审阅副本选择并验证一种策略：保持逻辑视野并整数缩放配合留边，或根据窗口调整逻辑视口同时维护预期游玩视野/UI尺寸。后者涉及相机和布局，不能仅改一项窗口数值。不要为追求整数缩放擅自改变怪物体积、攻击范围和难度。

像素本体使用最近邻、避免有损压缩，检查 `TextureRect`、Sprite、父节点和项目设置是否覆盖过滤方式；是否需要mipmap按实际用途决定，UI和1:1像素本体通常关闭。字体现有渲染方式独立处理，正文对比和小字号可读性比机械像素化更重要。

## 验收与完成条件

1. **文件**：每项尺寸、RGBA、可见色数、0/255 alpha合格；不透明底纹/背景允许全255；旧安装器要求透明角色同时包含0与255。图集整套共享色板，帧数/帧序正确；新文件对应当前配置，而非过时预览包。
2. **像素**：原尺寸能识别主体，4倍最近邻没有残边、孤立噪点或轮廓断裂；亮暗底都能读；细长武器、阴暗怪物和同类遗物不混淆。合法瞳孔/高光不要按警告数自动删除。
3. **运动**：无脚滑/大小闪变/多肢；循环首尾衔接；持物与攻击窗口、碰撞/投射物方向相符。
4. **界面**：1152×648与1920×1080实际渲染截图记录真实窗口/逻辑视口；属性栏、银行、附魔、商店、首页同屏比例一致，无文字遮挡、边框变形和木纹拉伸。
5. **工程**：完成导入、相关既有自测和实际渲染检查。仅通过图片脚本不算接入完成，headless运行不代替图像审阅。

已定位本机Godot控制台程序。接入时再验证可执行文件仍存在，导入命令为：

```powershell
$godotExe = 'D:\soft\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $godotExe)) { throw 'Re-locate the Godot executable before validation.' }
& $godotExe --headless --editor --path 'D:\project\useless\resources\infinite-build-dome-survival' --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed; inspect the log.' }
```

运行时验证在**包含候选修改的隔离审阅副本**进行，并设置独立 `user://` 保存位置；不要让审阅场景覆盖真实玩家存档。先确认审阅副本已经配置独立保存位置，再运行：

```powershell
$reviewProject = '<isolated_review_project>'
& $godotExe --headless --path $reviewProject --scene 'res://scenes/core/game_root.tscn' --quit-after 120
```

按改动选择已有 `scenes/tests/battle_environment_test.tscn`、`iron_knight_test.tscn` 或 `finance_preparation_test.tscn`，以同样 `--scene` 方式运行。保存日志并检查 Parse/Compile/SCRIPT ERROR、自测失败和导入警告；退出码为0也不能替代日志检查。120帧只是启动冒烟检查，不能证明所有交互正确。

实际视觉验收需启动可渲染窗口，交互打开相关面板、观察动画和截图。此前审阅使用GL Compatibility/ANGLE能够渲染；按本机可用渲染后端验证，不把headless截图描述为真实显示结果。本次只整理方案，尚未执行新素材的这些验收。

## 确认后的接入指令

用户完成第二次审阅后，可复制下句并填写本批成品目录：

> 我已确认【成品目录/修订号】这一批像素成品及项目内预览，请按 `docs/asset/art_refresh_plan/06_godot_delivery.md` 正式接入【具体任务键/对象】。核对确认范围和文件哈希，仅安装本批批准版本，保留原始高清图与审阅记录，保护现有其他改动。根据现有安装器的真实输入合同执行；特殊尺寸、图集、content_rect、显示槽位、九宫格与过滤设置一起同步。若环境安装器会重写无关尺寸，采用保留现有world_extent的定向流程。完成Godot导入、相关已有自测和1152×648／1920×1080实际渲染检查，交付最终截图、动画、改动文件与验证结果，并更新本批delivery.json。发现超出已确认范围的造型变更或缺失动作时，明确记录并保留未完成项，不把技术检查通过称为全批完成。

该指令把“确认像素稿”与“覆盖正式资源”的范围说清楚。收到后按已有授权执行，无需再重复询问同一批安装许可。
