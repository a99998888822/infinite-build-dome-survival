# Android 导出与 TapTap 发布检查

## 最新状态：精简与改名

按用户要求调整 Android 导出预设，手机显示名称为 **哥布林教你地下城**，包名为 `com.octopus.goblin.dungeon`，版本明确为 `1.0.0` / versionCode `1`。项目内部名称和 Windows 导出预设保持原值。

Android 导出排除了临时缓存、截图复查、测试及录制场景、开发脚本、文档和素材制作源文件。保留正式游戏资源；没有降低贴图或音频质量。

重新实际导出的 Debug APK 位于 `tmp/android_slim_review/goblin-dungeon-debug.apk`，48,430,668 字节（约 **46.19 MiB**），相比原包 262,088,836 字节减少 **81.52%**。此前的临时／测试目录内容已全部移除，导入资源组从约 197.79 MiB 降至 7.47 MiB。

验证结果：

- headless 编辑器检查与 APK 导出均退出 0。
- APK 实际包名、中文应用名、版本与 ARM64 架构已通过 `aapt` 检查。
- 签名 v2 / v3 验证与 `zipalign -c -P 16 4` 通过。
- 721 个静态运行资源引用检查未发现缺失；素材溯源 JSON 中的原始制作清单被单独识别为开发元数据，不视作运行依赖。
- 从 APK 提取的实际 sparse pack 可以在桌面 headless 中启动，配置加载完成、GameRoot 就绪；未出现 Parse / Compile / SCRIPT ERROR。仍有原先存在的 SubViewport stretch 警告。
- 尚未完成 Android 真机安装、触控和性能验收；该 APK 仍为调试签名包，正式发布签名与商店材料待办继续有效。

包名变更后，Android 会将其视作新应用，旧包的应用数据不会自动迁移。以下内容保留为首次检查记录，名称、体积及清理状态以本节为准。

### Logo 配置补齐

确认用户提供的 Logo 与根目录 `icon.png` 的 SHA-256 相同。项目图标从默认 `icon.svg` 改为 `icon.png`；Android 普通图标明确使用该文件，并补充由原图派生的自适应前景、同色背景与单色主题图标，避免现代 Android 仍显示 Godot 默认素材。自适应层给帽子、手部预留系统裁切边距。可通过 `scripts/tools/build_android_launcher_icons.py` 重新生成。

包含 Logo 的最新测试包：`tmp/android_icon_review/goblin-dungeon-icon-debug.apk`，约 **46.72 MiB**。headless 编辑器检查和导出退出 0；已从实际 APK 提取四类图标进行目视及像素比对，普通图标与缩放原图一致，自适应与主题图标均来自该 Logo。签名 v2 / v3、ZIP 对齐、包名及中文显示名称检查通过，临时和测试目录仍未入包。此前“默认图标待替换”的首次检查记录已解决；正式签名、真机验收与商店资料待办仍有效。

## 首次检查记录

首次对当时工作区实际导出了 Debug APK，并检查其 Manifest、原生库、签名和文件清单。当时未修改导出配置，未生成发布证书，未安装到手机，也未提交 TapTap 审核。

## 实际导出结果

| 项目 | 检查结果 |
| --- | --- |
| 导出命令 | Godot 4.7.1 `--headless --path . --export-debug Android tmp/mobile_apk_audit/infinite-build-debug.apk` |
| 导出退出码 | 0，签名与 APK 校验完成 |
| 测试包 | `tmp/mobile_apk_audit/infinite-build-debug.apk`，约 249.95 MiB |
| 包名 | `com.octopus.infinitebuilddome` |
| 手机显示名称 | `InfiniteBuild_DomeSurvival` |
| versionCode / versionName | `1` / `1.0.0`（versionName 当前由引擎提供默认值） |
| 最低 / 目标 Android API | 24 / 36，即 Android 7.0 起 |
| CPU 架构 | 仅 `arm64-v8a`，两份原生库的 ELF 均为 64 位 |
| 图形要求 | OpenGL ES 3.0 |
| 屏幕 | 横屏，存在 MAIN / LAUNCHER 启动别名 |
| 签名验证 | v2 / v3 通过；当前为 Godot 调试证书，Manifest 带 debuggable 标记 |
| ZIP 对齐 | `zipalign -c -P 16 4` 通过；这不等于完成原生 ELF 及 16 KB 页大小设备兼容验证 |
| Manifest 权限 | 本次 `aapt dump permissions` 未列出 uses-permission |

可以直接导出用于手机安装测试的 APK。正式 Release 签名配置为空，因此当前还不能按现有配置直接产出可提交的正式签名包。实际是否可正常安装、启动和完整游玩，需要在满足架构与系统要求的设备上验证。

## 对照打包规范

用户提供的“TapTap 打包规范”主要说明 64 位支持，并不是完整上架清单。

- 本次 APK 仅含 `lib/arm64-v8a/libgodot_android.so` 与 `lib/arm64-v8a/libc++_shared.so`，符合页面对 ARM64 的要求。无需为了合规额外开启 ARM32 或 x86。
- 当前包名没有渠道后缀，也不是引擎默认包名；唯一性及是否与 TapTap 后台已有记录一致，需要在开发者后台确认。
- versionCode 为 1，符合不得为 0 的要求。更新时建议始终递增；版本名应明确配置，并与提交资料保持一致。
- 当前 APK 用于调试。审核细则要求不得使用公用证书签名，需要配置并妥善保存自己的发布密钥及密码，后续更新沿用该签名。

## 发布前需要补齐

### 1. 发布构建与资源范围

`export_presets.cfg` 当前为 `all_resources`，排除规则为空。APK 实际包含：

- `assets/tmp/` 下 611 个文件，压缩后约 10.36 MiB，其中包含临时缓存和测试存档目录中的文件。
- `assets/scripts/tests/` 与 `assets/scenes/tests/` 下共 792 个文件，压缩后约 2.03 MiB。
- 包内还存在 `docs` 等开发目录。

需要整理发布导出范围，排除临时文件、截图检查脚本、测试场景及开发资料；同时确认正式运行所需 JSON、字体、翻译及动态加载资源保留完整。排除完成后应重新导出并检查实际 APK，不能只依据 Git 忽略规则判断哪些文件会入包。249.95 MiB 是本次 Debug APK 大小，不代表 Release 大小，也未据此认定超过 TapTap 限额。

### 2. 名称、图标与商店资料

Android 的 `package/name` 与专用图标配置为空，实际回退为工程名及 Godot 默认 `icon.svg`。需要设置正式名称，使手机桌面名称与商店标题一致，并替换默认图标。

按本次读取的物料规范，准备：

- 非默认方形图标：至少 512×512，PNG/JPG。
- 简介、更新日志。
- 至少 3 张不同实机截图；横版至少 1280×720，方向和比例一致，单张不超过 4 MB，包含核心玩法。
- 下载或试玩需要实机视频：大于 15 秒，前 5 秒展示核心玩法，核心玩法连续超过 10 秒。
- 16:9 宣传图：至少 1920×1080，包含游戏名，不得直接用未经设计的游戏截图替代。

现有移动 UI 复查截图可作为素材来源，但需要筛选正式游戏画面；本次未确认已有物料是否已在开发者后台提交并通过审核。

### 3. 隐私政策与游戏资质

项目代码中未找到现成隐私政策入口、TapSDK 或实名认证 / 防沉迷接入。本次 APK 未声明网络权限，当前实现表现为本地单机；这不能代替平台对游戏类型及资质的最终确认。

- 游戏分发前需要有效的隐私政策链接，并通过隐私合规检测。政策应如实描述本地存档、权限及实际使用的第三方组件；商店链接内容与游戏内政策保持一致。
- 核对开发者主体、软著、素材原创或授权证明，并在后台确认已有材料状态。
- TapTap《新建和管理游戏》说明，有版号可选“正式上线”，暂无版号可选“正式上线 试玩版”；无版号不得有内购计费。不可把“暂无版号”等同于所有发布方式均不可用。
- 同页说明资质视游戏情况而定，如联网游戏需提供 ICP 备案、内购计费游戏需提供版号。针对本作的纯单机、试玩或其他发布方式，需结合后台要求确认 APP 备案、实名及防沉迷的适用要求；若属于需接入的网络游戏，当前尚未实现。
- 没有接入 TapSDK 本身不等于不符合打包规范。需要登录、成就或防沉迷等服务时再按所选方案接入。

### 4. 真机质量验证

已有验证主要为桌面模拟移动布局及自动化检查，尚不能代替 Android 真机验收。至少验证安装和冷启动、首次开局、多指摇杆操作、列表拖动、返回键、刘海及手势区域、后台恢复、音频、存档、覆盖安装更新、长时间战斗的性能与温度。

此前移动端检查中仍有结算触屏滚动、奖励文字与点击目标等待复查记录。银行布局和部分操作设置已随后调整，应按当前 APK 重新检查，不能把旧报告中的所有问题都视为仍然存在或已经修复。

## 参考规范

- [TapTap 打包规范](https://developer.taptap.cn/docs/store/release/publish/bundle/)
- [TapTap 游戏审核规范细则](https://developer.taptap.cn/docs/store/release/publish/agree/)
- [新建和管理游戏](https://developer.taptap.cn/docs/store/release/publish/create-game/)
- [安全合规指南](https://developer.taptap.cn/docs/store/release/policy/policy-guide/)
- [游戏物料要求](https://developer.taptap.cn/docs/store/release/publish/material/)

导出日志与本次规范正文快照存放于 `tmp/mobile_apk_audit/`，该目录为本地临时资料。
