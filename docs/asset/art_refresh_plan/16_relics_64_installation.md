# 前三批24件遗物：64×64正式接入

用户确认“就使用64×64的替换正式资源”。本次将猪猪存钱罐所在第一批、理财经理所在第二批和绷带／护腕所在第三批，共24张已审阅64px PNG原样安装至 `assets/ui/icons/relics/`。

## 资源与备份

- 每张64×64、最多16色、alpha仅0或255；与已审阅PNG哈希完全一致。
- 沿用原路径、配置ID、Godot导入配置和UID；原有 `.png.import` 字节保持不变。
- 正式PNG旁保留同名可编辑 `.pxg`，内含色板，内容与PNG一致。
- 旧32px PNG及导入配置保存在[安装备份目录](../../../artifacts/previews/art_refresh_v1/relics_64/r01/installation/previous/)。
- [逐件安装哈希](../../../artifacts/previews/art_refresh_v1/relics_64/r01/installation/assets.json)与[原图来源](../../../artifacts/previews/art_refresh_v1/relics_64/r01/sources.json)保留完整溯源。原始审阅ZIP和前三批32px接入记录作为历史保留。

## 显示适配

新图标使用原生64px居中、最近邻采样。商店父槽从36px扩为64px，含新遗物的虚拟网格卡片行高为160px，列宽与滚动定位同步计算；仅有旧素材时沿用原布局。较小窗口通过滚动查看完整卡片。

遗物列表使用72px单元格并按实际宽度计算列数；图鉴自动容纳64px；奖励卡的小尺寸图框至少84px，保留漂浮动效；利息结算根据真实行高计算内容高度。复用商店卡片、图鉴和奖励卡切回旧素材时恢复原尺寸规则。

## 验证

Godot无界面编辑器导入，以及四组各6件的实际游戏UI回归，分别执行无界面和后台GPU验证。检查1152×648、1024×576下的遗物列表、商店顶部／中部／底部、逐件图鉴和小尺寸奖励卡；另检查结算行高度及最后一行可达。

GPU验证通过独立Windows桌面运行，未切换用户桌面。实际渲染的图标不透明像素与64px原图逐像素比对，允许每通道最多1级渲染误差。查看[验证结果](../../../artifacts/previews/art_refresh_v1/relics_64/r01/installation/verification.json)与[临时截图位置](../../../artifacts/previews/art_refresh_v1/relics_64/r01/installation/capture_locations.json)。

结果：24件全部通过，168次实机图标像素比对通过，脚本／布局检查失败数为0，前台抢占采样为0；本次日志无警告或错误。

本次不涉及图标造型重绘；第二批仍受384×256豆包源图的信息量限制，采用的是用户已确认的64px版本。
