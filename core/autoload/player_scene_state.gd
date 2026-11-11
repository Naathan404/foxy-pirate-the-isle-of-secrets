class_name PlayerSceneState
extends RefCounted
## Player progress kept in memory while GameManager replaces a map scene.

var hp: float
var sp: float
var chaos: float
var facing: Vector3
var inventory_slots: Array[InventorySlot] = []
var potion_capacities: Dictionary = {}
var primary_potion: Potion
var secondary_potion: Potion
var weapon_entries: Array[WeaponCollectionEntry] = []
var equipped_weapon_id: StringName = &""
var owned_charms: Array[StringName] = []
var unlocked_sockets: int = 0
var equipped_charms: Dictionary[int, StringName] = {}


func capture(player: Player) -> void:
	hp = player.hp.current_hp
	sp = player.stamina.current_sp
	chaos = player.chaos.current
	facing = player.last_facing_direction
	var inventory := player.get_node("Inventory") as Inventory
	for slot: InventorySlot in inventory.slots:
		inventory_slots.append(slot.duplicate() as InventorySlot)
	for kind: int in Potion.Kind.values():
		potion_capacities[kind] = inventory.get_potion_capacity(kind)
	primary_potion = player.potion.equipped_potion
	secondary_potion = player.potion.secondary_potion
	for entry: WeaponCollectionEntry in player.weapon_controller.collection:
		weapon_entries.append(entry.duplicate(true) as WeaponCollectionEntry)
	if player.weapon_controller.equipped != null:
		equipped_weapon_id = player.weapon_controller.equipped.definition.weapon_id
	if is_instance_valid(player.charm_registry):
		owned_charms = player.charm_registry.get_owned_ids()
	if is_instance_valid(player.charm_socket_manager):
		var loadout := player.charm_socket_manager.loadout
		unlocked_sockets = loadout.unlocked_socket_count
		equipped_charms = loadout.equipped_charm_ids.duplicate()


## A room reload restores progression but starts the new player at full health and stamina.
func restore(player: Player, restore_vitals: bool = true) -> void:
	var inventory := player.get_node("Inventory") as Inventory
	inventory.slots.clear()
	for slot: InventorySlot in inventory_slots:
		inventory.slots.append(slot.duplicate() as InventorySlot)
	for kind: int in potion_capacities:
		inventory.set_potion_capacity(kind, int(potion_capacities[kind]))
	inventory.changed.emit()

	var weapons := player.weapon_controller
	for source: WeaponCollectionEntry in weapon_entries:
		var weapon_id := source.definition.weapon_id
		weapons.set_blueprint_unlocked(weapon_id, source.blueprint_unlocked)
		weapons.set_weapon_owned(weapon_id, source.owned)
		if source.owned:
			weapons.set_weapon_forge(weapon_id, source.forge)
	if not equipped_weapon_id.is_empty():
		for weapon: WeaponInstance in weapons.get_owned_weapons():
			if weapon.definition.weapon_id == equipped_weapon_id:
				weapons.equip(weapon)
				break

	if is_instance_valid(player.charm_registry):
		for charm_id: StringName in player.charm_registry.get_registered_ids():
			player.charm_registry.set_owned(charm_id, owned_charms.has(charm_id))
	if is_instance_valid(player.charm_socket_manager):
		player.charm_socket_manager.restore_progression(unlocked_sockets, equipped_charms)

	if restore_vitals:
		player.hp.set_current_hp(hp)
		player.stamina.set_current_sp(sp)
		player.chaos.gain(chaos)
	else:
		player.hp.set_current_hp(player.hp.get_max_hp())
		player.stamina.set_current_sp(player.stamina.get_max_sp())
	player.last_facing_direction = facing
	player.potion.equipped_potion = primary_potion
	player.potion.secondary_potion = secondary_potion
	player.potion.equipped_potion_changed.emit(primary_potion)
	player.potion.secondary_potion_changed.emit(secondary_potion)
