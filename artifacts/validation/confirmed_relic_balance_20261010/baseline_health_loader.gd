extends Node

func _ready() -> void:
	# Restore pre-edit relics only inside this transient verification process.
	var old: Array = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/validation/confirmed_relic_balance_20261010/before_relics.json"))
	for record: Dictionary in old:
		DataRegistry.records_by_id["relics"][record.id] = record
		for index in DataRegistry.tables["relics"].size():
			if DataRegistry.tables["relics"][index].id == record.id:
				DataRegistry.tables["relics"][index] = record
	var node := Node.new()
	node.set_script(load("res://artifacts/validation/confirmed_relic_balance_20261010/baseline_health.gd"))
	add_child(node)
