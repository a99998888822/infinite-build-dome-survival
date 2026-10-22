extends Node
## The real inventory and reward strips must fit a complete row at overflow.
var failures := 0
var checks := 0
var output := ""


func _ready() -> void:
	WindowSettings._startup_applied = true
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): output = argument.trim_prefix("--capture-dir=")
	_run.call_deferred()


func frames() -> void:
	for i in 12: await get_tree().process_frame


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _run() -> void:
	CampProgression.begin_transient_session()
	var loadout := WeaponLoadout.new()
	add_child(loadout)
	loadout.set_physics_process(false)
	var records := DataRegistry.get_table("weapons")
	for scene in ["res://scenes/ui/esc/esc_overlay.tscn", "res://scenes/ui/shop/shop_popup.tscn"]:
		var popup := load(scene).instantiate() as Control
		add_child(popup)
		popup.show()
		var strip := popup.get_node("WeaponStrip") as WeaponStrip
		var scroll := strip.weapon_list.get_parent() as ScrollContainer
		for dimensions in [Vector2i(1920, 1080), Vector2i(960, 540)]:
			get_window().size = dimensions
			get_window().content_scale_size = dimensions
			for count in [0, 6, 14]:
				loadout.weapon_instances.clear()
				for i in count:
					var weapon := WeaponInstance.new()
					weapon.initialize(str(records[i].id), null)
					loadout.weapon_instances.append(weapon)
				strip.set_loadout(loadout, false, true)
				await frames()
				var label := "%s %s count=%d" % [popup.name, dimensions, count]
				check(strip.size.y >= strip.get_required_height(), "strip reserves its required height: " + label)
				var usable_height := scroll.size.y
				if scroll.get_h_scroll_bar().visible: usable_height -= scroll.get_h_scroll_bar().size.y
				check(usable_height >= strip.weapon_list.get_combined_minimum_size().y, "complete icons fit above horizontal scrollbar: " + label)
				check(not scroll.get_v_scroll_bar().visible and scroll.scroll_vertical == 0, "row never scrolls vertically: " + label)
				var panel := strip.get_node("StripPanel") as Control
				if count > 0:
					var first := strip._weapon_buttons[0].get_global_rect()
					var bounds := panel.get_global_rect()
					var top := first.position.y - bounds.position.y
					var bottom := bounds.end.y - first.end.y
					var left := first.position.x - bounds.position.x
					var right := bounds.end.x - strip.load_label.get_global_rect().end.x
					check(absf(top - bottom) <= 1, "weapon slots remain vertically centered: " + label)
					check(absf(top - left) <= 1 and absf(top - right) <= 1, "equal padding on all four sides: " + label)
				var content := popup.get_node("CenterContainer") as Control
				check(content.global_position.y >= panel.get_global_rect().end.y + 14, "taller strip keeps clear of modal content: " + label)
				if count == 14:
					check(scroll.get_h_scroll_bar().visible, "many weapons remain horizontally scrollable: " + label)
					scroll.ensure_control_visible(strip._weapon_buttons[-1])
					await frames()
					var last := strip._weapon_buttons[-1].get_global_rect()
					check(scroll.get_global_rect().encloses(last), "last weapon can be fully revealed: " + label)
					check(scroll.scroll_vertical == 0, "revealing last weapon preserves vertical baseline: " + label)
					if not output.is_empty() and DisplayServer.get_name() != "headless":
						DirAccess.make_dir_recursive_absolute(output)
						await RenderingServer.frame_post_draw
						get_viewport().get_texture().get_image().save_png(output.path_join("%s_%d.png" % [popup.name, dimensions.x]))
		popup.queue_free()
		await frames()
	loadout.queue_free()
	await frames()
	CampProgression.end_transient_session()
	print("WEAPON_STRIP_LAYOUT checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
