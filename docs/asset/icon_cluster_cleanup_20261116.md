# 武器与遗物图标内部清理

按用户确认的 Picxel 第二版样例处理全部正式图标，目标 36×36。原有 116 张 PNG 中，103 张合并了内部零碎纹理或过厚描边内侧，13 张已有干净色块而保留原文件；营地短刀、裂地战锤和破裂铜铃直接采用用户确认稿。原有 PNG 的透明轮廓、构图与色板均保留，不增色，不全图描边或重新设计。

刚焰炉和斩马刀此前仍引用 64×64 SVG（内部 32×32 像素造型），现保留其原色和像素结构，置入带两像素透明边距的 36×36 PNG。原 SVG 保留，正式配置转向 PNG；新增可编辑 `.pxg` 和 `.pal`。共 118 张正式 PNG，图标清单的路径、色数、边界与哈希已核对。

原资源完整备份：`E:/project/godot-project/infinite-build-dome-survival-icon-backup-20261116-231217`。备份包含武器与遗物目录全部文件、替换前图标清单、SVG 引用修改前的 `data_config/weapons.json`。`manifest.json` 记录最初 469 个文件的 SHA-256，`cleanup-validation.json` 记录处理结果。恢复时应成组恢复对应 PNG、源稿及清单；两张 SVG 还需恢复配置引用。

审阅材料：`artifacts/previews/all_icon_cluster_cleanup_20261116/`，包括六批前后对照、Picxel 原图／源稿／成品记录、处理源脚本、验证结果和 GPU 导入捕获。每批最多 20 张。处理属于 AI 检查后的本地网格修整，未调用图片生成模型。

验证：原有 PNG 全部通过 36×36、原色子集、alpha 轮廓不变、PNG 与 `.pxg` 一致、色板及清单哈希检查；完整备份哈希核对通过。Godot Headless 编辑器导入通过，图标基础回归 131 项、武器栏布局回归 1205 项通过。GPU 捕获运行在私有 Windows 桌面，`foreground_samples=0`，未抢占用户前台。
