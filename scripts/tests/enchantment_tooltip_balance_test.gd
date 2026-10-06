extends "res://scripts/tests/bounce_test.gd"
## Approved compact descriptions, shared UI output and actual revised spell damage.

const GROUPS := {
	"增益": ["might", "wisdom", "multishot", "domain", "precision", "lethality", "haste"],
	"法术": ["bounce", "explosion", "split", "pierce"],
	"元素": ["water", "light_sword", "black_hole", "fire", "lightning", "electric_spark", "ice", "wind"],
}

func _run() -> void:
	CampProgression.begin_transient_session()
	var inventory := ItemInventory.new()
	var markup := RegEx.new()
	markup.compile("\\[/?(?:color(?:=[^\\]]+)?|b)\\]")
	for group: String in GROUPS:
		for effect: String in GROUPS[group]:
			var item := inventory.add_item_from_base("scroll_" + effect, "drop")
			var esc := ItemInventoryCard.new()
			var finance := EnchantmentInventoryCard.new()
			var slot := EnchantmentSlotCard.new()
			for card in [esc, finance, slot]: card.item_instance = item.duplicate(true)
			var content := esc._build_tooltip()
			var plain := markup.sub(content, "", true)
			var expected := "%s\n类型：%s　稀有度：%s\n%s" % [item.display_name, group, ItemInventoryCard.RARITY_LABELS[item.rarity], item.description]
			check(plain == expected and content == finance._build_tooltip() and content == slot._build_tooltip(), "all detail entry points show only approved fields " + effect)
			check(item.category == "enchantment_scroll", "display classification preserves equip category " + effect)
			esc.item_instance.erase("enchantment_type")
			check(esc._build_tooltip() == content, "older instance can resolve display classification " + effect)
			if effect == "light_sword": check(plain.count("\n") == 3, "light exposure explanation retains its own line")
			for card in [esc, finance, slot]: card.free()
	check(DataRegistry.get_record("augmentations", "scroll_precision").rarity == "rare", "precision uses rare tier for inventory and drops")
	for i in 32:
		var item := inventory.add_item_from_base("scroll_lightning", "drop")
		check(is_equal_approx(float(item.rolled_parameters.stun_duration), 0.5), "every lightning drop matches fixed half-second description")
	await _spark_hit([], 60)
	await _spark_hit(["scroll_might"], 86)
	await _spark_hit(["scroll_wisdom"], 94)
	await fixture(BOW, [Vector2.ZERO, Vector2(80, 0)], ["scroll_lightning"])
	var hit := DamageEvent.create({"original_damage": 100, "damage": 100, "source_weapon_id": BOW})
	LightningParticleEffect.spawn(host, Vector2.ZERO, enemies[0], weapon, hit, Vector2.RIGHT)
	await get_tree().create_timer(0.25).timeout
	check(enemies[0].current_hp == 9945 and enemies[1].current_hp == 9945, "chain still deals 55 percent to each of two targets")
	check(is_equal_approx(enemies[0]._stunned_remaining, 0.5) and is_equal_approx(enemies[1]._stunned_remaining, 0.5), "real chain applies stated half-second paralysis")
	host.queue_free()
	await frames()
	AudioManager.stop_combat_sfx()
	AudioManager.stop_bgm()
	for voice in AudioManager.get_children():
		if voice is AudioStreamPlayer:
			voice.stop()
			voice.stream = null
	await frames()
	CampProgression.end_transient_session()
	print("ENCHANTMENT_TOOLTIP_BALANCE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _spark_hit(bonuses: Array, expected: int) -> void:
	await fixture(BOW, [Vector2.ZERO], ["scroll_electric_spark"] + bonuses)
	for stat in ["melee_damage", "ranged_damage", "element_damage", "damage_percent", "crit_chance"]:
		player.modifier_stack.set_base_stat(stat, 0)
		weapon.runtime_stats[stat] = 0
	weapon.runtime_stats.ranged_damage = 100
	if not bonuses.is_empty(): player.modifier_stack.set_base_stat("element_damage", 20)
	var hit := weapon.calculate_damage_events()[0]
	ElectricSparkEffect.spawn(host, Vector2.ZERO, weapon, hit, weapon.get_effect_instances("electric_spark")[0].item_instance_id)
	await get_tree().create_timer(0.3).timeout
	check(enemies[0].current_hp == 10000, "spark does not damage during warning")
	await get_tree().create_timer(0.4).timeout
	check(enemies[0].current_hp == 10000 - expected, "real delayed spark uses 60 percent once " + str(bonuses))
	await get_tree().create_timer(0.4).timeout
	check(enemies[0].current_hp == 10000 - expected, "spark animation cannot repeat damage")
