# 遗物 A 版第一批 12 件正式接入（2026-10-02）

用户确认 `relic_a_batch12/r02` 的 A 版后，将该版 12 张透明 PNG 及对应可编辑 `.pxg` 替换到 `assets/ui/icons/relics/`。正式 PNG 与确认稿 SHA-256 一致；规格为 64×64、每张 10–12 色、二值透明。猪猪存钱罐不在本批范围。

处理方法沿用 A 药瓶样例：以高清原图 RGB 为基础，7×7 中值过滤、轻抬近黑色、最多 12 色原图色板、无抖色。保留原始明暗与材质色调。本次接入直接使用用户确认文件，没有重新转换确认稿。

## 接入清单

| ID | 遗物 |
|---|---|
| `relic_worn_hemostatic_cloth` | 磨损的止血布条 |
| `relic_load_iron_bracer` | 负重铁皮护腕 |
| `relic_pungent_sachet` | 刺鼻香包 |
| `relic_broken_crystal` | 残破晶石 |
| `relic_dead_shield_badge` | 死寂护盾徽章 |
| `relic_turtle_shell_pendant` | 龟壳吊坠 |
| `relic_prison_copper_anklet` | 监狱铜制脚环 |
| `relic_brass_pocket_watch` | 黄铜怀表 |
| `relic_flesh_pauldron` | 血肉肩甲 |
| `relic_nightmare_healing_urn` | 梦魇治愈圣壶 |
| `relic_barrier_crystal` | 屏障结晶 |
| `relic_cracked_bronze_bell` | 裂纹铜铃 |

## 接入与验证

现有代码已将这些遗物作为独立 PNG 加载，并采用最近邻显示；无需修改图集裁切或界面逻辑。沿用列表／商店 32px、百科 64px、奖励 48px 的显示尺寸。`.png.import` 设置保持原样，PNG 与 `.pxg` 渲染结果逐像素一致。

- Godot 4.7.2 无窗口编辑器导入通过，未发现 Parse/Compile/SCRIPT ERROR。
- 现有 `relic_art_install_test.tscn` 分两组覆盖全部 12 件，headless 与 GPU 回归均为 `failures=0`。
- GPU 截图在私有 Windows 桌面完成，两次均验证引擎桌面一致且 `foreground_samples=0`。
- 人工查看商店与百科截图；114 处实际图标采样覆盖全部 12 件，前景像素与正式 PNG 的最近邻采样完全一致，最大 RGB 误差为 0。

## 文件记录

- [已确认 A 版总览](../../../artifacts/previews/relic_a_batch12/r02/delivery/review/A-batch12-overview.png)
- [安装文件、旧哈希与新哈希](../../../artifacts/previews/relic_a_batch12/r02/installation/assets.json)
- [替换前备份](../../../artifacts/previews/relic_a_batch12/r02/installation/previous/)
- [实际画面像素核验](../../../artifacts/previews/relic_a_batch12/r02/installation/pixel_checks.json)
- [第一组商店截图](../../../artifacts/previews/relic_a_batch12/r02/installation/captures-1/shop_1152x648.png)
- [第二组百科截图](../../../artifacts/previews/relic_a_batch12/r02/installation/captures-2/encyclopedia_relic_brass_pocket_watch.png)

下一批原图第 4 张的 12 件另存于 `artifacts/previews/relic_a_batch02/r01/`，作为 A 版审阅稿交付，未接入正式资源。
