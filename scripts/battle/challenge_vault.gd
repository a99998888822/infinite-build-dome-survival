extends StaticBody2D
class_name ChallengeVault
## A stationary contract objective; only hostile contact can damage it.

signal destroyed
var max_hp := 1
var current_hp := 1
var armor := 0.0
var alive := true
var _flash := 0.0
@onready var sprite: Sprite2D = $Sprite2D
@onready var caption: Label = $Caption


func initialize(health: int, copied_armor: float) -> void:
	max_hp = maxi(1, health)
	current_hp = max_hp
	armor = copied_armor
	alive = true
	_refresh()


func take_enemy_damage(amount: int) -> int:
	if not alive or amount <= 0 or bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)): return 0
	var damage := maxi(1, roundi(amount * StatDefinitions.calculate_damage_taken_from_armor(armor) / 100.0))
	var dealt := mini(current_hp, damage)
	current_hp -= dealt
	_flash = 0.12
	if current_hp <= 0:
		alive = false
		$CollisionShape2D.set_deferred("disabled", true)
		destroyed.emit()
	_refresh()
	return dealt


func _process(delta: float) -> void:
	if bool(GameGlobal.get_runtime_flag("battle_runtime_paused", false)): return
	_flash = maxf(0, _flash - delta)
	sprite.modulate = Color(1.6, 0.7, 0.6) if _flash > 0 else (Color.WHITE if alive else Color(0.3, 0.3, 0.3))


func _refresh() -> void:
	caption.text = L10n.text("ui.challenge.vault.health") % [current_hp, max_hp] if alive else L10n.text("ui.challenge.vault.destroyed")
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-28, -36, 56, 6), Color("17211c"))
	draw_rect(Rect2(-27, -35, 54.0 * current_hp / max_hp, 4), Color("e2bc66") if alive else Color("674132"))
