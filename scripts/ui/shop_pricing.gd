extends RefCounted
class_name ShopPricing

const WAVE_PRICE_STEP := 2
const PURCHASE_PRICE_STEP := 1
const INCOME_PER_PRICE_STEP := 200
const INCOME_SURCHARGE_CAP := 0.10


static func apply(offer: Dictionary, context: Dictionary) -> void:
	if bool(offer.get("purchased", false)):
		return
	# Custom/legacy offers retain their explicit basis.
	if not offer.has("shop_base_price"):
		HumanityEconomy.reprice_offer(offer, float(context.get("humanity", 100)))
		return
	var base := int(offer.shop_base_price)
	var grows := str(offer.get("offer_type", "")) in ["new_weapon", "relic"]
	var wave := maxi(1, int(context.get("shop_wave_number", 1)))
	var count := maxi(0, int(context.get("paid_purchase_count", 0)))
	var earned := maxi(0, int(context.get("wave_gold_earned", 0)))
	var wave_extra := (wave - 1) * WAVE_PRICE_STEP if grows else 0
	var purchase_extra := count * PURCHASE_PRICE_STEP if grows else 0
	var subtotal := base + wave_extra + purchase_extra
	var income_extra := mini(floori(float(earned) / INCOME_PER_PRICE_STEP), floori(subtotal * INCOME_SURCHARGE_CAP)) if grows else 0
	var layers: Array = context.get("shop_price_discounts", [float(context.get("shop_price_percent", 0))])
	offer["price_breakdown"] = {"base": base, "wave": wave_extra, "purchases": purchase_extra, "income": income_extra, "wave_number": wave, "purchase_count": count, "wave_gold": earned}
	offer["shop_price_basis"] = (subtotal + income_extra) * StatDefinitions.calculate_shop_price_multiplier(layers)
	HumanityEconomy.reprice_offer(offer, float(context.get("humanity", 100)))
