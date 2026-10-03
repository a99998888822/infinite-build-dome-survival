# 遗物 A 版第三批 12 件正式接入（2026-10-02）

用户确认第三批审阅稿后，将 `artifacts/previews/relic_a_batch03/r01/delivery/` 内的 12 张透明 PNG 与可编辑 `.pxg` 替换到 `assets/ui/icons/relics/`。所有 PNG 均为 64×64、12 色、二值透明，与已确认文件 SHA-256 一致。屠戮者臂铠使用审阅包中已修整下缘的最终版本。

本批为裂痕石子弹、急促弹簧扳机、粗糙研磨透镜、阻滞配重石、嗜血皮带、毒雾投囊、震颤握柄、黑斑鹰眼水晶、狂战士铜质徽章、蚀腐吹管、疾风轮盘、屠戮者臂铠。

处理沿用用户确认的 A 方案：原图 RGB、7×7 中值过滤、轻抬近黑像素、最多 12 色、无抖色，保留主要明暗与材质色调。接入使用已确认文件，没有重新转换。

## 接入验证

保留现有独立 PNG 引用、`.png.import` 设置及最近邻显示规则：列表／商店 32px、百科 64px、奖励 48px。无需修改界面代码或图集裁切。

- Godot 4.7.2 无窗口编辑器导入通过，无 Parse/Compile/SCRIPT ERROR。
- 现有 `relic_art_install_test.tscn` 分两组覆盖全部 12 件，headless 和 GPU 均为 `failures=0`。
- 两次 GPU 截图在私有 Windows 桌面完成，实际桌面与预期一致，`foreground_samples=0`。
- 人工核对商店和臂铠百科截图；114 处实际图标采样覆盖全部 12 件，前景 RGB 与正式 PNG 最近邻采样的最大误差为 0。
- 正式 PNG 与确认稿哈希一致，`.pxg` 渲染与 PNG 逐像素一致，导入设置未改动。

## 记录

- [安装文件与哈希](../../../artifacts/previews/relic_a_batch03/r01/installation/assets.json)
- [替换前备份](../../../artifacts/previews/relic_a_batch03/r01/installation/previous/)
- [实际界面像素核验](../../../artifacts/previews/relic_a_batch03/r01/installation/pixel_checks.json)
- [商店截图](../../../artifacts/previews/relic_a_batch03/r01/installation/captures-1/shop_1152x648.png)
- [臂铠百科截图](../../../artifacts/previews/relic_a_batch03/r01/installation/captures-2/encyclopedia_relic_executioner_bracer.png)

至此三批共 36 件 A 版已接入。原图第 6 张的下一批 12 件另存于 `artifacts/previews/relic_a_batch04/r01/`，作为审阅稿交付，未接入正式资源。猪猪存钱罐不在本次处理范围。
