extends DamageEvent
## Pre-cache arithmetic, retained for behavioral and equal-work controls.
func get_elemental_damage(multiplier: float) -> int:
	return maxi(1, int(roundi(get_elemental_base_damage() * maxf(multiplier, 0.0))))
