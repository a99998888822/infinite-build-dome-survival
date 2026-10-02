# Godot后台实机录制

验证脚本优先使用 `--headless`。需要实际渲染动图时，在Windows使用 `run_godot_background.py`，在独立的后台桌面运行Godot，不切换用户当前桌面，避免游戏弹到浏览器前面；这仍是真实GPU渲染，不是无界面截图。

```powershell
python scripts/tools/run_godot_background.py `
  --godot 'D:/soft/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' `
  --log "$env:TEMP/dagger-background.log" --timeout 180 -- `
  --path . --scene res://scenes/tests/camp_dagger_live_capture.tscn `
  --rendering-method gl_compatibility --rendering-driver opengl3_angle `
  --resolution 1152x768 --fixed-fps 30 --quit-after 1000 -- `
  --transient-session --variant=base --capture-dir="$env:TEMP/camp-dagger-qa/base"
```

短刀支持 `base`、`split`、`split_fire`、`split_lightning`。捕获脚本通过根视口读取每帧PNG，另写入实际命中和伤害统计JSON；工具本身不模拟画面。可用ffmpeg将顺序帧合成GIF，像素放大使用 `scale=...:flags=neighbor`。

工具只创建私有桌面，并通过子进程的 `STARTUPINFO.lpDesktop` 指定运行位置；不调用 `SwitchDesktop`，监测进程继续留在用户桌面。工具自动追加 `--background-capture`，让窗口管理器跳过启动居中／全屏／保存设置。以20ms间隔记录引擎是否进入用户桌面的前台，结束时打印 `foreground_samples`（正常为0）并在日志旁保存JSON。超时只停止本工具创建的引擎，退出时关闭私有桌面。

使用原生 `CreateProcessW` 传递桌面字段；不能动态给Python `subprocess.STARTUPINFO` 添加 `lpDesktop`，该字段不会被CPython传给Windows。启动后枚举私有桌面的真实引擎窗口，确认所属桌面后继续录制；找不到窗口立即停止本次引擎。

传入官方 `_console.exe` 时自动解析同目录真正的引擎 `.exe`，直接启动和监测引擎PID，避免只监测控制台启动器。

不要只依赖隐藏父窗口或 `SW_HIDE`：Godot初始化时仍可能争抢当前桌面焦点。后台桌面隔离经过实际渲染验证；不要调用 `SwitchDesktop` 把它显示出来。

用户希望验证不遮挡其浏览器，因此此项目后续图形验证继续使用该入口。输出应放系统临时目录；正式资源保留在assets，artifacts仅保留未接入的设计稿。
