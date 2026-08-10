# 音频与氛围表现模块实施 Checklist

本文档记录第 10 模块的实施事项。整体设计保持极简，只实现三类 BGM、武器命中音效和基础音量控制。

## 1. 当前状态

模块设计已完成，核心编码已完成，等待 Godot 环境验证和音频资源接入。

## 2. 已确认规则

1. 不制作玩家攻击、敌人死亡、拾取、升级、波次和 UI 操作音效。
2. 不制作环境氛围音和稀有度提示音。
3. 敌人受击音效绑定到具体武器。
4. 近战和范围武器每次攻击最多播放一次命中音效。
5. 远程武器每个投射物最多播放一次命中音效。
6. 穿透投射物后续命中不重复播放。
7. 缺少音频素材时静默降级。

## 3. 配置任务

- [x] 在武器 schema 中增加可选字段 `hit_sfx`
- [x] 在 `weapons.json` 的三把武器中配置命中音效路径
- [x] 更新数据校验器，允许并校验 `hit_sfx` 字符串路径
- [x] 更新武器配置字段文档

## 4. 编码任务

- [x] 新建全局音频管理器脚本 `autoloads/audio_manager.gd`
- [x] 接入 `master/bgm/sfx` 音量分组
- [x] 实现菜单、营地和战斗 BGM 切换
- [x] 实现武器命中音效资源读取
- [x] 近战和范围攻击命中后一次攻击只请求一次音效
- [x] 远程投射物记录自身是否已播放命中音效
- [x] 为同一帧大量远程命中增加轻量并发限制
- [x] 缺失音频资源时静默返回
- [x] 在 Bootstrap 中加入音频模块自测

## 5. 不实施事项

- [x] 玩家攻击音效
- [x] 敌人死亡音效
- [x] 经验球和血包拾取音效
- [x] 角色升级音效
- [x] 波次开始和结束音效
- [x] UI 确认、取消和错误音效
- [x] 环境氛围音
- [x] 稀有度提示音
- [x] 复杂分轨和动态混音

## 6. 建议自测输出

```text
[Bootstrap] audio checks
[Bootstrap] - audio manager initialize: passed
[Bootstrap] - bgm switch: passed
[Bootstrap] - weapon hit sfx lookup: passed
[Bootstrap] - melee hit sfx once: passed
[Bootstrap] - area hit sfx once: passed
[Bootstrap] - projectile hit sfx once: passed
[Bootstrap] - missing audio silent fallback: passed
```

## 7. 结项判断

1. 三类 BGM 可以正常切换。
2. 三把武器可以读取各自的命中音效路径。
3. 近战和范围攻击不会按命中敌人数重复播放。
4. 每个远程投射物最多播放一次。
5. 音频缺失时不报致命错误。
