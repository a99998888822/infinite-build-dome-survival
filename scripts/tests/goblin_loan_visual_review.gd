extends Node
## Art / UI review only. Fixture money never leaves a transient session.

const MOCKUP = preload("res://scripts/tests/fixtures/goblin_loan_visual_mockup.gd")
var game: GameRoot
var popup: FinancePopup
var manager: WaveManager
var controller: FinanceUIController
var mock: Control
var output := ""
var movie_dir := ""
var interactive := false
var failures := 0


func _ready() -> void:
	WindowSettings._startup_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output=arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--movie-dir="): movie_dir=arg.trim_prefix("--movie-dir=")
		if arg == "--interactive": interactive=true
	_run.call_deferred()


func frames(count := 4) -> void:
	for i in count: await get_tree().process_frame


func _run() -> void:
	CampProgression.begin_transient_session()
	seed(9282026)
	game = load("res://scenes/core/game_root.tscn").instantiate() as GameRoot
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	game.get_node("UiRoot/MainMenuUIController").hide()
	print("LOAN_REVIEW_STAGE game initialized")
	await frames(12)
	var window := get_tree().root
	window.mode = Window.MODE_WINDOWED
	window.size = Vector2i(1152,768)
	window.content_scale_size = window.size
	var flow := game.get_main_flow_coordinator()
	flow.enter_battle_selection("character_void_hunter",["weapon_void_blade"])
	await frames()
	flow.confirm_character_selection()
	print("LOAN_REVIEW_STAGE combat fixture")
	await frames(8)
	manager = flow._bound_wave_manager
	manager.set_process(false)
	manager.player.set_physics_process(false)
	manager.clear_enemies()
	manager.finance_system.deposit(800,true,"review_fixture")
	flow.finish_current_wave()
	print("LOAN_REVIEW_STAGE opening bank")
	await frames(12)
	manager.goblin_trades.cancel()
	controller = game.find_child("FinanceUIController",true,false) as FinanceUIController
	popup = controller.finance_popup
	popup.cancel_trade("rejected")
	popup.interest_arrival.stop()
	popup._tooltip.hide()
	_set_wallet(18)
	await frames()
	controller.set_process(false)
	AudioManager.stop_bgm()
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	mock = MOCKUP.new()
	layer.add_child(mock)
	mock.attach(popup,popup._safe_rect)
	mock.preview_accepted.connect(func(amount): _set_wallet(manager.current_gold+amount))
	mock.preview_repaid.connect(func(amount): _set_wallet(manager.current_gold-amount))
	if interactive: return
	mock.animate = false
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	if not movie_dir.is_empty(): DirAccess.make_dir_recursive_absolute(movie_dir)
	var principal_before := manager.finance_system.principal
	var first := _disabled_button()
	_check(first != null,"fixture contains a genuinely disabled purchase button")
	if first != null:
		for i in 3:
			var event := InputEventMouseButton.new()
			event.button_index=MOUSE_BUTTON_LEFT
			event.pressed=true
			event.position=first.get_global_rect().get_center()
			mock._input(event)
			_check(mock._modal.visible == (i==2),"preview reveal after click %d" % (i+1))
	mock.show_quote()
	mock.seek(2)
	await frames()
	_validate_layout()
	await capture("loan_popup")
	mock.dismiss_quote()
	await capture("state_available")
	mock.show_state("borrowed",500,600,518)
	_set_wallet(518)
	await capture("state_borrowed")
	mock.show_state("compound",500,720,80)
	_set_wallet(80)
	await capture("state_compound")
	mock.show_state("ready",500,720,800)
	_set_wallet(800)
	await capture("state_ready")
	_check(not mock.repay.disabled,"repay is a small active button when the sample wallet covers debt")
	var metadata := {"bank_rect":[mock.base_rect.position.x,mock.base_rect.position.y,mock.base_rect.size.x,mock.base_rect.size.y],
		"strip_rect":[mock._strip.position.x,mock._strip.position.y,mock._strip.size.x,mock._strip.size.y]}
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("layout.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(metadata,"  "))
	await _resize(Vector2i(640,360))
	_set_wallet(18)
	mock.show_state("available")
	mock.show_quote()
	mock.seek(2)
	await frames()
	_validate_layout()
	await capture("loan_small")
	mock.show_state("compound",500,720,80)
	_set_wallet(80)
	await frames()
	_check(popup.main_panel.get_global_rect().encloses(mock._strip.get_global_rect()),"small bank contains the persistent loan strip")
	await capture("loan_small_hud")
	await _resize(Vector2i(360,640))
	_set_wallet(18)
	mock.show_state("available")
	mock.show_quote()
	mock.seek(2)
	await frames()
	_validate_layout()
	await capture("loan_portrait")
	if not movie_dir.is_empty():
		await _resize(Vector2i(1152,768))
		await _movie()
	_check(manager.finance_system.principal==principal_before,"visual states do not withdraw or change real principal")
	print("GOBLIN_LOAN_VISUAL_COMPLETE failures=",failures)
	game.queue_free()
	AudioManager.stop_bgm()
	await frames(8)
	get_tree().quit(1 if failures else 0)


func _set_wallet(amount: int) -> void:
	manager.apply_gold_delta(amount-manager.current_gold,"review_fixture")
	if popup != null:
		popup.payload.gold=amount
		popup.configure(popup.payload)
		popup.interest_arrival.stop()
		popup.cancel_trade("rejected")
		if mock != null: mock.arrange_bank()


func _resize(bounds: Vector2i) -> void:
	get_tree().root.size=bounds
	get_tree().root.content_scale_size=bounds
	await frames(6)
	controller._apply_safe_rect(true)
	mock.base_rect=popup._safe_rect
	mock.arrange_bank()
	mock._layout_modal()
	await frames()


func _disabled_button() -> Button:
	for card: PreparationOfferCard in popup.shop_grid._pool:
		if card.is_visible_in_tree() and card.buy_button.disabled and int(card.offer.get("shop_cost",0))>manager.current_gold:
			return card.buy_button
	return null


func _validate_layout() -> void:
	var screen := get_viewport().get_visible_rect()
	_check(screen.encloses(mock._box.get_global_rect()),"loan modal fits viewport "+str(screen.size))
	for entry: Dictionary in mock._cards:
		_check(mock._box.get_global_rect().encloses(entry.panel.get_global_rect()),"loan card inside modal")
		_check(entry.panel.get_global_rect().encloses(entry.button.get_global_rect()) and not entry.button.disabled,"loan choice visible and immediately enabled")
	_check(mock._speech.text==mock.SPEECH,"approved dialogue retained verbatim")


func _check(ok: bool, label: String) -> void:
	if not ok: failures+=1
	print("PASS " if ok else "FAIL ",label)


func capture(name: String) -> void:
	await frames()
	if output.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var error := get_tree().root.get_texture().get_image().save_png(output.path_join(name+".png"))
	_check(error==OK,"capture "+name)


func _movie() -> void:
	mock.show_state("hidden",500,600,18)
	mock.automatic_shown=false
	mock.clicks=0
	_set_wallet(18)
	await frames()
	var button := _disabled_button()
	var click_at := button.get_global_rect().get_center() if button != null else Vector2(450,300)
	for frame in 240:
		var t := float(frame)/20.0
		if frame==20: mock.show_quote()
		if frame==72: mock.dismiss_quote()
		if frame==94: mock.show_quote()
		if frame==140:
			mock._choose(2)
			_set_wallet(518)
		if frame==172:
			mock.show_state("compound",500,720,80)
			_set_wallet(80)
		if frame==204:
			mock.show_state("ready",500,720,800)
			_set_wallet(800)
		if frame==224: mock._repay()
		if frame<20:
			mock.cursor(click_at,fmod(t,0.3)/0.3)
		elif frame<72:
			mock.seek(t-1.0)
			mock.cursor(Vector2(-100,-100))
		elif frame<94:
			mock.cursor(mock.reopen.get_global_rect().get_center(),-1)
		elif frame<140:
			mock.seek(t-4.7)
			mock.cursor(mock._cards[2].button.get_global_rect().get_center(),-1)
		else:
			mock.cursor(mock.repay.get_global_rect().get_center() if frame>=204 and frame<224 else Vector2(-100,-100))
		popup.portrait.set_process(false)
		popup.portrait._elapsed=t
		popup.portrait.expression=3 if frame<172 else 0
		popup.portrait.queue_redraw()
		if DisplayServer.get_name()=="headless":
			await frames(1)
		else:
			await RenderingServer.frame_post_draw
			var error := get_tree().root.get_texture().get_image().save_png(movie_dir.path_join("frame_%04d.png" % frame))
			if error!=OK:
				failures+=1
				return
