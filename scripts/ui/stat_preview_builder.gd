extends RefCounted
class_name StatPreviewBuilder

const OFFER_RELIC: String = "relic"


static func build_offer_stat_preview(offer: Dictionary, player: PlayerController, finance: BattleFinanceSystem = null, purchase_cost: int = 0) -> Dictionary:
	var result := {}
	if player == null or str(offer.get("offer_type", "")) != OFFER_RELIC:
		return result
	var relic_id := str(offer.get("target_id", offer.get("id", "")))
	if not player.can_add_relic(relic_id):
		return result
	var preview_player := player.create_stat_preview_copy()
	var preview_finance: BattleFinanceSystem = finance.create_preview_copy(preview_player, purchase_cost) if finance != null else null
	# Run actual acquisition on a detached copy, including dynamic and finance
	# effects, without changing the live player, gold, or RNG.
	if preview_player.add_relic(relic_id):
		for stat_id in StatDefinitions.get_all_stat_ids():
			var current := get_display_stat_value(player, stat_id, finance)
			var predicted := get_display_stat_value(preview_player, stat_id, preview_finance)
			if not is_equal_approx(current, predicted):
				result[stat_id] = predicted
	preview_player.free()
	return result


static func get_display_stat_value(player: PlayerController, stat_id: String, finance: BattleFinanceSystem = null) -> float:
	if player == null:
		return 0.0
	match stat_id:
		"revive_count":
			return float(player.get_remaining_revives())
		"shop_price_percent":
			return player.get_effective_shop_discount()
		"interest_rate":
			if finance != null:
				return finance.get_interest_rate()
		"finance":
			if finance != null:
				return float(finance.principal)
	return player.get_stat(stat_id)
