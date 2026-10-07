# 小 Boss 霸体视觉稿 V02

仅供视觉审阅；正式敌人脚本、场景、配置、图片与字体均未接入或替换。

- `review.html`：可切换站立、移动、翻转蓄力；支持暂停、拖动进度、慢放。
- `armor_preview_v02.gif`：2.8 秒循环，霸体显示 2 秒，左侧实战尺寸，右侧 2 倍放大。旧版 `armor_preview.gif` 保留用于对比。
- `sandbox/`：保留独立 Godot 工程的设计源码；重新运行前用 `prepare.py` 从正式资源补齐动画等参考副本。审阅页需要的中文像素字体仍保留。
- `reference_manifest.json`：来源资源的 SHA-256；`assemble.py` 校验来源未变。
- `gpu_*.json`：真实 GPU 捕获的桌面与前台采样记录。
- `validation.json`：导出的帧数、时长和审阅检查结果。

2026-10-07 已清理原始录屏帧、Godot 缓存、可重建的参考副本及 V01 重复视频／静帧。V02 审阅页与附件、V01 对照 GIF、独有着色器和制作脚本保留。旧 GPU 日志的结果与异常上下文见[日志摘要](../../maintenance/validation_log_summary_20261007.json)。下面的重新生成流程会重新创建参考副本、帧序列和日志。

视觉参数：黄、橙、红三色沿当前动画帧轮廓流动，相位流速从每秒 0.22 圈提高到 0.88 圈（4 倍），主要描边宽 3 个源像素（实战约 1.68 像素），外侧增加低透明度边缘；霸体展示 2 秒，末尾 0.14 秒淡出。黄色“霸体”以原标签中心为缩放基点，准确缩小至 0.7 倍（18 × 0.7 = 12.6 像素），保持水平居中；沿身体中轴从脚部上升到躯干中部，0.8 秒内消失，文字不随角色翻转。

这里只以固定时间轴展示效果，不实现霸体判定、免控、伤害或敌人 AI。移动与蓄力标签指现有动画姿态，未模拟真实战斗。

## 重新生成

在项目根目录运行 `python artifacts/previews/miniboss_super_armor_v01/prepare.py`，再对 `sandbox` 执行 Godot headless 导入和运行检查。

GPU 捕获使用项目工具 `scripts/tools/run_godot_background.py`，指定独立 `sandbox` 路径，分别传入 `--pose=idle`、`--pose=move`、`--pose=windup --mirrored`，将 `--output` 指向本目录下的 `frames/v02/idle`、`frames/v02/move`、`frames/v02/mirrored`，日志名为 `gpu_v02_<姿态>.log`。完成后运行 `assemble.py` 生成审阅媒体。

通过本地 HTTP 服务打开 `review.html`。本次审阅页面地址为 `http://127.0.0.1:8773/review.html`。
