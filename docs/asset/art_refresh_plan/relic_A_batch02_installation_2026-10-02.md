# 遗物 A 版第二批 12 件正式接入（2026-10-02）

用户审阅 A 版及其与旧正式素材的对照后授权替换。本次将 `artifacts/previews/relic_a_batch02/r01/delivery/` 内的 12 张 PNG 与对应 `.pxg` 安装到 `assets/ui/icons/relics/`。规格为 64×64、10–12 色、二值透明；PNG 与用户确认稿的 SHA-256 一致。

生命之种使用审阅包中已修正绿色幼芽的版本。其余处理沿用 A 方案：原图 RGB、7×7 中值过滤、轻抬近黑色、最多 12 色、无抖色，保留原始主要明暗和材质。未改变用户已确认的效果。

## 清单

| ID | 遗物 |
|---|---|
| `relic_cultic_holy_shield` | 密教圣盾 |
| `relic_lost_wayfarer_greave` | 迷途者胫环 |
| `relic_soul_keeper_face_stone` | 守魂人面石雕 |
| `relic_pain_vessel` | 苦痛祭皿 |
| `relic_true_silver_armor` | 真银护甲 |
| `relic_holy_silver_cup` | 圣质银杯 |
| `relic_suffering_carapace` | 受难甲壳 |
| `relic_costly_seed_of_life` | 代价生命之种 |
| `relic_shadowless_greave` | 无影遁形胫甲 |
| `relic_chain_of_hardship` | 苦难前行之枷锁 |
| `relic_void_tentacle` | 虚空触手 |
| `relic_worn_fighting_gloves` | 磨损格斗拳套 |

## 验证

沿用独立 PNG 引用与 `.png.import` 设置，未调整界面代码或图集。列表／商店显示 32px、百科 64px、奖励 48px，均使用现有最近邻采样。

- Godot 4.7.2 无窗口编辑器导入通过，无 Parse/Compile/SCRIPT ERROR。
- 现有 `relic_art_install_test.tscn` 分两组覆盖全部 12 件，headless 与 GPU 均为 `failures=0`。
- 两次 GPU 截图均在私有 Windows 桌面完成，实际桌面与预期一致，`foreground_samples=0`。
- 人工核对商店与百科画面；114 处图标采样覆盖全部 12 件，前景 RGB 与正式图最近邻采样的最大误差为 0。
- 已确认 PNG 与正式 PNG 哈希一致；每张 `.pxg` 渲染结果与正式 PNG 逐像素一致，导入设置未改动。

## 记录

- [安装文件与哈希](../../../artifacts/previews/relic_a_batch02/r01/installation/assets.json)
- [替换前备份](../../../artifacts/previews/relic_a_batch02/r01/installation/previous/)
- [实际界面像素核验](../../../artifacts/previews/relic_a_batch02/r01/installation/pixel_checks.json)
- [商店截图](../../../artifacts/previews/relic_a_batch02/r01/installation/captures-1/shop_1152x648.png)
- [生命之种百科截图](../../../artifacts/previews/relic_a_batch02/r01/installation/captures-2/encyclopedia_relic_costly_seed_of_life.png)

至此两批共 24 件 A 版已接入。下一批原图第 5 张的 12 件另存于 `artifacts/previews/relic_a_batch03/r01/`，只交审阅稿，未替换正式资源。猪猪存钱罐不在本次处理范围。
