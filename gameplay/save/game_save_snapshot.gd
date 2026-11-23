class_name GameSaveSnapshot
extends RefCounted
## Converts the persistent game state to a JSON-safe Dictionary and back.
## Saves hold stable IDs (item_id, weapon_id, forge_id, charm ID, scene path) only, never
## live nodes, resources or instance IDs. `validate()` rejects malformed data before any
## state changes; unknown content IDs inside a valid save are dropped with a warning so a
## removed item cannot crash a load.

const FORMAT_ID := "foxy_pirate_save"
## Bump when the layout changes, and convert older payloads before `validate()`.
const VERSION := 1
## JSON numbers are doubles; larger integers would silently lose precision.
const MAX_JSON_INTEGER := 9007199254740991
const VECTOR_COMPONENTS := 3


static func capture(
	player: Player,
	location: Dictionary,
	session: Node,
	merchant: SilasProgressStore,
	notes: Node,
) -> Dictionary:
	return {
		"format": FORMAT_ID,
		"version": VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"location": location.duplicate(),
		"player": _capture_player(player),
		"world": _capture_world(session),
		"merchant": merchant.get_save_data(),
		"notes": notes.get_save_data(),
	}


static func is_unsupported_version(payload: Dictionary) -> bool:
	var version: Variant = payload.get("version")
	return _is_integer(version, 1, MAX_JSON_INTEGER) and int(version) > VERSION


## Returns an empty String when the payload can be applied, otherwise the reason.
static func validate(payload: Dictionary) -> String:
	if payload.get("format") != FORMAT_ID:
		return "This is not a Foxy Pirate save file."
	if is_unsupported_version(payload):
		return "This save was made by a newer version of the game."
	if not _is_integer(payload.get("version"), VERSION, VERSION):
		return "The save version is not supported."
	if not _is_integer(payload.get("saved_at_unix"), 0, MAX_JSON_INTEGER):
		return "The save time is missing."
	var location: Variant = payload.get("location")
	if (
		not location is Dictionary
		or not _is_text(location.get("scene"))
		or not String(location.get("scene")).begins_with("res://")
		or not _is_text(location.get("rest_point"))
	):
		return "The save location is missing."
	for problem: String in [
		_validate_player(payload.get("player")),
		_validate_world(payload.get("world")),
		_validate_merchant(payload.get("merchant")),
		_validate_notes(payload.get("notes")),
	]:
		if not problem.is_empty():
			return problem
	return ""


static func get_scene_path(payload: Dictionary) -> String:
	return String(payload.location.scene)


static func get_rest_point_path(payload: Dictionary) -> NodePath:
	return NodePath(String(payload.location.rest_point))


## Session state lives on autoloads and must be restored before the saved room is built,
## because rooms read it in _ready (for example a defeated boss).
static func restore_world(
	payload: Dictionary, session: Node, merchant: SilasProgressStore, notes: Node
) -> void:
	var world: Dictionary = payload.world
	session.reset_session()
	session.gold_wallet.restore_balance(int(world.gold))
	var visited: Array[String] = []
	for scene_path: Variant in world.visited_rooms:
		if ResourceLoader.exists(String(scene_path), "PackedScene"):
			visited.append(String(scene_path))
	session.map_progress.restore(visited, String(world.current_room))
	for flag: Variant in world.story_flags:
		session.set_story_flag(StringName(String(flag)))
	for encounter_id: String in world.boss_encounters:
		session.boss_encounters[StringName(encounter_id)] = _read_boss_encounter(
			world.boss_encounters[encounter_id]
		)
	merchant.apply_save_data(payload.merchant)
	notes.apply_save_data(payload.notes)


## Applies saved progression to a freshly built Player. Order matters: weapons and
## inventory first, then Charms (which may change max HP/SP), then vitals.
static func restore_player(payload: Dictionary, player: Player) -> void:
	var data: Dictionary = payload.player
	_restore_weapons(data.weapons, player.weapon_controller)
	var inventory := player.get_node("Inventory") as Inventory
	_restore_inventory(data.inventory, inventory)
	_restore_potions(data.potions, player.potion, inventory)
	if is_instance_valid(player.charm_socket_manager) and is_instance_valid(player.charm_registry):
		if not CharmProgressionSnapshot.restore(
			data.charms, player.charm_socket_manager, player.charm_registry
		):
			push_warning("GameSaveSnapshot: Charm progression could not be restored")
	player.hp.set_current_hp(minf(float(data.hp), player.hp.get_max_hp()))
	player.stamina.set_current_sp(minf(float(data.sp), player.stamina.get_max_sp()))
	# Chaos is a combat meter that decays when idle, so a load always starts empty.
	player.chaos.consume(player.chaos.current)
	var facing := _read_vector(data.facing)
	if not facing.is_zero_approx():
		player.last_facing_direction = facing.normalized()


static func _capture_player(player: Player) -> Dictionary:
	var inventory := player.get_node("Inventory") as Inventory
	var slots: Array = []
	for slot: InventorySlot in inventory.slots:
		slots.append(
			null if slot.is_empty() else {"item": slot.item.item_id, "quantity": slot.quantity}
		)
	var capacities := {}
	for kind_name: String in Potion.Kind.keys():
		capacities[kind_name] = inventory.get_potion_capacity(Potion.Kind[kind_name])
	var weapons := player.weapon_controller
	var entries: Array = []
	for entry: WeaponCollectionEntry in weapons.collection:
		var forge_id := &""
		var owned_weapon := _find_owned_weapon(weapons, entry.definition.weapon_id)
		var forge: WeaponForge = entry.forge
		if owned_weapon != null:
			forge = owned_weapon.forge
		if forge != null:
			forge_id = forge.forge_id
		(
			entries
			. append(
				{
					"weapon": String(entry.definition.weapon_id),
					"blueprint_unlocked": entry.blueprint_unlocked,
					"owned": entry.owned,
					"forge": String(forge_id),
				}
			)
		)
	var equipped_id := ""
	if weapons.equipped != null and weapons.equipped.definition != null:
		equipped_id = String(weapons.equipped.definition.weapon_id)
	var charms := {}
	if is_instance_valid(player.charm_socket_manager):
		charms = CharmProgressionSnapshot.capture(
			player.charm_socket_manager, player.charm_registry
		)
	return {
		"hp": player.hp.get_current_hp(),
		"sp": player.stamina.get_current_sp(),
		"facing": _write_vector(player.last_facing_direction),
		"inventory": {"slots": slots, "potion_capacities": capacities},
		"potions":
		{
			"primary": _item_id_or_empty(player.potion.equipped_potion),
			"secondary": _item_id_or_empty(player.potion.secondary_potion),
		},
		"weapons": {"entries": entries, "equipped": equipped_id},
		"charms": charms,
	}


static func _capture_world(session: Node) -> Dictionary:
	var flags: Array[String] = []
	for flag: StringName in session.story_flags:
		if session.story_flags[flag]:
			flags.append(String(flag))
	flags.sort()
	var encounters := {}
	for encounter_id: StringName in session.boss_encounters:
		var state: Dictionary = session.boss_encounters[encounter_id]
		# An undefeated encounter is rebuilt from its room, so only defeats are progress.
		if bool(state.get("defeated", false)):
			encounters[String(encounter_id)] = _write_boss_encounter(state)
	return {
		"gold": session.gold_wallet.get_balance(),
		"visited_rooms": Array(session.map_progress.get_visited_rooms()),
		"current_room": session.map_progress.current_room,
		"story_flags": flags,
		"boss_encounters": encounters,
	}


static func _write_boss_encounter(state: Dictionary) -> Dictionary:
	var items: Array = []
	var stored_items: Dictionary = state.get("items", {})
	for index: int in stored_items:
		var entry: Dictionary = stored_items[index]
		var item := entry.get("item") as BaseItem
		if item == null or int(entry.get("quantity", 0)) <= 0:
			continue
		(
			items
			. append(
				{
					"index": index,
					"item": item.item_id,
					"quantity": int(entry.quantity),
					"position": _write_vector(entry.get("position", Vector3.ZERO)),
				}
			)
		)
	return {
		"opened": bool(state.get("opened", false)),
		"position": _write_vector(state.get("position", Vector3.ZERO)),
		"items": items,
	}


static func _read_boss_encounter(saved: Dictionary) -> Dictionary:
	var items := {}
	for entry: Dictionary in saved.items:
		var item := SaveContentCatalog.find_item(String(entry.item))
		if item == null:
			push_warning("GameSaveSnapshot: unknown boss reward item '%s'" % entry.item)
			continue
		items[int(entry.index)] = {
			"item": item,
			"quantity": mini(int(entry.quantity), item.max_stack),
			"position": _read_vector(entry.position),
		}
	return {
		"defeated": true,
		"opened": bool(saved.opened),
		"position": _read_vector(saved.position),
		"items": items,
	}


static func _restore_inventory(saved: Dictionary, inventory: Inventory) -> void:
	inventory.clear()
	# Capacities go first, while the bag is empty, so no limit rejects a carried bottle.
	for kind_name: String in saved.potion_capacities:
		if Potion.Kind.has(kind_name):
			inventory.set_potion_capacity(
				Potion.Kind[kind_name], int(saved.potion_capacities[kind_name])
			)
	var overflow: Array[InventorySlot] = []
	var saved_slots: Array = saved.slots
	for index: int in saved_slots.size():
		var entry: Variant = saved_slots[index]
		if entry == null:
			continue
		var item := SaveContentCatalog.find_item(String(entry.item))
		if item == null:
			push_warning("GameSaveSnapshot: dropping unknown item '%s'" % entry.item)
			continue
		var quantity := mini(int(entry.quantity), item.max_stack)
		var slot := inventory.get_slot(index)
		if slot == null:
			var extra := InventorySlot.new()
			extra.item = item
			extra.quantity = quantity
			overflow.append(extra)
			continue
		slot.item = item
		slot.quantity = quantity
	for extra: InventorySlot in overflow:
		if inventory.add_item(extra.item, extra.quantity) > 0:
			push_warning("GameSaveSnapshot: no room for saved '%s'" % extra.item.item_id)
	inventory.changed.emit()


static func _restore_potions(
	saved: Dictionary, potions: PotionComponent, inventory: Inventory
) -> void:
	potions.equipped_potion = _find_carried_potion(String(saved.primary), inventory)
	potions.secondary_potion = _find_carried_potion(String(saved.secondary), inventory)
	potions.equipped_potion_changed.emit(potions.equipped_potion)
	potions.secondary_potion_changed.emit(potions.secondary_potion)


## A quick-slot only points at a bottle kind the bag still carries.
static func _find_carried_potion(item_id: String, inventory: Inventory) -> Potion:
	var potion := SaveContentCatalog.find_item(item_id) as Potion
	return potion if potion != null and inventory.has_item(potion.item_id) else null


static func _restore_weapons(saved: Dictionary, weapons: WeaponController) -> void:
	var released: Array[StringName] = []
	for entry: Dictionary in saved.entries:
		var weapon_id := StringName(String(entry.weapon))
		if not weapons.has_weapon_definition(weapon_id):
			push_warning("GameSaveSnapshot: dropping unknown weapon '%s'" % weapon_id)
			continue
		weapons.set_blueprint_unlocked(weapon_id, bool(entry.blueprint_unlocked))
		if not bool(entry.owned):
			# Removed after the saved weapon is equipped, so the hand is never empty.
			released.append(weapon_id)
			continue
		weapons.set_weapon_owned(weapon_id, true)
		var forge_id := StringName(String(entry.forge))
		if forge_id.is_empty():
			weapons.set_weapon_forge(weapon_id, null)
			continue
		var forge := SaveContentCatalog.find_forge(forge_id)
		if forge != null:
			weapons.set_weapon_forge(weapon_id, forge)
		else:
			push_warning("GameSaveSnapshot: unknown forge '%s' kept as configured" % forge_id)
	var equipped_id := StringName(String(saved.equipped))
	var equipped := _find_owned_weapon(weapons, equipped_id)
	if equipped != null and weapons.equipped != equipped and not weapons.equip(equipped):
		push_warning("GameSaveSnapshot: saved weapon '%s' cannot be equipped" % equipped_id)
	for weapon_id: StringName in released:
		weapons.set_weapon_owned(weapon_id, false)
	if weapons.equipped == null and not weapons.get_owned_weapons().is_empty():
		weapons.equip(weapons.get_owned_weapons()[0])


static func _find_owned_weapon(weapons: WeaponController, weapon_id: StringName) -> WeaponInstance:
	for weapon: WeaponInstance in weapons.get_owned_weapons():
		if weapon.definition != null and weapon.definition.weapon_id == weapon_id:
			return weapon
	return null


static func _validate_player(value: Variant) -> String:
	if not value is Dictionary:
		return "Player data is missing."
	var player: Dictionary = value
	if not _is_number(player.get("hp")) or float(player.hp) <= 0.0:
		return "Player HP is invalid."
	if not _is_number(player.get("sp")) or float(player.sp) < 0.0:
		return "Player SP is invalid."
	if not _is_vector(player.get("facing")):
		return "Player facing is invalid."
	var inventory: Variant = player.get("inventory")
	if (
		not inventory is Dictionary
		or not inventory.get("slots") is Array
		or not inventory.get("potion_capacities") is Dictionary
	):
		return "Inventory data is missing."
	for entry: Variant in inventory.slots:
		if entry == null:
			continue
		if (
			not entry is Dictionary
			or not _is_text(entry.get("item"))
			or not _is_integer(entry.get("quantity"), 1, MAX_JSON_INTEGER)
		):
			return "An inventory slot is invalid."
	for capacity: Variant in inventory.potion_capacities.values():
		if not _is_integer(capacity, 0, MAX_JSON_INTEGER):
			return "A potion capacity is invalid."
	var potions: Variant = player.get("potions")
	if (
		not potions is Dictionary
		or not potions.get("primary") is String
		or not potions.get("secondary") is String
	):
		return "Equipped potions are invalid."
	var weapons: Variant = player.get("weapons")
	if (
		not weapons is Dictionary
		or not weapons.get("entries") is Array
		or not weapons.get("equipped") is String
	):
		return "Weapon data is missing."
	for entry: Variant in weapons.entries:
		if (
			not entry is Dictionary
			or not _is_text(entry.get("weapon"))
			or not entry.get("blueprint_unlocked") is bool
			or not entry.get("owned") is bool
			or not entry.get("forge") is String
		):
			return "A weapon entry is invalid."
	return _validate_charms(player.get("charms"))


static func _validate_charms(value: Variant) -> String:
	if not value is Dictionary:
		return "Charm data is missing."
	var charms: Dictionary = value
	# A Player without a Charm manager saves an empty section; restoring it is a no-op.
	if charms.is_empty():
		return ""
	if (
		not _is_integer(charms.get("unlocked_socket_count"), 0, CharmConstants.MAX_SOCKET_COUNT)
		or not _is_text_array(charms.get("owned_charm_ids"))
		or not _is_text_array(charms.get("equipped_charm_ids"), true)
	):
		return "Charm data is invalid."
	return ""


static func _validate_world(value: Variant) -> String:
	if not value is Dictionary:
		return "World progress is missing."
	var world: Dictionary = value
	if not _is_integer(world.get("gold"), 0, MAX_JSON_INTEGER):
		return "Gold is invalid."
	if (
		not _is_text_array(world.get("visited_rooms"))
		or not world.get("current_room") is String
		or not _is_text_array(world.get("story_flags"))
		or not world.get("boss_encounters") is Dictionary
	):
		return "World progress is invalid."
	for encounter: Variant in world.boss_encounters.values():
		if (
			not encounter is Dictionary
			or not encounter.get("opened") is bool
			or not _is_vector(encounter.get("position"))
			or not encounter.get("items") is Array
		):
			return "A boss encounter is invalid."
		for item: Variant in encounter.items:
			if (
				not item is Dictionary
				or not _is_integer(item.get("index"), 0, MAX_JSON_INTEGER)
				or not _is_text(item.get("item"))
				or not _is_integer(item.get("quantity"), 1, MAX_JSON_INTEGER)
				or not _is_vector(item.get("position"))
			):
				return "A boss reward is invalid."
	return ""


static func _validate_merchant(value: Variant) -> String:
	if (
		not value is Dictionary
		or not value.get("met_silas") is bool
		or not value.get("bow_purchased") is bool
	):
		return "Merchant progress is invalid."
	return ""


static func _validate_notes(value: Variant) -> String:
	if not value is Dictionary or not value.get("unlocked") is Dictionary:
		return "Note progress is invalid."
	for unlocked: Variant in value.unlocked.values():
		if not unlocked is bool:
			return "Note progress is invalid."
	return ""


static func _is_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


## JSON parses every number as a float, so whole floats count as integers.
static func _is_integer(value: Variant, minimum: int, maximum: int) -> bool:
	if not _is_number(value):
		return false
	var number := float(value)
	return number == floorf(number) and number >= minimum and number <= maximum


static func _is_text(value: Variant) -> bool:
	return value is String and not String(value).is_empty()


static func _is_text_array(value: Variant, allow_empty_entries: bool = false) -> bool:
	if not value is Array:
		return false
	for entry: Variant in value:
		if not entry is String or (not allow_empty_entries and String(entry).is_empty()):
			return false
	return true


static func _is_vector(value: Variant) -> bool:
	if not value is Array or value.size() != VECTOR_COMPONENTS:
		return false
	for component: Variant in value:
		if not _is_number(component):
			return false
	return true


static func _write_vector(vector: Vector3) -> Array:
	return [vector.x, vector.y, vector.z]


static func _read_vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


static func _item_id_or_empty(item: BaseItem) -> String:
	return item.item_id if item != null else ""
