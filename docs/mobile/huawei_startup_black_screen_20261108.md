# 华为 Android 1.0.2 启动黑屏排查

日期：2026-11-08。已知信息只有华为手机、Android APK、显示版本 1.0.2，未取得型号、系统版本、故障 APK 的校验值或设备日志。

## 结论

**尚未复现华为实机黑屏，不能确定唯一根因。** 当前源码和本机两个 1.0.2 APK 的游戏资源均能在桌面兼容渲染器显示主菜单。最有实测依据、应优先优化的项目风险是首屏之前的同步资源加载和纹理内存占用；设备 OpenGL ES 初始化失败仍需排查。现有证据不支持直接认定 Vulkan、TapTap 网络或防沉迷拦截导致了全黑。

本次未修改运行源码、导出配置或素材，未创建 Git 提交。诊断脚本、日志、截图和提取资源位于本地忽略目录 `tmp/huawei_black_screen_20261108/`。

## 已完成的验证

引擎：本机 Godot 4.7.1 stable。GPU 验证使用 `scripts/tools/run_godot_background.py` 私有 Windows 桌面，均记录实际桌面匹配、`foreground_samples=0`。GPU 为 GTX 1060，经 ANGLE / D3D11 提供 OpenGL ES 3.0；这不是华为 GPU 或 Android 原生运行环境。

| 验证 | 结果 | 范围限制 |
| --- | --- | --- |
| Headless 编辑器扫描 | 退出 0，无 Parse / Compile / SCRIPT ERROR | 不验证 GPU 与 Android 原生库 |
| Headless 主场景，移动布局 | 到达 `game root ready` | Dummy 渲染有两处既存空纹理错误和退出 RID 泄漏，不代表 Android GPU 同样失败 |
| 当前源码 GPU 首屏 | 主菜单可见，截图成功 | 桌面移动布局模拟 |
| 模拟 Android 登录必需但原生桥接缺失 | 显示错误面板、退出按钮和菜单遮罩 | 只模拟 GDScript 状态，不模拟 Java 加载和 SDK 原生崩溃 |
| 两个 APK 的 assets 提取为资源包，使用原编译脚本和纹理运行 | 均到达主菜单，截图一致 | Windows 引擎加载导出资源，不执行 APK 的 Android 生命周期、原生库或真实 TapTap SDK |
| `adb devices -l` / `emulator -list-avds` | 无连接设备 / 无已配置 AVD | 无法进行本次 Android 实机复现 |

APK 资源探针并行执行时，其中一次出现存档替换冲突；该运行仍显示主菜单。此错误有并行本地实例竞争同一存档路径的干扰，不能作为手机黑屏证据。后续源码分阶段探针使用 `--transient-session`；检查时主存档和备份均为有效 JSON。

## 首屏加载的具体风险

源码分阶段 GPU 探针（未进入战斗）测得：

| 阶段 | Godot 统计的纹理内存 |
| --- | --- |
| autoload 完成、加载主场景之前 | 163.02 MiB |
| 主场景 PackedScene 加载完成、实例化之前 | 315.50 MiB |
| 主菜单显示后 | 346.48 MiB |

该次主场景同步加载 3.77 秒；另一独立源码探针为 3.90 秒。静态分配统计约 251 MiB。以上是桌面引擎统计，**不是 Android 进程 PSS 或故障手机的实测值，不能直接相加当作手机总内存，也不能据此宣称已经 OOM**。APK 资源探针也测得约 346.48 MiB 纹理占用，说明这个负担并非仅由当前未导出的修改产生。

关键加载链路：

- `project.godot` 直接进入 `scenes/core/game_root.tscn`，没有独立的轻量首屏加载场景。`scripts/core/bootstrap.gd` 不是生产主入口，其中自检不在本次正常启动路径上。
- `scripts/core/game_scene_director.gd:4`、`:5` 常量预加载完整战斗和营地 PackedScene；尚未进入这两个模式也会解析其资源依赖。
- `scripts/ui/main_menu_ui_controller.gd:66` 起，在 `_ready()` 中立即创建地下城加载界面、角色选择和设置界面。隐藏界面同样可能持有纹理与字体。
- `scripts/ui/dungeon_loading_screen.gd:6` 至 `:11` 预加载战斗效果及两套渲染预热脚本，继续扩大战斗效果依赖。
- 导出启动背景设为黑色。在首帧菜单准备完毕之前，长时间加载或设备渲染异常容易被玩家描述成黑屏。是否发生应用无响应或系统终止需要设备日志确认。

建议优先做一个可对照验证的启动优化：轻量首屏先显示进度与错误状态，战斗/营地资源延后按需加载，隐藏页面延迟创建，记录 autoload、场景加载、实例化及首帧各阶段耗时。仅把一处 `preload` 改为 `load` 不保证降低整个依赖图的启动占用，必须重新测量。

## 渲染兼容性与其他发现

- 当前工程及两个包内 `project.binary` 都指定 `gl_compatibility`，移动端没有切换到 Vulkan。APK 声明 OpenGL ES 3.0、minSdk 24、targetSdk 36、仅 ARM64。不能把“兼容模式”理解为支持 OpenGL ES 2.0。
- 桌面 ANGLE 成功不能排除华为 Mali / Maleoon 等具体 GPU 驱动上的 EGL、上下文创建、纹理分配或着色器编译问题。品牌本身不足以判断 GPU 型号。
- 两个导出包均包含 5760×320 的 `meteor_flail_trail.png` 和 `block_vfx/flail.png` 纹理，原始导入为无损、无尺寸限制。应检查目标设备的纹理上限和 Godot 实际处理；单独一张超尺寸纹理不能据此推断整个主菜单必然全黑。
- `scripts/core/game_root.gd:207` 手动调整由 `stretch=true` 的 SubViewportContainer 管理的视口尺寸，稳定触发警告。GPU 首屏仍可显示，故目前没有证据将其认定为启动黑屏根因；可在后续视口修正中处理。
- TapTap 未配置、桥接缺失等 GDScript 路径设计为显示账号错误面板；模拟桥接缺失确实显示了面板。SDK 初始化缺少超时恢复是另一个可改进项，但这种等待预期保留可见账号界面，不能直接解释启动即全黑。

## 1.0.2 并非唯一构建

本机桌面导出目录发现：

| 文件 | versionCode | TapTap 原生库 | SHA-256 |
| --- | --- | --- | --- |
| `goblin-dungeon-1.0.2-debug-archived.apk` | 2 | 无 | `0e9ce95c6484da058c03f3581f5b9e566ca8f13a16c7e543eafe637c2bd02df8` |
| `goblin-dungeon-1.0.2-touch-fix.apk` | 3 | 有 | `5c50d8b4e083741f0fc6cfc53ece4ac4ac889e6a6733dc0146be6dcb730265f1` |

二者都为可调试包、显示版本 1.0.2。必须用 versionCode 或 SHA-256 对应玩家实际下载包；不能因显示版本相同就认为测试的是同一个构建。

## 如何拿到能定因的证据

连接一台能够发生问题的设备并允许 USB 调试后，先开始日志采集，再手动打开游戏复现。以下 `adb` 指 Android SDK 的 `platform-tools/adb.exe`，PowerShell 中重定向原始命令输出即可，不要先清空日志缓冲区：

```powershell
adb devices -l
adb shell getprop ro.product.model
adb shell getprop ro.build.version.release
adb shell getprop ro.build.version.sdk
adb shell dumpsys package com.octopus.goblin.dungeon > huawei-package.txt
adb logcat -v threadtime -b main -b system -b crash > huawei-startup.log
```

复现后结束 logcat；Android 11 及以上可再取最近退出原因：

```powershell
adb shell dumpsys activity exit-info com.octopus.goblin.dungeon > huawei-exit-info.txt
adb shell dumpsys meminfo com.octopus.goblin.dungeon > huawei-memory.txt
```

判读顺序：

1. EGL / GLES 上下文失败、GPU 驱动报错或 `SIGSEGV`：定位引擎/驱动初始化或原生崩溃。
2. `lmkd`、内存分配失败、系统 low-memory 退出：确认启动内存压力，再对照轻量首屏构建验证。
3. `ANR`：查主线程堆栈，区分资源加载、存储、SDK 或其他阻塞。
4. `SCRIPT ERROR`、缺资源或错误 remap：对应确切 APK 的资源与编译脚本排查。
5. 已记录 `game root ready` 但仍全黑：优先检查首帧提交、渲染目标、Surface 生命周期及 SDK 覆盖窗口。

最终定因至少需要一次故障启动日志；无需先拿齐所有机型信息才开始分析。

## 补充：Android 模拟器实跑尝试

同日按用户要求实际准备并启动 Android 模拟器，结果为**模拟器系统未能启动，尚未运行 APK**。不将这个结果计作游戏黑屏复现，也未完成多个 Android 版本或华为机型的验收。

环境检查发现：Intel i7-8700、`VirtualizationFirmwareEnabled=false`、`HypervisorPresent=false`，`emulator -accel-check` 返回 6，提示未安装 Android Emulator hypervisor driver。没有修改 BIOS、启用 Windows 虚拟化功能、安装内核驱动或重启电脑。

已完成的准备：

- 下载官方 Android 11 / API 30 Google APIs x86_64 系统镜像 r16，1,438,186,618 字节；SHA-1 与官方索引一致：`6ae21030eaadc041078444d3798e4b399f3e787d`。使用本机已有 Android SDK 许可。
- 镜像安装于 `C:/Users/octopus/AppData/Local/Android/Sdk/system-images/android-30/google_apis/x86_64/`。
- 创建独立 AVD `codex_startup_api30`，1080×2340、2 GiB RAM。镜像的 build.prop 声明 `x86_64,x86,arm64-v8a,armeabi-v7a,armeabi`；因 Android 未启动，尚未实测 ARM64 转译。
- 两次启动均使用 `-no-window -no-audio -no-snapshot -accel off -gpu swiftshader`，没有弹出模拟器窗口。

| 尝试 | 结果 |
| --- | --- |
| 4 核软件模拟 | ADB 始终 offline，观察后手动结束 |
| 1 核、关闭 Vulkan、开启内核输出 | 观察接近 3 分钟仍 offline，没有达到 `sys.boot_completed=1`，结束测试进程 |

模拟器日志明确提示 `x86_64 emulation may not work without hardware acceleration!`。这说明目前的测试环境无法提供有效的 Android 应用运行结果；不能据此断言游戏、华为系统或 Vulkan 存在故障。日志与启动配置保存在 `tmp/huawei_black_screen_20261108/emulator-api30*.log` 和相应状态 JSON；创建的测试进程已清理。

继续本机模拟测试的前置条件是启用 BIOS 的 Intel VT-x，并配置可用的 Windows 模拟器加速后重启。环境可用后，再依次执行 Android 11、13、14 的基线冷启动、不同内存/分辨率和两个原始 1.0.2 APK 的对照测试；本次尚未执行这些测试，不填写通过结论。

普通 AVD 无法模拟华为 P / Mate 系列的实际麒麟芯片、Mali / Maleoon 驱动、EMUI 或 HarmonyOS。更改机型名称、分辨率、RAM 或 Android 版本只能改变部分测试条件，不能称为“华为热门机型测试”。要覆盖 Mate 40、P60、Mate 60 等具体设备，应使用对应实体手机或提供这些型号的远程真机服务；后者需要可访问的测试账号和实际 APK。
