extends Node2D
class_name CampRoot

signal building_selected(building_id: String)

const CAMP_BUILDING_SLOT_SCENE: PackedScene = preload("res://scenes/camp/camp_building_slot.tscn")

const BUILDING_POSITIONS: Dictionary = {
	"camp_armory_workshop": Vector2(-260.0, -40.0),
	"camp_relic_archive": Vector2(-70.0, -120.0),
	"camp_blade_arena": Vector2(120.0, -140.0),
	"camp_farstar_range": Vector2(320.0, -50.0),
	"camp_kin_nursery": Vector2(-280.0, 150.0),
	"camp_mutation_laboratory": Vector2(-60.0, 170.0),
	"camp_dome_shelter": Vector2(140.0, 150.0),
	"camp_council_hall": Vector2(330.0, 150.0),
}

var building_slots: Dictionary = {}

@onready var building_layer: Node2D = get_node_or_null("BuildingLayer")


func _ready() -> void:
	if building_layer == null:
		building_layer = Node2D.new()
		building_layer.name = "BuildingLayer"
		add_child(building_layer)
	CampProgression.state_changed.connect(refresh_buildings)
	CampProgression.building_changed.connect(_on_progression_building_changed)
	_rebuild_scene()


func refresh_buildings() -> void:
	for slot in building_slots.values():
		if slot is CampBuildingSlot:
			slot.refresh_visual()


func get_building_slot(building_id: String) -> CampBuildingSlot:
	return building_slots.get(building_id, null)


func get_building_slot_count() -> int:
	return building_slots.size()


func _rebuild_scene() -> void:
	for child in building_layer.get_children():
		child.queue_free()
	building_slots.clear()
	for record in CampProgression.get_building_records():
		if not (record is Dictionary):
			continue
		var building_id := str(record.get("id", ""))
		if building_id.is_empty():
			continue
		var slot := CAMP_BUILDING_SLOT_SCENE.instantiate() as CampBuildingSlot
		if slot == null:
			continue
		slot.building_id = building_id
		slot.position = BUILDING_POSITIONS.get(building_id, Vector2.ZERO)
		slot.configure(building_id, str(record.get("name", building_id)))
		slot.pressed.connect(_on_building_pressed)
		building_layer.add_child(slot)
		building_slots[building_id] = slot
	refresh_buildings()


func _on_building_pressed(building_id: String) -> void:
	building_selected.emit(building_id)
	GameGlobal.log_debug("camp building pressed: %s" % building_id)


func _on_progression_building_changed(_building_id: String) -> void:
	refresh_buildings()
