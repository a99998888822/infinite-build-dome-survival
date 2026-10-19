extends EchoBat
const COST = preload("res://scripts/tests/fixtures/dense_cost_counters.gd")

func _physics_process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	super._physics_process(delta)
	COST.enemy_usec += Time.get_ticks_usec() - started

func take_damage(raw_damage: int, source_id: String = "", critical: bool = false, direction: Vector2 = Vector2.ZERO, components: Array[int] = [], light_bonus: bool = true) -> int:
	var started := Time.get_ticks_usec()
	var dealt := super.take_damage(raw_damage, source_id, critical, direction, components, light_bonus)
	COST.damage_usec += Time.get_ticks_usec() - started
	if dealt > 0: COST.hits += 1
	return dealt

func _spawn_damage_number(damage: int, critical: bool = false, index: int = 0, count: int = 1, light: bool = false, base: int = 0) -> void:
	if not COST.no_numbers: super._spawn_damage_number(damage, critical, index, count, light, base)

func _show_hit_visual() -> void:
	if not COST.no_hit_visual: super._show_hit_visual()
