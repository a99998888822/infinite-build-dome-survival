extends RefCounted
class_name GoblinSpecialTrades
## Quotes are read-only. Accepted transactions are run by GoblinTradeSystem once.


static func weapon_quote(weapon: WeaponInstance, player: PlayerController, multiplier: int) -> Dictionary:
	if weapon == null or player == null: return {}
	var service := InventoryTradeService.new()
	var humanity := player.get_stat("humanity")
	var quote := service.quote_weapon(weapon, humanity)
	var attached := weapon.get_attached_item_instances().duplicate(true)
	var items: Array[Dictionary] = []
	for item in attached:
		var owned := player.item_inventory.find_item(str(item.get("item_instance_id", "")))
		if owned.is_empty() or str(owned.get("equipped_weapon_id", "")) != weapon.weapon_id: return {}
		items.append(owned)
	var value := int(quote.total)
	for item in items: value += int(service.quote_item(item, humanity).total)
	return {"weapon_id": weapon.weapon_id, "instance_id": weapon.instance_id, "amount": value * multiplier,
		"weapon_name": str(quote.display_name), "items": items,
		"fingerprint": [weapon.instance_id, weapon.level, weapon.battle_title.duplicate(true),
			weapon.trade_base_basis, weapon.trade_upgrade_basis.duplicate(true), attached, items, humanity]}


static func best_weapon_quotes(loadout: WeaponLoadout, player: PlayerController, damage: Dictionary, multiplier: int) -> Array[Dictionary]:
	var quotes: Array[Dictionary] = []
	if loadout == null or loadout.get_weapon_instances().size() < 2: return quotes
	var highest := 0
	for weapon in loadout.get_weapon_instances():
		var dealt := int(damage.get(weapon.weapon_id, 0))
		if dealt <= 0 or dealt < highest: continue
		if dealt > highest:
			highest = dealt
			quotes.clear()
		var quote := weapon_quote(weapon, player, multiplier)
		if int(quote.get("amount", 0)) > 0: quotes.append(quote)
	return quotes


static func sanity_quote(player: PlayerController, finance: BattleFinanceSystem, definition: Dictionary) -> Dictionary:
	if player == null or finance == null: return {}
	var before := player.get_stat("humanity")
	var cost := ceili(finance.principal * float(definition.principal_cost_ratio))
	if cost <= 0 or cost >= finance.principal: return {}
	var preview_player := player.create_stat_preview_copy()
	var preview := finance.create_preview_copy(preview_player)
	preview.consume_trade_principal(cost)
	var recovery := maxf(0, float(definition.target_sanity) - preview_player.get_stat("humanity"))
	preview_player.restore_sanity_from_goblin_trade(recovery)
	var gain := preview_player.get_stat("humanity") - before
	preview_player.free()
	if gain <= 0: return {}
	return {"principal_before": finance.principal, "sanity_before": before, "cost": cost,
		"recovery": recovery, "gain": gain}


static func accept_weapon(offer: Dictionary, player: PlayerController, finance: BattleFinanceSystem, loadout: WeaponLoadout) -> bool:
	if loadout == null or loadout.get_weapon_instances().size() < 2: return false
	var weapon := loadout.get_weapon_instance(str(offer.weapon_id))
	var current := weapon_quote(weapon, player, int(offer.price_multiplier))
	if current.is_empty() or current.fingerprint != offer.fingerprint or int(current.amount) != int(offer.amount): return false
	# All ownership checks happen before anything is removed or any signals fire.
	for item: Dictionary in current.items:
		if player.item_inventory.find_item(str(item.item_instance_id)) != item: return false
	var index := loadout.weapon_instances.find(weapon)
	loadout.take_weapon_for_trade(weapon.weapon_id)
	var removed := player.item_inventory.take_weapon_bundle_for_trade(weapon.weapon_id)
	if not finance.grant_trade_gold(int(offer.amount)):
		for item in removed: player.item_inventory.restore_traded_item(item)
		loadout.restore_traded_weapon(weapon, index)
		return false
	loadout.finish_weapon_removal(weapon)
	player.item_inventory.items_changed.emit()
	return true


static func accept_sanity(offer: Dictionary, player: PlayerController, finance: BattleFinanceSystem) -> bool:
	var current := sanity_quote(player, finance, offer)
	if current.is_empty() or current != offer.sanity_quote: return false
	if not finance.consume_trade_principal(int(current.cost)): return false
	player.restore_sanity_from_goblin_trade(float(current.recovery))
	return true
