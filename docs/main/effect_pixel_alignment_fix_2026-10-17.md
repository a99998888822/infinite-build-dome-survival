# 战斗特效像素对齐修正与实机审阅

已修正结霜体型来源、状态分层与锚点、屏幕震动单位，以及主要武器特效在缩放和旋转后的像素采样。保留已确认的武器轮廓、大小、方向、伤害范围和卡肉机制。

## 本轮修正

- **结霜、冻结**：不再从整张动画画布推导身体半径。圆形、胶囊碰撞体共用实际身体尺寸；头顶、脚底位置使用四类敌人的稳定配置，并适配当前基础体型和挑战倍率。结霜在脚底绘制连片硬边冰面；冻结另有身体冰壳。霜层不会再随动画画布被放大数倍。
- **附着状态**：湿润、光、暗、眩晕、燃烧和霸体提示使用稳定锚点；小图标移除抗锯齿线段，霸体提示改为原生 12px 字号。阴影共用体型依据。
- **武器图集**：新增最终像素网格采样，先保留原来的拉伸、旋转和地面投影，再在最终画面中取整；采样限制在当前动画帧内。覆盖榴弹爆炸、秘仪命中/领域、触手、锤风/裂地、枪芒、摆锤轨迹、短刀刀花、位移图集、钱币与电浆球核等入口。
- **附魔与技能**：风刃改为在固定网格内计算方向；正式冰场及扩张、折射光束、光辉剑地面标记、蝙蝠技能图集补齐采样对齐。光辉剑主体沿用用户要求回退后的造型。
- **屏幕震动**：偏移按世界渲染像素计算，再换算附属图层位置；消除旧 UI 分辨率换算带来的额外放大。统计阈值和每次 0.05 秒定格逻辑未改动。
- **雷火审阅造型**：黄白色连片主体，外缘为直边尖角。

通用对齐修正已经进入对应正式绘制代码。雷火、连片冰场等上一轮整组组合反应造型仍由 `ReactionBlockPreview.enabled` 控制，正常游戏默认关闭；本轮审阅没有把整组候选切为正式资源。

## 审阅动图

均为私有 Windows 桌面上的实际 GPU 游戏运行。通过正式武器施放、投射物碰撞和附魔路径触发；目标设置高血量并停止追逐，保留伤害与状态逻辑。没有直接调用伤害函数或手动播放特效来代替命中。

录制为 1920×1080，交付媒体仅裁切、加说明；没有平滑缩放。无损 WebP 是审阅原件，另有不使用抖色的 GIF 兼容副本。

- [结霜、冻结、两种小 Boss](D:/project/useless/review-archives/pixel-alignment-fix-20261017/frost-review.webp)
- [黄白尖角雷火、斜向风刃、风冰候选](D:/project/useless/review-archives/pixel-alignment-fix-20261017/reaction-review.webp)
- [七种武器群体命中合集](D:/project/useless/review-archives/pixel-alignment-fix-20261017/weapons-review.webp)

| 武器 | 单次录制实际命中的不同怪物 | 单独动图 |
| --- | ---: | --- |
| 铸铁榴弹炮 | 12 | [查看](D:/project/useless/review-archives/pixel-alignment-fix-20261017/weapon-grenade.webp) |
| 坤舆秘仪书，附分裂 | 7 | [查看](D:/project/useless/review-archives/pixel-alignment-fix-20261017/weapon-tome.webp) |
| 异化触手 | 12 | [查看](D:/project/useless/review-archives/pixel-alignment-fix-20261017/weapon-tentacle.webp) |
| 裂地战锤 | 18 | [查看](D:/project/useless/review-archives/pixel-alignment-fix-20261017/weapon-hammer.webp) |
| 守夜长枪 | 12 | [查看](D:/project/useless/review-archives/pixel-alignment-fix-20261017/weapon-spear.webp) |
| 流星摆锤 | 12 | [查看](D:/project/useless/review-archives/pixel-alignment-fix-20261017/weapon-flail.webp) |
| 巨型手持火炮 | 3 | [查看](D:/project/useless/review-archives/pixel-alignment-fix-20261017/weapon-cannon.webp) |

## 验证与边界

- Godot headless editor：通过，无解析或编译错误。
- 像素对齐回归：headless 24 项、GPU 28 项通过。检查四种体型、缩放只计算一次、霜层生命周期与层级、屏幕位移、旋转图集不串帧、每个 3×3 格子取色一致、绘制节点复用。
- 通用受击反馈：109 项通过。
- 实机：七种武器群体命中、斜向风刃、普通怪物/两类小 Boss 结霜、水冰冻结、风冰扩张、雷火、正式折射触发均有成功记录。折射初次夹具先附光再用水攻击，光被正常伤害消耗；改为水后附冰与光辉剑，按真实规则触发通过。
- 所有本轮 GPU 审阅运行均核验实际引擎桌面与私有桌面一致，`foreground_samples=0`。
- 主场景 headless 启动、运行 120 帧成功；强制退出时报告菜单 BGM 的 Ogg 播放资源未释放。详细日志定位为 `bgm_menu.ogg`，不是本轮特效脚本解析或运行错误；未在本轮修改音频生命周期。
- UTF-8 替换字符检查与 `git diff --check` 通过。

本轮不是每种升级倍率、每个朝向和每类怪物技能的穷举录像。伤害数字的弹出缩放、柔和光晕、已批准的黑洞细线保持原表现。小于 1080p 的窗口仍会丢失世界画面的像素细节；最近邻只能避免混色，无法无损容纳所有像素。

工作区同时有分辨率、UI、基础体型和武器数值的独立修改，本轮予以保留。录制读取的是当时实际工作区：世界和 UI 均为 1920×1080，世界到窗口 1:1。旧审计文档中的 1152 UI 数值仅代表修正前的测量，不应当作当前运行值。

证据目录：`D:/project/useless/review-archives/pixel-alignment-fix-20261017/`。其中早期试录保留用于追溯，交付使用本文链接的成功片段；最终选择和运行核验见 [verification.json](D:/project/useless/review-archives/pixel-alignment-fix-20261017/verification.json)。
