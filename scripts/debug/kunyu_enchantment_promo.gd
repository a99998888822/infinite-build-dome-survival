extends "res://scripts/debug/enchantment_promo.gd"
## Same three-slot animation, with a legal five-projectile/large-domain build.


func _ready() -> void:
	WindowSettings._startup_applied = true
	weapon_id = "weapon_kunyu_ritual_tome"
	weapon_level = 5
	item_ids = ["scroll_multishot", "scroll_domain", "scroll_electric_spark"]
	intro_frames = 12
	flight_frames = [36, 39, 42]
	landing_frames = 12
	end_hold_frames = 87
	super._ready()


func _recording_config() -> Dictionary:
	return preload("res://scripts/debug/fixtures/kunyu_promo_build.gd").config(false)
