extends RefCounted
## Diagnostic scopes are inclusive and must not be summed as exclusive costs.
static var enemy_usec := 0
static var damage_usec := 0
static var backdrop_usec := 0
static var particle_usec := 0
static var scheduler_usec := 0
static var feedback_usec := 0
static var weapon_usec := 0
static var weapon_draw_usec := 0
static var reflection_usec := 0
static var hits := 0
static var no_numbers := false
static var no_hit_visual := false

static func reset() -> void:
	enemy_usec = 0
	damage_usec = 0
	backdrop_usec = 0
	particle_usec = 0
	scheduler_usec = 0
	feedback_usec = 0
	weapon_usec = 0
	weapon_draw_usec = 0
	reflection_usec = 0
	hits = 0
