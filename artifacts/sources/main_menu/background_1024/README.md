# 主界面背景 · 1024 精度正式版

2026-10-18 用户确认采用审阅稿并替换正式资源。画布 1024×572，正式文件为 `assets/ui/main_menu/bg_main_menu.png`。

- `background_layer_0.png`、`background_layer_1.png`：从高清原图直接处理的背景，两个图层互补，每层最多 16 色。编辑时保持画布及像素坐标。
- `protected_foreground.png`：沿用已确认的哥布林、五块符石与金币细节。
- `protected_mask.png`：保护区域，62131 个像素在此次背景重做中保持不变。
- `background.pal`：两层背景使用的 32 色色板。
- `manifest.json`：图层叠加顺序、原图路径、正式资源哈希及确认记录。

以透明 1024×572 画布按清单顺序叠加三个 RGBA 图层，再转为不透明 RGB PNG，即可还原正式文件的全部像素。原始高清图仍唯一保留于 `artifacts/sources/originals/3493776d30-main_menu_goblin_dungeon_origin.png`。制作使用项目 Picxel 本地流程，没有调用图片生成模型。
