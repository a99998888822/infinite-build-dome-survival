# TapTap Android SDK 与登录接入

## 审核退回后的包核对（2026-11-06）

审核反馈 vivo X200 上未成年账号可进入游戏。目前未取得本次实际提交 APK 及真机合规回调，不能据此确定是旧包、后台配置、账号状态或 SDK 行为。未成年在允许时段内也可能合法收到 `500`，不能将「未成年」直接等同于所有时间都应禁止。

已核对本地旧文件：`ui-fixes`、`compact`、`privacy` 等旧测试包，以及 `C:/Users/octopus/Desktop/workspace/battle.apk`，没有 `TapTapCompliance` 类。此前 `goblin-dungeon-taptap-compliance-debug.apk` 包含 SDK 和合规门禁，但未包含最后的 `_battle_runtime_pause_requested` 修正；旧文件时间为 03:11:49，不能作为最终源码已完整入包的证据。此前模拟测试通过只说明项目对模拟回调的处理，不能证明真实未成年账号被限制。

此次修订添加 `compliance-v2` 原生版本标识及 `TapTapComplianceBridge` 日志，仅记录启动、初始化及结果码，不记录账号或凭证；补处理 `1095` 健康提醒（不改变已有放行状态）与 `9001` 凭证过期（退出并保持拦截）。`useAgeRange=false` 按官方文档是静默授权配置，不关闭时段限制。

构建工具默认输出 `tmp/taptap_login_review/goblin-dungeon-taptap-compliance-v2-debug.apk`，导出后自动检查 APK 中的原生 SDK、桥接版本、编译脚本门禁、autoload 注册与配置，并生成同名 `.verification.json` 和 SHA-256。检查发现旧脚本即构建失败。也可单独执行：

本次完整构建退出 0，APK 大小为 54,247,625 字节，SHA-256 为 `8c77877d9ddda18e3b4aabee8a51f643c73077e1a1eb26f3abcee962678462a7`。包内上述五项检查通过，状态机 79 项检查通过，headless 编辑器检查无脚本错误。真机未连接，实际未成年账号验收尚未完成。

```powershell
python scripts/tools/verify_taptap_apk.py 'tmp/taptap_login_review/goblin-dungeon-taptap-compliance-v2-debug.apk'
```

真机诊断命令：

```powershell
& 'C:/Users/octopus/AppData/Local/Android/Sdk/platform-tools/adb.exe' logcat -d -s TapTapComplianceBridge:I
```

若 APK 校验通过，但禁玩时段仍可玩：先核对日志中是否有 `revision=compliance-v2 event=startup` 和对应 `event=result code=500/1030/1050`。`500` 表示 SDK 放行，需进一步核对后台开通、自测账号允许时段和游戏实际登录账号；`1030/1050` 后仍可操作则应继续排查客户端拦截。未连接真机前，不将本次修改描述为已通过平台防沉迷验收。

历史登录界面测试包（不含防沉迷，不用于本次验收）：`tmp/taptap_login_review/goblin-dungeon-taptap-ui-fixes-debug.apk`，**54,078,836 字节（51.57 MiB，约 54.08 MB）**。包含默认勾选隐私政策及主菜单账号/语言入口避免重叠两项调整；实际导出退出 0，APK v2 签名、16 KiB ZIP 对齐、原生库压缩、隐私配置及不包含测试目录检查通过。

此前恢复原生库 ZIP 压缩的包为 `tmp/taptap_login_review/goblin-dungeon-taptap-compact-debug.apk`，54,078,196 字节，比上一个 106,226,672 字节的联调包减少 52,148,476 字节（约 49.1%）。仅修改打包方式，四份原生库解压后的 SHA-256 与前包逐个一致，SDK 类及隐私配置保留。实际导出退出 0，APK v2 签名、16 KiB ZIP 对齐、包名、显示名称和安装时解压原生库配置均已核对。测试签名与后台需要登记的 MD5 保持一致。以下约 100 MiB 包保留为此前构建记录。

## 本次范围

接入 TapSDK **4.11.0** 的 `tap-core`、`tap-login`、`tap-compliance`，通过 Godot v2 Android 插件桥接。Android 包名继续使用 `com.octopus.goblin.dungeon`，显示名称继续为“哥布林教你地下城”。桌面版不要求 TapTap 登录。

Android 首次启动显示隐私授权；按用户要求，同意复选框默认勾选，点击“同意并继续”才保存授权并调用 TapSDK 初始化，默认勾选本身不会初始化。允许取消勾选，此时禁用继续按钮。初始化完成读取 SDK 保存的账号；没有账号时由用户点击“TapTap 登录”，由 SDK 拉起已安装的 TapTap 或 WebView 授权页面。支持取消、失败重试、账号恢复、主菜单的“TapTap 账号”入口及退出登录。主菜单右上角账号与语言入口由同一个横向容器排列，避免中英文切换或宽高比变化时重叠。未成功登录不能开始 Android 战斗。仅申请 `basic_info` 权限，不读取昵称、头像、好友或邮箱。用户协议可暂时留空用于开发联调，此时仅展示隐私政策与相应同意项；配置正式用户协议链接后再一起展示，不将“待补”作为有效协议。

**已补接实名认证与防沉迷代码。** 首次登录和冷启动恢复账号后，均使用 SDK 当前账号的 `openId` 发起合规检查，只有收到 `500` 才允许游戏；时段限制、时长耗尽、年龄限制、认证关闭、网络异常均保持拦截。游戏中触发限制时停用玩法处理与输入并打开账号面板；SDK 提供游戏健康提醒，额外年龄限制由项目显示提示。保留 `basic_info` 无感登录，合规选项为 `showSwitchAccount=true`、`useAgeRange=false`；前后台时长由 4.11.0 SDK 内部生命周期管理。退出账号时清理合规会话，失败不会直接恢复放行；迟到的旧请求不能放行新会话。后台仍须开通合规认证，实际弹窗与服务结果待用户真机验收。现有单机存档继续属于设备，切换 TapTap 账号不会切换单机存档。

## 配置与后台

编辑 `data_config/platform/taptap.json`：

| 字段 | 当前状态 / 用途 |
| --- | --- |
| `client_id` / `client_token` | 已填入本次用户提供的应用参数；它们用于客户端 SDK，未使用 Client Secret |
| `privacy_policy_url` | 2026-11-06 按用户要求换为 [隐私政策](https://share.note.youdao.com/s/ZWRUp8ma)；此前的 blogspot 链接不再使用 |
| `user_agreement_url` | 暂时留空，待补正式内容；不阻断 SDK 登录联调 |
| `consent_revision` | 当前为 `3`；协议内容或展示范围变更时递增，下一次启动重新征求同意。本次替换隐私政策链接后由 `2` 递增，已同意旧版本的设备会重新询问 |

隐私政策链接缺失时不会初始化 SDK；Android 显示配置待补并禁用登录。用户协议 URL 不是 TapSDK 初始化参数，早期要求两个 URL 齐全是本项目的界面检查，现已取消这一联调限制。正式面向玩家发行前应完成实际服务条款，不能用“待补”让玩家同意不存在的内容。

2026-11-06 按用户要求把隐私政策链接换为有道云笔记文档，链接替换已在导出包内核对。本次构建环境无法访问外网，未确认该页面是否可打开、是否仍有模板占位或缺 TapTap 披露，因此不视为文档内容已审查。此前 blogspot 链接检查时返回 HTTP 200，但正文仍有“【SDK名称】”“【隐私政策连接】”等模板占位，且未列明 TapTap；其中自行收集手机号、登录密码、广告等描述也应与实际功能逐项核对。接入链接不代表该文档已完成内容审查。隐私说明应按真实使用情况披露 TapTap 登录、SDK 及其相关数据处理。隐私同意记录仅保存协议版本；访问令牌由 TapSDK 管理，不传入 GDScript，不写入项目配置、用户存档或游戏日志。

TapTap 开发者后台需要确认：

1. 此 Client ID 所属游戏开通了 TapTap 登录；下一步实名认证和防沉迷还需开通合规认证。
2. Android 包名登记为 `com.octopus.goblin.dungeon`。
3. 登记与实际安装包一致的签名证书 **MD5（去掉冒号的 32 位字符串）**。当前测试包使用 Godot Debug 证书，正式包必须改用自己的发布证书，并同步登记后台签名；包名相同但签名不同也会授权失败。
4. 真实验收分别覆盖安装和未安装 TapTap 客户端、取消授权、断网、登录后冷启动恢复以及退出重登。

本机 `adb devices` 当前没有连接的设备；自动化使用假桥接验证状态机，不代表已完成 TapTap 实际授权。

本次测试包证书 MD5：`655c79512206a18ca3b2cd91734df18d`。这是证书指纹，供开发者后台登记测试签名使用，不是 Client Token 或发布私钥。

## 源码与构建

- `addons/taptap/native/`：Java 原生桥接源码、Manifest、Gradle 构建配置；Godot 不扫描其中的构建缓存。
- `addons/taptap/bin/taptap-godot.aar`：已编译桥接库，供 Godot 导出使用；不内嵌 TapSDK 依赖，依赖由 Maven 解析。
- `addons/taptap/export_plugin.gd`：v2 插件注册 AAR 和锁定版本的 Maven 依赖。
- `autoloads/taptap_session.gd`：隐私同意、初始化、登录状态机及游戏入口检查。
- `scripts/ui/taptap_account_panel.gd`：移动端隐私、登录与退出界面。

已启用 Android Gradle 导出，添加网络及网络状态权限。ARM64、Logo 与沉浸式横屏配置保留；原生源码、构建目录及 AAR 不打进 Godot 游戏资源包。Maven 将依赖打进 APK 的 Android 部分。

需要 JDK 17、与引擎匹配的 Godot Android 构建模板（当前 4.7.1）、Android API 36 和 Build Tools 36.1.0。首次构建需要联网下载 Gradle / Maven 依赖。可通过 Godot 的“项目 → 安装 Android 构建模板”重建被 Git 忽略的 `android/build`；维护的插件源码不放在该目录。

PowerShell 构建桥接库并导出测试包示例：

```powershell
python scripts/tools/build_taptap_android.py --java-home 'C:/Program Files/java/jdk-17.0.2' --android-sdk 'C:/Users/octopus/AppData/Local/Android/Sdk' --godot 'E:/engineSoftware/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe'
```

只修改 JSON 或 GDScript 时可直接用 Godot Android 预设导出；修改 Java 后先重新构建桥接 AAR。Release 签名沿用 Godot 标准导出配置，勿在仓库提交密钥密码。

## 验证

- 原生 `installBridge` / `assembleRelease` 编译成功。
- Godot headless 编辑器检查无 Parse / Compile / SCRIPT ERROR。
- `taptap_session_test.tscn`：headless 27 项检查通过，覆盖同意前不初始化、初始化失败重试、取消授权、重复点击、无效账号、令牌隔离、缓存恢复、退出成功与失败、缺少配置或插件时阻止进入游戏。
- 同一测试实际渲染 1920×1080、2400×1080：各 33 项检查通过，截图在 `tmp/taptap_login_review/`。使用私有桌面捕获，`foreground_samples=0`。
- `mobile_controls_test.tscn -- --mobile-ui`：114 项检查通过。
- 后续隐私政策配置调整：`taptap_session_test.tscn` headless 32 项通过，20:9 GPU 40 项通过，新增验证用户协议留空时仅展示隐私政策、同意前不初始化，以及同意后可初始化。`foreground_samples=0`。既有同时展示两份协议的路径继续覆盖。
- 按用户要求改为默认勾选后：headless 36 项、20:9 GPU 44 项通过，覆盖默认选中但尚未保存同意/初始化 SDK、取消勾选禁用继续、再次勾选恢复按钮。新增真实主菜单检查 `taptap_menu_layout_test.tscn`，16:9 / 20:9 各 12 项通过，覆盖中英文下账号与语言入口不重叠、留有间距、保持在视口内，以及两个入口分别可触屏点击。所有 GPU 复查均使用私有桌面，`foreground_samples=0`；20:9 主菜单仍有既存的 SubViewport stretch 警告。
- 2026-11-06 隐私政策链接换为有道云文档并递增同意版本后重新打包：`tmp/taptap_login_review/goblin-dungeon-taptap-policy-debug.apk`，54,247,577 字节（约 51.73 MiB），SHA-256 `9a9701f479f518151abbbc673d22e548c3b975501938f624480d858f17f72da7`。导出退出 0；包内配置核对为新的隐私政策 URL、用户协议留空、`consent_revision=3`；五项包检查（SDK/桥接 v2、编译后玩法门禁、autoload 注册、SDK 配置、测试资源未入包）通过；Godot Debug 证书 MD5 `655c79512206a18ca3b2cd91734df18d`，16 KiB ZIP 对齐校验成功；`taptap_session_test.tscn` headless 79 项 0 失败。包名 `com.octopus.goblin.dungeon`，版本 1.0.0（versionCode 1），minSdk 24 / target 36。
- 包含隐私政策链接和上述联调调整、尚未恢复原生库压缩的测试包：`tmp/taptap_login_review/goblin-dungeon-taptap-privacy-debug.apk`，106,226,672 字节。导出退出 0，已核对包内的真实配置：隐私政策 URL 正确、用户协议留空、同意版本为 `2`；APK v2 签名与 16 KiB ZIP 对齐检查通过。此前的 `goblin-dungeon-taptap-debug.apk` 保留为首次集成记录。
- 实际 APK：`tmp/taptap_login_review/goblin-dungeon-taptap-debug.apk`，106,226,404 字节（约 101.31 MiB），导出退出 0。包内已确认存在 Godot 桥接、TapSDK 初始化类、登录类与 SDK 授权 Activity；配置 JSON 也已入包。包名、应用名称和 ARM64 正确，未包含测试、临时或原生源码目录。APK v2 签名与 16 KiB ZIP 对齐检查通过，四个 ARM64 原生库的 ELF LOAD 对齐均为 16 KiB；真实设备兼容性仍待验收。
- 首次接入 Gradle 时沿用了 `gradle_build/compress_native_libraries=false`，将原生库直接存储；旧版直接导出时原生库被 ZIP 压缩。同一 Godot 引擎库从 ZIP 内 25,466,301 字节变为 76,177,376 字节，这就是约 100 MiB 包的主要增量，并非全部来自 SDK。现已将该选项改为 `true`，恢复原生库无损压缩；Android 安装时会解压原生库，因此主要减少 APK 下载体积。保留 SDK、素材与原生库内容。
- 根场景 headless 可到达 `game root ready`；现有天赋图标灰度贴图在 Dummy 渲染器下仍报告 `texture_2d_initialize` 空纹理及退出资源未释放。该相关脚本本次未改动，GPU 登录界面测试没有对应错误。

## 官方依据

- [Android SDK 集成与异步初始化](https://developer.taptap.cn/docs/sdk/integration-guides/android/)
- [Android TapTap 登录开发指南](https://developer.taptap.cn/docs/sdk/taptap-login/development-guide/android-native/)
- [开发者中心配置、包名与签名](https://developer.taptap.cn/docs/sdk/access/get-ready/)
- [SDK 合规说明与延迟初始化](https://developer.taptap.cn/docs/sdk/start/compliance/)
- [Android 实名认证与防沉迷开发指南（下一阶段）](https://developer.taptap.cn/docs/sdk/anti-addiction/development-guide/android-native/)
