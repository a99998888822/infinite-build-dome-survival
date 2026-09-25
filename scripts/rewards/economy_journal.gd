extends RefCounted
class_name EconomyJournal

signal changed

const MAX_ENTRIES := 300
var entries: Array[Dictionary] = []
var _sequence := 0


func clear() -> void:
	entries.clear()
	_sequence = 0
	changed.emit()


func append(entry: Dictionary) -> void:
	if str(entry.get("text", "")).is_empty():
		return
	var record := entry.duplicate(true)
	_sequence += 1
	record["sequence"] = _sequence
	entries.append(record)
	if entries.size() > MAX_ENTRIES:
		entries.pop_front()
	changed.emit()


func get_entries() -> Array[Dictionary]:
	return entries.duplicate(true)
