# Infinite-Build-Dome-Survival AI素材生产规范文档
## 1 文档概述
本文档规范本项目所有美术、音频素材的AI生成流程、平台选型、尺寸标准、提示词模板、后期修正流程、Godot导入规则、商用版权要求。
项目风格约束：轻克苏鲁虚空像素割草游戏，恐怖元素仅点缀，整体偏向爽快roguelite，不做惊悚血腥画面。

## 2 素材分类与标准像素尺寸
全部像素素材统一尺寸，避免后期大量返工：
1. 玩家主角：48×48px，俯视角4向动画（待机/行走/攻击）
2. 普通小怪：32×32px，俯视角2向基础动画
3. 精英/BOSS：64×64px，带触手、多眼畸变像素特征
4. 武器投射物：16/24px小型像素精灵
5. 遗物、拾取道具图标：32×32px
6. 场景瓦片：32×32px静态虚空地面、穹顶背景装饰
7. VFX粒子素材：32~64px（虚空裂隙、触手残影、畸变爆发）
8. UI按钮/面板：矢量像素风，无固定尺寸

## 3 AI平台选型分级推荐（美术素材）
### 3.1 首选生产平台（精灵动画、瓦片，直接输出精灵表）
#### 1）Ludo.ai（主力，游戏像素专用）
适用产出：玩家角色全套动作、怪物动画、场景瓦片、武器精灵
优势：原生俯视角像素、一键输出Sprite Sheet、内置Aseprite适配、锁定角色画风、支持图生图统一形象
套餐要求：付费月度订阅（商用授权），免费额度素材禁止Steam商用
适配本项目：生成4方向行走/攻击循环、虚空畸变像素生物、穹顶地面瓦片

#### 2）SpriteBrew（补充动画补全）
适用产出：已有单张角色原画，AI自动补全全套行走、攻击动画
优势：每日免费额度、轻量化精灵编辑器、直接输出Godot兼容精灵表
使用场景：AI生成满意原画后，批量扩展动作帧

### 3.2 概念图/宣传物料平台
#### Leonardo AI
适用产出：Steam商店封面、主菜单背景、BOSS概念原画、UI图标
配套LoRA：pixel art top down、cosmic horror soft、dark purple void
优势：图片一致性强，多次生成角色不漂移，大量社区像素模型

### 3.3 本地无月费方案（有N卡16G显存）
Stable Diffusion + ComfyUI
推荐模型：RetroDiffusion、PixelArt XL LoRA
优势：本地生成无版权上传风险、无限额度、可自定义像素画风
劣势：前期部署成本高，需手动拼接精灵表
适合长期大量批量产出小怪、道具素材

### 3.4 不推荐平台
Midjourney：像素边缘糊化，无法规整输出精灵表，仅可做概念参考
DALL·E 3：像素精度差，不适合游戏内运行素材

## 4 像素素材AI生成通用规范
### 4.1 硬性画风约束（所有提示词必带）
正向强制关键词：
top-down 2d pixel art, 32bit pixel, nearest neighbor pixel, dark void dome background, subtle cosmic horror tentacle details, desaturated indigo purple palette, clean pixel lines, game sprite sheet, transparent background
反向强制关键词（禁止画面崩坏）：
blurry, anti-aliasing, realistic, 3d render, text, watermark, deformed limbs, bright neon colors, blood, gore, messy pixel edges

### 4.2 提示词分层结构（概述模板）
所有AI提示词固定三段式结构，便于批量复用
1. 基础画布约束：尺寸、像素精度、俯视角、透明背景、精灵表格式
2. 主体描述：角色/怪物类型、克苏鲁轻度畸变特征（触手残影、多眼、虚空扭曲轮廓）
3. 动作约束：待机循环、4方向行走、自动攻击动画，帧数8帧循环
4. 氛围配色：暗紫虚空、低对比度、柔和虚空粒子点缀
5. 反向黑名单：糊图、高清写实、文字水印、高饱和亮色

### 4.3 AI产出后统一后期流水线（必须执行）
1. Aseprite导入AI精灵表
2. 统一全局色板，删除杂色、异色像素
3. 裁剪规整单帧、修正错位动画、补全缺失帧
4. 导出png精灵表，严格按命名规范：`player-main-spritesheet.png`
5. Godot导入设置：纹理过滤=Nearest，关闭Mipmap，开启重复边缘

## 5 音频AI生成平台与规范
### 5.1 BGM背景音乐平台
#### Suno AI（主力）
适用：主菜单循环、常规战斗BGM、BOSS战压迫曲风
商用要求：Pro付费订阅，保留订单授权截图用于Steam上架
通用曲风提示词概述：
lo-fi dark pixel game soundtrack, subtle cosmic horror whispers, no vocals, seamless loop 3min, slow deep bass, distant void murmurs, top down roguelite combat music

### 5.2 游戏音效SFX平台
1. ElevenLabs Sound Effects
适用：怪物嘶吼、触手摆动、虚空裂隙低语、畸变触发音效、棱彩羁绊爆发重音
2. Ludo.ai Audio
适用：持续环境音（穹顶虚空低频杂音）、拾取道具轻音效

### 5.3 音频后期工具（免费）
Audacity：音频降噪、裁剪无缝循环、调整音量分层
### 音频导入Godot规范
1. 音频分为3个轨道：BGM、环境氛围音、即时SFX
2. 循环BGM标记循环区间，避免卡顿断音
3. 高频攻击音效添加音量衰减，防止多武器同时发声噪音爆炸

## 6 素材文件命名规范（统一，方便Godot资源管理）
### 美术素材命名
- 玩家精灵：`sprite_player_[角色名]_action.png`
- 敌人精灵：`sprite_enemy_[怪物等级]_name.png`
- 武器投射物：`sprite_weapon_[轻重类型]_name.png`
- 遗物道具：`sprite_relic_[羁绊标签]_name.png`
- VFX粒子：`vfx_void_[特效名称].png`
- 场景瓦片：`tile_dome_ground_base.png`

### 音频素材命名
- BGM：`bgm_scene_场景名称_loop.wav`
- 音效：`sfx_分类_名称.wav`
示例：`sfx_weapon_heavy_swing.wav`、`sfx_void_rift_whisper.wav`

## 7 商用版权核心规则（Steam付费游戏强制遵守）
1. 所有用于游戏内正式素材，必须使用平台付费订阅账号生成
2. 免费试用额度产出素材**禁止商用**，存在下架风险
3. 本地SD生成素材需人工大幅修改（Aseprite重绘30%以上像素），降低侵权风险
4. 保存全部订阅订单、平台商用条款页面截图，留存备查
5. 禁止使用无开源商用授权的第三方LoRA、音效素材

## 8 素材生产分阶段计划（配合开发周期）
### 阶段1：原型阶段素材（少量试产）
1. 1套主角48px像素动作
2. 3种基础小怪、3类轻重武器精灵
3. 基础穹顶地面瓦片、简易虚空粒子VFX
4. 基础战斗循环BGM、拾取、攻击基础音效

### 阶段2：完整开发素材批量产出
1. 全部6名可解锁角色全套动画
2. 全部普通/精英/BOSS畸变怪物精灵
3. 全武器、全羁绊遗物图标
4. 裂隙事件、7层棱彩羁绊专属特效
5. BOSS战专属BGM、虚空低语持续环境音

### 阶段3：上线补充素材
1. Steam商店宣传原画、封面图
2. UI全套像素按钮、营地升级面板图标
3. 结算、升级弹窗配套轻克苏鲁装饰素材

## 9 交付AI协作通用指令（复制给Claude生成素材提示词）
