# 首页背景重绘 V2

## 用户修订

- 整张背景重新绘制，不能继续沿用旧背景作为完成稿。
- 画面不出现玩家角色，也不加入 NPC、怪物或人形剪影。
- 保持理财页的苔绿、暗木、旧金色气质，以及强烈、明确的像素游戏画风。
- 输出不含标题、按钮、文字的纯背景图供用户审阅；另附菜单叠加预览，帮助评估整体效果，正式接入仍待审阅。

## 绘制方向

16:9 的空旷遗迹前厅。残破拱门构成前景框架，中右侧空置的圆形石质祭坛形成视觉中心，远处是被薄雾分隔的残垣与塔楼。左侧约三分之一保留低对比度暗部，给后续菜单留出空间。用少量旧金色符文与暖色石面高光引导视线，避免大片荧光。

整张画面重新组织像素轮廓、色块、砖石结构和光照。采用统一像素颗粒、有限材质色阶与少量有组织的抖色，不用缩小放大、马赛克或滤镜处理旧图来代替重绘。

## 最终绘图提示词

Use case: stylized-concept
Asset type: complete 16:9 pixel-art game title-screen background, environment only.
Primary request: Paint an entirely new pixel-art ruined sanctuary background for the game Dome Survival. The previous smooth illustrated background was rejected. This deliverable must be a full repaint of the environment, not a recolor, pixelation filter, traced overpaint, or a UI collage.
References: The existing main-menu environment conveys the ruined-arch and circular-altar theme only; its painted rendering is not the desired style. The finance page's dark timber panel and aged metal colors define the muted moss-green, charcoal-brown, antique-gold palette. Do not transfer any reference characters into this image.
Scene: An empty, ancient, roof-broken sanctuary. Massive ruined stone arches frame the foreground and upper corners. A clearly readable, EMPTY circular stone altar occupies the middle-right lower half. Beyond it, broken towers and masonry recede in distinct mist-separated layers. Include only a few suspended stone fragments and restrained golden spiral inscriptions as environmental details.
Composition: Wide 16:9 frame. Keep approximately the left third darker, quieter, and low contrast for a later separate menu. Center the environmental focal point near 62% of the frame width. Preserve open space and readable depth. The empty altar itself is the subject; do not leave a conspicuous character-shaped gap or add a figure to fill it.
Style: Strong, professional, authored pixel art. Consistent visible pixel clusters, intentional stair-step contours, crisp edges, designed stone tiles and broken masonry, limited per-material color ramps, sparse controlled dithering. Visual logic of a 640x360 art grid enlarged by an integer factor. All environment layers must share this style.
Palette: Deep forest green, desaturated moss, charcoal wood-brown, weathered olive stone, aged brass and pale warm highlights. Reference colors #232A21, #30372A, #626B4E, #C5A16A, #E0D6B6, #A79F87. Reserve the brightest gold for a few focal accents.
Mood: Quiet, ominous, ancient, atmospheric. Dim green distance; restrained warm light across the altar; dark foreground framing. Readable forms without gray murk or excessive black crush.
Absolute exclusions: NO PLAYER, NO PEOPLE, NO NPC, NO GOBLIN, NO MONSTER, NO ANIMAL, NO HUMANOID STATUE, NO SILHOUETTED CHARACTER. No title, words, menu, buttons, HUD, watermark, logos, browser chrome, or decorative infographic labels. No smooth digital painting, photorealism, 3D rendering, soft airbrush gradients, broad bloom, or generic pixelation filter.
Deliverable: One complete background image for visual review. UI integration is deferred until review.

## 实际绘制与交付

按用户要求，由当前模型直接编写像素绘图代码完成整张环境绘制，未调用图片生成 API。原首页背景没有被读取、复制、重着色或像素化。所有环境形状在 640×360 原生网格上绘制，再用最近邻整数放大三倍至 1920×1080。画面无玩家、NPC、怪物及其他角色。

- `background-redrawn-v2.png`：1920×1080 纯背景审阅图。
- `homepage-preview-v2.png`：1920×1080 首页菜单叠加预览。
- `background-native-640x360.png`：原生像素背景。
- `menu-overlay-v2.png`：独立透明菜单层，沿用 V1 的菜单设计及理财页木板材质。
- `layers/`：天空、远景残墙、中景拱廊、地面、空祭坛、前景建筑、尘粒与浮石七层透明 PNG。
- `draw_background.py`：可复现的绘图源文件。
- `provenance.json`：绘制方式、分辨率、色数与素材来源记录。

本轮只创建审阅素材，没有替换正式首页、场景或玩家素材。
