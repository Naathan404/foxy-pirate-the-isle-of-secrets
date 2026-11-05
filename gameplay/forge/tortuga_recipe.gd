class_name TortugaRecipe
extends Resource

@export var weapon: WeaponData
@export_range(0, 1000000, 1) var gold_cost := 0
@export var ingredients: Array[TortugaIngredient] = []


func is_valid() -> bool:
	if weapon == null or weapon.weapon_id.is_empty() or gold_cost < 0:
		return false
	var seen: Dictionary[String, bool] = {}
	for ingredient in ingredients:
		if ingredient == null or not ingredient.is_valid() or seen.has(ingredient.item.item_id):
			return false
		seen[ingredient.item.item_id] = true
	return true
