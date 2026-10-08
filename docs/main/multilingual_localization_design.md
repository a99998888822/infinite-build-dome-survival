# 多语言版本设计方案

日期：2026-10-08。状态：已实现并完成专项验证。已接入语义 key 文案表、Godot 翻译资源、语言管理器、主界面入口与动态文本迁移；已通过无界面测试及私有桌面截图检查。实际维护及重新验证方法见 `localization/README.md`。审阅截图、报告和日志属于可重新生成的临时产物，已按要求清理。尚未导出或发布新版本。

## 1. 建议采用的方案

采用 **同一个游戏包 + Godot 原生翻译资源 + 稳定文案键 + 一个轻量语言管理器**。首批支持简体中文 `zh_CN`、英文 `en`，仅在主界面右上角即时切换并保存偏好。后续新增语言主要增加译文、必要字体和少量标题资源，复用同一套玩法、数据与界面。

最快的可靠路径是先接入集中入口，再按玩家实际游玩流程迁移文案。首个可对外发布的英文版应覆盖所有可到达页面及错误提示；只有主菜单和按钮变成英文时，应称为内部验证版。

现有中文配置可以作为迁移期的原文和回退，不要求第一步重写所有 JSON。翻译在开发阶段完成并随游戏打包，运行时不请求在线翻译服务。

## 2. 实施前项目盘点

本次对 `scripts/`、`autoloads/`、`data_config/` 和正式场景做了只读检查：

| 内容 | 发现 | 影响 |
| --- | --- | --- |
| 翻译接入 | 未检索到正式 `tr()` / `tr_n()`、`TranslationServer` 接入；`project.godot` 未配置翻译资源 | 需要建立统一入口 |
| 正式脚本文字 | 排除 tests、tools、debug 后，47 个脚本中发现约 711 处含中文的双引号字符串，原样去重约 635 条 | 菜单、提示、属性、经济流程均需覆盖 |
| JSON 文字 | 15 个配置文件中发现 538 个含中文的字符串值 | 名称、说明、短说明、图标说明、对话等需统一提取 |
| 场景文字 | 11 个非测试／调试场景中发现 45 个中文 text / tooltip_text / placeholder_text 字段 | 场景中的静态文字也要登记 |
| 设置入口 | 主菜单与战斗共用 `GameSettingsPanel` | 按用户要求，语言入口独立放在主界面，两个设置面板均不增加语言选项 |
| 字体 | 全局主题使用 Ark Pixel；选角等界面也显式加载同一字体 | 初版可沿用，不必先制作新字体 |
| 标题 | 中文标题是独立 PNG；已有英文透明标题候选 | 可按语言切换独立资源 |

上述为启发式候选统计，不是最终词条数：可能包含开发诊断、重复文案和暂未开放页面，也可能遗漏复杂字符串写法。实施时需补充运行路径与人工抽查，不能把正则结果当作完整本地化清单。

字体检查已确认现有 Ark Pixel 和 VT323 均包含基本英文字母、数字、常见格式符号及弯引号、长破折号。首版优先继续使用 Ark Pixel，字体覆盖不等于实际排版已通过。

## 3. 结构与职责

建议新增：

```text
autoloads/localization.gd                 # Autoload 名称 L10n
localization/locales.json                 # 可选语言、母语名称、发布开关、标题资源
localization/catalogs/*.csv               # ui、content、gameplay、messages 四张中英对照表
localization/generated/                  # 自动生成的既有原文兼容映射，不手工维护
localization/catalog_meta.json            # 来源、占位符、原文哈希、审阅状态
docs/localization/glossary.md             # 对外术语表
scripts/tools/localization_inventory.py   # 增量提取与候选清单
scripts/tools/localization_catalog.py     # 完整性、占位符、标签校验与原生资源登记
scripts/tools/validate_localization.py    # 有界的 Godot 无界面检查与日志保留
```

上述运行组件已开始接入。数字编号和哈希仅用于来源清单，不作为文案接口；已将原先按批次保存的翻译草稿迁入语义 key 表格。

CSV 直接采用 Godot 原生列结构，例如 `keys,zh_CN,en`。上下文和审阅状态存放在独立元数据中，不把它们误写成 Godot 会识别为语言的额外 CSV 列。各模块共享全局键空间，校验时禁止跨文件重复键。

CSV 由 Godot 导入为翻译资源并登记在 `project.godot`。发布时把语言资源一并打包，不要求玩家另下语言包。无需手写引擎生成的 `.translation` 或 UID 文件。

`L10n` 保持轻量，仅负责：

1. 读取、选择和保存语言；在首屏创建前初始化。
2. 调用 `TranslationServer.set_locale()`。
3. 提供带命名参数的文本格式化与基于数据 ID 的文案访问入口。
4. 提供语言资源选择、缺译诊断，以及语言变更版本号／信号。

玩法数据仍由原有系统管理。语言变化不调用 `DataRegistry.reload_all()`，不重新生成角色、物品或商品池。

## 4. 文案键与数据迁移

### 4.1 静态文字

使用与中文措辞无关的稳定键：

| Key | 简体中文 | English |
| --- | --- | --- |
| `ui.menu.start` | 开始战斗 | Start Run |
| `ui.menu.settings` | 设置 | Settings |
| `ui.main_menu.language` | 语言： | Language： |
| `ui.common.back` | 返回 | Back |
| `economy.deposit.action` | 存入 | Deposit |
| `economy.withdraw.action` | 取出 | Withdraw |

修改中文措辞时保留键，只更新原文并把对应译文标为待复核。同一个中文词如果在不同位置含义不同，可以使用不同键；不要以全局中文字符串替换建立长期翻译系统。

场景中的静态 Label／Button 可保留键并使用引擎自动翻译。动态生成、带参数或自绘的文字采用显式翻译与刷新；每个控件只选一种方式，避免已经格式化的文字再次进入自动翻译。

### 4.2 JSON 数据

顶层内容已有稳定 ID，可推导翻译键，优先减少 JSON 改动：

```text
data.weapons.weapon_void_blade.display_name
data.weapons.weapon_void_blade.shop_description
data.weapons.weapon_void_blade.level_upgrades.2.description
data.relics.relic_steel_vault.description
data.augmentations.scroll_lightning.display_name
data.goblins.trades.interest_pact.speech
```

拟议访问示例，仅说明接口：

```gdscript
L10n.data_text("weapons", weapon_id, "display_name")
L10n.text("combat.wave.label", {"wave": wave_number})
```

数据提取器需覆盖 `display_name`、`name`、`description`、`shop_description`、`icon_description`、`speech`、`body`、`detail` 和实际用于界面的 `role` 等字段。嵌套升级、遗物说明数组、营地解锁文字不能遗漏。

现有交易、借贷、挑战及结算配置并非全部经过 `DataRegistry`，必须为这些独立加载器建立明确映射，不能只遍历注册表。

无稳定子 ID 的可重排数组，需要补充仅用于文案的稳定标识或显式键；不要长期依赖数组位置。已有 `unlock`、升级等级等稳定含义可参与生成键。用于玩法判断的 `id`、`stat`、`tags`、内部分类、资源路径不翻译。

迁移期的原文维护规则：

- 配置数据的中文原文仍从 JSON 提取，CSV 对应中文列自动同步；译者维护英文列。原文哈希改变后，英文标记待复核。
- 已迁移的静态 UI 文案以 CSV 中文列为源，不再把整句中文散落在脚本中。
- 旧中文字段仅作为兼容回退，不在 DataRegistry 中写入当前语言的显示字符串。

### 4.3 动态句子与数值

整句翻译之后再填参数，避免拼接词序固定的中文片段：

```text
Key: economy.deposit.receipt
zh_CN: 已存入 {amount} 金币，本金为 {principal}。
en: Deposited {amount} gold. Principal: {principal}.
```

名称、数字和句子分别解析，但最终句式由译文决定。翻译不能修改 `amount` / `principal` 等参数名。过渡期可保留完整 `%d` / `%s` 模板，但必须在格式化前翻译，并校验类型、数量和顺序；新改造的动态句子优先命名参数。

伤害、冷却、概率、利息和交易代价取自已有数据／计算结果，不能在英文里另写一套数值。已有中文说明与实际规则不一致时，登记并核对实际玩法，避免把过期操作提示原样翻译出去。

简单计数可使用 `Remaining enemies: {count}` 这类自然的中性标签。以后需要自然语言单复数时，使用 Godot 原生 gettext PO／`tr_n()` 并保留现有键；不要用全语言通用的“末尾加 s”。单个键仅由一个翻译资源负责。

BBCode 的颜色、图标路径和样式尽量由显示组件持有；译文中的必要标记需检查闭合和占位符一致性。符号、小数精度、百分比与百分点分别制定规则，不能把“利率 +3 个百分点”翻译成本金“收益乘以 1.03”。

## 5. 运行中切换的关键处理

### 5.1 玩家体验

按用户最终要求，仅在主界面右上角增加 `语言：中文` / `Language：English`。标签后方是单选下拉框，当前仅包含 `中文`、`English`；使用深绿背景、金色像素边框和现有像素字体。共享设置面板与战斗界面不新增入口。

语言名称使用各自母语，选中后立即生效并记住选择；不要求重新开始一局。首次启动由系统语言决定：`zh_*` 映射到简体中文，其余未支持的系统语言回退英文。保存明确选择的语言，不在界面提供“跟随系统”选项。

语言偏好单独存入 `user://localization.cfg`，不修改营地进度存档或存档身份。测试覆盖临时目录，并沿用 `--transient-session` 等不持久化约定。读取无效偏好时安全回退，不让游戏无法启动。

### 5.2 两类刷新

引擎原生静态控件使用翻译变更通知。动态 UI 根组件使用统一的 `_refresh_localized_text()`；非节点的文本缓存可订阅语言变化信号。同一个组件不要同时重复响应两套机制。

切换顺序：更新语言和显示资源 → 让可见界面重新解析文案 → 重新测量布局 → 恢复焦点、滚动位置等显示状态。隐藏页面标记待刷新，在下次打开前更新。

已经打开的设置面板不能被整体销毁重建。语言切换只变更显示，不触发按钮业务信号，不重置当前设置页、银行输入、选中物品或战斗暂停状态。

### 5.3 本项目必须单独处理的缓存

| 现有位置 | 当前行为 | 改造要求 |
| --- | --- | --- |
| `shop_offer_generator.gd` | 商品含复制的中文名称、说明；升级名提前拼好 | 按 `target_id`、`offer_type`、`to_level` 重建显示，保留商品身份、价格、数量与随机结果 |
| `item_inventory.gd` | 实例保存 `display_name` 和 `description` | 显示按 `base_item_id` 查文案，保留实例 ID、稀有度与已掷参数 |
| `goblin_trade_system.gd` | `prepare()` 抽交易并格式化 `offer.body` | 保留交易 ID、amount 和 token，只刷新句子；不能为了翻译再次执行 prepare |
| `battle_finance_system.gd` / `economy_journal.gd` | 日志保存最终中文 `text` | 新日志保存文案键、原始参数和引用 ID，显示时翻译 |
| `battle_hud.gd` | 属性标签与显示缓存可能在数值未变时跳过刷新 | 语言版本变化时清除文本／布局缓存，不动数值缓存 |
| `weapon_damage_meter.gd` | 自绘名称并按字符截短 | 重查名称，按当前字体的像素宽度裁切并重绘 |
| `GameTooltipLayer` 与各个 tooltip 构造器 | 可能保留旧悬停文字 | 切换时关闭旧 tooltip，下次悬停根据当前语言生成 |
| `run_settlement_panel.gd` | 保存对话文本，按时间展示与播放声音 | 保留结算与演出进度，仅刷新标签；不得重复发放奖励或重新播放音频 |

拟议日志结构：

```json
{
  "wave": 4,
  "message_key": "economy.log.relic_growth",
  "params": {"amount": 2},
  "refs": {
    "relic": {"table": "relics", "id": "relic_steel_vault", "field": "display_name"},
    "stat": {"stat_id": "armor"}
  }
}
```

历史数字使用发生时的快照，不因切换语言重新计算。引用名称在显示时解析。已有只含 text 的旧记录可兼容显示原文；正式完整接入后，新一局产生的记录应全部可重译。

缓存键加入 `locale_revision`，只在语言或数据变化时重建文本。禁止每帧重新翻译全部遗物、遍历重建整个场景或重复读取磁盘翻译文件。

## 6. 字体、排版和语言资源

### 6.1 字体与布局

首版继续使用现有 Ark Pixel，保持界面风格。若英文实际可读性需要调整，再单独比较 VT323 或其他合规字体；使用西文字体时必须处理中文回退。

重点检查：设置侧栏及按键说明、11px 商品说明、银行窄按钮、属性抽屉、角色卡、结算对话。英文长度不按中文字符数估算，应使用实际字体测量。

优先使用较短的界面译文、自动换行、适当增高或可滚动容器；只在辅助摘要上使用省略号。购买代价、交易后果与完整技能说明必须可读，不以持续缩小字体解决所有溢出。

首轮尺寸覆盖项目默认 1152×648、最小常用预设 1024×576、1920×1080，以及 960×540 的布局压力检查。若当前发行包包含移动端，再补横屏触控与实际导出包验证。

### 6.2 标题与图片

复用已拆分的主菜单标题与无文字背景。中文继续使用正式 `assets/ui/main_menu/title_main_menu.png`，英文候选来自 `artifacts/generated/english_promo_20261007/title_en.png`，正式接入时再复制到明确的语言资源目录。

英文候选与中文标题纵横比不同，需要在主菜单逻辑区域内分别适配，不能直接拉伸。候选图在宣传封面上的效果不能替代主菜单实机检查。字体和标题资源通过语言表配置，初版使用显式路径选择，避免运行中仍引用旧纹理。

哥布林背景沿用用户指定的正式像素资源 `assets/ui/main_menu/bg_main_menu.png`，各语言共用。背景、按钮装饰、图标原则上不带文字；发现已经烘焙的文字再单独拆分或制作语言变体。

当前结算配置的 `voice_path` 为空，不需要把英文配音作为首发阻塞项。未来声音本地化独立配置，缺少目标语言配音时仍提供对应字幕，不承诺本次制作配音。

## 7. 英文术语先统一

| 当前概念 | 建议英文 | 说明 |
| --- | --- | --- |
| 哥布林教你地下城 | Goblin's Guide to Dungeons | 沿用本次宣传候选名 |
| 随身金币 | Gold | 可立即消费的金币 |
| 本金 | Principal | 银行存款，不和随身金币混用 |
| 理财／银行页面 | Bank | 页面标题避免直译 Financial Management |
| 利息 | Interest | 收益 |
| 利率 | Interest Rate | 区分百分比与百分点 |
| 理智 | Sanity | 对应历史内部字段 `humanity`，不按字段名直译 Humanity |
| 侵蚀 | Corruption | 对应历史内部字段 `divinity`，不直译 Divinity |
| 遗物 | Relic | 全界面统一 |
| 附魔 | Enchantment | 名词；操作可用 Enchant |
| 羁绊 | Synergy | 不直接按字面使用 Bond |
| 负载／负载上限 | Load / Load Capacity | 明确是装备预算 |
| 轮椅模式 | Auto-Attack | 用实际功能命名；说明位移技能仍手动施放 |
| 快捷施法 | Quick Cast | 操作提示随移动模式一起变化 |
| 营地币 | Camp Coins | 与局内 Gold 分开 |

术语仅影响玩家看到的名称，不改配置 ID、属性 key 或存档字段。特别是 `StatDefinitions.get_category()` 等返回值可能用于分组／过滤，应保留内部语义，另设显示标签，不能一律替换成译文。

哥布林台词可以做自然英语改写；数值说明以准确、简短和不歧义为优先，不能为了宣传感改掉交易后果。

## 8. 分阶段实施与可审阅成果

| 阶段 | 工作 | 完成时可审阅的结果 |
| --- | --- | --- |
| A：打通切换 | 翻译资源、L10n、偏好保存、主界面右上角入口、标题及动态交易卡 | 中英即时切换、偏好保存、交易金额与身份不变的验证样例 |
| B：完整英文 Demo | 角色、操作提示、战斗、全部可获取武器／遗物／附魔、银行／交易／借贷／挑战、奖励／结算／日志、可访问营地及错误提示 | 从启动到一局结束及营地的英文闭环，可作为发布候选 |
| C：长期维护 | 自动增量清单、原文变更提示、术语／占位符／布局检查完善；按需求加入其他语言 | 新语言通过补译文、字体／标题配置和验证接入，无需另维护玩法分支 |

增量提取和基础校验从 A 阶段就应具备，C 阶段完善维护体验；不要等英文版结束后再补质量检查。B 阶段包括所有实际可见的入口，不能把已开放的营地或对话遗漏到后续。

初版优先复用字体、图标、背景和公共 UI，省下重做美术与整套界面的成本。可按模块批量翻译，再集中校对关键术语、操作说明和交易代价。最终词条清单确认前，不给“一键翻译即可完成”或固定工期承诺。

建议第一个实施切片为“设置切换 + 主菜单 + 有金额的哥布林交易卡”，因为它同时验证静态文字、动态格式化、数据 ID、状态保留和长英文排版，比只替换按钮更能验证架构。

## 9. 发布与后续维护验收

1. 首启语言选择、系统语言映射、无效设置回退、重启后偏好保持正常。
2. 中文 → 英文 → 中文，多次切换后商品 ID、报价 token、金币／本金、装备实例、角色属性、冷却、波次、随机状态和营地进度不因语言变化改变。
3. 设置、银行输入、选中项、暂停状态、滚动位置保留；日志旧条目能重译；隐藏页面再次打开为当前语言。
4. 武器名称、短说明、详细 tooltip、遗物说明、交易台词和结算同时覆盖；无裸键、未填参数或破损 BBCode。
5. 每种发布语言覆盖全部必需键；未完成的语言在语言清单中关闭发布，不把中文回退当作英文翻译已经完成。
6. 原生回退语言设为英文；迁移包装器在缺译时还可使用明确的中文原文，记录一次诊断。最终发布检查要求关键页面不依赖回退。
7. 校验重复键、缺失／多余占位符、格式符类型、中文原文变更、弃用键、字体缺字及可见中文残留。中文残留仅检查面向玩家的文本，不要求翻译调试日志或开发文档。
8. 测试中的中文固定断言分离为语言用例或固定 locale 的用例，既不能因用户系统是英文误报，也不能以英文自测掩盖中文退化。
9. 实施后的脚本／场景修改先执行 Godot headless 编辑器与必要运行检查；GPU 排版截图使用项目私有桌面工具，验证实际桌面且 `foreground_samples=0`。最后检查实际发行包包含翻译和字体资源。
10. 不增加每帧全量刷新；大量遗物、银行货架与 300 条日志只在必要时更新显示。

后续内容新增流程固定为：新增数据／文案键 → 提取差异 → 填写目标语言 → 校对术语和参数 → 运行完整性检查 → 检查对应界面。已有键保持稳定，减少平衡更新带来的翻译返工。

## 10. 本次依据与边界

主要核对：`project.godot`、`autoloads/data_registry.gd`、`autoloads/window_settings.gd`、`autoloads/combat_settings.gd`、`scripts/ui/game_settings_panel.gd`、`scripts/ui/shop_offer_generator.gd`、`scripts/items/item_inventory.gd`、`scripts/rewards/goblin_trade_system.gd`、`scripts/rewards/battle_finance_system.gd`、`scripts/rewards/economy_journal.gd`、`scripts/ui/economy_log_panel.gd`、`scripts/ui/battle_hud.gd`、`scripts/ui/weapon_damage_meter.gd`、`scripts/ui/run_settlement_panel.gd`、`scripts/data/stat_definitions.gd`、`scripts/weapons/weapon_instance.gd` 以及现有字体与配置。

本方案基于当前工作区，其中有用户正在进行的战斗与敌人修改。实施应在合并最新状态后分批推进，并保留这些改动。本次只新增本文档，不启动美术转换、不提交翻译请求、不生成独立英文游戏分支。
