# 素材安装工具

2026-10-04钢甲骑士更新：256px，idle1／move7（10FPS）／windup7／dash2／recover1，idle选移动第1帧。Boss安装器、图集构建与临时对照图工具均按此规格更新。当前可编辑PXG／PAL及帧序来源清单位于资源目录的 `frames/` 和 `art_source_manifest.json`；接入与回归见[本轮记录](../../docs/asset/art_refresh_plan/knight_256_installation_2026-10-04.md)。普通怪当前为128px、移动7帧（14FPS），其独立接入记录见[小怪记录](../../docs/asset/art_refresh_plan/grub_128_installation_2026-10-04.md)；通用安装器的非Boss历史契约不作为本轮验收入口。

正式资源位于 `assets/`。安装工具保留在本目录，不依赖 `artifacts` 中的审阅包。默认运行或传入 `--check` 仅检查现有资源的尺寸、色板、透明度和图集布局；旧审阅包已删除，不再进行与历史审阅文件的哈希比对。

```powershell
python scripts/tools/install_combat_picxel_assets.py --check
python scripts/tools/install_player_picxel_assets.py --check
python scripts/tools/install_iron_knight_assets.py --check
python scripts/tools/install_goblin_portraits.py --check
```

安装用户确认的新 PNG 时，给前三种工具传入 `--source <目录>`。输入目录采用与 `assets/` 相同的相对布局，例如 `sprites/player/combat/void_hunter_idle_right.png`；文件名、帧数和尺寸须符合当前游戏配置。先完整校验输入，再复制文件并核对复制前后哈希，沿用现有 `.import`。Boss 工具同时重建当前五组动作帧表。

哥布林工具使用 `--source <目录>`，目录内需要五张 128×128 RGBA PNG：`goblin_neutral.png`、`goblin_downcast.png`、`goblin_displeased.png`、`goblin_smile.png`、`goblin_delighted.png`。它组装理财和结算图集，并校验表情对应关系。

环境素材工具 `install_battle_environment_assets.py <目录>` 保留原接口，输入为该目录中的 `128px/` 编号 PNG。

`build_combat_sprites.py` 是通用安装工具的兼容入口，同样需显式传入 `--source` 才写入资源。`build_iron_knight_review.py` 可从当前正式 Boss 图集生成临时逐帧对照图。安装新素材后再由 Godot 导入；修改动画帧数时仍需同步游戏配置。

`build_nightwatch_spear_art.py` 从保留的像素几何绘制正式守夜长枪，只写入 `assets/` 下的64×64图标和248×28枪身；检查最多16色、透明通道仅0或255，不生成中间审阅包。

`build_camp_dagger_art.py` 默认检查正式营地短刀图标、刀身与斩击PNG是否与旁边的可编辑 `.pxg` 像素源一致；传入 `--write` 才重建这三项PNG，沿用Godot生成的 `.import`。各PXG自带色板，后续修改无需旧参考图。

`build_weapon_trio_art.py` 管理赤铜炉灯、异化触手、裂地战锤的三个64×64图标和四组动画图集。默认核对正式PNG与PXG；`--write` 从 `assets/` 内的可编辑源重建，检查每帧最多16色、透明通道仅0或255以及透明边界。火流6帧、触手19帧、战锤9帧、裂缝4帧；后续改图无需审阅包。`--source <已批准的weapon_trio目录>` 仅用于首次安装R02/R03设计源。

2026-09-30：11张武器UI图标已替换为用户确认的64×64 Picxel稿，当前PNG旁均有自带色板的PXG和PAL。短刀图标允许最多16色，刀身与斩击规格保持原样。旧版程序绘图工具（如 `build_nightwatch_spear_art.py`）会重画旧图标，其历史图标输出不能覆盖本次确认稿；需要重建图标时以当前同名PXG为准。战斗贴图不属于本次更新。

需要录制实机审阅时，使用[后台录制入口](BACKGROUND_CAPTURE.md)，避免Godot遮挡正在使用的浏览器。

当前正式战场采用已确认的 C 方案。地表分布图 `ground-context.png.import` 必须保持 `process/fix_alpha_border=false`，其透明像素保留地面颜色数据。复验入口为 `scenes/tests/battle_environment_test.tscn`。

2026-10-02：属性栏、地面与草地安装器已解除对旧 r03/r05 处理包的依赖。以下命令只检查当前 PNG 尺寸和 JSON 可读性，不覆盖文件：

```powershell
python scripts/tools/install_stats_drawer_art.py --check
python scripts/tools/install_green_battlefield.py --check
python scripts/tools/install_meadow_battle_assets.py --check
```

这三个工具通过 `current_art_package.py` 实现。安装新批准的资源时传入 `--source <包目录> --backup-dir <新备份目录>`；包内使用项目根目录相对路径，例如 `assets/sprites/background/meadow/grass-atlas.png`，地面包还需包含 `data_config/green_battlefield.json`。全部输入验证后才备份并复制，保留 `.import`；新 PNG 与旧网格不再相同时，索引改用新 PNG 作为编辑源，避免误报旧网格仍匹配。备份目录须尚不存在。

2026-09-30：12张附魔UI图标已按用户选定的32×32安装，PNG旁保留PXG与PAL。弹跳、共鸣的配置引用已由SVG改为PNG；未引用的旧SVG已在2026-10-02清理。重建以当前同名PXG为准，不用历史64px候选覆盖已确认稿。接入与验证见[附魔安装记录](../../docs/asset/art_refresh_plan/24_augmentations_sheet_01_installation.md)。

2026-10-02：角色／敌人的唯一高清帧原稿从 `assets/sprites/player/tobe_handled/` 移至 `artifacts/sources/character_frames/`；`prepare_player_picxel_review.py` 与 `picxel_combat_source_masks.py` 已同步。结算离线预览改用当前草地；音效试听工具允许已废弃的旧版音效不存在。最终编辑源和唯一原稿入口分别为 `artifacts/editable/index.json` 与 `artifacts/sources/index.json`。历史录制脚本的截图／日志属于可再生成输出，清理后需先重新录制。

现有通用战斗／Boss 安装器的部分 `--check` 会逐字比较 `.tres`。Godot 保存后的 UID、顺序或布尔序列化差异可能导致检查失败；动画是否可用需结合实际资源解析和 `iron_knight_test.tscn` 判断，不要为消除文本差异覆盖已经确认的正式帧表。
