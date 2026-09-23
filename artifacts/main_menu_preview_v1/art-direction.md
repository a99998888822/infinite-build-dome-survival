# 首页预览 V1

本轮为现有素材合成的视觉排版稿，用于审阅布局、材质、字体与主次层级。未接入游戏，未替换原有素材。背景和角色沿用项目素材；菜单面板从理财页木板重新组合，按钮以像素几何和既有木纹制作。未使用图片生成 API。

## 审阅重点

- 左侧标题和木质菜单，右侧保留祭坛与角色。
- 旧金主按钮、苔绿次按钮、深木板与金属包角。
- 采用项目 Ark Pixel 原生 12px 字体，再整数放大；少量缺字使用项目 IPix 字体补齐。现有 16px 字体缺少首页所需汉字，未用于预览。
- 背景仍为原有插画，当前稿不代表背景像素重绘的完成效果。

## 后续背景绘制提示词

Use case: stylized-concept
Asset type: 16:9 pixel-art game main-menu environment, no UI baked into the art.
Primary request: Redraw the project's ruined sanctuary as deliberate, professional pixel art. Preserve the broken stone arches, suspended rubble, distant towers, circular stone altar, and moss-green / antique-gold atmosphere.
Input images: bg_main_menu.png is composition and environment reference; finance_board.png and goblin_banker_states.png are palette and pixel-material references. Do not insert the banker into the environment.
Composition: Broken arch frames the upper edge. The circular altar is the focal point around 62% across and 70% down the canvas. Keep the left 35% quiet and dark for a separate menu. Leave a clear place for the existing hooded player sprite on the altar. Maintain generous, readable spatial depth.
Style: Authored pixel clusters, stepped silhouettes, limited per-material ramps, crisp hard edges, sparse intentional dithering, consistent logical pixel scale. Work as though designed on a 640x360 pixel grid. No smooth painted gradients, airbrush, blur, bevel-rendered 3D surfaces, or photographic texture.
Palette: deep forest green, desaturated olive, charcoal wood, aged brass, warm stone highlights. UI reference colors: #232A21 #30372A #626B4E #C5A16A #E0D6B6 #A79F87.
Lighting: restrained pale gold on the altar, low contrast behind the menu, dim green atmosphere in the distance. Keep the altar readable; no neon wash.
Constraints: No words, title, buttons, logos, watermark, or new characters. Do not change the world into a tavern, bank interior, or cartoon village.

## 后续完整绘图预览提示词

Use case: ui-mockup
Asset type: polished pixel-art game title-screen review image, 16:9.
Primary request: Show the ruined sanctuary background above with a compact dark wood-and-aged-metal menu on the left and the existing hooded player standing on the right-side altar. The interface should share the finance page's material and palette.
Title text verbatim: 穹顶求生
Button text verbatim, top to bottom: 开始战斗 / 天赋 / 设置 / 退出
Typography: chunky, crisp Chinese pixel lettering. Title in muted antique gold. Main action is visually strongest. Secondary labels are warm cream. All text must be exact and unobstructed.
Materials: straight-edged dark timber, subtle plank seams, stepped corners, small aged metal fasteners, hard pixel shadows. No pill buttons or soft modern dashboard cards.
Constraints: No extra menu entries or invented gameplay data. Keep approximately 60% of the screen available to appreciate the environment. Treat as a static review proposal, not an implemented screenshot.
