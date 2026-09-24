# 电浆炮像素球状闪电

最新修订位于 `contact_v4/`。球体与接触伤害统一为12像素半径，显示、物理碰撞、灼击查询和属性栏读取同一配置；移除旧112像素伤害范围。只有正在接触球体的怪物会受到灼击，离开后停止，保留每颗最多5次和0.1秒间隔。球体仍使用 `energy_v3` 的圆形脉动内核、短促火花及接地电弧。旧版媒体保留在根目录、`compact_v2/` 和 `energy_v3/`，以下文件以 `contact_v4/` 内为准。

- `plasma_live.gif`：8秒、20帧/秒的正式攻击实录。
- `plasma_detail.gif`：同一实录首发弹体的三倍跟随放大，保持原速，便于检查电弧抖动与闪回。
- `plasma_live.mp4`：1152×648、30帧/秒的完整游戏视口。
- `capture.json`：逐帧弹体位置、每次伤害时球体与怪物碰撞体的表面间距、目标剩余生命及暂停验证结果。只有每次灼击表面间距≤0.25像素才允许导出；该容差只用于录制验证，不加入实际伤害查询。
- `first_contact.png`：第一发首次造成伤害的原始实录帧裁剪。
- `editor.log`、`headless.log`、`capture.log`、`contact_test.log`：本次验证与实际运行日志，22项接触回归涵盖边界内外、斜向接触、连续灼击、离开／重新接触、动态缩放与暂停。

录制使用完整 GameRoot、BattleRoot、WeaponLoadout 和正式 ProjectileInstance。为观察完整飞行过程，三只普通敌人固定位置并设为1000生命，暴击率设为0；武器范围、伤害、攻速、弹速和接触灼击均使用正式配置。记录真实伤害事件验证接触时机，旁边未接触到的怪物可以不受伤。使用隔离工程及独立存档目录，不影响玩家存档。

球体由代码一次生成16帧24×24内核纹理并共享缓存，采用四档自发光色阶，不计算镜面球体光照。所有火花、电弧均为视觉，不增加伤害判定。暂停检查同时验证球体位置、视觉时钟和地面落点冻结。引擎退出时仍有既有 ObjectDB／Canvas／资源清理提示，保留在日志内。39项战斗音效回归结果仍见根目录 `combat_audio_test.log`。

```text
godot --headless --editor --path <project> --quit
godot --headless --path <isolated-project> --scene res://scenes/tests/plasma_ball_live_capture.tscn --fixed-fps 30 --quit-after 600
godot --path <isolated-project> --scene res://scenes/tests/plasma_ball_live_capture.tscn --fixed-fps 30 --quit-after 600 -- --capture-dir=C:/Users/mi/AppData/Local/Temp/codex-plasma-ball-live
godot --headless --path <isolated-project> --scene res://scenes/tests/plasma_contact_test.tscn --fixed-fps 60 --quit-after 1800
python scripts/tools/build_plasma_ball_review.py --revision contact_v4
```
