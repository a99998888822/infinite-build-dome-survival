# 初心者移动攻击与后跳接入

用户确认移动攻击 F10 的 Picxel 试稿后，授权按该风格处理两组全部素材并替换正式资源。本轮共 19 帧：移动攻击 9 帧、后跳 10 帧。F10 的已确认 PNG 原样保留；其余帧逐帧按源图的材质、姿态与表情检查，使用共同的 16 色色板整理色块、线条及细节。处理为本地像素化和网格修整，没有调用图片生成模型。

| 动作 | 正式资源 | 帧数与时序 |
| --- | --- | --- |
| 移动攻击 | `assets/sprites/player/actions/novice_128/move_attack.png` | 9 帧，一次挥拳，每帧 1/12 秒，全长 0.75 秒 |
| 后跳 | `assets/sprites/player/actions/novice_128/jump_backward.png` | 10 帧，源视频 F162、168、172、175、178、184、187、190、195、201；按最新要求加速至 2 倍，全长 0.875 秒 |
| 前跳 | `assets/sprites/player/actions/novice_128/jump_forward.png` | 10 帧、18 FPS，逐字节保留此前指定给前跳的旧后跳图集 |

每帧 128×128，硬透明 alpha 为 0/255。新帧保留审阅时的透明轮廓、统一 0.23 缩放与居中位置。动画配置支持逐帧 `frame_durations`。后跳在首次接入时为源视频原速 1.75 秒，随后按用户要求将全部停留时间减半，正式播放时长为 0.875 秒，保持各姿态的相对节奏；移动攻击仍为原速 0.75 秒。`r01` 下的实机动图保留首次接入的播放速度。

2 倍速调整已通过 Godot 编辑器导入、动画回归 92/92 及主场景 headless 120 帧检查，均无脚本或运行错误。核验所有后跳帧的停留时间精确减半，其他动作配置及图集哈希保持一致；日志与修改前配置保存在 `artifacts/previews/novice_new_actions_20261015/r02_speed/`。

普通攻击释放时，如果人物正在向攻击方向移动，选择 `move_attack`；静止或向反方向移动时保持原 `attack`。没有将向前迈步的素材当成后退攻击。攻击期间锁定实际瞄准方向，结束后恢复当前移动方向。新后跳供火炮反冲和向后瞬移使用；本次不改变碰撞、位移距离、伤害和冷却。

当前配置共 8 类 61 帧。既有 idle、move、attack、sustain、move_sustain 保持原资源；原前跳 8 帧和替换前配置保存在本轮任务的 `backup/`。

制作与审阅任务：`artifacts/previews/novice_new_actions_20261015/r01/`。19 张透明 PNG、接入哈希和帧时序在 `delivery/`；可编辑网格、共享色板、来源映射在 `artifacts/editable/player_actions/novice_128/new_actions_20261015/`，并已更新可编辑素材索引。

复现制作：`scripts/tools/build_novice_new_actions.py` 的 `prepare/build/refine/approve/install` 命令。实机演示：`scenes/tests/novice_new_actions_live_review.tscn`，通过 `scripts/tools/run_godot_background.py` 在独立 Windows 桌面运行。演示使用生产角色选择流程、武器释放、移动和渲染；镜头为正常 1 倍，角色仍按正式 50% 显示。为稳定录制而停止随机刷怪，并设置不移动的高生命敌人，演示设置不写入正式玩法配置。

## 验证与实机审阅

- 动画回归 92/92、主战斗联动 146/146、位移联动 133/133、GPU 像素采样 132/132，共 503 项检查通过。采样覆盖当前 61 帧，核对缩小显示的轮廓、内部颜色、硬透明、左右镜像及复活闪烁。
- 编辑器导入和主场景 headless 运行通过，无 Parse/Compile/SCRIPT ERROR。主战斗测试仍记录既有的 dummy texture 空纹理与退出时 1 个 RID 资源泄漏错误，断言 146/146 通过；本次未修改无关的选人页纹理生命周期。动画、位移、新动作演示、主场景及 GPU 日志未出现这些错误。
- GPU 实机录像为 612 帧、30 FPS、20.4 秒，8 次真实武器释放全部成功；逐帧记录覆盖移动攻击全部 9 帧及后跳全部 10 帧，实际纹理路径指向新的正式图集。
- 实机和采样两次 GPU 运行均核验引擎位于指定独立桌面，`foreground_samples=0`，退出码为 0，无脚本或渲染报错。

`delivery/review.html` 展示 7 组原速动图和完整画面录像。动图来自实际视口截图，以人物为中心裁切后最近邻放大 2 倍；没有用素材拼接替代实机画面。完整录像 `novice_new_actions_live.mp4` 为 1280×720。

| 动图 | 内容 |
| --- | --- |
| `01_move_attack_right.gif` | 向右移动 → 移动攻击 → 移动 |
| `02_move_attack_left.gif` | 向左移动 → 移动攻击 → 移动 |
| `03_idle_backjump_idle.gif` | 待机 → 后跳 → 待机 |
| `04_move_backjump_move.gif` | 移动 → 后跳 → 移动 |
| `05_attack_backjump_move.gif` | 移动攻击 → 后跳 → 移动 |
| `06_forward_jump_preserved.gif` | 前跳旧确认素材保留验证 |
| `07_retreat_attack_facing.gif` | 向后移动、向前开火的朝向检查 |

`live_all_19_frames.png` 为全部新帧的实机截图证据；`live_capture.json` 记录每张截图的动作、帧号、实际贴图、位置和朝向；`background_capture.json` 记录独立桌面验证。编码与打包入口为 `scripts/tools/build_novice_new_actions_review.py`。

## 完成后的临时文件清理

按用户要求清理了实机原始逐帧 PNG、GIF 编码中间帧、可重新提取的原视频拆帧、早期审阅包、重复对照图和 Python 缓存，共 1766 个文件，约 543 MiB；关闭本次 4 个审阅服务器和项目 Picxel 面板。正式资源、可编辑源稿、确认样例、最终 GIF/MP4、逐帧 JSON 记录、必要的原图及制作输入、备份和 2 倍速验证日志保留，154 个保留文件的哈希复核一致。

最终审阅文件可从 `r01/delivery/` 本地打开；旧 localhost 链接已停止服务。需要重新打包实机录像时，先重跑录制以生成逐帧 PNG；需要全部视频拆帧时，使用保留的 `process_video.py` 从原 MP4 重新提取。清理清单位于 `artifacts/previews/novice_new_actions_20261015/cleanup_20261015.json`。
