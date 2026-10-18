extends AudioStreamPlayer
## One loop per owner. Gameplay refreshes it only while its action is active.

func configure(source: AudioStreamWAV, gain_db: float, target_bus: String) -> void:
	stream = source.duplicate()
	var loop := stream as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	# Imported WAVs may use QOA/ADPCM. Compressed byte counts are not sample counts.
	loop.loop_end = roundi(source.get_length() * source.mix_rate)
	volume_db = gain_db
	bus = target_bus
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_active(active: bool) -> void:
	active = active and not bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)) and not get_tree().paused
	if active and not playing:
		play()
	elif not active and playing:
		stop()


func _process(_delta: float) -> void:
	# This still runs when a panel disables the parent's physics processing.
	if get_tree().paused or bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)) or not get_parent().is_physics_processing():
		set_active(false)
