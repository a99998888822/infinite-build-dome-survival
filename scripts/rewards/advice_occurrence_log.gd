extends RefCounted
class_name AdviceOccurrenceLog
## Small cumulative log beside the profile; run-owned advice state deduplicates events.

const SAVE_PATH := "user://saves/trade_challenge_counts.csv"
const HEADER := ["类别", "ID", "项目", "出现", "选择"]
const CATALOGS := {"trade": "res://data_config/goblin_trades.json", "challenge": "res://data_config/wave_challenges.json"}
const LABELS := {
	"strong_refresh": "强力刷新", "principal_advance": "本金援助", "cash_price": "应急金币",
	"interest_pact": "利率契约", "spending_money": "零花钱", "exclusive_relic": "专属遗物",
	"weapon_buyout": "武器收购", "sanity_buyback": "理智回购", "preferred_customer": "熟客折扣",
	"capital_protection": "本金护身", "extra_elites": "额外精英", "rising_tide": "风浪收益",
	"all_in": "全额存款", "business_expansion": "生意扩张", "fleeting_fortune": "限时金币",
	"capital_custody": "本金保险箱", "paid_overtime": "加班报酬", "debt_hunter": "债务猎手",
}

var storage_path := SAVE_PATH


func record(kind: String, offer_id: String, selected: bool) -> void:
	if not CATALOGS.has(kind) or offer_id.is_empty(): return
	if storage_path == SAVE_PATH and (Engine.is_editor_hint() or CampProgression._transient_session_active): return
	var rows := _empty_rows()
	if not _read(rows): return
	var key := kind + ":" + offer_id
	if not rows.has(key): return
	var row: Dictionary = rows[key]
	if selected: row.selected += 1
	else: row.appeared += 1
	_write(rows)


func _empty_rows() -> Dictionary:
	var rows := {}
	for kind in CATALOGS:
		var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOGS[kind]))
		for entry in config.get("trades" if kind == "trade" else "challenges", []):
			var id := str(entry.id)
			rows[kind + ":" + id] = {"kind": kind, "id": id, "name": str(LABELS.get(id, id)), "appeared": 0, "selected": 0}
	return rows


func _read(rows: Dictionary) -> bool:
	if not FileAccess.file_exists(storage_path): return true
	var file := FileAccess.open(storage_path, FileAccess.READ)
	if file == null:
		push_warning("Cannot read advice counts: " + storage_path)
		return false
	if file.get_csv_line() != PackedStringArray(HEADER):
		push_warning("Invalid advice counts header; existing log preserved: " + storage_path)
		return false
	while not file.eof_reached():
		var fields := file.get_csv_line()
		if fields.size() == 1 and fields[0].is_empty(): continue
		if fields.size() != 5 or fields[0] not in ["交易", "挑战"] or not fields[3].is_valid_int() or not fields[4].is_valid_int():
			push_warning("Invalid advice counts row; existing log preserved: " + storage_path)
			return false
		var kind := "trade" if fields[0] == "交易" else "challenge"
		var key := kind + ":" + fields[1]
		# Keep historical rows even if a future version retires an offer.
		if not rows.has(key): rows[key] = {"kind": kind, "id": fields[1], "name": fields[2]}
		rows[key].appeared = maxi(0, int(fields[3]))
		rows[key].selected = maxi(0, int(fields[4]))
	return true


func _write(rows: Dictionary) -> void:
	var directory := ProjectSettings.globalize_path(storage_path).get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_warning("Cannot create advice log directory: " + directory)
		return
	var temporary := storage_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_warning("Cannot write advice counts: " + temporary)
		return
	file.store_csv_line(PackedStringArray(HEADER))
	for row: Dictionary in rows.values():
		file.store_csv_line(PackedStringArray(["交易" if row.kind == "trade" else "挑战", row.id, row.name, str(row.appeared), str(row.selected)]))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(temporary, storage_path) != OK:
		push_warning("Cannot replace advice counts; previous log preserved: " + storage_path)
