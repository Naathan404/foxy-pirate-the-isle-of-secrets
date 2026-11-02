class_name MerchantOffer
extends Resource

## One data-driven line item sold or bought by a merchant.
enum Kind { ITEM, WEAPON }

@export var offer_id: StringName
@export var kind: Kind = Kind.ITEM
@export var item: BaseItem
@export var weapon: WeaponData
@export_group("Trade configuration")
## Number of items transferred by one click. Prices below apply to this whole bundle.
@export_range(1, 100000, 1) var trade_amount := 1
@export_range(0, 1000000, 1) var buy_price := 0
@export_range(0, 1000000, 1) var sell_price := 0


func get_display_name() -> String:
	if kind == Kind.WEAPON:
		return weapon.display_name if weapon != null else "Unknown weapon"
	return item.display_name if item != null else "Unknown item"


func get_icon() -> Texture2D:
	if kind == Kind.WEAPON:
		return weapon.icon if weapon != null else null
	return item.icon if item != null else null


func is_valid() -> bool:
	if offer_id.is_empty():
		return false
	if trade_amount < 1:
		return false
	if kind == Kind.WEAPON:
		return weapon != null and not weapon.weapon_id.is_empty() and trade_amount == 1
	return item != null and not item.item_id.is_empty()
