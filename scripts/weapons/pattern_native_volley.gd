extends DirectedWeaponRuntime
class_name PatternNativeVolley
## Native bodies keep their animations and contacts; the wrapper owns one cast.
var bodies: Array[Node2D] = []

func initialize(source: WeaponInstance, plan: AttackPatternPlan, aim: Vector2) -> void:
	bind_weapon(source, "pattern_native_volleys")
	var angles := plan.angles(source)
	for i in plan.units.size():
		var copy := source.make_cast_copy()
		copy.attack_context = source.attack_context
		plan.apply_unit(copy, i)
		var direction := aim.rotated(deg_to_rad(angles[i]))
		var body: Node2D
		if copy.is_camp_dagger(): body = CampDagger.new()
		elif copy.is_nightwatch_spear(): body = NightwatchSpear.new()
		elif copy.is_meteor_flail(): body = MeteorFlail.new()
		elif copy.is_earth_hammer(): body = EarthHammer.new()
		elif copy.is_mutant_tentacle(): body = MutantTentacle.new()
		elif copy.is_copper_lamp(): body = CopperLamp.new()
		elif copy.is_furnace(): body = FurnaceRuntime.new()
		elif copy.is_ritual_tome(): body = RitualDomain.new()
		if body == null: continue
		add_child(body)
		if body is MutantTentacle:
			body.initialize(copy)
			body.try_attack(direction)
		elif body is CopperLamp:
			body.initialize(copy)
			body.manual_control = true
			body.manual_direction = direction
			body.externally_driven = true
			body.burst_active = true
		elif body is FurnaceRuntime: body.initialize(copy)
		elif body is RitualDomain:
			body.initialize(copy, true)
			if copy.pattern_merged: body.marks_remaining = 1
		else:
			body.initialize(copy, direction)
			if body is CampDagger: body.configure_continuous_combo()
		bodies.append(body)

func is_attacking() -> bool:
	for body in bodies:
		if not is_instance_valid(body) or body.cancelled: continue
		if body is CopperLamp and body.burst_active: return true
		if body is MutantTentacle and body.attacking: return true
		if body is MeteorFlail and body.is_swinging(): return true
		if body.has_method("is_attacking") and body.is_attacking(): return true
	return false

func _physics_process(_delta: float) -> void:
	if not ready_to_tick(): return
	if not is_attacking(): cancel()

func cancel() -> void:
	for body in bodies:
		if is_instance_valid(body) and body.has_method("cancel"): body.cancel()
	super.cancel()
