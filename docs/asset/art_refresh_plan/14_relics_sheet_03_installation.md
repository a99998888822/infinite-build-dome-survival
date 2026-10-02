# 第三批：12件遗物像素化与正式接入

用户提供2364×1773白底图集，并在同一条指令中授权像素化后直接替换。按实际物件核对4列×3行，逐件抠底，经项目 Picxel 转换与人工像素修整后，安装到 `assets/ui/icons/relics/`。本次记录为助手视觉检查加用户直接安装授权，不表述为用户已经单独审阅最终像素稿。

12件包括止血布条、铁皮护腕、香包、残破晶石、生命力药瓶、护盾徽章、龟壳吊坠、铜脚环、黄铜怀表、血肉肩甲、治愈圣壶和屏障结晶。全部32×32、每件5～16色、硬透明、四角透明，主体至少留1px边距；游戏内使用原生32px和最近邻过滤。前三批累计安装24件。

## 处理与保留

- 保留2364×1773原图、实际裁切坐标、透明裁切、anchor、Picxel底稿、修整网格和最终色板。
- 保留原图大轮廓和配色，恢复缩图后变弱的绷带卷芯、扎绳、护腕边缘、龟壳分区、怀表指针和圣壶把手。
- 屏障结晶最下方尖端被平台水印遮挡，对约19/1368图高范围进行局部形状与色面修复；原始图集未改动。未调用图片生成模型。
- 正式PNG与交付PNG逐文件哈希一致；原配置ID、文件名、导入UID和导入设置保留。
- 本批加入 `FinanceUIStyle.NATIVE_RELIC_ICONS`；未改动其他UI框架、按钮或游戏数值。

## 文件与验证

工作目录：`artifacts/previews/art_refresh_v1/relics_sheet_03/r01/`。

- `review/final_dark.png`、`final_light.png`、`source_vs_pixel.png`：深浅底、原尺寸、4倍放大和原图对照。
- `export/png/`、`export/grids/`、`export/palettes/`：正式PNG、可编辑网格和色板。
- `installation/previous/`：替换前12张PNG及 `.import` 备份。
- `installation/assets.json`、`verification.json`：安装哈希与实际渲染比对。
- `installation/capture_locations.json`：系统临时目录中的真实GPU截图位置；`gpu_a.json`、`gpu_b.json` 记录独立桌面和前台监测。

测试分为两组六件，确保每件在实际界面内可见。Godot导入、无窗口运行、后台GPU运行和48次不透明源像素比对通过；覆盖两种窗口尺寸的商店、全部12件图鉴、遗物清单，以及复用卡片恢复旧武器布局、结算行高和滚动末行。

第二组最初的加速无窗口测试在退出时报告Ogg背景音乐资源未释放；详细日志定位到音频播放对象。改为按真实帧时间运行该无窗口测试后退出正常，保留初始日志供追溯。测试场景和正式音频代码未改动。编辑器仍有本机Android build-tools目录不可用的既有提示。

两个GPU进程均在独立Windows桌面完成，`foreground_samples=0`。验证使用临时游玩状态，未抢占用户前台。

下一步：[第四批12件生成包](batches/relics_sheet_04/README.md)，仅画风参考与561字提示词，4列×3行。
