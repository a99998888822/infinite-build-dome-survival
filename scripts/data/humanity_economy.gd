extends RefCounted
class_name HumanityEconomy
## Shared, continuous rules for prices, settlements and their UI explanations.


static func get_multipliers(humanity: float) -> Dictionary:
	var deficit := maxf(0.0, 100.0 - humanity)
	return {
		"purchase": 1.0 + deficit / 500.0,
		"sale": 1.0 / (1.0 + deficit / 500.0),
		"interest": 1.0 / (1.0 + deficit / 100.0),
	}


static func number(value: float) -> String:
	return ("%.1f" % value).trim_suffix("0").trim_suffix(".")


static func describe(humanity: float) -> String:
	var factors := get_multipliers(humanity)
	return L10n.text("economy.sanity.summary") % [
		number(humanity), number((float(factors.purchase) - 1.0) * 100.0),
		number((1.0 - float(factors.sale)) * 100.0), number((1.0 - float(factors.interest)) * 100.0),
	]


static func tooltip(humanity: float) -> String:
	return describe(humanity) + L10n.text("economy.sanity.rules")


static func reprice_offer(offer: Dictionary, humanity: float) -> void:
	if bool(offer.get("purchased", false)):
		return
	var basis := float(offer.get("shop_price_basis", offer.get("shop_cost", 0)))
	offer["shop_price_basis"] = basis
	offer["shop_cost_without_humanity"] = maxi(1, ceili(basis)) if basis > 0 else 0
	offer["shop_cost"] = maxi(1, ceili(basis * float(get_multipliers(humanity).purchase))) if basis > 0 else 0
	offer["humanity"] = humanity


static func price_text(actual: int, neutral: int) -> String:
	if actual == neutral:
		return str(actual)
	return "%d(%d%s%d)" % [actual, neutral, "+" if actual > neutral else "−", absi(actual - neutral)]


static func purchase_tooltip(offer: Dictionary) -> String:
	var text := L10n.text("economy.price.purchase_tooltip") % [
		price_text(int(offer.get("shop_cost", 0)), int(offer.get("shop_cost_without_humanity", offer.get("shop_cost", 0)))),
		describe(float(offer.get("humanity", 100))),
	]
	var parts: Dictionary = offer.get("price_breakdown", {})
	if not parts.is_empty():
		text += L10n.text("economy.price.cost_breakdown") % [parts.base, parts.wave, parts.purchases, parts.income]
		if str(offer.get("offer_type", "")) in ["new_weapon", "relic"]:
			text += L10n.text("economy.price.wave_income_rules") % int(parts.wave_gold)
	return text


static func sale_tooltip(quote: Dictionary) -> String:
	return L10n.text("economy.price.sale_tooltip") % [
		price_text(int(quote.get("total", 0)), int(quote.get("total_without_humanity", quote.get("total", 0)))),
		int(quote.get("total_without_humanity", quote.get("total", 0))), int(quote.get("humanity_loss", 0)),
	]
