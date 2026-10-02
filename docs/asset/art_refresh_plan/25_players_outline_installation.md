# 两名玩家64px描边版正式接入

2026-09-30，用户确认使用独立的 `outline_r01` 替换正式资源。已将初心者／资本家的idle与walk共4张PNG安装至 `assets/sprites/player/combat/`，沿用原资源路径和导入UID。无描边的 `pixel_r02` 与描边审阅包均保持不变。

| 角色 | idle | walk | 播放速度 |
|---|---|---|---|
| 初心者 | 64×64，walk第一帧 | 384×64，6帧 | 6 FPS |
| 资本家 | 64×64，walk第一帧 | 448×64，7帧 | 7 FPS |

同步更新角色配置、控制器初心者默认帧数／帧率、素材安装器规格和角色回归断言。保留Sprite居中、1倍最近邻、碰撞形状、武器锚点和移动速度；外描边沿原轮廓向外延伸1px。选角大图与头像为独立资源，本次哈希不变。

安装前完整备份位于 [install_outline_01/backup](../../../artifacts/previews/art_refresh_v1/players_walk_01/install_outline_01/backup)，文件映射与哈希见 [安装清单](../../../artifacts/previews/art_refresh_v1/players_walk_01/install_outline_01/installation.json)。正式PNG逐字节匹配批准稿，Godot载入后的可见像素也逐项比对；测试的 `--installed` 模式不注入候选贴图或覆盖动画配置。

验证包括Godot编辑器导入、15张战斗相关正式贴图的尺寸／色板／透明度校验、角色回归103项、两名玩家headless与GPU完整帧序／镜像／停步检查。GPU在独立Windows桌面录制，前台抢占为0。具体结果与日志见 [交付说明](../../../artifacts/previews/art_refresh_v1/players_walk_01/install_outline_01/README.md)。编辑器原有Android build-tools目录提示不影响桌面导入。

附件指定区域已从原动态对照稿裁出两份独立GIF：深绿色背景、保留原3倍像素显示、一秒循环，去除标题和底部小尺寸重复人物。实机动图另由正式游戏资源运行截图生成。
