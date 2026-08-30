extends Node

signal bgm_changed(bgm_id: String)

const BUS_MASTER: String = "Master"
const BUS_BGM: String = "BGM"
const BUS_SFX: String = "SFX"
const BGM_PLAYBACK_GAIN_DB: float = 12.0
const VOLUME_SETTING_BY_BUS: Dictionary = {
	"Master": "master_volume",
	"BGM": "bgm_volume",
	"SFX": "sfx_volume",
}
const UI_SFX_PATHS: Dictionary = {
	"modal_open": "res://assets/audio/sfx/ui/sfx_ui_modal_open.ogg",
	"modal_close": "res://assets/audio/sfx/ui/sfx_ui_modal_close.ogg",
	"confirm": "res://assets/audio/sfx/ui/sfx_ui_confirm.ogg",
	"zone_select": "res://assets/audio/sfx/ui/sfx_ui_zone_select.ogg",
	"reward_reveal": "res://assets/audio/sfx/ui/sfx_ui_reward_reveal.ogg",
	"interest_reveal": "res://assets/audio/sfx/finance/sfx_interest_settle.ogg",
	"purchase_success": "res://assets/audio/sfx/ui/sfx_ui_purchase_success.ogg",
	"purchase_error": "res://assets/audio/sfx/ui/sfx_ui_purchase_error.ogg",
}
const DEFAULT_BGM_PATHS: Dictionary = {
	"menu": "res://assets/audio/bgm/bgm_menu.ogg",
	"camp": "res://assets/audio/bgm/bgm_menu.ogg",
	"battle": "res://assets/audio/bgm/bgm_battle.ogg",
}

var current_bgm_id: String = ""
var _bgm_player: AudioStreamPlayer = null
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor: int = 0
var _last_sfx_time_ms: Dictionary = {}


func _ready() -> void:
	_ensure_bus(BUS_BGM)
	_ensure_bus(BUS_SFX)
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BgmPlayer"
	_bgm_player.bus = BUS_BGM
	_bgm_player.volume_db = BGM_PLAYBACK_GAIN_DB
	add_child(_bgm_player)
	for index in range(8):
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % index
		player.bus = BUS_SFX
		add_child(player)
		_sfx_players.append(player)
	_apply_saved_volume_settings()


func play_bgm(bgm_id: String) -> bool:
	var sanitized_id := bgm_id.strip_edges()
	if sanitized_id.is_empty() or _bgm_player == null:
		return false
	if sanitized_id == current_bgm_id:
		if not _bgm_player.playing:
			_bgm_player.play()
		return true
	var path := str(DEFAULT_BGM_PATHS.get(sanitized_id, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		current_bgm_id = sanitized_id
		_bgm_player.stop()
		bgm_changed.emit(sanitized_id)
		return false
	var stream := load(path) as AudioStream
	if stream == null:
		return false
	_bgm_player.stream = stream
	_bgm_player.play()
	current_bgm_id = sanitized_id
	bgm_changed.emit(sanitized_id)
	return true


func stop_bgm() -> void:
	if _bgm_player != null:
		_bgm_player.stop()
	current_bgm_id = ""


func play_exp_orb_collect_sfx() -> bool:
	return play_sfx_path("res://assets/audio/sfx/pickups/sfx_exp_orb_collect.ogg", 35, "exp_orb_collect")


func play_wave_end_sfx() -> bool:
	return play_sfx_path("res://assets/audio/sfx/ui/sfx_wave_end_safe.ogg", 0, "wave_end_safe")


func play_ui_sfx(sfx_id: String, minimum_interval_ms: int = 45) -> bool:
	var path := str(UI_SFX_PATHS.get(sfx_id.strip_edges(), ""))
	if path.is_empty():
		return false
	return play_sfx_path(path, minimum_interval_ms, "ui_" + sfx_id.strip_edges())


func play_weapon_hit_sfx(weapon_id: String, minimum_interval_ms: int = 0) -> bool:
	var weapon_data := DataRegistry.get_record("weapons", weapon_id)
	return play_sfx_path(str(weapon_data.get("hit_sfx", "")), minimum_interval_ms, weapon_id)


func play_sfx_path(resource_path: String, minimum_interval_ms: int = 0, dedupe_key: String = "") -> bool:
	if resource_path.is_empty() or not ResourceLoader.exists(resource_path) or _sfx_players.is_empty():
		return false
	var key := dedupe_key if not dedupe_key.is_empty() else resource_path
	var now_ms := Time.get_ticks_msec()
	if minimum_interval_ms > 0 and now_ms - int(_last_sfx_time_ms.get(key, -minimum_interval_ms)) < minimum_interval_ms:
		return false
	var stream := load(resource_path) as AudioStream
	if stream == null:
		return false
	var player := _sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	player.stream = stream
	player.play()
	_last_sfx_time_ms[key] = now_ms
	return true


func set_bus_volume(bus_name: String, volume_percent: int, persist: bool = true) -> void:
	_apply_bus_volume(bus_name, volume_percent)
	if not persist:
		return
	var setting_key := str(VOLUME_SETTING_BY_BUS.get(bus_name, ""))
	if setting_key.is_empty():
		return
	CampProgression.set_volume_setting(setting_key, volume_percent)


func _apply_saved_volume_settings() -> void:
	_apply_bus_volume(BUS_MASTER, CampProgression.get_volume_setting("master_volume", 100))
	_apply_bus_volume(BUS_BGM, CampProgression.get_volume_setting("bgm_volume", 100))
	_apply_bus_volume(BUS_SFX, CampProgression.get_volume_setting("sfx_volume", 100))


func _apply_bus_volume(bus_name: String, volume_percent: int) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var clamped_percent := clampi(volume_percent, 0, 100)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(float(clamped_percent) / 100.0) if clamped_percent > 0 else -80.0)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
