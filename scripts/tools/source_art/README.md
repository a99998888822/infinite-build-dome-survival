# 正式美术绘制与处理工具

当前素材的可复用绘制与处理源统一保留在本目录。`artifacts/` 保存原图、参考和必要来源映射，不再额外归档处理稿；过程输出写入 `temp/`。

| 工具 | 用途 | 验证或输出 |
|---|---|---|
| `english_menu_title.py` | 英文标题原创字形 | `--output <目录>` 导出，当前正式标题像素一致 |
| `pixel_effects.py` | 9 个当前特效 | 无参数检查；`--output <目录>` 导出 |
| `cavern_sunlight.py` | 云噪声、岩石受光遮罩 | `--output <目录>` 导出，当前两张贴图像素一致 |
| `moving_cast_composition.py` | 已归档步态与捐赠帧的移动施法合成 | `--output <目录>` 导出并核对 8 张来源图 |
| `player_source_processing.py` | 角色来源图去背景、选定视频帧提取 | 纯函数；调用者提供图片、视频或输出路径 |
| `foreground_contours.py` | 当前前景的轮廓与晶体局部修整算法 | 接收网格和来源图，返回网格，不写文件 |
| `rubble_materials.py` | 碎石材质归并算法 | 接收图片并返回图片 |
| `terrain_recipe.py` | 地面绘制配方 | `--source <输入图> --output <目录>`；历史输入已删除，不能声称可直接精确重建当前地面 |

角色及银行的最终画面以 `assets/` 正式PNG和图集为准。旧稿归档及依赖它们的重建脚本已清理；新资源通过上级目录对应安装器的显式输入接入。

从旧审阅脚本保留的原创像素绘制函数，不包含历史说明、校验日志或打包逻辑。函数返回 Pillow 图像，输出路径由调用者指定。

- `capital_relics.py`：`trigger`、`ledger`、`amplifier`、`dividend`、`vow`，对应镀金扳机、无眠账簿、失控增幅器、狂热分红、清醒誓言。
- `principal_relics.py`：`coin_heart`、`hoarders_ring`、`golden_sarcophagus`。
- `attribute_relics.py`：绯红凝血瓶、哥布林特许状、虚市通行钥匙、猎群骨哨、锈蚀祭铃；本地原创绘制，64px 像素网格，最近邻导出 128px 透明 PNG。
- `combat_attribute_relics.py`：猎隼瞄针、刽子手磨石、猩红断头印、褪色护身符、双腔弹匣、凝时琥珀；本地原创绘制，沿用上述调色板及 64px → 128px 透明像素流程。
- `challenge_vault.py`：已正式采用的保险箱像素绘图源；`challenge_vault.json` 保存调色板、参考来源、尺寸与正式 PNG 哈希。运行绘图脚本会重建 `assets/ui/finance/` 中的两张正式 PNG，并将临时预览写入 `temp/artifacts/previews/vault_redraw/`。

正式 PNG 位于 `assets/ui/icons/relics/`。此目录保留绘制能力，审阅文件夹不再重复保存这些正式资源。
