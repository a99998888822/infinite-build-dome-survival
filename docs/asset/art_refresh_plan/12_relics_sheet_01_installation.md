# 第一批6件遗物正式接入

2026-09-29：用户确认“审阅通过，替换正式资源；然后进行下一步”。本次直接安装已确认的32×32成品，未重绘或再次像素化。

正式目录：`assets/ui/icons/relics/`。本批为猪猪存钱罐、钢铁保险柜、吸金罗盘、复利宝典、周期分红钟、量化操盘。每个正式PNG与 [r01审阅输出](../../../artifacts/previews/art_refresh_v1/relics_sheet_01/r01/README.md) 的SHA256一致，硬透明、统一16色色板；配置ID、文件路径与导入UID不变。

## 显示适配

`FinanceUIStyle.set_item_icon()`只对已确认的6件启用原生尺寸居中与最近邻过滤。商店36px槽位、遗物列表48px槽位和图鉴48px槽位内显示32px图，不放大到分数倍；利息结算的20px槽位为本批扩至32px，超出内容继续滚动。主菜单固有遗物和旧奖励卡入口也使用同一策略。复用控件切回其他素材时恢复原来的尺寸与过滤设置。

保持既有悬浮、稀有度呼吸与弹窗入场动画，原生32px约定对应静态布局；整个窗口被外部系统缩放时仍受窗口缩放影响。其他遗物、武器、附魔不提前迁移；导航、按钮、属性栏和理财框均保留原样。

## 备份与交付

以下目录均位于 `artifacts/previews/art_refresh_v1/relics_sheet_01/r01/`：

- `installation/previous/`：替换前6张PNG和各自 `.import`。
- `installation/assets.json`：新旧PNG哈希、正式路径、导入设置哈希。
- `export/grids/`、`export/shared.pal`：可编辑Picxel网格与共享色板，继续保留。
- `source/`、`split_and_matte.json`：完整高清源图、裁切坐标与抠图记录。
- `installation/captures/`：真实商店、遗物列表、图鉴与结算截图。商店排列使用测试用6件货架，未伪造购买或更改存档。
- `installation/verification.json`：正式文件、日志与GPU像素比对结果。

需要回退本批图像时，将 `installation/previous/` 的6张PNG复制回上述正式目录并重新导入；导入设置本次未改。显示适配与图像备份分开记录。

## 验证

已运行Godot无窗口编辑器导入，以及 `scenes/tests/relic_art_install_test.tscn` 的无窗口和独立Windows桌面GPU验证。覆盖真实遗物列表、六件图鉴切换、1152×648和1024×576商店、卡片复用、结算行高与底部可达性。编辑器仅提示本机Android build-tools目录不可用，不影响桌面导入与渲染。

GPU由 `scripts/tools/run_godot_background.py` 启动，核实引擎位于独立桌面，`foreground_samples=0`，未抢占用户桌面。验证传入 `--transient-session` 与后台参数，保护用户存档与窗口偏好。

无窗口与GPU运行均为0失败。静态商店、图鉴及遗物列表共24次不透明源像素比对通过；测试场景暂时冻结列表的稀有度染色，正式运行继续保留该动画。结算截图主动滚动到底部，因此不把被滚动裁掉的上部图标纳入逐像素比对。

下一步：[第二批豆包参考图与提示词](batches/relics_sheet_02/README.md)。收到第二批原始高清图之后，先审阅，再拆分和像素化。
