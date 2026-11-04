class_name TortugaCatalog
extends Resource

@export var recipes: Array[TortugaRecipe] = []
@export_group("Reforge cost")
@export_range(0, 1000000, 1) var forge_gold_cost := 75
@export var forge_ingredients: Array[TortugaIngredient] = []
@export var forge_pool: WeaponForgePool


func get_recipe(weapon_id: StringName) -> TortugaRecipe:
	for recipe in recipes:
		if recipe != null and recipe.weapon != null and recipe.weapon.weapon_id == weapon_id:
			return recipe
	return null


func is_valid() -> bool:
	if forge_pool == null or not forge_pool.is_valid() or forge_gold_cost < 0:
		return false
	var seen: Dictionary[StringName, bool] = {}
	for recipe in recipes:
		if recipe == null or not recipe.is_valid() or seen.has(recipe.weapon.weapon_id):
			return false
		seen[recipe.weapon.weapon_id] = true
	for ingredient in forge_ingredients:
		if ingredient == null or not ingredient.is_valid():
			return false
	return true
