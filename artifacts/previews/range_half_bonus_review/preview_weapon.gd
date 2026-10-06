extends "res://scripts/weapons/weapon_instance.gd"
## Preview-only adapter: raw equipment stats stay intact. Native cast snapshots
## receive the reduced bonus once, so collision, VFX and enchantments agree.
var bonus_efficiency := 1.0
var geometry: WeaponInstance

func _scaled_cast() -> WeaponInstance:
	var copy := super.make_cast_copy()
	for stat in ["area_size", "damage_area_size"]:
		# Keep this archived A/B fixture reproducible after the formal formula changes.
		copy._cast_stats[stat] = float(copy._cast_stats[stat]) * bonus_efficiency / StatDefinitions.RANGE_BONUS_EFFICIENCY
	return copy

func refresh_geometry() -> void:
	geometry = _scaled_cast()

func make_cast_copy() -> WeaponInstance:
	return _scaled_cast()

func get_attack_range() -> float:
	return geometry.get_attack_range() if geometry != null else super.get_attack_range()

func get_hit_radius() -> float:
	return geometry.get_hit_radius() if geometry != null else super.get_hit_radius()

func get_grenade_blast_radius() -> float:
	return geometry.get_grenade_blast_radius() if geometry != null else super.get_grenade_blast_radius()

func get_projectile_visual_scale() -> float:
	return geometry.get_projectile_visual_scale() if geometry != null else super.get_projectile_visual_scale()

func get_dagger_outer_radius() -> float:
	return geometry.get_dagger_outer_radius() if geometry != null else super.get_dagger_outer_radius()

func get_dagger_body_scale() -> Vector2:
	return geometry.get_dagger_body_scale() if geometry != null else super.get_dagger_body_scale()

func get_domain_axes() -> Vector2:
	return geometry.get_domain_axes() if geometry != null else super.get_domain_axes()
