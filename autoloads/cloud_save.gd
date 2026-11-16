extends Node
## TapTap mobile cloud saves. Independent installation slots avoid concurrent
## overwrites; ancestry detects branches without merging spendable balances.

signal state_changed
signal profile_replaced

const SLOT_PREFIX := "profile_01_"
const MAX_BYTES := 10 * 1024 * 1024
const MAX_HISTORY := 128
const REQUEST_TIMEOUT := 60.0
const UPLOAD_DELAY := 10.0

var state := "disabled"
var status_message := ""
var enabled := false
var storage_root := "user://saves/cloud"
var _session: Node
var _progression: Node
var _bridge: Object
var _owner := ""
var _key := ""
var _install := ""
var _slot_uuid := ""
var _request := 0
var _busy := ""
var _deadline := 0.0
var _next_sync := 0.0
var _backoff := 30.0
var _last_upload := -UPLOAD_DELAY
var _opened := false
var _active_profile := false
var _restoring := false
var _baseline := ""
var _base_revision := ""
var _history: Array = []
var _archives: Array = []
var _snapshots: Array = []
var _heads: Array = []
var _download_index := 0
var _sent: Dictionary = {}
var _choices: Array = []
var _configured := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# --mobile-ui is a desktop presentation preview and must never contact TapSDK.
	if not OS.has_feature("android") or CampProgression.is_transient_session(): return
	configure(TapTapSession._bridge, TapTapSession, CampProgression)


func configure(bridge: Object, session: Node, progression: Node) -> void:
	enabled = true
	_bridge = bridge
	_session = session
	_progression = progression
	_session.state_changed.connect(_on_session_changed)
	_progression.state_changed.connect(_on_progress_changed)
	_session.set_cloud_ready(false)
	if bridge == null or not bridge.has_signal("cloudCompleted") or not bridge.has_signal("cloudFailed") or not bridge.has_signal("cloudStatus"):
		_set_state("unavailable", "云存档插件缺失，请安装新版 Android 包。")
		return
	bridge.connect("cloudCompleted", _on_completed)
	bridge.connect("cloudFailed", _on_failed)
	bridge.connect("cloudStatus", _on_status)
	var identity := _read_json(storage_root.path_join("installation.json"))
	_install = str(identity.get("id", ""))
	if _install.is_empty():
		if _file_or_backup_exists(storage_root.path_join("installation.json")):
			_set_state("unavailable", "云存档设备记录损坏，请保留本机数据并联系支持。")
			return
		_install = Crypto.new().generate_random_bytes(16).hex_encode()
		if not _write_json(storage_root.path_join("installation.json"), {"id": _install}):
			_set_state("unavailable", "无法保存云存档设备记录，请检查存储空间。")
			return
	if _install.length() != 32 or not _install.is_valid_hex_number(false):
		_set_state("unavailable", "云存档设备记录无效，请保留本机数据并联系支持。")
		return
	_set_state("waiting_login", "登录并通过防沉迷检查后同步云存档。")
	_configured = true
	_on_session_changed()


func _on_session_changed() -> void:
	if not enabled or not _configured or _session == null or state == "unavailable": return
	if not _session.is_authenticated():
		_request += 1
		_busy = ""
		_next_sync = 0.0
		var same_account := not _owner.is_empty() and str(_session.account.get("open_id", "")) == _owner
		if same_account and not _session.state in ["logging_out", "logged_out", "compliance_exited"]:
			_set_state("waiting_login", "通过防沉迷检查后继续同步云存档。")
			_session.set_cloud_ready(false)
			return
		_owner = ""
		_opened = false
		_active_profile = false
		_next_sync = 0.0
		_set_state("waiting_login", "登录并通过防沉迷检查后同步云存档。")
		_session.set_cloud_ready(false)
		return
	var owner := str(_session.account.get("open_id", ""))
	if owner == _owner:
		if state == "waiting_login":
			if _opened: _session.set_cloud_ready(true)
			_start_list()
		return
	_owner = owner
	_key = owner.sha256_text()
	_slot_uuid = ""
	_opened = false
	_active_profile = false
	_baseline = ""
	_base_revision = ""
	_history = []
	_session.set_cloud_ready(false)
	var claim_path := storage_root.path_join("legacy_owner.json")
	var claim := _read_json(claim_path)
	if claim.is_empty():
		if _file_or_backup_exists(claim_path) or not _write_json(claim_path, {"owner": _key}):
			_fail("无法读取或保存旧档迁移记录，请检查存储空间。")
			return
		claim = {"owner": _key}
	_restoring = true
	var activated: bool = _progression.activate_cloud_account(_key, claim.get("owner") == _key)
	_restoring = false
	if not activated:
		_fail("无法读取或保存此账号的本机存档，请检查设备存储。")
		return
	var metadata := _read_json(_metadata_path())
	if metadata.is_empty() and _file_or_backup_exists(_metadata_path()):
		_fail("同步记录损坏，已保留本机进度。请联系支持。")
		return
	if not metadata.is_empty() and (not _valid_digest(metadata.get("digest")) or not _valid_digest(metadata.get("revision")) or not metadata.get("history") is Array):
		_fail("同步记录格式无效，已保留本机进度。请联系支持。")
		return
	if not metadata.is_empty():
		if metadata.history.size() > MAX_HISTORY:
			_fail("同步记录过长，已保留本机进度。请联系支持。")
			return
		for revision in metadata.history:
			if not _valid_digest(revision):
				_fail("同步历史记录损坏，已保留本机进度。请联系支持。")
				return
	_baseline = str(metadata.get("digest", ""))
	_base_revision = str(metadata.get("revision", ""))
	_history = metadata.get("history", []) if metadata.get("history", []) is Array else []
	_active_profile = true
	profile_replaced.emit()
	_start_list()


func _process(_delta: float) -> void:
	if not enabled or _owner.is_empty() or state == "unavailable": return
	var now := _now()
	if not _busy.is_empty() and now >= _deadline:
		_request += 1 # A late SDK result cannot acknowledge a newer request.
		_busy = ""
		_fail("云存档请求超时，本机进度已保留，可重试同步。")
	elif _busy.is_empty() and _next_sync > 0.0 and now >= _next_sync:
		_next_sync = 0.0
		_start_list()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and enabled and _opened:
		retry.call_deferred()


func retry() -> void:
	if not enabled or _session == null or not _session.is_authenticated() or state == "unavailable" or not _busy.is_empty(): return
	# Account activation failures must be retried before any network request.
	if not _active_profile:
		_owner = ""
		_on_session_changed()
		return
	_start_list()


func continue_offline() -> void:
	if not can_continue_offline(): return
	_open_game()
	_set_state("offline", "正在使用本机进度；尚未同步的进度无法在卸载后恢复。")
	_next_sync = _now() + _backoff


func can_continue_offline() -> bool:
	return state == "error" and _active_profile


func is_busy() -> bool:
	return not _busy.is_empty()


func conflict_options() -> Array:
	return _choices.duplicate(true)


func choose_progress(index: int) -> void:
	if state != "conflict" or index < 0 or index >= _choices.size() or is_busy(): return
	var selected: Dictionary = _choices[index]
	if selected.get("local", false):
		# The local snapshot can have changed since the conflict was presented.
		selected = {"progress": _progression.cloud_progress()}
	else:
		if not _restore(selected.progress): return
	_history = _combined_history()
	_open_game()
	_upload()


func _start_list() -> void:
	if _owner.is_empty() or not _session.is_authenticated() or is_busy(): return
	_next_sync = 0.0
	_archives.clear()
	_snapshots.clear()
	_heads.clear()
	_choices.clear()
	_slot_uuid = ""
	_begin("list")
	_bridge.call("cloudList", _owner, _request)


func _begin(operation: String) -> void:
	_request += 1
	_busy = operation
	_deadline = _now() + REQUEST_TIMEOUT
	_set_state("uploading" if operation == "upload" else "loading", "正在上传云存档…" if operation == "upload" else "正在检查云端进度…")


func _on_completed(id: int, operation: String, payload: String) -> void:
	if id != _request or operation != _busy or _owner.is_empty() or not _session.is_authenticated(): return
	_busy = ""
	if payload.to_utf8_buffer().size() > MAX_BYTES:
		_fail("云端数据超过大小限制，已保留本机进度。")
		return
	var parsed: Variant = JSON.parse_string(payload)
	match operation:
		"list":
			if not parsed is Array or parsed.size() > 100:
				_fail("云存档列表无效，已保留本机进度。")
				return
			for archive in parsed:
				if not archive is Dictionary:
					_fail("云存档列表无效，已保留本机进度。")
					return
				if not str(archive.get("name", "")).begins_with(SLOT_PREFIX): continue
				if str(archive.get("uuid", "")).is_empty() or str(archive.get("file_id", "")).is_empty():
					_fail("云存档标识无效，请重试。")
					return
				_archives.append(archive)
			_download_index = 0
			_download_next()
		"download":
			if not _valid_snapshot(parsed):
				_fail("云存档损坏或版本不兼容，已保留本机进度，未覆盖云端。")
				return
			var archive: Dictionary = _archives[_download_index]
			parsed["archive"] = archive
			_snapshots.append(parsed)
			if archive.name == SLOT_PREFIX + _install:
				_slot_uuid = str(archive.uuid)
			_download_index += 1
			_download_next()
		"upload":
			if not parsed is Dictionary or str(parsed.get("uuid", "")).is_empty():
				_fail("云存档上传未返回有效确认，请重试。")
				return
			_slot_uuid = str(parsed.uuid)
			if not _record_base(str(_sent.digest), _sent.history, str(_sent.revision)): return
			_backoff = 30.0
			if digest(_progression.cloud_progress()) != _baseline:
				_on_progress_changed()
			else:
				_set_state("synced", "已同步到 TapTap 云端")


func _download_next() -> void:
	if _download_index >= _archives.size():
		_reconcile()
		return
	var archive: Dictionary = _archives[_download_index]
	_begin("download")
	_bridge.call("cloudDownload", _owner, _request, str(archive.uuid), str(archive.file_id))


func _reconcile() -> void:
	var by_revision: Dictionary = {}
	for snapshot in _snapshots:
		if by_revision.has(snapshot.revision) and snapshot.digest != by_revision[snapshot.revision].digest:
			_fail("云存档版本标识冲突，已保留所有进度。")
			return
		by_revision[snapshot.revision] = snapshot
	_heads.clear()
	for revision in by_revision:
		var superseded := false
		for other in by_revision.values():
			if other.revision != revision and revision in other.history:
				superseded = true
				break
		if not superseded: _heads.append(by_revision[revision])
	if not by_revision.is_empty() and _heads.is_empty():
		_fail("云存档继承关系异常，已保留所有进度。")
		return
	var local: Dictionary = _progression.cloud_progress()
	var local_digest := digest(local)
	if _heads.is_empty():
		# Only a successful empty list permits the first upload.
		_open_game()
		_upload()
		return
	var resolved_heads := true
	for head in _heads:
		if not head.revision in _history: resolved_heads = false
	if resolved_heads:
		# A chosen resolution can wait for the upload rate limit. Its in-memory
		# acknowledgement is valid only while no new remote branch appears.
		_open_game()
		_upload()
		return
	var equivalent_heads := true
	for head in _heads:
		if head.digest != _heads[0].digest: equivalent_heads = false
	if equivalent_heads:
		var remote: Dictionary = _heads[0]
		if local_digest == remote.digest:
			if not _record_base(local_digest, remote.history, str(remote.revision)): return
			_open_game()
			_backoff = 30.0
			if _heads.size() > 1:
				_history = _combined_history()
				_upload()
				return
			_set_state("synced", "已同步到 TapTap 云端")
			return
		if _baseline == remote.digest:
			_history = _combined_history()
			_open_game()
			_upload()
			return
		var fresh: bool = _baseline.is_empty() and not _progression.has_cloud_progress()
		var clean_descendant: bool = local_digest == _baseline and _base_revision in remote.history
		if not _opened and (fresh or clean_descendant):
			if not _restore(remote.progress) or not _record_base(str(remote.digest), remote.history, str(remote.revision)): return
			_open_game()
			if _heads.size() > 1:
				_history = _combined_history()
				_upload()
				return
			_set_state("synced", "已恢复 TapTap 云端进度")
			_on_progress_changed()
			return
	# Never add balances or take maxima: purchases and refunds are non-monotonic.
	_choices = [{"local": true, "progress": local}]
	_choices.append_array(_heads)
	_next_sync = 0.0
	_set_state("conflict", "发现不同进度。请选择要保留的一份；恢复云端进度会返回主菜单。")
	_session.set_cloud_ready(false)
	_session.login_required.emit()


func _upload() -> void:
	var earliest := _last_upload + UPLOAD_DELAY
	if _now() < earliest:
		_next_sync = earliest
		_set_state("pending", "已保存到本机，等待同步到云端…")
		return
	if not _progression.save_state():
		_fail("本机存档写盘失败，已停止上传，请检查存储空间。")
		return
	var progress: Dictionary = _progression.cloud_progress()
	if not _progression.valid_cloud_progress(progress):
		_fail("本机进度格式无效，已停止上传。")
		return
	var hash_value := digest(progress)
	var history := _history.duplicate()
	if not _base_revision.is_empty() and not _base_revision in history: history.append(_base_revision)
	if history.size() > MAX_HISTORY: history = history.slice(history.size() - MAX_HISTORY)
	_sent = {"format": 1, "owner": _key, "progress": progress, "digest": hash_value, "revision": Crypto.new().generate_random_bytes(32).hex_encode(), "history": history, "saved_at": int(Time.get_unix_time_from_system())}
	var payload := JSON.stringify(_sent)
	if payload.to_utf8_buffer().size() > MAX_BYTES:
		_fail("存档超过 TapTap 的 10MB 限制，本机进度已保留。")
		return
	_begin("upload")
	_last_upload = _now()
	_bridge.call("cloudUpload", _owner, _request, _slot_uuid, SLOT_PREFIX + _install, payload, JSON.stringify({"format": 1, "digest": hash_value}))


func _restore(progress: Dictionary) -> bool:
	# Retain a stable pre-restore copy, separate from normal rotating backups.
	if not _write_json(storage_root.path_join(_key + ".before_restore.json"), _progression.cloud_progress()):
		_fail("无法备份本机进度，已取消云端恢复。")
		return false
	_restoring = true
	var success: bool = _progression.restore_cloud_progress(progress)
	_restoring = false
	if not success:
		_fail("云端恢复写盘失败，已保留本机进度。")
		return false
	profile_replaced.emit()
	return true


func _on_progress_changed() -> void:
	if _restoring or not _opened or _owner.is_empty() or state == "conflict": return
	if digest(_progression.cloud_progress()) == _baseline: return
	if not is_busy(): _set_state("pending", "已保存到本机，等待同步到云端…")
	if _next_sync == 0.0: _next_sync = _now() + UPLOAD_DELAY


func _on_failed(id: int, code: int) -> void:
	if id != _request or _busy.is_empty() or _owner.is_empty(): return
	_busy = ""
	_fail("云存档同步失败（%d），本机进度已保留，可重试。" % code)


func _on_status(code: int) -> void:
	if _owner.is_empty(): return
	_request += 1
	_busy = ""
	_fail("TapTap 云存档服务不可用（%d），请重试或重新登录。" % code)
	if code == 300001: _session.logout()


func _fail(message: String) -> void:
	_set_state("error", message)
	_next_sync = _now() + _backoff if _opened else 0.0
	_backoff = minf(_backoff * 2.0, 300.0)


func _open_game() -> void:
	_opened = true
	_session.set_cloud_ready(true)


func _record_base(hash_value: String, history: Array, revision: String) -> bool:
	if not _write_json(_metadata_path(), {"digest": hash_value, "history": history, "revision": revision}):
		_fail("同步记录写盘失败，本机进度已保留，请重试。")
		return false
	_baseline = hash_value
	_base_revision = revision
	_history = history.duplicate()
	return true


func _combined_history() -> Array:
	var result := _history.duplicate()
	for head in _heads:
		for value in head.history + [head.revision]:
			if not value in result: result.append(value)
	return result.slice(maxi(0, result.size() - MAX_HISTORY))


func _valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary or value.get("format") != 1 or value.get("owner") != _key: return false
	if not _progression.valid_cloud_progress(value.get("progress")) or not value.get("history") is Array: return false
	if value.history.size() > MAX_HISTORY or not _valid_digest(value.get("digest")) or not _valid_digest(value.get("revision")): return false
	for ancestor in value.history:
		if not _valid_digest(ancestor) or ancestor == value.revision: return false
	return digest(value.progress) == value.digest


func _valid_digest(value: Variant) -> bool:
	return value is String and value.length() == 64 and value.is_valid_hex_number(false)


static func digest(progress: Dictionary) -> String:
	return JSON.stringify(_canonical(progress)).sha256_text()


static func _canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		var keys: Array = value.keys()
		keys.sort()
		for key in keys: result[key] = _canonical(value[key])
		return result
	# Progress fields are integers; JSON decoding produces floating-point numbers.
	if value is float: return int(value)
	return value


func _metadata_path() -> String:
	return storage_root.path_join(_key + ".sync.json")


func _read_json(path: String) -> Dictionary:
	for candidate in [path, path + ".backup"]:
		if not FileAccess.file_exists(candidate): continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate))
		if parsed is Dictionary and not parsed.is_empty(): return parsed
	return {}


func _file_or_backup_exists(path: String) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".backup")


func _write_json(path: String, value: Dictionary) -> bool:
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(value))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return false
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".backup") and DirAccess.remove_absolute(path + ".backup") != OK: return false
		if DirAccess.rename_absolute(path, path + ".backup") != OK: return false
	if DirAccess.rename_absolute(path + ".tmp", path) == OK: return true
	if FileAccess.file_exists(path + ".backup"): DirAccess.rename_absolute(path + ".backup", path)
	return false


func _set_state(next: String, message: String) -> void:
	state = next
	status_message = message
	state_changed.emit()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
