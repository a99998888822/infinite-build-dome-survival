# 第二批r02：6件遗物正式接入

用户确认替换后，已将 `artifacts/previews/art_refresh_v1/relics_sheet_02/r02/export/png/` 的6张确认稿原样复制至 `assets/ui/icons/relics/`：理财经理、分红支票、定期存单、恶意收购、小费托盘、高利契约。本次没有重新生成或像素化，正式PNG与确认稿SHA256一致。

所有文件32×32、硬透明，每件6～12色。原配置ID、文件名、导入UID与导入设置保留。本批加入 `FinanceUIStyle.NATIVE_RELIC_ICONS`，与第一批一起按原生32px居中显示，最近邻过滤；未确认的其他素材继续沿用原设置。先前未通过的r01没有安装。

## 备份和证据

以下均位于 `artifacts/previews/art_refresh_v1/relics_sheet_02/r02/installation/`：

- `previous/`：替换前的6张PNG及 `.import`。
- `assets.json`：正式路径、新旧PNG哈希、导入设置哈希。
- `verification.json`：文件与GPU逐像素核验结果。
- `editor.log`、`headless.log`、`gpu.log`：导入、无窗口运行和后台GPU运行日志。
- `gpu.json`：引擎实际独立桌面核验与前台采样记录。
- `captures/`：真实商店、遗物清单、图鉴及结算截图。货架由测试数据放入本批6件，仅用于视觉验证。

源图、透明裁切、Picxel网格与色板仍在r02目录保留。原像素审阅ZIP保持交付时版本，正式安装状态以 `delivery.json` 与本记录为准。

## 验证结果

Godot编辑器导入、无窗口运行、独立Windows桌面GPU运行均通过。核对1152×648与1024×576商店、本批六件图鉴、遗物清单、复用卡片切回旧武器、结算行高和最后一行可达性。静态显示共24次不透明像素比对通过；列表的稀有度染色仅在测试中冻结，正式动画保留。

后台验证 `foreground_samples=0`，实际引擎桌面与专用桌面一致。使用 `--transient-session` 和后台参数，未覆盖用户浏览器或修改游玩存档。编辑器仅提示本机Android build-tools目录不可用，不影响此次桌面验证。

测试场景支持 `--relic-ids=` 指定本轮6件，避免随着安装名单增加而把未显示在屏幕内的图标混入截图比对。

下一步：[第三批12件生成包](batches/relics_sheet_03/README.md)，4列×3行，仅一张画风参考与约600字提示词。
