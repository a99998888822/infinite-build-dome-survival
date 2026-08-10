# 存档与本地进度模块实施清单

本清单对应 `11-save_progress_design.md`。当前模块已完成核心编码，本文档主要用于收口、验收和后续复查。

## 1. 当前状态

- [x] 已确认只保留局外进度存档。
- [x] 已确认当前仅使用一个存档槽 `profile_01`。
- [x] 已确认不保存战斗过程、中途退出继续本局、`void_shards`、`settlement_id` 等字段。
- [x] 已完成 `CampProgression` 读写、迁移、备份、原子写盘。
- [x] 已完成音量设置持久化。
- [x] 已在 `bootstrap` 中加入存档自检。

## 2. 已完成的编码项

- [x] 注册 `CampProgression` 为 Autoload。
- [x] 注册 `AudioManager` 为 Autoload。
- [x] 存档路径统一为 `user://saves/profile_01.json`。
- [x] 备份路径统一为 `user://saves/profile_01.backup.json`。
- [x] 临时写入路径统一为 `user://saves/profile_01.tmp.json`。
- [x] 存档结构仅保留 `currencies.camp_currency`、`building_levels`、`upgrade_levels`、`settings`。
- [x] 支持旧存档 `user://camp_progression.json` 迁移。
- [x] 保存时自动写入备份文件，降低异常中断风险。
- [x] 音量设置会随存档加载与保存自动同步。

## 3. 待验证项

- [ ] 在具备 Godot 的电脑上启动项目，确认无报错。
- [ ] 确认能正常生成 `profile_01.json`。
- [ ] 确认重启后能正确读取 `camp_currency`、`building_levels`、`upgrade_levels`、`settings`。
- [ ] 确认音量设置修改后可以持久化。
- [ ] 确认旧存档迁移流程可用。
- [ ] 确认战斗中不会写入正式存档。
- [ ] 确认仅在死亡或通关后的结算阶段触发正式保存。

## 4. 结项标准

- [ ] 单槽存档行为正确。
- [ ] 仅保留局外进度字段。
- [ ] 音量设置可读写。
- [ ] 旧存档可迁移。
- [ ] 战斗中不落盘，战斗结束后才正式写入。
