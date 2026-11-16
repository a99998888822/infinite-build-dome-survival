# TapTap 移动端云存档接入

日期：2026-11-15。客户端已实现，真实账号及开发者后台验收待完成。此文取代旧版自建服务器方案。

2026-11-16 清理说明：新增的 `cloud_save_test.gd`、测试场景及其他专项测试已移出项目，归档到 `E:/project/godot-project/infinite-build-dome-survival-review-cleanup-20261116-222414`。下文相关测试结果及专用命令属于历史验收记录，恢复归档文件后才能重新运行；既有登录测试和正式 APK 校验工具保留。

## 平台与恢复范围

当前项目只有 Android 的 TapSDK 原生桥接，因此本次接入 Android。Windows、其他桌面系统、网页以及桌面的 `--mobile-ui` 预览不初始化云存档、不访问网络，继续沿用原有本地存档。项目尚无 iOS 导出预设或原生登录桥接，因此不声明已支持 iOS。

复用现有 TapTap 隐私同意、登录与防沉迷流程，通过后才读取云端。同步天赋点 `camp_currency`、建筑等级及解锁、已购天赋等级、结算凭据 `run_settlements`、存档版本及档案 ID。音量、设备设置、隐私同意、SDK 凭证和实名认证结果不上传。云存档不包含尚未结束的战斗现场。

无需文件夹选择，也不需要另建服务器或在客户端配置管理密钥。TapSDK 的基础、登录、防沉迷和云存档模块统一使用 **4.11.1**；Android 原生桥接 AAR 已重新构建，导出插件同时声明 Maven 依赖。

## 玩家流程

1. 覆盖升级保留原有 `user://saves/profile_01.json`、backup 与 legacy 文件。首次通过登录及防沉迷的账号独占认领旧档；其他账号不能再次导入这份旧档。原始旧档保留不删除。
2. 每个账号使用 `user://saves/accounts/<open_id 的 SHA-256>.json` 独立保存。切换账号、恢复云端进度会返回主菜单，防止继续使用上一账号构筑或结算。
3. 首次进游戏前检查云端；只有请求成功且明确无档时才创建云档。新安装、没有历史进度时自动恢复同账号云档；本机没有新变化且云端版本继承自本机已同步版本时也自动恢复。
4. 获得结算奖励、购买或重置天赋等变化先保存本机，合并 10 秒内变化后同步。单次上传期间发生的新变化保留为待同步。后台恢复重新检查云端，失败按 30–300 秒退避重试，也可以在主菜单「TapTap 账号」点击同步。
5. 读取失败不视为云端无档，不上传默认空档。显示错误及重试入口；有效账号本机档已准备好时，可以明确选择「使用本机存档继续」。离线未上传进度在卸载后无法恢复。
6. 同一进度出现不同分支时展示本机及每份云端天赋点、已购天赋数量，由玩家选定保留版本。不同分支不累加余额，不取天赋等级最大值。恢复前单独保存 `<账号哈希>.before_restore.json`；普通档轮换不会改写这份恢复前备份。下一次恢复可能轮换此备份，因此不是无限历史备份。

账号面板显示云端状态；结算页区分「已保存到本机」与「已同步到云端」。SDK 超时、请求失败、损坏或未知格式、未来存档版本、写盘失败、过期回调均不能被当成成功确认。

## 多设备与服务限制

官方创建/更新 API 未提供原子条件版本更新，因此不能靠「下载后覆盖同一 UUID」保证跨设备并发安全。本实现为每次安装生成随机 ID，并仅创建/更新 `profile_01_<installation_id>` 槽位。其他安装的槽位保留，下载全部本项目槽位后，用随机版本标识及祖先列表识别继承与分叉；同一进度摘要可以重复出现，但每次写入版本标识唯一，避免退回旧余额时形成继承环。

每次上传前重新读取列表并检查分叉；每个客户端串行请求，上传至少间隔 10 秒。上传使用不可变快照临时文件，SDK 回调后删除，不直接读取正在修改的本机档。登录、退出及请求代号共同过滤旧回调。上传提交成功但响应丢失时，下一次查询可以识别已提交的进度，而不会重复发放奖励。

祖先最多保留 128 个版本。超出历史窗口后遇到很旧设备，可能保守地要求玩家选择进度，不直接推断为可覆盖。每次重装可能产生一个新槽位；本版本不自动删除其他安装的槽位，避免删掉另一个设备正在使用的档。达到 TapTap 每账号每游戏 100 档或容量上限时显示失败并保留本机档，需要后续维护云端槽位；不能声称可以无限次重装创建新档。

单文件在桥接及业务层限制为 10MB，不上传封面。客户端校验版本、字段类型、非负整数、大小及摘要，摘要用于发现损坏，不构成服务端反作弊；本地战斗结果仍由客户端生成。

## 后台与真机验收

必须在此 Client ID 对应的 [TapTap 开发者中心](https://developer.taptap.cn/) 开通云存档服务，保持现有登录、合规、包名与签名登记正确。没有开通时客户端显示错误，代码不会把失败解释为没有云档。

实际隐私政策应披露使用 TapTap 云存档、上传的游戏进度字段、账号关联、保存和删除方式。仓库只保存政策 URL，无法修改站外政策正文；完成正文更新后应递增 `consent_revision`，重新取得用户同意。本次未擅自改动站外政策或后台开关。

使用独立测试账号或隔离设备验证真实 SDK：有/无 TapTap 客户端登录、旧档 88 点与已购天赋迁移、在线结算确认后重装恢复、断网后重连、双设备同时玩、账号切换、强杀重启和防沉迷限制。不能卸载玩家当前正式安装作为自动测试。

## 源码与验证命令

- `autoloads/cloud_save.gd`：移动平台边界、同步状态机、冲突与持久化同步记录。
- `autoloads/camp_progression.gd`：账号档案路径、迁移、数据校验与本机恢复。
- `addons/taptap/native/src/main/java/com/octopus/goblin/taptap/TapTapCloudSaveBridge.java`：官方 SDK 接口桥接。
- `scripts/ui/taptap_account_panel.gd`：同步状态、重试、离线与冲突选择界面。
- `scripts/tests/cloud_save_test.gd`：独立测试目录和假传输，不读写玩家正式档。
- `scripts/tools/verify_taptap_apk.py`：检查实际 APK 的云存档 SDK、SO、桥接、编译脚本与 autoload 注册。

```powershell
& '<Godot绝对路径>' --headless --editor --path . --quit
& '<Godot绝对路径>' --headless --path . --scene res://scenes/tests/cloud_save_test.tscn -- --transient-session
& '<Godot绝对路径>' --headless --path . --scene res://scenes/tests/taptap_session_test.tscn -- --transient-session
python scripts/tools/build_taptap_android.py --java-home 'C:/Program Files/java/jdk-17.0.2' --android-sdk 'C:/Users/octopus/AppData/Local/Android/Sdk' --godot '<Godot绝对路径>' --apk tmp/cloudsave-review/goblin-dungeon-cloudsave-debug.apk
```

自动验证：云存档 headless 71 项及 20:9 GPU 73 项、既有登录/防沉迷 79 项通过；headless 编辑器与主场景 120 帧运行检查无脚本错误。主场景 headless 退出仍有商店 `shop_ui_controller.gd:39` 的 DummyTexture 空纹理及 RID 释放报错，2026-11-08 的 `tmp/huawei_black_screen_20261108/main-headless.log` 和既有登录集成运行日志也有相同错误，本次未扩展修改商店渲染。GPU 使用私有 Windows 桌面且 `foreground_samples=0`。测试采用模拟桥接，不能代替真实 TapTap 账号及重装恢复验收；本机 `adb devices` 没有已连接设备。

参考：[功能及限制](https://developer.taptap.cn/docs/sdk/tap-cloudsave/features/)、[Android 开发指南](https://developer.taptap.cn/docs/sdk/tap-cloudsave/development-guide/android-native/)、[常见问题](https://developer.taptap.cn/docs/sdk/tap-cloudsave/faq/)。

最终测试包：`tmp/cloudsave-review/goblin-dungeon-cloudsave-debug.apk`，57,881,793 字节（约 55.2 MiB），SHA-256 `d682acd5dea797a8efdfc80df6bd61eacf184b1f95aa205acb7f891d8c7c0660`。最终导出退出 0，实际 APK 的 7 项结构检查通过：合规桥接、云存档 SDK/桥接/原生库、编译脚本门禁、登录及云存档 autoload 注册、SDK 配置存在、测试资源排除。包为 Android Debug 联调版本，尚未进行真实账号云端恢复验收。
