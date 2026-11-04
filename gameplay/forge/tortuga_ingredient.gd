class_name TortugaIngredient
extends Resource

@export var item: BaseItem
@export_range(1, 999, 1) var amount := 1


func is_valid() -> bool:
	return item != null and not item.item_id.is_empty() and amount > 0
