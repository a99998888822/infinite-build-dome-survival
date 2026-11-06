# TapTap 实名认证与防沉迷接入方案

核对日期：2026-11-06。下文保留接入前的分析与实现要求；对应代码现已实现，原生桥接编译及 Godot 状态机验证已通过。实际 SDK 提示、账号与后台服务由用户真机验收，录屏由用户完成。

## 当前状态

- 项目使用 TapSDK 4.11.0，通过 Godot v2 Android 插件桥接；已有 `tap-core`、`tap-login`，尚无 `tap-compliance`。
- `TapTapGodotPlugin.java` 仅申请 `Scopes.SCOPE_BASIC_INFO`，官方支持此权限组合进行无感登录；可以继续保留。
- `autoloads/taptap_session.gd` 的登录成功、缓存账号恢复路径直接设置 `logged_in`；`can_enter_game()` 只检查登录状态及 `open_id`，尚未检查合规认证。
- 主菜单开始战斗、确认角色、实际开始战斗已有登录检查，可扩展现有统一入口。
- 当前没有合规回调触发的运行中拦截。仅补开始游戏前的一次检查，不足以处理游戏过程中跨入禁玩时段的情况。

## 后台准备

在此 Client ID 所属游戏的「游戏服务 → 合规认证」开通服务。官方不同页面的菜单层级略有差别，以后台的「合规认证」入口为准。

- 暂无版号：可选择「暂无版号」方案直接开通，不要求先完成中宣部系统注册。
- 已有版号：按后台要求完成中宣部注册、接口测试及审核，配置 `bizId`、`APPID`、密钥和 IP 白名单。这些服务端配置不写进游戏客户端。
- 保持包名 `com.octopus.goblin.dungeon`，核对实际安装包签名证书 MD5；测试包与正式签名分别正确登记。
- 在合规认证后台准备自测账号，覆盖未实名、成年及未成年状态。官方自测账号可调整可玩时段，便于验证中途到时限制。

## 推荐调用流程

```text
隐私同意 → TapSDK 异步初始化 → 注册合规回调
  → 恢复已有账号 / 用户点击 TapTap 登录
  → 取得有效账号 → 正在进行合规检查，禁止进入游戏
  → TapTapCompliance.startup(activity, account.getOpenId())
  → 回调 500 → 当前会话允许游戏
  → 其他拦截结果 → 保持禁止，显示提示、重试或返回登录
```

首次登录与冷启动恢复账号必须走同一条合规检查路径。不能把一次 `500` 持久化成以后免检的资格。重复启动仍调用 `startup()`；SDK 可以复用实名结果，但游戏仍须等待本次是否允许游戏的结果。

## 需要修改的位置

| 文件 | 改动 |
| --- | --- |
| `addons/taptap/native/build.gradle` | 添加 `implementation 'com.taptap.sdk:tap-compliance:4.11.0'`，与已有两个模块同版本 |
| `addons/taptap/export_plugin.gd` | Android 导出依赖同时加入 `com.taptap.sdk:tap-compliance:4.11.0`；当前桥接 AAR 不内嵌 Maven 依赖，仅改原生构建文件不足以保证 APK 包含模块 |
| `addons/taptap/native/src/main/java/com/octopus/goblin/taptap/TapTapGodotPlugin.java` | 初始化加入合规选项；注册合规回调；新增启动认证方法与合规结果信号；退出账号时调用 `TapTapCompliance.exit()` |
| `autoloads/taptap_session.gd` | 分开保存账号登录与合规放行状态；登录、恢复后发起检查；只在本次检查收到 `500` 后放行；统一处理限制、取消、失败和账号切换 |
| `scripts/ui/taptap_account_panel.gd` | 区分正在认证、认证重试、已登录但被限制、退出账号；不能继续用 `can_enter_game()` 判断是否已登录或应显示退出按钮 |
| `scripts/core/game_root.gd` / `scripts/core/main_flow_coordinator.gd` | 订阅合规权限撤销，在战斗中立即暂停玩法及输入，并保持拦截或返回登录；防止普通暂停菜单恢复玩法绕过限制 |
| `scripts/tests/taptap_session_test.gd` | 扩展假桥接，验证无 `500` 不放行、恢复账号也检查、限制撤销权限、重试与退出状态 |

原生初始化建议显式指定：

```java
TapTapComplianceOptions complianceOptions =
    new TapTapComplianceOptions(true, false);
// true: 显示切换账号按钮，必须处理 1001。
// false: 不向游戏提供真实年龄段信息，使用 Tap 实名时静默授权。
TapTapSdk.init(activity.getApplicationContext(), options, complianceOptions);
```

现有隐私同意前不初始化 SDK 的边界继续保留。`useAgeRange=false` 不会关闭防沉迷限制；游戏依赖合规结果决定是否放行，不需要自己取得年龄并判断。若以后确需年龄段，改用 `true` 时应一起审视授权流程：官方说明首次未开启该权限的用户，后续年龄段查询可能一直为 `-1`。

原生启动认证时直接读取 `TapTapLogin.getCurrentTapAccount()`，使用 SDK 返回的 `openId`，不使用随机设备 ID 或自行拼接账号标识。认证未返回前禁止重复调用 `startup()`。信号继续通过现有 `deliver()` 回到 Godot 渲染线程；不向 GDScript 传递访问令牌、姓名、证件信息或完整 SDK 对象。

## 合规结果处理

| code | 官方含义 | 项目处理 |
| --- | --- | --- |
| `500` | `LOGIN_SUCCESS`，玩家未受限制 | 仅对当前有效账号和当前检查会话设置允许游戏 |
| `1000` | `EXITED`，认证退出或凭证失效 | 清除合规放行，返回登录页；显式 `exit()` 也会触发，避免递归退出 |
| `1001` | `SWITCH_ACCOUNT` | 立即清除放行，退出旧合规会话及 TapTap 登录，引导重新登录 |
| `1030` | `PERIOD_RESTRICT`，时段限制 | 禁止进入或继续游戏，保留 SDK 拦截提示 |
| `1050` | `DURATION_LIMIT`，时长耗尽 | 同上；运行中也必须生效 |
| `1100` | `AGE_LIMIT`，后台额外设置的可玩年龄限制 | 禁止游戏，自行显示年龄限制提示；官方说明此码仅回调，SDK 不代画提示 |
| `1200` | 应用配置无效或网络异常 | 保持禁止，提示检查网络/配置，提供显式重试 |
| `9002` | 玩家关闭实名窗口 | 保持禁止，提供再次认证或返回登录 |

未识别的结果不能作为认证通过。账号切换或退出后应忽略旧会话的迟到结果。退出失败也不能像当前 `_on_logout_failed()` 一样无条件恢复到可玩的 `logged_in`：恢复玩法必须仍有有效的合规放行状态。

SDK 负责实名流程和防沉迷时段/时长业务，游戏负责实际停止玩法。不要在 GDScript 里用本机日期、周末判断或自制倒计时替代 SDK。当前官方 Android 开发指南未列出旧版常见的 `enterGame/leaveGame` 调用；实现时按 4.11.0 实际 API 验证前后台生命周期，不直接照搬旧教程。真机必须验证切后台跨过允许时段后回到前台的限制效果。

目前仅需接时间与认证流程；若以后引入真实货币充值，再接支付前 `checkPaymentLimit()` 与支付成功后 `submitPayment()`，金额单位均为分。玩法里的金币商店不等于充值。

## 截图所示录屏与验证

当前 `basic_info` 登录配合 `useAgeRange=false`，适合用户截图左侧的无感流程。截图说明适用于 TapSDK 4.3.10 以上，项目 4.11.0 满足版本要求。

真实录屏使用已在 TapTap 客户端实名的未成年账号，并选择不可玩时段：

1. 从点击游戏图标开始录制。
2. 游戏内点击 TapTap 登录，走无感授权。
3. 出现 SDK「游戏健康提醒」并且确实不能进行游戏。
4. 关闭进程，重新打开；恢复账号后仍出现限制提示，仍然不能玩。

如果以后改为获取年龄段的非无感授权流程，应按截图右侧补录拒绝年龄段授权不能绕过、同意后继续检查的过程。

另外验证成年账号放行、未实名流程、认证取消、断网重试、重复点击、切换账号，以及允许时段内开始游戏后触发限制、后台跨时段再回前台。后台自测账号用于联调；截图要求的证明视频应按其指定真实账号场景录制。

实现后先构建桥接 AAR，再导出 Android APK。Godot 头部无界面检查和假桥接测试只能验证项目状态处理；SDK 弹窗、服务开通、前后台限制与证明视频必须在 Android 真机完成。

## 官方依据

- [Android 实名认证和防沉迷开发指南](https://developer.taptap.cn/docs/sdk/anti-addiction/development-guide/android-native/)
- [功能介绍、开通条件与测试账号](https://developer.taptap.cn/docs/sdk/anti-addiction/features/)
- [最佳实践：缓存账号仍需检查合规状态](https://developer.taptap.cn/docs/sdk/anti-addiction/practice/)
- [常见问题：时长拦截 UI 与额外年龄限制 UI](https://developer.taptap.cn/docs/sdk/anti-addiction/faq/)
- [Android 登录指南：`basic_info` 支持无感登录](https://developer.taptap.cn/docs/sdk/taptap-login/development-guide/android-native/)
