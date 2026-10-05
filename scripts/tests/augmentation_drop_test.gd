extends Node

var failures := 0
var checks := 0
const RARITIES := {"scroll_split": "epic", "scroll_bounce": "epic", "scroll_lightning": "rare", "scroll_explosion": "common",
	"scroll_might": "rare", "scroll_wisdom": "uncommon", "scroll_multishot": "epic", "scroll_domain": "rare", "scroll_lethality": "rare", "scroll_haste": "rare",
	"scroll_light_sword": "rare", "scroll_black_hole": "rare", "scroll_wind": "rare"}

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", message)

func sample(drops: DropRewardSystem, table: Dictionary, count: int = 10000) -> Dictionary:
	var counts := {}
	for i in count:
		var action := drops._build_augmentation_action(table, 0)
		if action.is_empty():
			check(false, "guaranteed valid pool must produce a drop")
			return counts
		var rarity := str(DataRegistry.get_record("augmentations", action.entry.item_id).rarity)
		counts[rarity] = int(counts.get(rarity, 0)) + 1
	return counts

func _run() -> void:
	check(not DataRegistry.has_record("augmentations", "wizard_scroll_chain_mastery"), "removed enchantment has no config")
	for data: Dictionary in DataRegistry.get_table("augmentations"):
		check(data.rarity == RARITIES.get(str(data.id), "uncommon"), "configured rarity " + str(data.id))
	var drops := DropRewardSystem.new()
	for table_id in ["drop_basic_enemy", "drop_elite_enemy", "drop_boss_enemy"]:
		var table := DataRegistry.get_record("drop_tables", table_id).duplicate(true)
		table.augmentation_chance_percent = 100
		drops.begin_wave()
		seed(927061)
		var counts := sample(drops, table)
		print("RARITY_SAMPLE ", table_id, " ", counts)
		for rarity: String in table.augmentation_rarity_weights:
			check(absf(float(counts.get(rarity, 0)) / 100.0 - float(table.augmentation_rarity_weights[rarity])) < 1.0,
				table_id + " conditional distribution " + rarity)
		# Changing weights only within the green tier must not change the tier distribution.
		for entry: Dictionary in table.entries:
			if entry.type == "augmentation" and DataRegistry.get_record("augmentations", entry.item_id).rarity == "uncommon":
				entry.weight *= 100
		seed(927061)
		check(sample(drops, table) == counts, "item weights do not distort rarity odds: " + table_id)
	var restricted := {"augmentation_chance_percent": 100, "augmentation_rarity_weights": {"uncommon": 70, "mythic": 30},
		"entries": [{"type": "augmentation", "item_id": "scroll_fire", "weight": 1}]}
	check(sample(drops, restricted, 100).get("uncommon", 0) == 100, "empty rarity tiers redistribute to available items")
	restricted.entries = [{"type": "augmentation", "item_id": "wizard_scroll_chain_mastery", "weight": 1}]
	check(drops._build_augmentation_action(restricted, 0).is_empty(), "stale removed entry cannot produce a drop")
	var invalid := DataRegistry.get_record("drop_tables", "drop_basic_enemy").duplicate(true)
	invalid.augmentation_rarity_weights.rare = -1
	var validator := DataValidator.new()
	validator._validate_drop_table_records([invalid], DataRegistry.records_by_id)
	check(not validator.errors.is_empty(), "negative rarity weights fail config validation")

	var player := PlayerController.new()
	player.auto_initialize_on_ready = false
	add_child(player)
	player.initialize_from_character("character_void_hunter")
	player.set_physics_process(false)
	var host := Node2D.new()
	add_child(host)
	check(drops.spawn_augmentation("wizard_scroll_chain_mastery", 1, Vector2.ZERO, host, player) == null,
		"removed enchantment cannot spawn directly")
	for id in ["scroll_fire", "scroll_lightning", "scroll_electric_spark", "scroll_split", "scroll_explosion", "scroll_bounce"]:
		drops.begin_wave()
		var pickup := drops.spawn_augmentation(id, 1, Vector2(100, 0), host, player)
		pickup.set_physics_process(false)
		var card := ItemInventoryCard.new()
		add_child(card)
		card.configure(DataRegistry.get_record("augmentations", id), false)
		check(pickup._icon_sprite.texture == card.icon and pickup._icon_sprite.texture.get_size() * pickup._icon_sprite.scale == Vector2(32, 32),
			"pickup uses identical ESC icon at the existing 32px display size: " + id)
		var rarity := str(DataRegistry.get_record("augmentations", id).rarity)
		check(pickup._display_color == ItemInventoryCard.RARITY_COLORS[rarity], "glow matches inventory rarity: " + id)
		pickup._physics_process(0.1)
		check(pickup.rotation == 0 and pickup.position.x < 100, "upright icon retains attraction: " + id)
		var before := player.item_inventory.get_item_count()
		pickup.collect()
		pickup.collect()
		check(player.item_inventory.get_item_count() == before + 1, "pickup is collected exactly once: " + id)
		card.free()
	host.queue_free()
	player.queue_free()
	await get_tree().process_frame
	print("AUGMENTATION_DROP_TEST checks=", checks, " failures=", failures)
	get_tree().quit(1 if failures else 0)
