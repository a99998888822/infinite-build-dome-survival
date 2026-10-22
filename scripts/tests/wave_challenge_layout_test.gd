extends Node
## Native artwork stays fixed while text, locale and viewport change.
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 4) -> void:
	for i in count: await get_tree().process_frame

func _ready() -> void:
	WindowSettings._startup_applied = true
	_run.call_deferred()

func _run() -> void:
	var old_locale := L10n.locale
	var layer := CanvasLayer.new()
	add_child(layer)
	var page := WaveChallengePopup.new()
	layer.add_child(page)
	page.presentation.sound_enabled = false
	var challenges := WaveChallengeSystem.new()
	for locale in ["zh_CN", "en"]:
		L10n.set_locale(locale, false)
		for viewport in [Vector2i(1920,1080), Vector2i(1152,768), Vector2i(640,360), Vector2i(320,240)]:
			get_window().size = viewport
			get_window().content_scale_size = viewport
			for definition: Dictionary in challenges.config.challenges:
				var payload := definition.duplicate(true)
				payload.wave = 12
				page.present(payload)
				page.presentation.set_process(false)
				page.presentation.seek(4.6)
				await frames()
				var p := page.presentation
				var tag := "%s %s %s" % [locale, str(viewport), str(payload.id)]
				check(page.portrait.size == Vector2(372,372) and p.get_global_transform().get_scale() == Vector2.ONE, "native portrait " + tag)
				check(p._seal.get_global_rect().size == Vector2(32,32), "native icon " + tag)
				check(p._speech_tail.get_global_rect().size == Vector2(18,12), "native speech tail " + tag)
				check(not page.portrait.get_global_rect().intersects(p._speech.get_global_rect()), "speech clears portrait " + tag)
				check(not p._speech.get_global_rect().intersects(p._card.get_global_rect()), "speech clears card " + tag)
				check(p._title.position.y + p._title.size.y + 12 <= p._body_scroll.position.y, "header clears body " + tag)
				check(p._yes.size.y >= p._yes.get_combined_minimum_size().y, "button text fits " + tag)
				check(page._scroll.get_global_rect().position.is_equal_approx(page._scroll.get_global_rect().position.round()), "integer pixel placement " + tag)
				check(page._content.get_global_rect().encloses(page._back.get_global_rect()), "back within scroll content " + tag)
				page._scroll.ensure_control_visible(p._no)
				await frames(2)
				check(page._scroll.get_global_rect().encloses(p._no.get_global_rect()), "decline reachable " + tag)
				page._scroll.ensure_control_visible(p._yes)
				await frames(2)
				check(page._scroll.get_global_rect().encloses(p._yes.get_global_rect()), "accept reachable " + tag)
				if viewport.x >= 1000:
					check(page._scroll.scroll_vertical == 0 and page._scroll.scroll_horizontal == 0, "standard layout fully visible " + tag)
	page.queue_free()
	await frames()
	L10n.set_locale(old_locale, false)
	print("WAVE_CHALLENGE_LAYOUT_COMPLETE checks=%d failures=%d" % [checks,failures])
	get_tree().quit(1 if failures else 0)
