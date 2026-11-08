extends Node
## Payout table for the early-death compensation and the unchanged victory line.
## Runs only the production settlement formula and its production panel.

const CASES := [
	{"label": "第1波早死 40击杀/60金", "kills": 40, "gold": 60, "waves": 0, "interest": 0, "victory": false, "difficulty": "1"},
	{"label": "第2波 100击杀/160金/1波", "kills": 100, "gold": 160, "waves": 1, "interest": 10, "victory": false, "difficulty": "1"},
	{"label": "第4波 300击杀/500金/3波", "kills": 300, "gold": 500, "waves": 3, "interest": 60, "victory": false, "difficulty": "1"},
	{"label": "第8波 900击杀/1800金/7波", "kills": 900, "gold": 1800, "waves": 7, "interest": 240, "victory": false, "difficulty": "1"},
	{"label": "第12波 1800击杀/4000金/11波", "kills": 1800, "gold": 4000, "waves": 11, "interest": 500, "victory": false, "difficulty": "1"},
	{"label": "通关16波 3000击杀/8000金", "kills": 3000, "gold": 8000, "waves": 16, "interest": 900, "victory": true, "difficulty": "1"},
	{"label": "第1波早死（难度3）", "kills": 40, "gold": 60, "waves": 0, "interest": 0, "victory": false, "difficulty": "3"},
	{"label": "通关16波（难度3）", "kills": 3000, "gold": 8000, "waves": 16, "interest": 900, "victory": true, "difficulty": "3"},
]

var output := ""
var checks := 0
var failures := 0
var rows: Array[Dictionary] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func frames(count := 4) -> void:
	for i in count: await get_tree().process_frame


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)


func _run() -> void:
	CampProgression.begin_transient_session()
	L10n.set_locale("zh_CN", false)
	var panel: RunSettlementPanel = null
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		panel = _make_panel()
	var early_now := 0
	var early_legacy := 0
	var clear_now := 0
	for entry in CASES:
		var stats := {"run_id": "payout_" + str(rows.size()), "kills": int(entry.kills), "gold": int(entry.gold),
			"waves": int(entry.waves), "interest": int(entry.interest), "has_advice": false}
		var report := RunSettlement.build(stats, bool(entry.victory), str(entry.difficulty))
		var base := int(report.base_camp_currency)
		var multiplier := float(report.reward_multiplier)
		var legacy := roundi(float(base) * multiplier)
		var row := {"label": String(entry.label), "base": base, "multiplier": multiplier,
			"compensation": int(report.compensation), "legacy": legacy, "current": int(report.camp_currency),
			"victory": bool(report.victory), "difficulty": String(entry.difficulty)}
		rows.append(row)
		print("PAYOUT %s | base=%d x%.2f | legacy=%d | compensation=%d | now=%d" % [row.label, base, multiplier, legacy, row.compensation, row.current])
		if String(entry.label).begins_with("第1波早死 40"):
			early_legacy = legacy
			early_now = int(report.camp_currency)
			check(int(report.compensation) > 0 and int(report.camp_currency) >= 150, "first-wave death now pays at least 150 points")
		if String(entry.label) == "通关16波 3000击杀/8000金":
			clear_now = int(report.camp_currency)
			check(int(report.camp_currency) == legacy, "late victory payout is unchanged")
		if entry.victory:
			check(int(report.compensation) == 0, "victory never receives defeat compensation: " + str(entry.label))
		if int(entry.waves) >= 10:
			check(int(report.compensation) == 0, "compensation ends for waves ten and later: " + str(entry.label))
		if not output.is_empty() and panel != null:
			report["paid"] = true
			panel.present(report)
			panel.seek(30)
			await frames(3)
			await capture(panel, "payout_" + str(rows.size()))
	check(early_now >= 150 and early_legacy < 20 and clear_now > early_now, "early death rises sharply and stays far below a late clear")
	_report()
	if panel != null: panel.queue_free()
	await frames(2)
	CampProgression.end_transient_session()
	print("SETTLEMENT_PAYOUT_REVIEW checks=%d failures=%d rows=%d" % [checks, failures, rows.size()])
	get_tree().quit(0 if failures == 0 else 1)


func _make_panel() -> RunSettlementPanel:
	var layer := CanvasLayer.new()
	layer.layer = 95
	add_child(layer)
	var panel := RunSettlementPanel.new()
	panel.sound_enabled = false
	panel.set_process(false)
	layer.add_child(panel)
	return panel


func capture(panel: RunSettlementPanel, name: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "GPU " + name + " " + panel._conversion.text)


func _report() -> void:
	if output.is_empty(): return
	var file := FileAccess.open(output.path_join("payout_review.json"), FileAccess.WRITE)
	var config := RunSettlement.configuration()
	file.store_string(JSON.stringify({"formula": config.get("formula", {}), "rows": rows}, "\t"))
