# 11件武器图标正式接入

用户已确认64×64像素稿并授权替换。11张PNG、对应PXG与PAL已安装到 `assets/ui/icons/weapons/`，文件名、配置引用及Godot导入UID保持原样。替换前的PNG、已有PXG／PAL及导入文件均保存在本批 `installation/previous/`。

安装稿与审阅导出哈希一致，PNG与可编辑网格逐像素相同，每件最多16色、硬透明、至少1px透明边距。正式营地短刀图标的维护检查上限由12色同步为16色，刀身与斩击上限不变。其余维护逻辑、战斗贴图和动画未修改。

Godot无界面导入、现有工作台回归及短刀测试通过；工作台另在独立Windows桌面录制1152×768与1024×576截图，20项检查通过、前台抢占采样为0。截图已检查新木弓、炉灯、触手、战锤与短刀；其余6件通过文件、网格及导入核对，本记录不声称11件都已逐界面录制。

源纹理为64×64，工作台、商店、图鉴等现有较小槽位继续使用原有最近邻缩放；本次没有把所有显示槽强制改成64px。原生PNG清晰度与UI槽位大小分开记录。其他90件已更新遗物的文件哈希保持不变。

- [审阅图与原始处理记录](../../../artifacts/previews/art_refresh_v1/weapons_sheet_01/pixel_r01/README.md)
- [安装与备份记录](../../../artifacts/previews/art_refresh_v1/weapons_sheet_01/pixel_r01/installation/assets.json)
- [验证记录](../../../artifacts/previews/art_refresh_v1/weapons_sheet_01/pixel_r01/installation/verification.json)
- [工作台后台截图](../../../artifacts/previews/art_refresh_v1/weapons_sheet_01/pixel_r01/installation/captures/workbench_end_1024x576.png)
- [下一波：12张附魔图标](batches/augmentations_sheet_01/README.md)
