class_name MerchantCatalog
extends Resource

## A merchant owns only data. Runtime gold, inventory and weapon state remain on the player.
@export var offers: Array[MerchantOffer] = []
@export_group("Buy stock")
## These offers are sold on every visit; all other buy offers form the draw pool.
@export var guaranteed_buy_offer_ids: Array[StringName] = []
## Number of distinct offers drawn per stock roll. Zero keeps all offers.
@export_range(0, 100, 1) var random_buy_offer_count := 0


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


func roll_buy_stock(
	random: RandomNumberGenerator, previous_stock: MerchantCatalog = null
) -> MerchantCatalog:
	if random_buy_offer_count == 0:
		return self
	var selected: Dictionary[StringName, bool] = {}
	for offer_id: StringName in guaranteed_buy_offer_ids:
		selected[offer_id] = true
	var pool := get_buy_offers()
	for index in range(pool.size() - 1, -1, -1):
		if selected.has(pool[index].offer_id):
			pool.remove_at(index)
	for _draw in range(mini(random_buy_offer_count, pool.size())):
		var picked: MerchantOffer = pool.pop_at(random.randi_range(0, pool.size() - 1))
		selected[picked.offer_id] = true
	if previous_stock != null and not pool.is_empty():
		var same_selection := true
		for offer: MerchantOffer in get_buy_offers():
			var previous_offer := previous_stock.get_offer(offer.offer_id)
			if (previous_offer != null and previous_offer.buy_price > 0) != selected.has(
				offer.offer_id
			):
				same_selection = false
				break
		if same_selection:
			for offer: MerchantOffer in get_buy_offers():
				if selected.has(offer.offer_id) and not guaranteed_buy_offer_ids.has(offer.offer_id):
					selected.erase(offer.offer_id)
					selected[pool.front().offer_id] = true
					break
	var stock := MerchantCatalog.new()
	for offer: MerchantOffer in offers:
		var copy := offer.duplicate() as MerchantOffer
		if copy.buy_price > 0 and not selected.has(copy.offer_id):
			copy.buy_price = 0
		stock.offers.append(copy)
	return stock


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids: Dictionary[StringName, bool] = {}
	var sell_item_ids: Dictionary[StringName, bool] = {}
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
			if offer.sell_price > 0:
				if sell_item_ids.has(offer.item.item_id):
					errors.append("Duplicate sell offer for item: %s" % offer.item.item_id)
				sell_item_ids[offer.item.item_id] = true
		else:
			if offer.weapon.weapon_id != offer.offer_id:
				errors.append("Merchant weapon offer ID must match weapon ID: %s" % offer.offer_id)
			if weapon_ids.has(offer.weapon.weapon_id):
				errors.append("Duplicate merchant weapon: %s" % offer.weapon.weapon_id)
			weapon_ids[offer.weapon.weapon_id] = true
	var guaranteed: Dictionary[StringName, bool] = {}
	for offer_id: StringName in guaranteed_buy_offer_ids:
		if guaranteed.has(offer_id):
			errors.append("Duplicate guaranteed buy offer: %s" % offer_id)
		guaranteed[offer_id] = true
		var offer := get_offer(offer_id)
		if offer == null or offer.buy_price <= 0:
			errors.append("Guaranteed buy offer is unavailable: %s" % offer_id)
	return errors
