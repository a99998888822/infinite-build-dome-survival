# 哥布林死亡嘲讽 · 两段结尾素材

输出目录：`artifacts/previews/goblin_death_promo_20261024/`。

| 成片 | 时长 | 原生台词与表情 |
| --- | --- | --- |
| `01_goblin_death_followed.mp4` | 4 秒 | 完整结算界面；接受挑战后死亡，欣喜表情：“哥布林包赚，但不包活哈哈哈！” |
| `02_goblin_death_refused.mp4` | 4 秒 | 完整结算界面；拒绝挑战后死亡，不悦表情：“嘬嘬嘬，不听哥布林，吃亏在眼前！” |

两段均为 1920×1080、60fps、H.264/AAC。原生结算音效 100，背景音乐 0 且静音。当前两句台词的语音配置为空，本次没有增加配音、配乐或外部字幕。

## 镜头处理

使用原生结算面板的四帧表情动画与每秒 18 字的对白显示。原录制从结算时间 3.85 秒开始，约 0.75 秒后出现对白，完整显示后继续停留至片尾。

用户随后明确要求保留结算界面，因此当前交付为不含 `_closeup` 的完整画面原片，同时呈现结算数据、哥布林和逐字对白。原片的统计为临时局的零值，未虚构实战收益。`full_settlement_contact.jpg` 与 `full_settlement_validation.json` 保存本次画面和音轨核对结果。

此前 `_closeup` 版本仅作为备选保留：从实际 GPU 画面裁出完整对白框与哥布林，采用整数两倍像素缩放，并直接复制原录制音轨。

## 录制边界与验证

- 独立临时游戏，通过实际挑战 UI 分别接受、拒绝额外精英挑战，由原生建议记录选择对应结算反应。
- 开拍前使用脚本触发死亡，直接进入正式结算流程；只录制结算尾段。没有录制或宣称此前经过一场完整战斗，完整原片的统计为临时局数据。
- 正式游戏规则、台词、表情资源均未修改，不写入正式存档。
- Godot 无窗口导入检查和两种反应排练已完成。接受版的无窗口排练遇到角色选择 UI 的既有 dummy texture 提示；两段正式 GPU 录制均无脚本或资源错误。
- GPU 在私有 Windows 桌面运行，两段 `foreground_samples=0`，实际桌面与目标桌面一致。
- 已核对逐字显示、两种表情、完整台词及裁切边界。成片各 240 帧、4 秒，音频峰值约 0.160，无削波。
- `delivery_contact.jpg` 保存画面抽查，`delivery_validation.json` 保存成片参数；各分镜的 `report.json`、`capture.json`、`export.json` 保存原始验证记录。

```powershell
python scripts/tools/record_goblin_deaths.py --mode headless
python scripts/tools/record_goblin_deaths.py --mode record
python scripts/tools/finish_goblin_deaths.py
```
