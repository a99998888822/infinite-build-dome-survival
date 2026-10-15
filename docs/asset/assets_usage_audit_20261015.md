# assets 正式素材使用盘点（2026-10-15）

> 本文为本次删除前的库存快照，保留原分类和逐项证据。用户确认清理后已删除 117 个媒体素材，当前剩余 426 个；执行结果见[素材清理记录](assets_cleanup_20261015.md)。下文 543、39、78 等数字均为清理前数据。

统计当前工作区（包含未提交修改），目录实际名称为 `assets/`。这是代码与配置的静态接入审计，未做逐帧运行覆盖率验证。

## 结论与口径

共 **543 个媒体素材文件**，其中 **419 个有主流程有效引用**；**124 个当前未生效或未接入**。

| 状态 | 数量 | 解释 |
|---|---:|---|
| 主流程有效引用 | 419 | 菜单、选人、营地、战斗、奖励、交易、结算及其正常条件分支、不同尺寸图集 |
| 残留/后备引用，当前未生效 | 39 | 旧背景与环境音、被覆盖的后备图、没有消费的预载常量 |
| 独立场景引用，未接入主流程 | 7 | 七个营地障碍物场景未由营地主场景实例化 |
| 未发现运行代码引用 | 78 | 包含历史素材、拆分帧与表情单图 |

仅搜索引用会得到 **458 个有引用、85 个无主流程接入**；人工复核后，其中 **39 个引用属于当前未生效的残留/后备**。所以不能直接把 458 当成当前有效使用数量。

计数单位是磁盘上的一个媒体文件：481 PNG、14 SVG、44 WAV、2 OGG、2 字体，共 543；不按动画帧数或图集区域数累加，也未对不同文件的内容做去重。母图、拆分帧、旧版 PNG 留在 assets 内也纳入库存，再标记使用状态。

“有效引用”包括需要对应武器、遗物、角色、事件、界面尺寸等条件才加载的资源，不代表启动一次游戏就全部显示。它是静态接入数量，不是实机渲染覆盖数量。

## 按内容分类

| 分类 | 总数 | 有效引用 | 残留/后备 | 无主流程接入 |
|---|---:|---:|---:|---:|
| 玩家角色 | 13 | 10 | 1 | 2 |
| 敌人角色 | 53 | 18 | 0 | 35 |
| 武器表现 | 26 | 25 | 1 | 0 |
| 战斗特效 | 57 | 57 | 0 | 0 |
| 战场背景 | 98 | 31 | 34 | 33 |
| 营地场景 | 19 | 12 | 0 | 7 |
| 掉落物 | 2 | 2 | 0 | 0 |
| 界面图标 | 159 | 159 | 0 | 0 |
| 其他界面 | 68 | 60 | 0 | 8 |
| 音频 | 46 | 43 | 3 | 0 |
| 字体 | 2 | 2 | 0 | 0 |

## 未接入的 85 个文件集中在哪里

| 分组 | 数量 | 说明 |
|---|---:|---|
| 旧洞穴地表变体与 panorama | 33 | 32 张地表变体，加旧 panorama.png |
| 冥狼拆分帧 | 20 | 现用 3 张合成图集；attack_01.png 另有实际引用，不在这 20 张中 |
| 蝙蝠拆分帧 | 15 | 现用合成动作图集 |
| 营地树木、石块和木堆 | 7 | 仅独立障碍物场景引用 |
| 哥布林表情单图 | 5 | 现用合成表情图集 |
| 资本家旧战斗图 | 2 | 现用 display_clarity 版本 |
| 选人页备用框 | 2 | roster_empty.png、roster_frame.png |
| 旧挑战图标 | 1 | challenge_vault.svg |

其中 **40 个是已合成图集的拆分源图**（20 冥狼 + 15 蝙蝠 + 5 哥布林）。文件没有被运行时单独读取，不代表对应美术内容没有用到，也不等于应该删除。

## 目录内另外 930 个辅助文件

| 类型 | 数量 | 口径 |
|---|---:|---|
| Godot .import / .uid | 551 | 导入元数据与标识，不单独算素材 |
| PXG / PAL / Aseprite | 346 | 可编辑像素源稿、色板、工程源文件 |
| JSON / TRES / Shader / GD | 30 | 配置、清单、主题、动画资源与渲染辅助；不并入媒体素材数 |
| Markdown | 3 | 使用说明 |

因此 assets 全部文件为 **1473**，媒体素材为 **543**。如果把主题、脚本、Shader、配置/清单也统称资源，排除导入标识、编辑源文件和说明文档后是 **573**，但其中 30 个需要单独看待。

## 39 个残留/后备引用详情

| 文件 | 当前未生效原因 | 证据 |
|---|---|---|
| `assets/audio/sfx/environment/water_drop.wav` | 只由旧 WetlandBackdrop 预载/播放，当前主战场不实例化该类。 | `scripts/battle/wetland_backdrop.gd:9`、`scenes/battle/battle_root.tscn:24` |
| `assets/audio/sfx/environment/wet_step_01.wav` | 只由旧 WetlandBackdrop 预载/播放，当前主战场不实例化该类。 | `scripts/battle/wetland_backdrop.gd:9`、`scenes/battle/battle_root.tscn:24` |
| `assets/audio/sfx/environment/wet_step_02.wav` | 只由旧 WetlandBackdrop 预载/播放，当前主战场不实例化该类。 | `scripts/battle/wetland_backdrop.gd:9`、`scenes/battle/battle_root.tscn:24` |
| `assets/sprites/background/background-sky-Recovered.png` | 旧天空贴图仍挂在场景中，当前洞穴背景主动隐藏 Sky。 | `scripts/battle/battle_environment.gd:54`、`scripts/battle/cavern_battle_horizon.gd:42` |
| `assets/sprites/background/cavern/detail_crack_0.png` | 旧洞穴配置的地面、裂缝、草。当前地面改读 cavern_meadow_battlefield.json；远景只读取旧配置的 panorama、ruins、foreground。 | `scenes/battle/battle_root.tscn:158`、`scripts/battle/cavern_population_backdrop.gd:20`、`scripts/battle/cavern_battle_horizon.gd:21` |
| `assets/sprites/background/cavern/detail_crack_1.png` | 旧洞穴配置的地面、裂缝、草。当前地面改读 cavern_meadow_battlefield.json；远景只读取旧配置的 panorama、ruins、foreground。 | `scenes/battle/battle_root.tscn:158`、`scripts/battle/cavern_population_backdrop.gd:20`、`scripts/battle/cavern_battle_horizon.gd:21` |
| `assets/sprites/background/cavern/detail_crack_2.png` | 旧洞穴配置的地面、裂缝、草。当前地面改读 cavern_meadow_battlefield.json；远景只读取旧配置的 panorama、ruins、foreground。 | `scenes/battle/battle_root.tscn:158`、`scripts/battle/cavern_population_backdrop.gd:20`、`scripts/battle/cavern_battle_horizon.gd:21` |
| `assets/sprites/background/cavern/detail_crack_3.png` | 旧洞穴配置的地面、裂缝、草。当前地面改读 cavern_meadow_battlefield.json；远景只读取旧配置的 panorama、ruins、foreground。 | `scenes/battle/battle_root.tscn:158`、`scripts/battle/cavern_population_backdrop.gd:20`、`scripts/battle/cavern_battle_horizon.gd:21` |
| `assets/sprites/background/cavern/detail_crack_4.png` | 旧洞穴配置的地面、裂缝、草。当前地面改读 cavern_meadow_battlefield.json；远景只读取旧配置的 panorama、ruins、foreground。 | `scenes/battle/battle_root.tscn:158`、`scripts/battle/cavern_population_backdrop.gd:20`、`scripts/battle/cavern_battle_horizon.gd:21` |
| `assets/sprites/background/cavern/detail_crack_5.png` | 旧洞穴配置的地面、裂缝、草。当前地面改读 cavern_meadow_battlefield.json；远景只读取旧配置的 panorama、ruins、foreground。 | `scenes/battle/battle_root.tscn:158`、`scripts/battle/cavern_population_backdrop.gd:20`、`scripts/battle/cavern_battle_horizon.gd:21` |
| `assets/sprites/background/cavern/grass_grass_dense.png` | 旧洞穴配置的地面、裂缝、草。当前地面改读 cavern_meadow_battlefield.json；远景只读取旧配置的 panorama、ruins、foreground。 | `scenes/battle/battle_root.tscn:158`、`scripts/battle/cavern_population_backdrop.gd:20`、`scripts/battle/cavern_battle_horizon.gd:21` |
| `assets/sprites/background/cavern/grass_grass_long.png` | 旧洞穴配置的地面、裂缝、草。当前地面改读 cavern_meadow_battlefield.json；远景只读取旧配置的 panorama、ruins、foreground。 | `scenes/battle/battle_root.tscn:158`、`scripts/battle/cavern_population_backdrop.gd:20`、`scripts/battle/cavern_battle_horizon.gd:21` |
| `assets/sprites/background/cavern/grass_grass_short.png` | 旧洞穴配置的地面、裂缝、草。当前地面改读 cavern_meadow_battlefield.json；远景只读取旧配置的 panorama、ruins、foreground。 | `scenes/battle/battle_root.tscn:158`、`scripts/battle/cavern_population_backdrop.gd:20`、`scripts/battle/cavern_battle_horizon.gd:21` |
| `assets/sprites/background/cavern/reference_moss_full.png` | 旧洞穴配置的地面、裂缝、草。当前地面改读 cavern_meadow_battlefield.json；远景只读取旧配置的 panorama、ruins、foreground。 | `scenes/battle/battle_root.tscn:158`、`scripts/battle/cavern_population_backdrop.gd:20`、`scripts/battle/cavern_battle_horizon.gd:21` |
| `assets/sprites/background/green_ground/green-ground-repeat.png` | 旧 Green/Meadow 背景类仍参与类型判断，但当前场景实例化 CavernSunlightBackdrop，未实例化这些旧背景。 | `scenes/battle/battle_root.tscn:24`、`scripts/battle/battle_environment.gd:88` |
| `assets/sprites/background/meadow/grass-atlas.png` | 旧 Green/Meadow 背景类仍参与类型判断，但当前场景实例化 CavernSunlightBackdrop，未实例化这些旧背景。 | `scenes/battle/battle_root.tscn:24`、`scripts/battle/battle_environment.gd:88` |
| `assets/sprites/background/meadow/ground-context.png` | 基类初始化仍预载并短暂设置旧草地，子类在同一次 setup 中用 pit-ground / pit-ground-context 替换并重建；不作为当前最终背景。 | `scripts/battle/cavern_meadow_backdrop.gd:4`、`scripts/battle/cavern_grassland_backdrop.gd:16` |
| `assets/sprites/background/meadow/meadow-ground.png` | 基类初始化仍预载并短暂设置旧草地，子类在同一次 setup 中用 pit-ground / pit-ground-context 替换并重建；不作为当前最终背景。 | `scripts/battle/cavern_meadow_backdrop.gd:4`、`scripts/battle/cavern_grassland_backdrop.gd:16` |
| `assets/sprites/background/meadow/root-shadow.png` | 旧 Green/Meadow 背景类仍参与类型判断，但当前场景实例化 CavernSunlightBackdrop，未实例化这些旧背景。 | `scenes/battle/battle_root.tscn:24`、`scripts/battle/battle_environment.gd:88` |
| `assets/sprites/background/wetland/decal_compact_moss.png` | 旧湿地/绿色战场配置使用；当前洞穴草地仅复用湿地目录中的七张碎砖、碎石贴花。 | `data_config/cavern_meadow_battlefield.json:73`、`scenes/battle/battle_root.tscn:24`、`scripts/battle/battle_environment.gd:88` |
| `assets/sprites/background/wetland/decal_cyan_crack.png` | 旧湿地/绿色战场配置使用；当前洞穴草地仅复用湿地目录中的七张碎砖、碎石贴花。 | `data_config/cavern_meadow_battlefield.json:73`、`scenes/battle/battle_root.tscn:24`、`scripts/battle/battle_environment.gd:88` |
| `assets/sprites/background/wetland/decal_fine_crack.png` | 旧湿地/绿色战场配置使用；当前洞穴草地仅复用湿地目录中的七张碎砖、碎石贴花。 | `data_config/cavern_meadow_battlefield.json:73`、`scenes/battle/battle_root.tscn:24`、`scripts/battle/battle_environment.gd:88` |
| `assets/sprites/background/wetland/decal_forked_crack.png` | 旧湿地/绿色战场配置使用；当前洞穴草地仅复用湿地目录中的七张碎砖、碎石贴花。 | `data_config/cavern_meadow_battlefield.json:73`、`scenes/battle/battle_root.tscn:24`、`scripts/battle/battle_environment.gd:88` |
| `assets/sprites/background/wetland/decal_long_moss.png` | 旧湿地/绿色战场配置使用；当前洞穴草地仅复用湿地目录中的七张碎砖、碎石贴花。 | `data_config/cavern_meadow_battlefield.json:73`、`scenes/battle/battle_root.tscn:24`、`scripts/battle/battle_environment.gd:88` |
| `assets/sprites/background/wetland/decal_mossy_crack.png` | 旧湿地/绿色战场配置使用；当前洞穴草地仅复用湿地目录中的七张碎砖、碎石贴花。 | `data_config/cavern_meadow_battlefield.json:73`、`scenes/battle/battle_root.tscn:24`、`scripts/battle/battle_environment.gd:88` |
| `assets/sprites/background/wetland/decal_puddle.png` | 旧湿地/绿色战场配置使用；当前洞穴草地仅复用湿地目录中的七张碎砖、碎石贴花。 | `data_config/cavern_meadow_battlefield.json:73`、`scenes/battle/battle_root.tscn:24`、`scripts/battle/battle_environment.gd:88` |
| `assets/sprites/background/wetland/decal_spreading_crack.png` | 旧湿地/绿色战场配置使用；当前洞穴草地仅复用湿地目录中的七张碎砖、碎石贴花。 | `data_config/cavern_meadow_battlefield.json:73`、`scenes/battle/battle_root.tscn:24`、`scripts/battle/battle_environment.gd:88` |
| `assets/sprites/background/wetland/decal_vertical_crack.png` | 旧湿地/绿色战场配置使用；当前洞穴草地仅复用湿地目录中的七张碎砖、碎石贴花。 | `data_config/cavern_meadow_battlefield.json:73`、`scenes/battle/battle_root.tscn:24`、`scripts/battle/battle_environment.gd:88` |
| `assets/sprites/background/wetland/decal_wet_moss.png` | 旧湿地/绿色战场配置使用；当前洞穴草地仅复用湿地目录中的七张碎砖、碎石贴花。 | `data_config/cavern_meadow_battlefield.json:73`、`scenes/battle/battle_root.tscn:24`、`scripts/battle/battle_environment.gd:88` |
| `assets/sprites/background/wetland/decal_wet_patch.png` | 旧湿地/绿色战场配置使用；当前洞穴草地仅复用湿地目录中的七张碎砖、碎石贴花。 | `data_config/cavern_meadow_battlefield.json:73`、`scenes/battle/battle_root.tscn:24`、`scripts/battle/battle_environment.gd:88` |
| `assets/sprites/background/wetland/fx_cyan_ripples.png` | 旧湿地/绿色战场配置使用；当前洞穴草地仅复用湿地目录中的七张碎砖、碎石贴花。 | `data_config/cavern_meadow_battlefield.json:73`、`scenes/battle/battle_root.tscn:24`、`scripts/battle/battle_environment.gd:88` |
| `assets/sprites/background/wetland/fx_fine_ripples.png` | 旧湿地/绿色战场配置使用；当前洞穴草地仅复用湿地目录中的七张碎砖、碎石贴花。 | `data_config/cavern_meadow_battlefield.json:73`、`scenes/battle/battle_root.tscn:24`、`scripts/battle/battle_environment.gd:88` |
| `assets/sprites/background/wetland/ruin_broken_arch.png` | 旧湿地/绿色战场配置使用；当前洞穴草地仅复用湿地目录中的七张碎砖、碎石贴花。 | `data_config/cavern_meadow_battlefield.json:73`、`scenes/battle/battle_root.tscn:24`、`scripts/battle/battle_environment.gd:88` |
| `assets/sprites/background/wetland/ruin_eroded_pillar.png` | 旧湿地/绿色战场配置使用；当前洞穴草地仅复用湿地目录中的七张碎砖、碎石贴花。 | `data_config/cavern_meadow_battlefield.json:73`、`scenes/battle/battle_root.tscn:24`、`scripts/battle/battle_environment.gd:88` |
| `assets/sprites/background/wetland/ruin_short_column.png` | 旧湿地/绿色战场配置使用；当前洞穴草地仅复用湿地目录中的七张碎砖、碎石贴花。 | `data_config/cavern_meadow_battlefield.json:73`、`scenes/battle/battle_root.tscn:24`、`scripts/battle/battle_environment.gd:88` |
| `assets/sprites/background/wetland/ruin_square_pillar.png` | 旧湿地/绿色战场配置使用；当前洞穴草地仅复用湿地目录中的七张碎砖、碎石贴花。 | `data_config/cavern_meadow_battlefield.json:73`、`scenes/battle/battle_root.tscn:24`、`scripts/battle/battle_environment.gd:88` |
| `assets/sprites/background/wetland/ruin_twin_pillar_wall.png` | 旧湿地/绿色战场配置使用；当前洞穴草地仅复用湿地目录中的七张碎砖、碎石贴花。 | `data_config/cavern_meadow_battlefield.json:73`、`scenes/battle/battle_root.tscn:24`、`scripts/battle/battle_environment.gd:88` |
| `assets/sprites/player/capitalist_idle_right.png` | 仅作为 display_sprite 后备路径；资本家已配置 combat_visuals.idle，选人页优先读取后者。 | `data_config/characters.json:61`、`scripts/ui/character_select_view.gd:242` |
| `assets/sprites/weapons/copper_lamp/copper_lamp.png` | FIRE 常量仅声明预载，没有消费该常量的代码；当前火焰使用 CopperLampFlame 绘制。 | `scripts/weapons/copper_lamp.gd:4` |

## 85 个无主流程接入文件详情

| 文件 | 原因 |
|---|---|
| `assets/sprites/background/cavern/eroded_paving_0.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/eroded_paving_1.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/eroded_paving_2.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/eroded_paving_3.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/eroded_paving_broad_0.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/eroded_paving_broad_1.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/eroded_paving_broad_2.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/eroded_paving_broad_3.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/layered_moss_0.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/layered_moss_1.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/layered_moss_2.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/layered_moss_3.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/layered_moss_broad_0.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/layered_moss_broad_1.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/layered_moss_broad_2.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/layered_moss_broad_3.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/panorama.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/reference_moss_0.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/reference_moss_1.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/reference_moss_2.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/reference_moss_3.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/reference_moss_broad_0.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/reference_moss_broad_1.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/reference_moss_broad_2.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/reference_moss_broad_3.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/shallow_water_0.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/shallow_water_1.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/shallow_water_2.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/shallow_water_3.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/shallow_water_broad_0.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/shallow_water_broad_1.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/shallow_water_broad_2.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/background/cavern/shallow_water_broad_3.png` | 旧洞穴地表变体或旧 panorama，当前代码/场景/配置无运行引用。 |
| `assets/sprites/camp/stone1.png` | 独立场景引用，未接入主流程 |
| `assets/sprites/camp/stone4.png` | 独立场景引用，未接入主流程 |
| `assets/sprites/camp/tree3.png` | 独立场景引用，未接入主流程 |
| `assets/sprites/camp/tree5.png` | 独立场景引用，未接入主流程 |
| `assets/sprites/camp/tree6.png` | 独立场景引用，未接入主流程 |
| `assets/sprites/camp/tree8.png` | 独立场景引用，未接入主流程 |
| `assets/sprites/camp/wood2.png` | 独立场景引用，未接入主流程 |
| `assets/sprites/enemies/echo_bat/attack/01.png` | 蝙蝠拆分帧留档；主流程使用同目录下合成动作图集。 |
| `assets/sprites/enemies/echo_bat/attack/02.png` | 蝙蝠拆分帧留档；主流程使用同目录下合成动作图集。 |
| `assets/sprites/enemies/echo_bat/attack/03.png` | 蝙蝠拆分帧留档；主流程使用同目录下合成动作图集。 |
| `assets/sprites/enemies/echo_bat/attack/04.png` | 蝙蝠拆分帧留档；主流程使用同目录下合成动作图集。 |
| `assets/sprites/enemies/echo_bat/attack/05.png` | 蝙蝠拆分帧留档；主流程使用同目录下合成动作图集。 |
| `assets/sprites/enemies/echo_bat/attack/06.png` | 蝙蝠拆分帧留档；主流程使用同目录下合成动作图集。 |
| `assets/sprites/enemies/echo_bat/attack/07.png` | 蝙蝠拆分帧留档；主流程使用同目录下合成动作图集。 |
| `assets/sprites/enemies/echo_bat/attack/08.png` | 蝙蝠拆分帧留档；主流程使用同目录下合成动作图集。 |
| `assets/sprites/enemies/echo_bat/attack/09.png` | 蝙蝠拆分帧留档；主流程使用同目录下合成动作图集。 |
| `assets/sprites/enemies/echo_bat/move/01.png` | 蝙蝠拆分帧留档；主流程使用同目录下合成动作图集。 |
| `assets/sprites/enemies/echo_bat/move/02.png` | 蝙蝠拆分帧留档；主流程使用同目录下合成动作图集。 |
| `assets/sprites/enemies/echo_bat/move/03.png` | 蝙蝠拆分帧留档；主流程使用同目录下合成动作图集。 |
| `assets/sprites/enemies/echo_bat/move/04.png` | 蝙蝠拆分帧留档；主流程使用同目录下合成动作图集。 |
| `assets/sprites/enemies/echo_bat/move/05.png` | 蝙蝠拆分帧留档；主流程使用同目录下合成动作图集。 |
| `assets/sprites/enemies/echo_bat/move/06.png` | 蝙蝠拆分帧留档；主流程使用同目录下合成动作图集。 |
| `assets/sprites/enemies/underworld_wolf/frames/attack_02.png` | 冥狼拆分帧留档；主流程使用 atlases。attack_01 另用于场景初始姿势和结算，仍计入有效引用。 |
| `assets/sprites/enemies/underworld_wolf/frames/attack_03.png` | 冥狼拆分帧留档；主流程使用 atlases。attack_01 另用于场景初始姿势和结算，仍计入有效引用。 |
| `assets/sprites/enemies/underworld_wolf/frames/attack_04.png` | 冥狼拆分帧留档；主流程使用 atlases。attack_01 另用于场景初始姿势和结算，仍计入有效引用。 |
| `assets/sprites/enemies/underworld_wolf/frames/jump_01.png` | 冥狼拆分帧留档；主流程使用 atlases。attack_01 另用于场景初始姿势和结算，仍计入有效引用。 |
| `assets/sprites/enemies/underworld_wolf/frames/jump_02.png` | 冥狼拆分帧留档；主流程使用 atlases。attack_01 另用于场景初始姿势和结算，仍计入有效引用。 |
| `assets/sprites/enemies/underworld_wolf/frames/jump_03.png` | 冥狼拆分帧留档；主流程使用 atlases。attack_01 另用于场景初始姿势和结算，仍计入有效引用。 |
| `assets/sprites/enemies/underworld_wolf/frames/jump_04.png` | 冥狼拆分帧留档；主流程使用 atlases。attack_01 另用于场景初始姿势和结算，仍计入有效引用。 |
| `assets/sprites/enemies/underworld_wolf/frames/jump_05.png` | 冥狼拆分帧留档；主流程使用 atlases。attack_01 另用于场景初始姿势和结算，仍计入有效引用。 |
| `assets/sprites/enemies/underworld_wolf/frames/jump_06.png` | 冥狼拆分帧留档；主流程使用 atlases。attack_01 另用于场景初始姿势和结算，仍计入有效引用。 |
| `assets/sprites/enemies/underworld_wolf/frames/jump_07.png` | 冥狼拆分帧留档；主流程使用 atlases。attack_01 另用于场景初始姿势和结算，仍计入有效引用。 |
| `assets/sprites/enemies/underworld_wolf/frames/jump_08.png` | 冥狼拆分帧留档；主流程使用 atlases。attack_01 另用于场景初始姿势和结算，仍计入有效引用。 |
| `assets/sprites/enemies/underworld_wolf/frames/jump_09.png` | 冥狼拆分帧留档；主流程使用 atlases。attack_01 另用于场景初始姿势和结算，仍计入有效引用。 |
| `assets/sprites/enemies/underworld_wolf/frames/jump_10.png` | 冥狼拆分帧留档；主流程使用 atlases。attack_01 另用于场景初始姿势和结算，仍计入有效引用。 |
| `assets/sprites/enemies/underworld_wolf/frames/move_01.png` | 冥狼拆分帧留档；主流程使用 atlases。attack_01 另用于场景初始姿势和结算，仍计入有效引用。 |
| `assets/sprites/enemies/underworld_wolf/frames/move_02.png` | 冥狼拆分帧留档；主流程使用 atlases。attack_01 另用于场景初始姿势和结算，仍计入有效引用。 |
| `assets/sprites/enemies/underworld_wolf/frames/move_03.png` | 冥狼拆分帧留档；主流程使用 atlases。attack_01 另用于场景初始姿势和结算，仍计入有效引用。 |
| `assets/sprites/enemies/underworld_wolf/frames/move_04.png` | 冥狼拆分帧留档；主流程使用 atlases。attack_01 另用于场景初始姿势和结算，仍计入有效引用。 |
| `assets/sprites/enemies/underworld_wolf/frames/move_05.png` | 冥狼拆分帧留档；主流程使用 atlases。attack_01 另用于场景初始姿势和结算，仍计入有效引用。 |
| `assets/sprites/enemies/underworld_wolf/frames/move_06.png` | 冥狼拆分帧留档；主流程使用 atlases。attack_01 另用于场景初始姿势和结算，仍计入有效引用。 |
| `assets/sprites/enemies/underworld_wolf/frames/move_07.png` | 冥狼拆分帧留档；主流程使用 atlases。attack_01 另用于场景初始姿势和结算，仍计入有效引用。 |
| `assets/sprites/player/combat/capitalist_idle_right.png` | 资本家旧战斗图；已改用 display_clarity/player 中的素材。 |
| `assets/sprites/player/combat/capitalist_walk_right_spritesheet.png` | 资本家旧战斗图；已改用 display_clarity/player 中的素材。 |
| `assets/ui/character_select/roster_empty.png` | 未发现运行代码引用 |
| `assets/ui/character_select/roster_frame.png` | 未发现运行代码引用 |
| `assets/ui/finance/challenge_vault.svg` | 未发现运行代码引用 |
| `assets/ui/finance/portraits/goblin_delighted.png` | 哥布林表情单图留档；主流程使用 goblin_banker_states.png 等合成图集。 |
| `assets/ui/finance/portraits/goblin_displeased.png` | 哥布林表情单图留档；主流程使用 goblin_banker_states.png 等合成图集。 |
| `assets/ui/finance/portraits/goblin_downcast.png` | 哥布林表情单图留档；主流程使用 goblin_banker_states.png 等合成图集。 |
| `assets/ui/finance/portraits/goblin_neutral.png` | 哥布林表情单图留档；主流程使用 goblin_banker_states.png 等合成图集。 |
| `assets/ui/finance/portraits/goblin_smile.png` | 哥布林表情单图留档；主流程使用 goblin_banker_states.png 等合成图集。 |

## 可追溯清单

- 本文记录清理前的 543 个媒体文件和分类结论；当时只做审计，没有改动游戏素材、配置和运行脚本。
- 后续处置见[素材清理记录](assets_cleanup_20261015.md)及 [artifacts 清理记录](artifacts_cleanup_20261015.md)。原始库存、扫描脚本和中间日志已随过程附件清理，不再提供旧路径作为复跑入口。
- 人工规则针对当时场景快照；以后背景或选人逻辑改变时应重新复核。实际删除清单与哈希保留在[执行清单](../../temp/artifacts_cleanup_20261015/previous_assets_cleanup.json)。
