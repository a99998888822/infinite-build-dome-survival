# 当前战场环境

[battle_root.tscn](../../scenes/battle/battle_root.tscn)使用 `cavern_sunlight_backdrop.gd` 和 `cavern_pit_horizon.gd`，正式资源来自 `data_config/`、`assets/` 与 `shaders/`。

- 场景由洞窟远景、洞口之间的四种遗迹、草地、草簇、战斗障碍、云影斑驳和椭圆暗沿组成。
- A01 圆石与 A05 倒木仅作为战斗障碍，保留随机生成、底座碰撞与遮挡，不在超远景重复摆放。
- 遗迹与洞窟共用水平视差，保持洞口避让、跨周期连续性和同局返回位置稳定。
- 摄像机构图将玩家放在画面高度的约 57%，位置按屏幕像素取整。
- 草簇按实际不透明底缘与人物当前动画脚底排序，投影与接地关系随当前素材和缩放维护。
- 每局使用独立地形种子，同局分块由种子和坐标确定。重新访问、暂停恢复及加载顺序变化保持布局稳定，不消耗玩法全局随机序列。

地表纹理与采样图统一读取 [cavern_meadow_battlefield.json](../../data_config/cavern_meadow_battlefield.json)，远景由 [cavern_battlefield.json](../../data_config/cavern_battlefield.json)配置。地面分布图透明像素携带颜色信息，保留 `process/fix_alpha_border=false` 的导入约定。

修改布局或导入设置后检查地形、碰撞、草簇遮挡、镜头往返与随机数隔离。配置来源专项为 [cavern_config_source_test.tscn](../../scenes/tests/cavern_config_source_test.tscn)，后台画面验证使用项目私有桌面工具。
