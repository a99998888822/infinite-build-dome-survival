# 铸铁榴弹炮攻击动图验收

- `grenade_attack_normal.gif`：正常速度，5.40 秒，三次完整攻击，战斗区域放大 2 倍。
- `grenade_attack_half_speed.gif`：同一录制的首轮攻击，以 0.5 倍速度播放，3.60 秒。
- 素材来源：Godot 4.7.2 真实运行，每秒采集 30 帧；没有替换或重绘攻击画面。
- 录制条件：一级榴弹炮、无附魔、单投射物；固定玩家和怪群位置，怪物生命提高至 1000，关闭暴击和自然刷怪，以观察连续攻击。没有更改正式武器配置。
- 正常攻击间隔为 1.80 秒，配置飞行时间为 0.45 秒。三次爆炸每次命中四只怪物。
- 为便于观察，原始 1152×648 画面裁取 `(480, 190, 480, 270)`，最近邻放大至 960×540。
- 当前已能看到：发射闪光、铁球抛物线、分离的地面影子、收拢的金色落点、爆炸火光和烟尘散去。
- 当前美术差距：尚无独立持枪／后坐动画；爆炸火光与烟尘偏轻，重量感仍可加强。

录制入口：`scenes/tests/grenade_attack_capture.tscn`。在隔离工程及隔离用户存档目录中执行：

```powershell
& $godotExe --path $isolatedProject --scene res://scenes/tests/grenade_attack_capture.tscn --fixed-fps 30 -- --capture-dir=$frameDir
```

`capture.json` 保留帧数、配置及发射／爆炸记录。`capture.log`、`headless.log` 与编辑器日志保留运行检查结果：无解析／编译／脚本错误，录制检查通过。退出时仍有既有资源清理警告。
