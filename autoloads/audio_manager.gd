extends Node

signal bgm_changed(bgm_id: String)
signal combat_sfx_played(cue_id: String, resource_path: String)

const BUS_MASTER: String = "Master"
const BUS_BGM: String = "BGM"
const BUS_SFX: String = "SFX"
const BUS_COMBAT: String = "CombatSFX"
const COMBAT_LIBRARY = preload("res://scripts/audio/combat_sound_library.gd")
const AUDIO_IMPACT_SCRIPT = preload("res://scripts/audio/combat_audio_impact.gd")
const REACTION_WEAPON_GAIN_DB: float = -5.0
const MAX_PENDING_AUDIO_IMPACTS: int = 256
const COMBAT_VOICES: int = 12
const COMBAT_DETAIL_VOICES: int = 8
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
var _combat_players: Array[AudioStreamPlayer] = []
var _combat_last_ms: Dictionary = {}
var _combat_last_variant: Dictionary = {}
var _combat_bursts: Dictionary = {}
var _combat_clock_ms: float = 0.0
var _combat_rng := RandomNumberGenerator.new()
var _audio_impact_stack: Array[RefCounted] = []
var _pending_audio_impacts: Array[RefCounted] = []


func _ready() -> void:
	# Resolve scheduled strikes before choosing the sound for each contact.
	process_priority = 1000
	_ensure_bus(BUS_BGM)
	_ensure_bus(BUS_SFX)
	_ensure_combat_audio()
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


func _ensure_combat_audio() -> void:
	_ensure_bus(BUS_COMBAT)
	var bus_index := AudioServer.get_bus_index(BUS_COMBAT)
	AudioServer.set_bus_send(bus_index, BUS_SFX)
	# This bus contains only combat one-shots; UI and music retain their mix.
	if AudioServer.get_bus_effect_count(bus_index) == 0:
		var compressor := AudioEffectCompressor.new()
		compressor.threshold = -12.0
		compressor.ratio = 4.0
		compressor.attack_us = 1500.0
		compressor.release_ms = 100.0
		AudioServer.add_bus_effect(bus_index, compressor)
		var limiter := AudioEffectLimiter.new()
		limiter.ceiling_db = -2.0
		AudioServer.add_bus_effect(bus_index, limiter)
	_combat_rng.randomize()
	for index in range(COMBAT_VOICES):
		var player := AudioStreamPlayer.new()
		player.name = "CombatSfx%d" % index
		player.bus = BUS_COMBAT
		add_child(player)
		_combat_players.append(player)


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		# Discard short tails on opening a panel; never replay stale impacts.
		stop_combat_sfx()
		return
	_combat_clock_ms += delta * 1000.0
	flush_combat_audio()


func stop_combat_sfx() -> void:
	for impact in _pending_audio_impacts:
		impact.requests.clear()
		impact.queued = false
	_pending_audio_impacts.clear()
	for player in _combat_players:
		if player.playing:
			player.stop()


func begin_combat_audio(impact: RefCounted = null) -> RefCounted:
	if impact == null:
		impact = current_combat_audio()
	if impact == null:
		impact = AUDIO_IMPACT_SCRIPT.new()
	_audio_impact_stack.append(impact)
	return impact


func current_combat_audio() -> RefCounted:
	return _audio_impact_stack.back() if not _audio_impact_stack.is_empty() else null


func end_combat_audio() -> void:
	assert(not _audio_impact_stack.is_empty(), "Unbalanced combat audio scope")
	_audio_impact_stack.pop_back()


func mark_combat_reaction(reaction_id: String) -> void:
	var impact := current_combat_audio()
	if impact != null:
		impact.mark_reaction(reaction_id)


func flush_combat_audio(force: bool = false) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		stop_combat_sfx()
		return
	if not _audio_impact_stack.is_empty():
		return
	var pending := _pending_audio_impacts
	_pending_audio_impacts = []
	for impact in pending:
		# One render-frame grace includes call_deferred arms and first chain
		# strikes without delaying damage, visuals, or the effect scheduler.
		if not force and int(impact.request_frame) >= Engine.get_process_frames():
			_pending_audio_impacts.append(impact)
			continue
		impact.queued = false
		var requests: Dictionary = impact.requests.duplicate(true)
		impact.requests.clear()
		# Preserve the weapon cue first, then reactions, then unrelated details.
		for order in range(3):
			for cue: String in requests:
				var request: Dictionary = requests[cue]
				var is_weapon := bool(request.is_weapon)
				var cue_order := 0 if is_weapon else (1 if cue.begins_with("reaction_") else 2)
				if cue_order != order or impact.suppressed_cues.has(cue):
					continue
				var gain := REACTION_WEAPON_GAIN_DB if is_weapon and impact.has_reaction else 0.0
				_play_combat_sfx_now(cue, int(request.interval_ms), gain)


func _request_combat_sfx(cue_id: String, minimum_interval_ms: int, is_weapon: bool) -> bool:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)) or not COMBAT_LIBRARY.PROFILES.has(cue_id):
		return false
	var impact := current_combat_audio()
	if impact == null:
		return _play_combat_sfx_now(cue_id, minimum_interval_ms)
	if not impact.queued:
		if _pending_audio_impacts.size() >= MAX_PENDING_AUDIO_IMPACTS:
			return false
		impact.queued = true
		impact.request_frame = Engine.get_process_frames()
		_pending_audio_impacts.append(impact)
	impact.request(cue_id, minimum_interval_ms, is_weapon)
	return true # Accepted for arbitration, not necessarily played under saturation.


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
	var cue := str(weapon_data.get("hit_sfx_cue", ""))
	if not cue.is_empty():
		return _request_combat_sfx(cue, minimum_interval_ms, true)
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return false
	return play_sfx_path(str(weapon_data.get("hit_sfx", "")), minimum_interval_ms, weapon_id)


func play_enchantment_sfx(enchantment_id: String) -> bool:
	return play_combat_sfx(enchantment_id.strip_edges())


func play_reaction_sfx(reaction_id: String) -> bool:
	mark_combat_reaction(reaction_id.strip_edges())
	return play_combat_sfx("reaction_" + reaction_id.strip_edges())


func play_combat_sfx(cue_id: String, minimum_interval_ms: int = 0) -> bool:
	return _request_combat_sfx(cue_id, minimum_interval_ms, false)


func _play_combat_sfx_now(cue_id: String, minimum_interval_ms: int = 0, gain_offset_db: float = 0.0) -> bool:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)):
		return false
	var profile: Dictionary = COMBAT_LIBRARY.PROFILES.get(cue_id, {})
	if profile.is_empty():
		return false
	var interval := maxi(int(profile.cooldown_ms), minimum_interval_ms)
	if _combat_clock_ms - float(_combat_last_ms.get(cue_id, -10000.0)) < interval:
		return false
	var priority := int(profile.priority)
	# Reserve four voices for weapon impacts / landings / reactions. A burst
	# gets at most three detail and three important starts in 60 ms.
	var lane := "impact" if priority >= 2 else "detail"
	var burst: Dictionary = _combat_bursts.get(lane, {"time": -10000.0, "count": 0})
	if _combat_clock_ms - float(burst.time) >= 60.0:
		burst = {"time": _combat_clock_ms, "count": 0}
	if int(burst.count) >= 3:
		return false
	var voices := 0
	var active := 0
	var available: AudioStreamPlayer = null
	for player in _combat_players:
		if player.playing:
			active += 1
			if str(player.get_meta("cue_id", "")) == cue_id:
				voices += 1
		elif available == null:
			available = player
	# Never steal a playing voice, so lightning and crystal tails stay intact.
	if available == null or voices >= int(profile.max_voices) or (priority < 2 and active >= COMBAT_DETAIL_VOICES):
		return false
	var streams: Array = profile.streams
	var variant := _combat_rng.randi_range(0, streams.size() - 1)
	if streams.size() > 1 and variant == int(_combat_last_variant.get(cue_id, -1)):
		variant = (variant + 1) % streams.size()
	available.stream = streams[variant]
	available.volume_db = float(profile.gain_db) + gain_offset_db
	var spread := float(profile.pitch_spread)
	available.pitch_scale = _combat_rng.randf_range(1.0 - spread, 1.0 + spread)
	available.set_meta("cue_id", cue_id)
	available.play()
	_combat_last_ms[cue_id] = _combat_clock_ms
	_combat_last_variant[cue_id] = variant
	burst.count = int(burst.count) + 1
	_combat_bursts[lane] = burst
	combat_sfx_played.emit(cue_id, available.stream.resource_path)
	return true


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
