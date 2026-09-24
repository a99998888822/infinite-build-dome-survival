# 坤舆秘仪书／食利者钱袋正式实现

已接入正式 `WeaponLoadout` 和 `WeaponInstance`，不依赖 `scripts/tests/tome_purse_preview.gd`。通过现有商店／升级奖励候选获得，支持负载校验、五级成长、附魔、出售与退还附魔。

## 参数与效果

| 项目 | 坤舆秘仪书 | 食利者钱袋 |
| --- | --- | --- |
| 基础伤害（1～5级） | 10／13／16／19／22 | 4／5／6／7／8 |
| 加成 | 元素伤害 ×1 | 远程伤害 ×0.6＋0.3×√银行本金 |
| 攻击间隔 | 0.80秒 | 1.10秒 |
| 默认数量 | 每轮点名1个领域内目标 | 每轮3枚金币，相隔120°，下一轮偏转30° |
| 范围 | 椭圆半轴220×145 | 飞行距离280、速度380 |
| 负载／附魔槽 | 22／3 | 18／3 |
| 分裂 | 在领域内追加不同目标，默认2次、60%伤害、一代 | 生成默认2枚小金币、60%伤害、一代 |
| 穿透 | 拒绝并提示原因 | 支持卷轴额外命中次数 |

两者均不显示玩家身边的武器本体。领域保留已确认的 V5 方粒、间距大幅波动、随机初始角度、轻微旋转和最高20%不透明度符文。主金币使用已确认的8帧翻转贴图和方粒拖尾。同轮金币及分裂弹共享原生命中记录，避免同一敌人重复承受原生伤害。

本金只读银行当前余额，独立于开局“理财”属性；普通增伤、暴击、敌方减伤与元素附魔走正式战斗流程。

秘仪书指纹爆发版：`impact_v3/tome_live.gif`，局部三倍放大、半速播放见 `impact_v3/impact_detail_slow.gif`。沿用蓝白色，以五道不对称的开口弧纹构成指纹：0.16秒内快速撑开，0.18～0.48秒淡出，仅保留6枚小方粒，总表现时长0.60秒；移除双层菱形、外围符文与十字闪光。该修改仅调整命中绘制；领域、伤害、攻速和钱袋表现沿用正式版本。`impact_v3/test.log` 的64项专项检查通过；实录与编辑器日志同存该目录。前版保留在 `impact_v2`。

最新尺寸调整版：`impact_v4/tome_live.gif`。指纹宽高缩小至 `impact_v3` 的50%，描边、方粒大小及扩散距离等比例缩小，命中中心与动画时序不变。编辑器及正式战斗实录日志保留在 `impact_v4`。

## 验证

- `test.log`：64项专项检查通过，包含真实银行存取款、伤害计算、范围边界、分裂与火焰、穿透、冷却与粒子暂停、波末清理、买入／升级／出售交易、退还附魔及返回主菜单。
- `grenade_regression.log`：87项既有榴弹炮检查通过，也覆盖弓箭／电浆炮装备和原有附魔兼容规则。
- `editor.log`：主工程 headless 编辑器验证。
- `capture_*.log`、`*_capture.json`：正式图形运行的发射、命中、击杀和移动记录。
- 引擎退出仍会报告已有 Canvas／ObjectDB／资源清理提示，保留在日志中。

## 实录

`tome_live.gif`、`purse_live.gif` 展示单把武器；`combined_live.gif` 展示两把武器同时装上分裂与火焰。GIF裁取战斗区域，为640×540、8秒、20帧/秒；同名MP4保留完整HUD，为1152×648、30帧/秒。`media_validation.json` 记录媒体规格。

实录使用完整 GameRoot、BattleRoot、正式装备和移动敌人，调用玩家现有移动输入接口。为避免随机刷怪和奖励弹窗打断，固定生成18个使用原生属性的普通怪物，不冻结敌人；录制角色生命调至1000，暴击率设为0，钱袋通过银行存入演示本金400。武器伤害、冷却、范围、动画和命中处理均未替换为预览逻辑。

运行使用隔离工程和独立用户存档目录 `CodexTomePurseImplementation`，不改动用户真实游戏存档。逐帧PNG位于工程外临时目录。

```text
godot --headless --editor --path <project> --quit
godot --headless --path <isolated-project> --scene res://scenes/tests/tome_purse_weapon_test.tscn --fixed-fps 60
godot --path <isolated-project> --scene res://scenes/tests/tome_purse_live_capture.tscn --fixed-fps 30 -- --variant=tome --capture-dir=<external-frame-directory>
python scripts/tools/build_tome_purse_live_review.py
```

录制变体支持 `tome`、`purse`、`combined`。导出脚本读取临时目录 `codex-tome-purse-live-<variant>`。
