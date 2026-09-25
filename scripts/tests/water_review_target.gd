extends "res://scripts/enemies/enemy_controller.gd"

# Capture fixture: keep native status timers, collisions and knockback, but
# remove autonomous chasing so each combination can be reviewed in one place.
func _process_chase() -> void:
	velocity = Vector2.ZERO
	_set_movement_visual(false, get_physics_process_delta_time())


func _process_contact_damage() -> void:
	pass
