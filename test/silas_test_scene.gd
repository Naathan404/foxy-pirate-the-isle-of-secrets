extends Node3D

## Isolated merchant sandbox. It never changes Foxy's shared starter data.
@export var starting_gold := 250

@onready var foxy: Player = $Foxy


func _ready() -> void:
	await get_tree().process_frame
	var weapons := foxy.weapon_controller
	if is_instance_valid(weapons):
		weapons.set_weapon_owned(&"bow", false)
		var progress := get_node_or_null("/root/SilasProgress") as SilasProgressStore
		if progress != null and progress.has_bow_purchase():
			weapons.grant_weapon(&"bow")
	var inventory := foxy.get_node_or_null("Inventory") as Inventory
	if inventory != null:
		inventory.remove_item(&"wooden_arrow", inventory.count_item(&"wooden_arrow"))
	var wallet := get_node("/root/GameManager").get("gold_wallet") as GoldWallet
	if wallet != null and wallet.get_balance() == 0:
		wallet.add_gold(starting_gold)
