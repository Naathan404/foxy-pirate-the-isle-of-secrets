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


func get_sell_offer_for_item(item_id: StringName) -> MerchantOffer:
	for offer: MerchantOffer in get_sell_offers():
		if offer.item != null and offer.item.item_id == item_id:
			return offer
	return null


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids: Dictionary[StringName, bool] = {}
	var item_ids: Dictionary[StringName, bool] = {}
	var weapon_ids: Dictionary[StringName, bool] = {}
	for offer: MerchantOffer in offers:
		if offer == null or not offer.is_valid():
			errors.append("Merchant catalog has an invalid offer")
			continue
		if offer.trade_amount < 1:
			errors.append("Merchant offer must trade at least one item: %s" % offer.offer_id)
		if ids.has(offer.offer_id):
			errors.append("Duplicate merchant offer: %s" % offer.offer_id)
		ids[offer.offer_id] = true
		if offer.kind == MerchantOffer.Kind.ITEM:
			if offer.item.item_id != offer.offer_id:
				errors.append("Merchant item offer ID must match item ID: %s" % offer.offer_id)
			if item_ids.has(offer.item.item_id):
				errors.append("Duplicate merchant item: %s" % offer.item.item_id)
			item_ids[offer.item.item_id] = true
		else:
			if offer.weapon.weapon_id != offer.offer_id:
				errors.append("Merchant weapon offer ID must match weapon ID: %s" % offer.offer_id)
			if weapon_ids.has(offer.weapon.weapon_id):
				errors.append("Duplicate merchant weapon: %s" % offer.weapon.weapon_id)
			weapon_ids[offer.weapon.weapon_id] = true
	return errors
