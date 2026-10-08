# 多语言文案维护

`catalogs/` 下的 4 张 CSV 是正式文案的唯一维护入口，使用 UTF-8。原来的 50 张细分表已合并，语义 key 和中英文内容保持不变：

| 文件 | 维护内容 | Key 前缀 |
| --- | --- | --- |
| `ui.csv` | 主菜单、设置、战斗界面、银行、商店等界面文字 | `ui.*` |
| `content.csv` | 角色、武器、遗物、附魔、敌人、营地等内容名称和说明 | `content.*`、`enchantment.*` |
| `gameplay.csv` | 属性、战斗标签、难度、稀有度、物品类型与经济规则 | `stat.*`、`combat.*`、`difficulty.*`、`rarity.*`、`item.*`、`economy.*` |
| `messages.csv` | 错误提示与战斗、交易、结息等日志模板 | `error.*`、`log.*` |

新增文案按上表归类，各表按 key 排序；无需为每个页面或小功能再建文件。文件名不参与运行时查找，代码始终使用语义 key。每行同时包含 key、中文和英文：

```csv
keys,zh_CN,en
ui.bank.deposit.confirm,确认存入,Confirm Deposit
ui.settings.audio.music,背景音乐,Music
stat.max_health.name,最大生命,Max HP
```

## Key 的规则

- 用“领域.功能.用途”命名，例如 `ui.bank.deposit.confirm`、`log.finance.deposit`、`stat.max_health.description`。
- key 表示用途，不复制整句英文；调整中英文措辞时，保持 key 不变。
- 同一概念的名称、说明、提示分别使用 `.name`、`.description`、`.tooltip` 等明确后缀。
- 数据文案使用既有内容 ID，例如 `weapon.weapon_void_blade.name`，不改变游戏逻辑使用的 ID。
- 不使用数字序号、文本 hash 或按翻译批次命名的文件作为正式文案接口。
- `%d`、`%s`、`%.2f`、`%%` 等占位符必须保持数量、类型与顺序，富文本标签也必须匹配。
- 多行文案采用标准 CSV 引号；用支持 CSV 的表格编辑器查看时仍是一行一条文案。

## 工具与当前状态

`catalog_meta.json` 是扫描来源清单，用于查找原文所在文件、行号和数据字段。`index` 仅是查看清单时的定位编号，运行时及翻译文件都不依赖它。`source_hash` 用于核对原文变化，不是文案 key。没有完成整理的候选项显式标为 `pending`，其 key 为空。

```powershell
python scripts/tools/localization_inventory.py
python scripts/tools/localization_catalog.py
python scripts/tools/localization_catalog.py --require-complete
python scripts/tools/localization_catalog.py --build --require-complete
```

第一个命令更新来源清单并保留语义 key；第二个检查重复 key、空译文、占位符、富文本和编码；`--require-complete` 拒绝未完成的候选项；`--build` 更新兼容映射并在项目中登记 Godot 原生翻译资源。之后用 Godot 编辑器导入，或运行无界面导入检查。

原先按数字索引记录的临时翻译草稿已迁入上述模块表并移除。运行组件、主界面入口与动态文案已经接入。`artifacts/localization/` 仅存放按需生成的验证日志、审阅截图和压缩包，不纳入版本控制；审阅完成后可以整目录删除，不影响游戏运行。

`generated/` 完全由工具生成，不手工编辑。其中额外的 `source_aliases.csv` 和 `source_keys.json` 把现有配置中的原文、显示常量对应到语义 key，采用整条精确查找，不进行中文子串替换。日常只需维护上面的 4 张表；`.csv.import`、`.translation` 是 Godot 自动生成的导入信息和运行资源，也不手工编辑。原文来源清单与实际译文分开，因此修订中文措辞时可以保留 key，也不必修改玩法 ID 或载入后的数值配置。新增内容先补语义 key 与两种译文，再生成映射。

运行时入口是 `L10n.text(key)`；格式化模板先翻译，再代入参数。数据显示使用 `L10n.source(value)` 或 `L10n.record_text(record, field)`。需要跨语言重绘的历史事件使用 `L10n.message(key, args)` 保存参数，在显示时调用 `L10n.render_message()`。不要把已经拼好的句子当作可长期重绘的事件数据。

语言偏好保存在独立的 `user://localization.cfg`。主界面右上角提供唯一入口；首次运行根据系统语言选择中文或英文。无界面、截图和 `--transient-session` 会话不写用户偏好，可用 `--locale=en` 或 `--locale=zh_CN` 指定验证语言。

## 增加语言

在 `locales.json` 登记语言代码、母语名称与标题图片，并在每张模块表中按清单顺序增加对应语言列。补全翻译后执行构建与 Godot 导入；下拉框自动读取清单。检查该语言的字体覆盖和长文案排版。当前共享的像素字体已包含中英文，不需要因这次接入更换字体。

验证命令：

```powershell
python scripts/tools/validate_localization.py editor localization_test --locale en
python scripts/tools/validate_localization.py main --locale zh_CN
```

GPU 审阅仍须通过项目的 `run_godot_background.py` 私有桌面工具，不能为自动验证弹出普通游戏窗口。

完整实机截图入口是 `scenes/tests/localization_visual_review.tscn`。分别传入 `--locale=zh_CN`、`--locale=en` 和 `--capture-dir=res://artifacts/localization/review`，使用临时进度展示界面、全部图鉴条目、属性与附魔详情、银行、借贷、挑战及结算；长列表包含滚动分页。可用 `--review-section=menus|battle|encyclopedia|bank|events` 单独重拍对应部分。截图目录有 `.gdignore`，不参与游戏导入或打包。

两种语言拍摄完成后，运行 `python scripts/tools/build_localization_review.py`，生成 `artifacts/localization/review/index.html` 中英文对照审阅页及 `artifacts/localization/localization_review.zip` 离线压缩包。页面支持原图查看、分类搜索和审阅意见导出，并附完整文案清单；截图清单及可见文字检查结果保存在同目录的 `manifest_*.json`。

当前导出预设已显式包含 `localization/locales.json`、`localization/generated/source_keys.json` 和现有玩法 JSON。新增导出预设时也需要包含这些非资源文件；翻译 CSV 对应的 `.translation` 由 Godot 导入并通过项目设置打包。开发来源清单和临时翻译草稿不参与运行。
