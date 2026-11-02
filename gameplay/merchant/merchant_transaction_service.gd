class_name MerchantTransactionService
extends RefCounted

## Keeps each trade atomic from the caller's perspective.
enum Result {
	SUCCESS,
	INVALID_OFFER,
	INSUFFICIENT_GOLD,
	INVENTORY_FULL,
	ALREADY_OWNED,
	NOT_OWNED,
	GOLD_CAP_REACHED,
	GRANT_FAILED,
}

var catalog: MerchantCatalog


func _init(merchant_catalog: MerchantCatalog = null) -> void:
	catalog = merchant_catalog


func purchase(
	offer_id: StringName, inventory: Inventory, wallet: GoldWallet, weapons: WeaponController
) -> Result:
	var offer := _get_buy_offer(offer_id)
	if offer == null or wallet == null:
		return Result.INVALID_OFFER

	if offer.kind == MerchantOffer.Kind.WEAPON:
		if weapons == null or offer.weapon == null:
			return Result.INVALID_OFFER
		if weapons.is_weapon_owned(offer.weapon.weapon_id):
			return Result.ALREADY_OWNED
		if not wallet.can_afford(offer.buy_price):
			return Result.INSUFFICIENT_GOLD
		if not wallet.try_spend(offer.buy_price):
			return Result.INSUFFICIENT_GOLD
		if not weapons.grant_weapon(offer.weapon.weapon_id):
			wallet.add_gold(offer.buy_price)
			return Result.GRANT_FAILED
		return Result.SUCCESS

	if inventory == null or offer.item == null:
		return Result.INVALID_OFFER
	if not wallet.can_afford(offer.buy_price):
		return Result.INSUFFICIENT_GOLD
	if not inventory.can_add_item(offer.item):
		return Result.INVENTORY_FULL
	if not wallet.try_spend(offer.buy_price):
		return Result.INSUFFICIENT_GOLD
	if inventory.add_item(offer.item, 1) != 0:
		wallet.add_gold(offer.buy_price)
		return Result.INVENTORY_FULL
	return Result.SUCCESS


func sell(offer_id: StringName, inventory: Inventory, wallet: GoldWallet) -> Result:
	var offer := _get_sell_offer(offer_id)
	if offer == null or inventory == null or wallet == null or offer.item == null:
		return Result.INVALID_OFFER
	if not inventory.has_item(offer.item.item_id):
		return Result.NOT_OWNED
	if wallet.get_balance() > GoldWallet.MAX_GOLD - offer.sell_price:
		return Result.GOLD_CAP_REACHED
	if inventory.remove_item(offer.item.item_id, 1) != 1:
		return Result.NOT_OWNED
	if not wallet.add_gold(offer.sell_price):
		inventory.add_item(offer.item, 1)
		return Result.GOLD_CAP_REACHED
	return Result.SUCCESS


func get_result_message(result: Result) -> String:
	match result:
		Result.SUCCESS:
			return "Trade complete."
		Result.INSUFFICIENT_GOLD:
			return "Not enough gold."
		Result.INVENTORY_FULL:
			return "No room for that item."
		Result.ALREADY_OWNED:
			return "You already own this."
		Result.NOT_OWNED:
			return "You do not have that item."
		Result.GOLD_CAP_REACHED:
			return "Your gold pouch is full."
		Result.GRANT_FAILED:
			return "Unable to grant that weapon."
		_:
			return "This trade is unavailable."


func _get_buy_offer(offer_id: StringName) -> MerchantOffer:
	if catalog == null:
		return null
	var offer := catalog.get_offer(offer_id)
	return offer if offer != null and offer.buy_price > 0 else null


func _get_sell_offer(offer_id: StringName) -> MerchantOffer:
	if catalog == null:
		return null
	var offer := catalog.get_offer(offer_id)
	return (
		offer
		if offer != null and offer.kind == MerchantOffer.Kind.ITEM and offer.sell_price > 0
		else null
	)
