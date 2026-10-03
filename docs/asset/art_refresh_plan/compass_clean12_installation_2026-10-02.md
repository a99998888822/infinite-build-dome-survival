# 吸金罗盘 12 色大色块正式接入

用户确认去纹理、原色大色块、12 色版本并要求替换正式资源。安装确认稿 `artifacts/previews/relic_compass_tone_study/r02/delivery/compass_clean_clusters12-64.png`：64×64、12 色、硬透明，按原图材质区域清理，色板来自原图真实像素，保留深青表盘、暗金外壳、斜向指针与镂空吊环。

正式 PNG 为 `assets/ui/icons/relics/relic_gold_compass.png`，SHA256 为 `7f7fdc089fcd6c9b8d7e4e432f55110da3f6d684369364a84b3d60be829a300b`，与确认稿一致。同名 `.pxg` 使用自包含 custom 色板，渲染与 PNG 一致。替换前 PNG、网格和导入设置保存在 `artifacts/previews/relic_compass_tone_study/r02/installation/previous/`，哈希见 `installation/assets.json`。

Godot 4.7.2 无窗口编辑器导入通过。现有 `relic_art_install_test.tscn` 使用第一批六件遗物夹具，无窗口和私有桌面 GPU 检查均为 0 失败；覆盖列表、图鉴、两种尺寸商店、结算、奖励卡及控件复用。实际引擎桌面符合后台运行要求，`foreground_samples=0`。使用临时游玩状态，保持现有导入设置和最近邻显示：列表与商店 32px、图鉴 64px、奖励 48px。

截图与运行记录在 `installation/captures/` 和 `installation/gpu.log`。`installation/verify_pixels.py` 根据真实 GPU 像素中心取样核验，罗盘在列表、商店、图鉴和奖励卡的 8 处显示均与确认稿不透明像素完全一致，详见 `installation/pixel_checks.json`。编辑器日志中已有的 Android build-tools 配置提示不影响桌面验证。

下一批 12 件位于 `artifacts/previews/relic_batch12_clean/r01/`，交付审阅，尚未接入正式资源。
