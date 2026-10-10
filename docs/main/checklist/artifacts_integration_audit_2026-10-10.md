# artifacts 测试设计与正式资源接入核查（2026-10-10）

后续处理已完成：小 Boss 霸体 V02 已接入正式敌人抗控反馈，见 [安装说明与截图](super_armor_install_2026-10-10.md)。下表中的英文方形宣传封面、最新遗物建议，以及“旧方案未原样采用”表列出的全部旧试稿已按用户要求移除；霸体 sandbox 也已由正式实现和新截图取代。共 142 个文件逐个移入回收站，移除体积 62.89 MiB，空目录同步清理；正式英文菜单标题保留。见 `artifacts/maintenance/cleanup_20261010.md`。以下为清理前核查快照，路径仅用于解释当时的判断，不再表示待接入或现存文件。

本次扫描 `artifacts/` 现存 1,936 个文件，重点核查 analysis、generated、performance、previews、reviews、validation 下的 52 个二级目录，其中 4 个为空目录。结合设计说明、后续安装记录、当前正式脚本引用、配置和 PNG／代码 SHA-256 判断状态；没有运行游戏，没有替换或删除素材。未提交但已经被正常游戏加载的资源也计为正式接入。

清理前结论：当时候选主要有小 Boss 霸体视觉 V02、英文方形宣传封面及未确认的遗物建议。本轮后续处理已完成接入或清理，不再作为待安装清单。

## 清理前尚未接入或尚未实施的项目（现已处理）

| 项目 | artifacts 位置 | 核查结果 |
| --- | --- | --- |
| 小 Boss 霸体视觉 V02 | `previews/miniboss_super_armor_v01/` | 黄／橙／红流动描边与“霸体”飘字仍仅在独立 sandbox 工程中。V02 使用 `warm_outline.gdshader`，正式敌人、场景、着色器中没有该资源的接入引用。可见预览时长为 2 秒、文字 0.7 倍、轮廓流速 0.88 圈/秒。此稿只展示外观，未包含真实霸体触发、免控或 AI 逻辑。 |
| 英文方形宣传封面 | `generated/english_promo_20261007/` | `cover_en_pixel_2048/1024/512/256.png` 及无字方形背景仍是独立宣传交付，未找到正式资源副本或运行引用。宣传封面不一定需要加入游戏运行时；这里仅说明接入状态。 |
| 最新遗物审计的剩余建议 | `analysis/post_confirmation_relic_audit_20261010/review.md` | 攻速遗物减轻伤害代价、生命力药瓶调整持续侵蚀成本、受难甲壳等调整防御预算，仍为分析建议，没有候选正式数值包等待复制。当前仍是攻速 +5/移速 −2，攻速 +10/伤害 −3%，攻速 +18/伤害 −5%；药瓶仍每秒回血 +0.25、每波侵蚀 +1；受难甲壳仍护甲 +20、生命 +4、近战 +5。 |

最近用户确认的小费托盘“10% 概率额外基础经验／金币各 2”和扩散喷口“通用伤害 +5%、元素 +3、伤害范围 +12、攻速 −6”已经接入。审计中小费托盘“各 4”的建议未获采用，不能再视为漏装内容。

英文标题与封面需分开判断：`generated/english_promo_20261007/title_en_pixel_480.png` 与 `assets/ui/main_menu/title_main_menu_en.png` 的 SHA-256 完全相同，`localization/locales.json` 已将英文标题指向该正式 PNG。因此英文菜单标题已接入；高分辨率 `title_en.png` 是源稿，不属于遗漏。

## 旧方案未原样采用，当前已有后续实现

| 旧试作 | 原试作内容 | 当前正式实现与结论 |
| --- | --- | --- |
| `previews/lightning_appearance_20261006/` | 闪电总时长 0.44 秒、移除路径辉光、喷溅数量及辉光半径减半 | 当前 `lightning_particle_effect.gd` 使用每段 0.08 秒，总时长 0.36 秒；无路径外圈，喷溅数量／距离／辉光半径系数均为 0.5，命中改为 PNG 飞溅。核心方向已采用并继续演进，0.44 秒旧时长未原样采用。不能直接套用旧 `candidate.diff`。 |
| `performance/warning_png_20261006/` | 512×384、48 帧整圈预警 PNG；非默认半径回退旧绘制 | 当前已采用 R04：128×128 图集、256 个方向帧、24 粒子单 MultiMesh 批次。扩大范围只改变粒子轨道，不放大粒子。旧整圈图集没有安装，但预警 PNG 优化已完成。 |
| `performance/hammer_lightning_20261006/` | 删除路径辉光／删除全部白色喷溅，以及隐藏预警的诊断实验 | 当前去掉路径外圈、保留 PNG 白色飞溅，并使用 R04 预警。完全删除白色喷溅和隐藏预警的实验未采用，尤其“隐藏预警”是定位性能瓶颈的手段，不是交付方案。 |
| `performance/water_ice_20261006/` | 分别隐藏水波、碎冰、冰场等定位瓶颈 | 后续水波／碎冰及冰场绘制已迁移至 PNG 方案。逐项隐藏实验不是待替换的效果设计。 |
| `generated/mobility_weapons_20261007/` | 三把位移武器早期美术预演 | 4 张图标和火炮的 4 张特效与正式资源哈希一致；短刃／移星的 7 张旧图集已被 10 月 10 日 R01 新版取代。3 张武器实体按设计只作参考，不显示在玩家旁边。 |
| `analysis/attack_relic_review_20261010/proposal.md` | 最初 25 件攻击遗物建议 | 后续用户逐项确认值已经替换正式资源；原建议的拳套 +3、皮带 +6、臂铠 +16 等差异是方案被替代，不是未安装。 |
| `previews/attack_speed_75/`、`previews/attack_speed_log/` | 攻速映射调整与验证 | 当前正式 `StatDefinitions.calculate_attack_interval()` 已采用正攻速对数递减，100 点攻速对应 75% 冷却。保留的是不同阶段的验证记录。 |

关键后续记录：

- [闪电命中 PNG R02 正式安装](lightning_hit_png_r02_2026-10-07.md)
- [落雷地面电弧与 PNG 预警 R04 正式安装](lightning_ground_warning_r04_2026-10-07.md)
- [攻击遗物确认清单](confirmed_attack_relic_balance_2026-10-10.md)
- [位移武器当前实现](../mobility_weapons_implementation.md)

## 已正式接入的近期审阅包

| artifacts 目录 | 当前接入证据 |
| --- | --- |
| `previews/pixel_effects_r01_20261010/` | 9 组特效全部与 `validation/pixel_effects_install_20261010/installed_assets.json` 的正式 PNG 哈希一致；正式脚本引用对应素材。 |
| `previews/combat_feedback_r02_20261010/` | 正式敌人和武器引用 R02；`combat_feedback_settings.gd` 默认开启；核心反馈、接触效果、武器提示、设置和短音共 5 个文件与安装清单哈希一致。 |
| `validation/weapon_cooldown_feedback_install_20261010/` | 正式武器栏挂载冷却提示；4 个正式源码均与安装清单哈希一致。只采用冷却完成亮边，R03 施放回弹等未采用内容及其旧审阅包已清理。 |
| `performance/water_png_20261006/`、`performance/freeze_png_20261006/` | 有明确正式安装记录，运行脚本已引用 `assets/sprites/effects/water_wave/` 和 `ice_shards/`，不依赖旧试作工程。 |
| `previews/range_half_bonus_review/`、`range_half_bonus_install/` | 当前正式攻击距离／伤害范围加成效率为 0.5；存在正式接入及回归记录。 |
| `analysis/spawn_and_stats_20261010/`、`validation/player_stat_implementation_20261010/` | 旧属性审计后续确认的控制时间、波初护盾与侵蚀增加普通刷怪数量均已接入；旧表格保留的是修改前快照。 |
| `analysis/erosion_review_20261010/`、`validation/elite_cap_9_20261010/` | 侵蚀曲线及精英上限的分析／验证产物，不是独立资源候选。 |
| `previews/goblin_*`、`challenge_expansion_20261009/`、`vault_redraw*` | 已有正式交易／挑战配置、保险箱资源和后续清理／验证记录，保留内容主要为验收数据。 |
| `previews/esc_idle_review/`、`shop_icon_text_review/`、`capsule_interest_review/`、`relic_performance/` 等 UI 与性能目录 | 正式功能审阅或前后对照记录；没有发现单独等待复制安装的候选实现。 |

其余目录中的 `before`、`original`、`baseline`、旧源码、逐帧截图、运行日志、曲线采样和通过／失败记录，本身不代表有未完成的替换。空目录 `reviews/locale_after_exit_20261009`、`reward_access_20261009`、`reward_access_double_20261009`、`spawn_density_20261009` 不含现存候选文件。

## 另一个未闭环的排查记录

`previews/tooltip_burn_review/findings.md` 中的角色遗物提示修复已经接入；“燃烧状态消失后仍持续飘字”在当时未复现，记录没有给出已完成的修复方案。这属于待进一步复现的问题，不能列为一份漏装的修复稿。本次没有重新运行燃烧测试，也没有据旧日志判定当前仍存在或已经修复该问题。

## 核查边界

本次范围是当前 `artifacts/` 与正式项目的接入关系；未遍历项目外 `review-archives/` 中的所有实验工程。原图、画风参考、编辑源、宣传输出和测试夹具不要求全部复制进 `assets/`。正式代码的 `res://artifacts/` 文本引用检查中，排除测试和制作工具后仅发现调试审计器的输出目录，不是正常战斗对候选素材的读取依赖。

后续已更新 `artifacts/README.md` 和英文标题源稿说明；10 月 6–9 日历史清理说明仍仅代表当时状态，当前应以正式实现和最新安装／清理记录为准。
