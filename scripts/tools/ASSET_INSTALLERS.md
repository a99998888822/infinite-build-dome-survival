# 素材安装与检查工具

正式资源位于 `assets/`，尺寸、显示倍率与图集约定见[当前素材规则](../../docs/asset/asset_rules_summary.md)和[精灵规范](../../docs/asset/combat_sprite_clarity.md)。武器图标为 36px、遗物为 36px、附魔为 32px；历史生成器的旧输出不能覆盖当前 PNG/PXG/PAL。

## 来源与重建

原图和可编辑源使用 `artifacts/sources/`、`artifacts/editable/` 及正式 PNG 旁的文件。逐件图标信息见[当前索引](../../docs/asset/icon_manifest.json)。`art_source_archive.py --check` 核对其管理的来源；`--output <目录>` 可输出相应重建结果。可复用绘制函数见 [source_art/README.md](source_art/README.md)，临时输出放在 `temp/`。

现有工具的管理范围不完全相同，旧数值或逐字资源检查不能替代当前场景和配置验证。尤其 `.tres` 的 UID、属性顺序与 Godot 序列化变化可能造成纯文本差异，应检查资源解析与对应测试。

## 通用入口

```powershell
python scripts/tools/install_combat_picxel_assets.py --check
python scripts/tools/install_player_picxel_assets.py --check
python scripts/tools/install_iron_knight_assets.py --check
python scripts/tools/install_goblin_portraits.py --check
python scripts/tools/install_stats_drawer_art.py --check
python scripts/tools/install_green_battlefield.py --check
python scripts/tools/install_meadow_battle_assets.py --check
```

前三类安装器通过 `--source <目录>` 接收新资源，使用与 `assets/` 对应的布局。安装前校验文件、帧数和尺寸，复制后核对哈希并保留 `.import`；修改动画帧数时同步游戏配置。`build_combat_sprites.py` 是通用入口的兼容包装。

哥布林安装器接收五张 320×320 RGBA 图，运行表情为 `neutral/downcast/displeased/smile/delighted`，也接受确认稿的别名。当前理财来源在 `artifacts/editable/finance_ui_20261018/`，`align_finance_lamp_glow.py --output <新路径>` 处理背景灯光对齐。

属性抽屉与地面安装器通过 `current_art_package.py` 校验包；安装新批准资源使用 `--source <包目录> --backup-dir <新目录>`。地表采样图透明像素携带颜色信息，保留其导入设置，具体运行配置见[战场环境](../../docs/asset/battle_environment.md)。

## 专项工具

- `build_echo_bat_art.py --check`、`install_underworld_wolf_art.py --check` 检查正式图集与元数据；显式重建参数分别为 `--rebuild`、`--rebuild-atlases`，先确认输入仍存在。
- `build_camp_dagger_art.py`、`build_weapon_trio_art.py` 通过现有 PNG/PXG 检查或显式 `--write` 重建其管理的资源；先核对当前尺寸与输出范围。
- `build_weapon_block_vfx.py` 保存块状武器特效的绘制源；当前喷焰与其他特效入口见[特效说明](../../docs/asset/combat_effects.md)。
- 新素材安装后由 Godot 导入，并运行对应场景验证；自动截图使用[后台录制入口](BACKGROUND_CAPTURE.md)。
