extends RefCounted
class_name FinanceUIStyle

const TEXT := Color("e0d6b6")
const MUTED := Color("a79f87")
const GOLD := Color("c5a16a")
const GREEN := Color("a9c498")
const RELIC_LIST_ICON_SCALE := 0.625
const RELIC_DISPLAY_SIZE := 64.0
static var _item_icon_cache: Dictionary = {}

# Opt in only after a batch has passed art review. Legacy assets keep their layout.
const NATIVE_RELIC_ICONS := [
	"relic_piggy_bank", "relic_steel_vault", "relic_gold_compass",
	"relic_compound_interest_tome", "relic_periodic_dividend_clock", "relic_quant_trading",
	"relic_finance_manager", "relic_dividend_check", "relic_fixed_deposit_certificate",
	"relic_hostile_takeover", "relic_tip_tray", "relic_high_yield_contract",
	"relic_worn_hemostatic_cloth", "relic_load_iron_bracer", "relic_pungent_sachet",
	"relic_broken_crystal", "relic_vitality_potion", "relic_dead_shield_badge",
	"relic_turtle_shell_pendant", "relic_prison_copper_anklet", "relic_brass_pocket_watch",
	"relic_flesh_pauldron", "relic_nightmare_healing_urn", "relic_barrier_crystal",
	"relic_cultic_holy_shield", "relic_lost_wayfarer_greave", "relic_soul_keeper_face_stone",
	"relic_pain_vessel", "relic_true_silver_armor", "relic_holy_silver_cup",
	"relic_suffering_carapace", "relic_costly_seed_of_life", "relic_shadowless_greave",
	"relic_chain_of_hardship", "relic_void_tentacle", "relic_worn_fighting_gloves",
	"relic_cracked_stone_bullet", "relic_hasty_spring_trigger", "relic_rough_grinding_lens",
	"relic_blocking_counterweight", "relic_bloodstained_belt", "relic_poison_mist_pouch",
	"relic_tremor_grip", "relic_black_spot_eagle_eye", "relic_berserker_copper_badge",
	"relic_corroded_blowpipe", "relic_gale_roulette", "relic_executioner_bracer",
	"relic_judgment_eye_pendant", "relic_split_crystal_warhead", "relic_gold_digger_gloves",
	"relic_incomplete_divination_dice", "relic_travelers_ledger", "relic_defiled_blessing_coin",
	"relic_expanded_backpack_strap", "relic_stargazers_lens", "relic_harvest_sacrificial_vessel",
	"relic_amulet_of_humanity", "relic_gift_mark", "relic_void_storage_casket",
	"relic_reincarnation_hellfire_candle", "relic_guarding_heart_copper_mirror", "relic_sleepless_ledger",
	"relic_frenzied_dividend", "relic_gilded_trigger", "relic_runaway_amplifier",
	"relic_lucid_vow", "relic_coin_heart", "relic_hoarders_ring",
	"relic_golden_sarcophagus", "relic_old_brass_telescope", "relic_cracked_bronze_bell",
	"relic_long_focus_eyepiece", "relic_diffusion_nozzle", "relic_range_tripod",
	"relic_aftershock_hourglass", "relic_golden_rangefinder", "relic_abyssal_echo_shell",
	"relic_folded_star_chart", "relic_horizon_orrery", "relic_flyer_ad",
	"relic_merger_reorg", "relic_divine_fusion", "relic_goblin_central_bank_printer",
	"relic_medical_cutback", "relic_welfare_cutback", "relic_annual_leave_cutback",
	"relic_salary_adjustment", "relic_perpetual_annuity_scroll", "relic_bankruptcy_reorg",
]


static func is_native_relic_icon(texture: Texture2D) -> bool:
	return texture != null and texture.resource_path.get_base_dir() == "res://assets/ui/icons/relics" and texture.resource_path.get_file().get_basename() in NATIVE_RELIC_ICONS


static func relic_icon_size(texture: Texture2D, display_scale: float = 1.0) -> Vector2:
	# Keep the established UI footprint when an approved source gains resolution.
	return texture.get_size() * (RELIC_DISPLAY_SIZE / maxf(texture.get_width(), 1.0)) * display_scale


static func set_item_icon(control: TextureRect, texture: Texture2D, native_scale: float = 1.0) -> void:
	if control.has_meta("scaled_relic_icon"):
		control.custom_minimum_size = Vector2.ZERO
		control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		control.remove_meta("scaled_relic_icon")
	control.texture = texture
	var native_pixel := is_native_relic_icon(texture)
	if native_pixel:
		if not control.has_meta("legacy_icon_layout"):
			control.set_meta("legacy_icon_layout", [control.stretch_mode, control.texture_filter, control.custom_minimum_size])
		control.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var previous: Array = control.get_meta("legacy_icon_layout")
		var extent := relic_icon_size(texture, native_scale)
		control.custom_minimum_size = (previous[2] as Vector2).max(extent)
		if extent != texture.get_size():
			# Center an explicit drawing rect; shrinking only the minimum size leaves
			# STRETCH_KEEP_CENTERED drawing the full source texture.
			control.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			control.custom_minimum_size = extent
			control.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			control.size = extent
			control.offset_left = -extent.x * 0.5
			control.offset_top = -extent.y * 0.5
			control.offset_right = extent.x * 0.5
			control.offset_bottom = extent.y * 0.5
			control.set_meta("scaled_relic_icon", true)
	elif control.has_meta("legacy_icon_layout"):
		# Shop cards and encyclopedia details are reused for different items.
		var previous: Array = control.get_meta("legacy_icon_layout")
		control.stretch_mode = previous[0]
		control.texture_filter = previous[1]
		control.custom_minimum_size = previous[2]
		control.remove_meta("legacy_icon_layout")


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


static func bank_button(control: Button, selected: bool = false) -> void:
	button(control, selected)
	var normal := box("756943" if selected else "293228f2", "b59b61" if selected else "786e4d", 6)
	normal.border_width_bottom = 2
	control.add_theme_stylebox_override("normal", normal)
	control.add_theme_stylebox_override("hover", box("414b34", "b59b61", 6))
	control.add_theme_stylebox_override("pressed", box("293228", "b59b61", 6))
	control.add_theme_stylebox_override("disabled", box("20281fed", "53543d", 6))
	control.add_theme_color_override("font_color", Color("e8dbb9"))
	control.add_theme_color_override("font_disabled_color", Color("97987f"))
	FinanceFrameSkin.button(control, selected)


static func bank_tab(control: Button, selected: bool) -> void:
	control.toggle_mode = true
	control.set_pressed_no_signal(selected)
	bank_button(control, selected)
	for state in ["font_color", "font_pressed_color", "font_focus_color"]:
		control.add_theme_color_override(state, Color("f7e4ad") if selected else Color("b9b59a"))


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


static func horizontal_scroll(control: ScrollContainer) -> void:
	control.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	control.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var bar := control.get_h_scroll_bar()
	bar.custom_minimum_size.y = 8
	bar.add_theme_stylebox_override("scroll", box("171f19", "343e2d", 3))
	bar.add_theme_stylebox_override("scroll_focus", StyleBoxEmpty.new())
	bar.add_theme_stylebox_override("grabber", box("797752", "aaa178", 3))
	bar.add_theme_stylebox_override("grabber_highlight", box("979367", "d4bc81", 3))
	bar.add_theme_stylebox_override("grabber_pressed", box("aaa178", "e0d6b6", 3))
	var blank := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	for icon_name in ["increment", "increment_highlight", "increment_pressed", "decrement", "decrement_highlight", "decrement_pressed"]:
		bar.add_theme_icon_override(icon_name, blank)


static func bank_scroll(control: ScrollContainer) -> void:
	scroll(control)
	FinanceFrameSkin.scrollbar(control.get_v_scroll_bar())


static func bank_horizontal_scroll(control: ScrollContainer) -> void:
	horizontal_scroll(control)
	FinanceFrameSkin.scrollbar(control.get_h_scroll_bar())


static func reason(code: String) -> String:
	return str({
		"loan_dialog_open": "请先选择或关闭贷款条款。",
		"loan_expired": "这份贷款条款已失效。",
		"loan_not_active": "当前没有需要偿还的贷款。",
		"loan_insufficient_gold": "金币不足，无法一次性还清当前欠款。",
		"bank_operation_used": "本波已办理存取，下波恢复。",
		"trade_bank_blocked": "交易限制：本次银行存取已关闭，下波恢复。",
		"trade_deposit_blocked": "交易限制：本次不可存款，下波恢复。",
		"trade_expired": "这笔交易已失效。",
		"strong_refresh_unavailable": "当前没有可购买的史诗遗物，强力刷新资格已保留。",
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
	if _item_icon_cache.has(resolved):
		return _item_icon_cache[resolved]
	if (resolved.is_empty() or not ResourceLoader.exists(resolved)) and not table.is_empty():
		resolved = str(DataRegistry.get_record(table, record_id).get("icon", ""))
	if resolved.is_empty() or not ResourceLoader.exists(resolved):
		return null
	if not _item_icon_cache.has(resolved):
		_item_icon_cache[resolved] = load(resolved) as Texture2D
	return _item_icon_cache[resolved]
