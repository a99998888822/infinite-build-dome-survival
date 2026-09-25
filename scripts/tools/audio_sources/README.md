# 已确认的电火花母版

`lightning_bright_approved.wav` 保存用户确认的“原味提亮”单次放电，48 kHz、16-bit PCM、单声道、0.28 秒。

母版从当时“原味提亮”试听的第一个独立放电片段（0.25–0.53 秒）提取，补偿试听中的 -10 dB 增益。保留确认版本的原音高、颗粒和提亮效果，不再对母版进行合成、饱和或峰值归一化；旧试听文件已清理，后续生成直接读取本目录的母版。

`scripts/tools/build_combat_audio.py` 使用此母版生成正式电火花，并作为导电／雷火联动中的电弧层。这样重新构建音效包也会保留已确认的音色，不依赖临时审阅目录。

运行时使用 `assets/audio/sfx/combat/lightning_01.wav`；本目录仅供素材构建使用，通过 `.gdignore` 排除在 Godot 资源扫描之外。来源与 SHA-256 记录在 `lightning_bright_approved.json`。
