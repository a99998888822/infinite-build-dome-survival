# 当前 HUD 样式

正式界面共用炭黑底、灰铁边与骨白文字；选中、悬停及关键收益使用烟褐与古铜。素材位于 `assets/ui/hud/neutral_iron/`、`assets/ui/hud/smoke_bronze/`，颜色与组件实现集中在 `scripts/ui/`。

| 界面 | 当前规则 |
| --- | --- |
| 天赋、设置 | 中性框体；选中天赋节点、移动方式卡片使用烟褐与古铜 |
| 升级与 Boss 奖励 | 共用奖励组件、灰铁常态，悬停古铜；武器栏保留黄色换位箭头及彩色手动／自动图标 |
| 结算 | 灰铁框体、骨白文字，收益强调古铜；保留哥布林立绘及原气泡配色 |
| 理财与出售确认 | 商店、银行、附魔、交易等统一框体；银行操作区收窄，商店四列等宽 |
| Esc、挑战与指引 | 复用同一套框体、滚动条、按钮和高亮规则 |
| 常驻战斗 HUD | 状态框装饰最多，波次框次之，武器格简洁；伤害统计和悬浮提示采用单像素细线框 |

武器释放状态使用暖金手指与浅绿循环箭头，状态颜色不随悬停抹平。理财背景与属性栏卷轴使用当前确认素材。逻辑坐标、窗口适配和字体维护见[HUD 布局](../main/hud_native_1920.md)。

主要实现入口为 `hud_palette.gd`、`settings_pixel_style.gd`、`talent_page_frame.gd`、`reward_hud_style.gd`、`finance_hud_box.gd`、`finance_frame_skin.gd` 和 `run_settlement_panel.gd`，均位于 `scripts/ui/`。
