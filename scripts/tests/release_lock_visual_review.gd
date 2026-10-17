extends Node
## Candidate-only menus with actual production layout; no persistent unlock edits.
const PREVIEW = preload("res://scripts/tests/reviews/release_lock_preview.gd")
var output := ""
var checks := 0
var failures: Array[String] = []
var captures: Array[String] = []


func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	run.call_deferred()


func frames(count := 5) -> void:
	for i in count: await get_tree().process_frame


func check(ok: bool, note: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", note)
	if not ok: failures.append(note)


func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await frames()
	await RenderingServer.frame_post_draw
	var result := get_tree().root.get_texture().get_image().save_png(output.path_join(name+".png"))
	check(result==OK,"saved "+name)
	captures.append(name+".png")


func run() -> void:
	if output.is_empty() or not OS.get_cmdline_user_args().has("--transient-session"):
		get_tree().quit(2)
		return
	if DisplayServer.get_name()!="headless" and not OS.get_cmdline_user_args().has("--background-capture"):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	get_tree().root.unfocusable = true
	get_tree().root.size = Vector2i(1920,1080)
	CampProgression.begin_transient_session()
	# A disposable level-2 sample shows the existing upgrade rows for context.
	CampProgression.state.building_levels["camp_armory_workshop"] = 2
	CampProgression.state.building_levels["camp_dome_shelter"] = 2
	CampProgression.set_camp_currency(1200)
	var game := load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await frames(20)
	var menu := game.get_node("UiRoot/MainMenuUIController") as MainMenuUIController
	menu._on_talents_pressed()
	await frames(25)
	var talents := game.get_node("UiRoot/CampBlueprintUIController") as CampBlueprintUIController
	check(talents.visible,"actual talent page opened")
	await get_tree().create_timer(.8).timeout
	await capture("01_talents_before_1920")
	PREVIEW.apply_talents(talents)
	await frames()
	var available := 0
	var locked := 0
	for row in talents._building_list.get_children():
		if row.disabled: locked += 1
		else: available += 1
	check(available==2 and locked==4,"two talent facilities available, four gray")
	check(str(talents._building_list.get_child(1).get_meta("building_id"))=="camp_dome_shelter" and not talents._building_list.get_child(1).disabled,"shelter is available in second position")
	check(str(talents._building_list.get_child(4).get_meta("building_id"))=="camp_relic_archive" and talents._building_list.get_child(4).disabled,"archive replaces shelter in fifth position and is release-locked")
	await capture("02_talents_preview_1920")
	talents._on_back_pressed()
	await frames()
	menu._on_start_battle_pressed()
	await get_tree().create_timer(.5).timeout
	var view := menu.character_view
	view.reset_animation()
	view.set_process(false)
	await capture("03_characters_before_1920")
	var portraits := PREVIEW.apply_roster(view)
	await frames(10)
	check(not (view.character_list.get_child(0) as Button).disabled and (view.character_list.get_child(1) as Button).disabled,"beginner available and capitalist gray")
	check(view.character_list.get_child_count()==10,"two known characters plus eight full-width silhouette rows")
	var capitalist := view.character_list.get_child(1) as Button
	for i in range(2,10):
		var card := view.character_list.get_child(i) as Button
		check(card.size==capitalist.size and card.get_theme_stylebox("disabled")==capitalist.get_theme_stylebox("disabled"),"same dimensions and frame as capitalist: "+str(i))
		check(card.text.is_empty() and not card.has_node("CharacterName") and card.has_node("SilhouettePortrait"),"silhouette portrait without character name: "+str(i))
	for i in portraits.size(): portraits[i].get_image().save_png(output.path_join("silhouette_%02d.png" % (i+1)))
	await capture("04_characters_preview_1920")
	view.roster_scroll.scroll_vertical = int(view.roster_scroll.get_v_scroll_bar().max_value)
	await frames()
	# Ignore float roundoff at the shared bottom edge after uniform UI scaling.
	check(view.roster_scroll.get_global_rect().grow(.01).encloses((view.character_list.get_child(9) as Control).get_global_rect()),"last silhouette fully reachable by scrolling")
	await capture("05_characters_scrolled_1920")
	view.roster_scroll.scroll_vertical = 0
	get_tree().root.size = Vector2i(1280,720)
	await frames(10)
	check(view.roster_scroll.get_global_rect().encloses(capitalist.get_global_rect()),"capitalist frame stays in bounds at 1280x720")
	await capture("06_characters_preview_1280")
	view.roster_scroll.scroll_vertical = int(view.roster_scroll.get_v_scroll_bar().max_value)
	await frames()
	check(view.roster_scroll.get_global_rect().grow(.01).encloses((view.character_list.get_child(9) as Control).get_global_rect()),"last silhouette fully reachable at 1280x720")
	FileAccess.open(output.path_join("verification.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"candidate_only":true,"note":"R02: shelter and archive swap positions; archive release-locked. Eight unnamed silhouettes share the capitalist row frame. Temporary level-2 armory and shelter demonstrate upgrade content; save data and production unlock rules are untouched."},"\t"))
	game.queue_free()
	await frames(8)
	AudioManager.stop_bgm()
	AudioManager.stop_combat_sfx()
	for audio in AudioManager.get_children():
		if audio is AudioStreamPlayer:
			audio.stop()
			audio.stream = null
	CampProgression.end_transient_session()
	print("RELEASE_LOCK_VISUAL_REVIEW checks=",checks," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
