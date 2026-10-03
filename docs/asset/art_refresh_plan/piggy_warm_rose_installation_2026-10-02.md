# 猪猪存钱罐暖藕粉正式接入

用户确认暖藕粉版本并要求替换正式资源。本次安装 `artifacts/previews/relic_piggy_style_study/r03/delivery/pig_warm_rose-64.png`，64×64、6 色、硬透明、大色块拼接。暖藕粉为此前暖陶色与粉嫩色逐色号的 50% 中间值，作为猪猪存钱罐的专属配色例外。

正式 PNG 为 `assets/ui/icons/relics/relic_piggy_bank.png`，SHA256 为 `e195698e324a4d15993284ad1d672ef6a51d1c500e909418fb7eb36a520e7551`，与确认稿逐字节一致。同步更新同名 `.pxg` 为自包含 `custom` 色板，网格渲染与 PNG 逐像素一致。配置 ID、导入 UID、导入设置和显示逻辑保持现状。列表及商店显示 32px，图鉴显示 64px，奖励卡显示 48px，均使用已有最近邻设置。

备份位于 `artifacts/previews/relic_piggy_style_study/r03/installation/previous/`，包括替换前 PNG、网格和 `.import`；新旧哈希在 `installation/assets.json`。美术清单和 `icon_manifest.json` 已同步。

Godot 4.7.2 无窗口编辑器导入成功。现有 `relic_art_install_test.tscn` 使用原第一批六件遗物的测试数据，无窗口及独立 Windows 桌面 GPU 运行均为 0 失败，覆盖遗物列表、图鉴、两种窗口尺寸的商店、结算和奖励卡复用。后台运行已确认实际引擎桌面与私有桌面一致，`foreground_samples=0`，使用临时游玩状态。

真实截图在 `installation/captures/`。按实际 GPU 像素中心进行最近邻取样核验，猪猪存钱罐在列表、商店、图鉴及奖励卡的 8 处显示均与确认图的不透明像素完全一致，覆盖 32px、48px 和 64px 显示尺寸。截图记录和像素比对结果分别在 `captures/capture_report.json`、`pixel_checks.json`，验证脚本为 `installation/verify_pixels.py`。

初次仅放一件遗物的测试在结算页“图标完全可见”断言上失败，日志保留为 `headless.log`；改用该测试常用的六件遗物后无窗口与 GPU 均通过，日志为 `headless_batch.log`、`gpu.log`。未为这一单件测试夹具改动正式结算布局。编辑器仍提示本机 Android build-tools 目录不可用，不影响桌面导入。

本次只安装用户明确确认的猪猪存钱罐；吸金罗盘的新色调版本另行保留为审阅稿。
