# R01 像素特效正式安装记录

2026-10-10，用户确认全部采用。9 组正式 PNG 与审阅包候选逐一通过 SHA-256 校验，清单见 [installed_assets.json](installed_assets.json)。

## 安装内容

- 替换 7 组位移图集：突进落地斩击、突进残影、移星离开／抵达／返回、原位星印、冲击环。
- 新增正式风刃与摆锤拖影图集，分别接入 `wind_blade_effect.gd` 与 `meteor_flail.gd`。
- 风刃沿实际生命周期取帧，保留移动方向、速度、效果范围系数、碰撞、击退和地场交互。
- 摆锤以各次挥动的独立时间取帧，镜像反向动作，按实际锤头距离缩放并对齐前沿；支持延迟分裂及火／冰／电染色。原锤头、铁链、伤害结算和挥动时序保留。
- 突进斩击继续使用 145:220 椭圆投影；基础圆形伤害半径 96 不变。已确认的浅青灰指示器样式保留。

原 7 张 PNG 和安装前两个绘制脚本保存在 `before/`，未覆盖其他并行工作。风刃安装前已有的 `control_power` 击退参数保留。[原审阅包](../../previews/pixel_effects_r01_20261010/README.md)及其基线、候选、画面全部保留。

## 验证结果

| 检查 | 结果与记录 |
| --- | --- |
| 编辑器导入 | 完成，无脚本／编译错误；见 `editor-final.log` |
| 位移武器 | 109 项通过；见 `mobility.log` |
| 范围规则 | 118 项通过；见 `ranges.log` |
| 图集运行时 | 93 项通过，无错误或警告；见 `atlas-clean.log` |
| 正式资源 GPU 采样 | 120 张，失败 0；见 `gpu_capture.json`、`gpu.json` |
| 扩大视野的运行时变体复核 | 8 张，失败 0；见 `gpu_live_capture.json`、`gpu-live.json` |

上述三个专项套件共 320 项通过。图集测试检查真实不透明像素相对锤头的位置，覆盖正反向、斜向、扩大范围、延迟分裂和起止帧；另检查风刃实际移动、方向、暂停和自定义生命周期。GPU 使用正式资源、正式运行时代码，两次均退出 0，实际引擎桌面与指定私有桌面匹配，`foreground_samples=0`。

运行时画面：[反向摆锤](renders/live_flail_reverse.png)、[真实命中触发火焰分裂](renders/live_flail_fire_split.png)、[斜向移动风刃](renders/live_wind_diagonal.png)。这是受控采样，不是密集混战性能测试。第二次采样扩大取景框以完整显示加长铁链与锤头。

## 未通过与既有提示

- 原摆锤测试共 45 项，10 项硬编码伤害数值断言失败。使用安装前绘制脚本的独立子类再次运行，同样 10 项失败；失败名称逐项一致，见 [legacy_test_comparison.json](legacy_test_comparison.json)、`flail.log`、`flail-baseline.log`。这 10 项不计入本次通过结果。
- 原像素效果测试共 27 项，其中 `water area modifier still applies` 失败；风刃速度、接触、忽略目标、击退、重复命中保护、暂停和生命周期检查通过。见 `wind-mechanics.log`。本次没有修改水域范围逻辑。
- 主场景无界面运行 120 帧退出 0，但仍报告 4 个 ObjectDB 实例／2 个资源的退出释放提示，见 `main.log`。
- 编辑器仍报告 Android build-tools 目录和嵌套测试项目提示。
- 一次并行验证启动时出现存档 JSON 读取错误，记录于 `atlas-final.log`；随后确认实际 JSON 有效，串行重跑的 `atlas-clean.log` 93 项通过且无错误或警告。本次未修改存档。

## 文件用途

`install_assets.py` 是已执行的复制及备份脚本；`prepare_validation.py` 生成旧绘制方式对照与正式资源采样夹具；`capture.gd`、`launch.gd` 为安装验证入口；`godot_frames/` 与 `renders/` 为采样结果。正式运行时只引用 `assets/` 下的图集，不依赖本目录或审阅目录。

审阅包已作为存档保留；不要在原目录重跑制作或捕获以覆盖替换前基线。后续迭代应使用新目录。回退时应参考 `before/` 中的文件，对两个正式脚本只撤销绘制相关差异，避免覆盖后续其他改动。
