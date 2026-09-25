extends RefCounted
class_name FinanceUIStyle

const TEXT := Color("e0d6b6")
const MUTED := Color("a79f87")
const GOLD := Color("c5a16a")
const GREEN := Color("a9c498")


static func principal_revive_status(state: Dictionary) -> String:
	if state.is_empty():
		return "未持有"
	if int(state.get("remaining_uses", 0)) <= 0:
		return "本局已使用"
	if bool(state.get("available", false)):
		return "可触发（消耗%d本金）" % int(state.get("principal_cost", 0))
	return "本金不足（需%d）" % int(state.get("minimum_principal", 0))


static func box(fill: String = "232a21", edge: String = "576048", margin: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(fill)
	style.border_color = Color(edge)
	style.set_border_width_all(1)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style


static func button(control: Button, selected: bool = false) -> void:
	control.add_theme_stylebox_override("normal", box("3c4833" if selected else "30372a", "92996a" if selected else "626b4e", 5))
	control.add_theme_stylebox_override("hover", box("45543b", "a7ac78", 5))
	control.add_theme_stylebox_override("pressed", box("243122", "a7ac78", 5))
	control.add_theme_stylebox_override("disabled", box("242b22", "434c37", 5))
	control.add_theme_stylebox_override("focus", box("3c483300", "d4bc81", 1))
	control.add_theme_color_override("font_color", TEXT)
	control.add_theme_color_override("font_disabled_color", Color("737c64"))
	control.add_theme_font_size_override("font_size", 12)
	control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func label(control: Label, font_size: int = 14, color: Color = TEXT) -> void:
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_color_override("font_color", color)


static func tab(control: Button, selected: bool) -> void:
	button(control)
	var normal := box("cfb477" if selected else "20271f", "f1d797" if selected else "626b4e", 5)
	normal.border_width_bottom = 3 if selected else 1
	control.add_theme_stylebox_override("normal", normal)
	control.add_theme_stylebox_override("hover", box("dfc58b" if selected else "3b4732", "f1d797" if selected else "92996a", 5))
	control.add_theme_stylebox_override("hover_pressed", box("dfc58b" if selected else "3b4732", "f1d797" if selected else "92996a", 5))
	control.add_theme_stylebox_override("pressed", normal)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		control.add_theme_color_override(state, Color("25291c") if selected else MUTED)
	control.add_theme_font_size_override("font_size", 14)
	control.toggle_mode = true
	control.set_pressed_no_signal(selected)


static func scroll(control: ScrollContainer) -> void:
	control.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	control.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	control.get_v_scroll_bar().add_theme_stylebox_override("scroll", box("171f19", "343e2d", 0))
	control.get_v_scroll_bar().add_theme_stylebox_override("grabber", box("797752", "aaa178", 0))
	control.get_v_scroll_bar().add_theme_stylebox_override("grabber_highlight", box("979367", "c2b388", 0))
	control.get_v_scroll_bar().add_theme_stylebox_override("grabber_pressed", box("999364", "c2b388", 0))


static func reason(code: String) -> String:
	return str({
		"bank_operation_used": "本波已办理存取，下波恢复。",
		"amount_must_be_positive": "请输入大于 0 的整数。",
		"amount_exceeds_gold": "存入金额超过金币余额。",
		"amount_exceeds_principal": "取出金额超过本金。",
		"invalid_action": "请选择存入或取出。",
		"insufficient_gold": "金币不足",
		"insufficient_gold_for_refresh": "金币不足，无法刷新。",
		"already_purchased": "已购买",
		"weapon_already_owned": "已拥有此武器",
		"load_capacity_exceeded": "武器负载不足",
		"upgrade_no_longer_available": "升级条件已改变",
		"relic_stack_limit": "遗物已达叠加上限",
		"attachment_failed": "无法配置：请检查武器空槽和附魔归属。",
		"incompatible_enchantment": "此武器不支持该附魔；铸铁榴弹炮暂不支持穿透。",
		"enchantment_page_required": "请在理财页面调整附魔或出售物品。",
		"last_weapon": "至少保留一把武器，最后一把不可出售。",
		"detach_before_sale": "已装备的附魔需要先卸下。",
		"item_not_found": "物品已不存在，请重新选择。",
		"sale_quote_changed": "物品或报价已变化，请重新确认。",
		"shop_price_changed": "理智变化后价格已更新，请查看新价格再购买。",
		"transaction_busy": "操作正在处理。",
		"sale_failed": "出售失败，物品已恢复。",
	}.get(code, "操作未成功，请重试。"))


static func item_icon(path: String, table: String = "", record_id: String = "") -> Texture2D:
	var resolved := path
	if (resolved.is_empty() or not ResourceLoader.exists(resolved)) and not table.is_empty():
		resolved = str(DataRegistry.get_record(table, record_id).get("icon", ""))
	return load(resolved) as Texture2D if not resolved.is_empty() and ResourceLoader.exists(resolved) else null
