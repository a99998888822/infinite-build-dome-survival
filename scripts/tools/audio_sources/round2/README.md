# 第二轮修改的来源素材

这两份 WAV 是项目自制音效在 2026-09-25 第二轮决策执行前的原件，不来自外部素材库。

- `before_plasma_hit_01.wav`：原电浆命中音，SHA-256 为 `aef81dc5608d9b45008e098a26101ed4a3b347751d4fc76a795d5d4ac787823f`。用户认为适合流星摆锤，因此保留音色，将原游戏播放的 −10 dB 增益写入摆锤素材，以适配摆锤的 0 dB 直接播放入口。
- `before_light_sword_01.wav`：原光辉剑落地音，SHA-256 为 `25667d1cab5385d0761be5845ecb2c2efffd8f8d277b6726b9a9bf2025593c60`。第二轮配方对其低通处理，再加入低中频撞击主体。

两份文件均为 48 kHz、16-bit 单声道。由 `combat_audio_revision_round2.py` 读取；保留稳定来源，避免反复生成时叠加处理。最终确认清单见 `artifacts/reports/audio_release.json`。
