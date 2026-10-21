extends Label
class_name CombatDamageNumber
## Pooled display state. The label, rather than its victim, owns its budget slot.
var active := false
var origin := Vector2.ZERO
var critical := false

func release() -> void:
	if not active: return
	active = false
	EnemyController.release_damage_number()

func _exit_tree() -> void:
	release()
