class_name TortugaService
extends RefCounted

var catalog: TortugaCatalog
var inventory: Inventory
var wallet: GoldWallet
var weapons: WeaponController
var random := RandomNumberGenerator.new()


func _init(
	config: TortugaCatalog, bag: Inventory, gold: GoldWallet, controller: WeaponController
) -> void:
	catalog = config
	inventory = bag
	wallet = gold
	weapons = controller
	random.randomize()


func can_pay(gold_cost: int, ingredients: Array[TortugaIngredient]) -> bool:
	if inventory == null or wallet == null or not wallet.can_afford(gold_cost):
		return false
	for ingredient in ingredients:
		if ingredient == null or not ingredient.is_valid():
			return false
		if not inventory.has_item(StringName(ingredient.item.item_id), ingredient.amount):
			return false
	return true


func craft(weapon_id: StringName) -> String:
	var recipe := catalog.get_recipe(weapon_id) if catalog != null else null
	if recipe == null or not recipe.is_valid() or weapons == null:
		return "No crafting recipe for this weapon."
	if weapons.is_weapon_owned(weapon_id):
		return "Weapon already owned."
	if not weapons.is_blueprint_unlocked(weapon_id):
		return "Blueprint not unlocked."
	if not can_pay(recipe.gold_cost, recipe.ingredients):
		return "Not enough gold or materials."
	if not _pay(recipe.gold_cost, recipe.ingredients):
		return "Payment failed."
	if not weapons.grant_weapon(weapon_id):
		_refund(recipe.gold_cost, recipe.ingredients)
		return "Unable to grant weapon."
	return ""


## Payment happens when the pair is rolled. One of these two options can then be applied.
func roll_forges(weapon_id: StringName) -> Array[WeaponForge]:
	var result: Array[WeaponForge] = []
	if catalog == null or not catalog.is_valid() or weapons == null:
		return result
	if not weapons.is_weapon_owned(weapon_id):
		return result
	var pool := catalog.forge_pool
	var first := pool.roll(random)
	if first == null:
		return result
	var total := 0.0
	for forge in pool.forges:
		if forge != null and forge != first:
			total += forge.drop_weight
	if total <= 0.0 or not can_pay(catalog.forge_gold_cost, catalog.forge_ingredients):
		return result
	if not _pay(catalog.forge_gold_cost, catalog.forge_ingredients):
		return result
	var roll := random.randf() * total
	for forge in pool.forges:
		if forge == null or forge == first or forge.drop_weight <= 0.0:
			continue
		roll -= forge.drop_weight
		if roll < 0.0:
			result.assign([first, forge])
			return result
	# Floating-point boundary fallback.
	for forge in pool.forges:
		if forge != null and forge != first and forge.drop_weight > 0.0:
			result.assign([first, forge])
			return result
	_refund(catalog.forge_gold_cost, catalog.forge_ingredients)
	return result


func apply_forge(weapon_id: StringName, chosen: WeaponForge) -> bool:
	return chosen != null and weapons != null and weapons.set_weapon_forge(weapon_id, chosen)


func _pay(gold_cost: int, ingredients: Array[TortugaIngredient]) -> bool:
	if not can_pay(gold_cost, ingredients) or not wallet.try_spend(gold_cost):
		return false
	var removed: Array[TortugaIngredient] = []
	for ingredient in ingredients:
		var amount := inventory.remove_item(StringName(ingredient.item.item_id), ingredient.amount)
		if amount != ingredient.amount:
			if amount > 0:
				inventory.add_item(ingredient.item, amount)
			_refund(gold_cost, removed)
			return false
		removed.append(ingredient)
	return true


func _refund(gold_cost: int, ingredients: Array[TortugaIngredient]) -> void:
	if gold_cost > 0:
		wallet.add_gold(gold_cost)
	for ingredient in ingredients:
		inventory.add_item(ingredient.item, ingredient.amount)
