extends RefCounted
## Frozen pre-unification tracks, also present in damage_number_animation_baseline.json.
static func animate(label: Label, critical: bool) -> Tween:
	var tween := label.create_tween()
	tween.set_parallel(true)
	if critical:
		tween.tween_method(EnemyController._animate_critical_damage_number.bind(label, label.global_position), 0.0, 0.62, 0.62)
	else:
		tween.tween_property(label, "global_position", label.global_position + Vector2(0, -42), 0.62)
	tween.tween_property(label, "modulate:a", 1.0, 0.10)
	tween.tween_property(label, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(0.10)
	tween.tween_property(label, "modulate:a", 0.0, 0.28)
	return tween
