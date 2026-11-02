class_name MerchantCatalog
extends Resource

## A merchant owns only data. Runtime gold, inventory and weapon state remain on the player.
@export var offers: Array[MerchantOffer] = []


func get_offer(offer_id: StringName) -> MerchantOffer:
	for offer: MerchantOffer in offers:
		if offer != null and offer.offer_id == offer_id:
			return offer
	return null


func get_buy_offers() -> Array[MerchantOffer]:
	var result: Array[MerchantOffer] = []
	for offer: MerchantOffer in offers:
		if offer != null and offer.buy_price > 0:
			result.append(offer)
	return result


func get_sell_offers() -> Array[MerchantOffer]:
	var result: Array[MerchantOffer] = []
	for offer: MerchantOffer in offers:
		if offer != null and offer.kind == MerchantOffer.Kind.ITEM and offer.sell_price > 0:
			result.append(offer)
	return result


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids: Dictionary[StringName, bool] = {}
	for offer: MerchantOffer in offers:
		if offer == null or not offer.is_valid():
			errors.append("Merchant catalog has an invalid offer")
			continue
		if ids.has(offer.offer_id):
			errors.append("Duplicate merchant offer: %s" % offer.offer_id)
		ids[offer.offer_id] = true
	return errors
