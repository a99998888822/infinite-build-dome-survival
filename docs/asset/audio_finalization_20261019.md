# 音效正式接入与 artifacts 清理（2026-10-19）

本轮音效已确认并接入正式游戏。音频位于 `assets/audio/`，播放入口、循环行为和停用规则均使用正式脚本及配置，不依赖审阅目录。

## 最终生效内容

- 按用户提供的 `audio.rar/audio_list.txt` 接入 17 段音频，其中火池燃烧声最终停用，现有 16 段在用。
- 导电爆裂复用电火花，导电雷鸣复用普通落雷，保留原有触发时机和声音并发限制。
- 人物移动声随实际步行循环；赤铜炉灯在持续喷火期间循环，停止释放或暂停时停止。
- 普通火池、神圣火焰和暗焰的燃烧音频完全停用；光暗湮灭也保持无声。伤害、状态、特效及反应声音抑制照常生效。
- 异化触手使用独立命中声；流星摆锤和裂地战锤共用重击声；其余已确认替换沿用当前正式素材和增益。

来源文件、用途 TXT 和原始备份保存在 `artifacts/sources/audio_user_20261018/`。精确映射和 SHA-256 见 [user_audio_manifest.json](../../scripts/tools/audio_sources/user_audio_manifest.json)，播放规则见 [combat_audio.md](combat_audio.md)。清理前逐项核对全部 17 份来源与正式 WAV 哈希一致；清理后 `assets/audio/` 的 92 个文件（含导入设置）与清理前完全一致。

本日后续音量校准：以最响连续 50 ms 的 RMS 电平约 −20 dBFS 为目标，流星摆锤与裂地战锤的命中增益设为 −13 dB（原 −7.2 → −20.2 dBFS），异化触手命中增益设为 −16 dB（原 −4.1 → −20.1 dBFS）。增益保存在 `weapons.json` 的 `hit_sfx_gain_db`，由实际播放入口应用；原始音频不变，其他音效复用播放器时恢复自身增益。上述电平为单次声音进入总线前的测量估计。

## 清理结果

| 项目 | 清理前 | 清理后 |
| --- | ---: | ---: |
| artifacts 文件数 | 14,811 | 485 |
| artifacts 大小（十进制） | 2.86 GB | 93.7 MB |

清理 `reviews/`、`previews/`、`validation/`、`maintenance/` 中共 14,326 个临时文件，合计 2,770,909,857 字节，包括试听页面、录制视频、截图、日志、旧稿及隔离副本。保留 `sources/`、`editable/`、说明文件与 `.gdignore`；483 个来源和可编辑文件均通过清理前后哈希核对。

直接递归删除被自动审批策略拦截，最终采用 Windows 回收站清理，文件可恢复；上述数字表示 artifacts 目录减少的占用，不代表已清空回收站、释放同等磁盘空间。两个只用于本轮旧预览和音效审阅的本地服务已关闭。

可复用的录制脚本与场景已移至 `scripts/tests/reviews/` 和 `scenes/reviews/`，场景配方保存在 `scripts/tools/audio_sources/`。后续音效审阅输出写入 `temp/audio-review/`。

## 验证

- Godot 无界面编辑器导入通过。
- 脚步与喷火循环、战斗音效、元素反应及火池静音共 120 项检查通过。
- Bootstrap 数据自检通过；退出时仍有既有的资源释放提示。
- 来源索引 138 项、编辑入口 381 项、角色 61 帧及 9 张重建图验证通过。
- 清理执行清单和核对结果位于 `temp/audio-finalization-20261019/`，不属于正式资源。

## 重新生成审阅

音效原生录像场景为 `res://scenes/reviews/user_audio_capture.tscn`，配方为 `res://scripts/tools/audio_sources/user_audio_review_cases.json`。先创建 `temp/audio-review/capture/`，通过 `scripts/tools/run_godot_background.py` 在私有桌面录制，向引擎传入：

```text
--path . --audio-driver Dummy --write-movie temp/audio-review/capture/gameplay.avi --fixed-fps 30 --scene res://scenes/reviews/user_audio_capture.tscn -- --cases=res://scripts/tools/audio_sources/user_audio_review_cases.json --output=res://temp/audio-review/capture
```

再运行 `python scripts/tools/build_user_audio_review.py --ffmpeg <ffmpeg绝对路径>`，生成 `temp/audio-review/user-audio/review.html`。录制必须遵循项目的后台验证规则。全音效清单可通过 `python scripts/tools/build_sfx_scene_review.py` 重新生成；没有重新录制的项目仅提供单独试听。
