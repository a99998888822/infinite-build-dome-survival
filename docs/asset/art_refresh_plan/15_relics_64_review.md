# 前三批24件遗物：64×64像素稿审阅

更新：用户已确认使用64×64版本替换正式资源，安装与显示适配见[64px正式接入记录](16_relics_64_installation.md)。下文保留生成时的审阅记录。

用户反馈32px版本过于简化，要求从猪猪存钱罐所在批次开始，基于豆包原图重新处理64×64版本。本轮已完成三批全部24件，交付独立透明PNG、可编辑网格、色板与等大对照图；正式32px资源保持原状态。

- [全部24件预览](../../../artifacts/previews/art_refresh_v1/relics_64/r01/review/all_24_dark.png)
- [前12件等大对照](../../../artifacts/previews/art_refresh_v1/relics_64/r01/review/same_size_comparison_01.png)
- [后12件等大对照](../../../artifacts/previews/art_refresh_v1/relics_64/r01/review/same_size_comparison_02.png)
- [完整64px交付包](../../../artifacts/previews/art_refresh_v1/relics_64/r01/relics_24_64px.zip)
- [来源、修整与交付说明](../../../artifacts/previews/art_refresh_v1/relics_64/r01/README.md)

每件64×64、14～16色，alpha仅0/255、四角透明、主体至少留1px边距。全部直接从原始尺度裁切处理，未使用32px稿放大作为输入。以保留原图结构为主，只对遗漏的材质点缀色重做四件色板，并补保险柜锁轮两段短高光弧线。

第一批源图1920×1280，第二批源图384×256，第三批源图2364×1773。第二批六件的原始裁切约百像素，64px能保留更多已有信息，但无法恢复原图不存在的高清细节。当前交付不声称进行过模型重绘。

等大对照统一显示为128px区域：旧32px放大4倍、新64px放大2倍。单批预览另含64px原尺寸，用于判断实际观感。所有已安装32px图标哈希保持不变；本轮没有Godot脚本、场景或运行时修改。

后续采用64px时，需要同步检查实际UI槽位、行高和显示尺度，再按授权范围安装并后台验证。第四批豆包原图生成包仍可使用；高清生成阶段不受这次后处理尺寸审阅影响。
