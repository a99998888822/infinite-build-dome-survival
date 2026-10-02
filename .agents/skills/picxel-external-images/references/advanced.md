# 按需使用的 Picxel 能力

以下操作复用附带的运行库。仅在实际输入或交付目标需要时使用，不为使用工具而增加处理阶段。

## 区域预处理

直接 `build` 已使用 anchor 的区域信息为取色加权，但不会自动执行区域马赛克，也不会理解 `drop` 中的文字并删除物体。只有原图纹理确实干扰像素可读性时，才做一次可审阅的预处理：

```powershell
python -B <skill>/vendor/picxel/scripts/picxel.py mosaic <masked>/hero.png --anchor <refs>/hero.anchor.json --background none -o <prepared>/hero.png
python -B <skill>/scripts/external_pixel.py build <refs> -o <work> --prepared-dir <prepared> --background none --sizes 128
```

先完成复杂背景遮罩，再用 `none` 保留 alpha。`regions` 按顺序叠加，`fine` 保留原细节，`medium/coarse` 简化色块；后面的眼口精细区域可覆盖前面的粗化区域。保持原画布和坐标，检查预处理图与原图，不把马赛克称为语义重绘。已有可用 prepared 图时不重复预处理。技术底色只在确认主体不含该颜色时使用，并在第一次去背景阶段移除；去除后以 `none` 传入下游。

## 从已修整大图派生小图

正常多尺寸输出仍从高清输入分别计算。只有大尺寸已完成重要修整、确实值得同步到已请求的小尺寸时，才使用 `derive`。不能用小图放大充作高精度结果。

下面代码放入 UTF-8 临时脚本执行；`skill`、`work`、`large_path`、`asset`、`size` 取自当前任务。目标尺寸必须已在报告请求范围内，源图与目标遵守同一色板：

```python
import sys
sys.path.insert(0, str(skill / "vendor/picxel/scripts"))
from picxel import load, derive, check, render

small = derive(load(large_path), size)
small.name = f"{asset}-{size}-derived"
small.path = work / f"{small.name}.pxg"
assert not check(small)[0]
small.path.write_text(small.dump(), encoding="utf-8")
render(small, work)
```

底层 CLI `derive` 只写 `.pxg`，不会渲染 PNG，且会执行一次孤点清理；上例直接派生后渲染，不额外平滑已修过的眼口。派生结果只是起点，逐尺寸检查瞳孔、嘴形、把手和细链，修整后调用 `external_pixel.py select` 再 `finish`。用户后来增加尺寸时创建新修订任务、显式加入所需尺寸，不手改旧报告伪造完成项。

## 地块

外部地块参考使用 `kind: tile`，地面纹理通常用 `--background none`，不强制透明角或提取单个主体。检查左右、上下接缝和至少 3×3 重复预览；程序的接缝色差只是提醒，不能证明无缝。透明 tile 仅用于明确需要的覆盖层。地块仍受 32／64／128 方形网格和最多 16 色约束。

## 只打包已选版本

仅当用户要求图集或 HTML 时运行：

```powershell
python -B <skill>/scripts/external_pixel.py sheet <work> -o <work>/dist --columns 8
```

此入口复用上游 `sheet`，先核验原图哈希、每个尺寸的选用记录和最终 PNG，再临时收集已选图纸，统一使用 `<name>-<size>` 名称，输出 `sheet.png`、`sheet.json`、`index.html`、`png/`。目标目录应为新目录或空目录；重出使用新的导出目录。不会修改面板状态，旧任务也可单独打包。

不要直接运行 `picxel.py sheet <work>`：工作目录同时保留底稿、detail、face 等版本，上游会把所有 `.pxg` 都打包。图集的帧矩形来自 `sheet.json`；混合尺寸以最大单元排布，不应假设所有帧同尺寸。这个静态图集不包含动作时序、帧率或 Godot 动画资源。

## 项目接入与规格

请求接入或明确要求“符合项目风格”时，读取 [素材规则](../../../../docs/asset/asset_rules_summary.md) 中对应类型，检查目标 PNG／图集实际尺寸、场景／脚本引用，以及用户指定的已确认样例。尺寸优先级：用户本次要求、实际接入契约、相关素材约定、最后才是技能默认。历史建议和现有文件冲突时说明实际差异，不直接套通用尺寸。

- 头像与表情：参考已确认的角色外观，统一色板、头部占比和视线；不同表情分别定位眼口。
- 道具、武器、遗物：查看同类正式图标及其 UI 显示尺度；保留轮廓、材质明暗和留白。小图标以游戏显示尺寸的可读性验收。
- 战斗角色与 Boss：项目有 54×54 战斗帧和 160×160 Boss 等特殊契约；先读目标专用规则和帧布局，不把它们声称为 Picxel 原生输出尺寸。必要的裁切、补边或最近邻缩放另存接入产物，记录方法并检查细节；正式尺寸不能通过只改扩展名或图集裁切参数解决。
- 动画：需要统一画布、角色缩放、脚底基线、支点、朝向、帧序和帧率。Picxel 默认逐图适配主体范围，必须另外对齐和检查连续播放，避免角色大小或位置跳动；不从一张静态图虚构缺失动作。

样例文件、实际色板、目标尺寸与支点等沿用当前任务已知信息；如果尚不明确，先从项目查询，仅询问不能推断的美术选择。不要让用户填写程序可查出的参数。

接入时检查所有资源引用和裁切，最近邻显示；按项目 `AGENTS.md` 查找 Godot、执行导入／相关运行验证，并检查游戏中的真实大小、背景对比及新图是否实际加载。只要求审阅图时不执行正式替换。

## 上游对照与更新

[上游 SKILL.md](https://github.com/See-Sol-Lab/Picxel/blob/4dc28f9dab520cbac5b1a9f4863689c4a686fcaa/SKILL.md) 的面板优先、按需修整、局部重做、派生与图集原则已映射到本项目流程。生图效果图环节在本技能中由外部原图／prepared 图代替；从零绘制和 ComfyUI 节点不属于此入口，不为普通图片转换安装它们。

对照提交和文件哈希见 [VENDOR.json](../vendor/picxel/VENDOR.json)。更新时先比对核心脚本及调用接口，保留项目独立任务文件和本地面板文案，再运行 `scripts/test_external_pixel.py`。快照来源未记录的原始提交保持如实标注，不能把本次对照提交冒充原始来源。不要自动覆盖运行库或全局技能。
