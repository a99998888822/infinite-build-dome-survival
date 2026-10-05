# 武器图标 128×128 正式接入

2026-10-04，按用户确认的 128 分辨率，将 `wuqi_icon.png` 中的 11 件武器图标替换到 `assets/ui/icons/weapons/` 现有路径。营地短刀直接复用已确认的 128 样例，文件 SHA256 保持 `cce3bcbd298fd4515512415dfc7f2adec6b6c2b4a2ade392762ac3ad6fc639e5`。

原始整图保留在 `artifacts/sources/weapons/wuqi_icon.png`；[来源与接入清单](../../../artifacts/sources/weapons/wuqi_icon_manifest.json)记录每件武器的裁剪位置、资源 ID、正式路径、颜色数、轮廓范围与 PNG 哈希。按原图非空格从左到右、从上到下映射；原图第二行前两格为空。用户称“木质短弓”的箭矢图沿用现有 `weapon_void_blade` / `weapon_wood_arrow.png`，配置显示名“木质弓箭”保持原样。

制作采用项目 Picxel 外图流程：原图裁剪、边界连通去底、内部空隙抠图、限色网格化，再对照原图做局部像素修整，没有调用生图模型。沿用短刀样例的尺度与描边清理方式，不同材质各用自己的原色板。保留灯焰、枪械扳机空隙、链环与钱袋旁金币；触手底部修复了去底时误删的紫色阴影。

11 张正式 PNG 均为 128×128 RGBA，alpha 仅为 0/255，实际使用 10–15 色，四周有透明留白。每张 PNG 旁同步同名 PXG/PAL，像素一致；`artifacts/editable/index.json` 同步尺寸与哈希。现有 `.png.import`、配置引用、UI 控件尺寸、战斗贴图及数值保持不变。`build_camp_dagger_art.py` 图标校验尺寸改为 128，刀身与斩击仍为 32/64。

图标总览：`artifacts/previews/weapon_icons/20261004-all128-r2/results/all-icons-128.png`。后续重建使用当前同名 PXG，不运行历史程序绘图入口覆盖新图标。

验证结果：

- 全部 PNG 与 PXG 逐像素一致，尺寸、透明度、颜色数、边距及原图/样例哈希通过检查；短刀、武器三件套的现有素材检查器通过。
- Godot 4.7.2 headless 编辑器导入通过；角色选择现有测试 69 项、0 失败，理财准备测试 0 失败。角色选择测试退出时另有 4 个 ObjectDB 实例和 2 个资源未释放提示，保留在日志中，没有因此修改产品逻辑。
- 临时实机审阅场景通过正式游戏流程进入角色选择、战斗和武器百科，逐张检查 11 件武器的导入尺寸、可见像素、48px 显示框和最近邻过滤，headless 与 GPU 均 0 失败。GPU 保存了角色选择及全部武器百科截图，逐张检查后未发现裁切或布局溢出。
- GPU 使用私有桌面运行，退出码 0，`foreground_samples=0`，实际引擎桌面与私有桌面一致；本次运行没有遮挡用户桌面。

验证日志、实机截图与旧正式资源备份位于 `C:/Users/mi/.codex/visualizations/2026/10/04/01a104c9-baaa-7751-9d04-db1d997cefc6/weapon-icons-128/`。运行使用临时存档会话；原有存档不受影响。
