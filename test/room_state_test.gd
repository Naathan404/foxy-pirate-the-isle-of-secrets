extends SceneTree
## Room persistence, campfire resets and respawning, on real rooms and the real Foxy:
## - rooms keep killed enemies, broken props and opened chests between visits;
## - a rest or a death starts a new cycle that brings enemies and props back and reshuffles
##   random layouts, while opened chests stay open and are saved;
## - death respawns beside the campfire of the latest rest, the hub before any rest;
## - a fall into the void puts Foxy back at a door of the same room for a little HP, and only
##   counts as a death when that HP cost would kill her;
## - loot left on the ground is gone after leaving; PropSlot picks are stable per cycle.
## Writes only under user://test_saves/ and fails if the player's real saves change.

const SANDBOX := preload("res://test/fixtures/save_test_sandbox.gd")
const PROP_SLOT_ROOM := preload("res://test/fixtures/prop_slot_room.tscn")
const ITEM_PICKUP := preload("res://gameplay/inventory/item_pickup.tscn")
const HUB := "res://world/biomes/hub/map/castaway_cove.tscn"
const RANDOM_ROOM := "res://world/biomes/coral_valley/map/room_14.tscn"
const OTHER_ROOM := "res://world/biomes/coral_valley/map/room_02.tscn"
const CHEST_ROOM := "res://world/biomes/coral_valley/map/room_04.tscn"
const RAID_ROOM := "res://world/biomes/coral_valley/map/room_16.tscn"
const CHEST_KEY := "TreasureChest"
const KILLING_DAMAGE := 1000000.0
const MAX_CYCLE_SEARCH := 12
const LAYOUT_CYCLES := 4
const SPAWN_TOLERANCE := 0.75
const VOID_DROP_METERS := 3.0

var sandbox := SANDBOX.new()
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	sandbox.setup(self, "rooms")
	var manager := sandbox.manager
	_check(manager.start_new_game(HUB), "start a new game")
	await sandbox.wait_transition()
	await _check_respawn_before_any_rest()
	await _check_rooms_keep_state()
	await _check_rest_resets_rooms()
	await _check_death_resets_rooms()
	await _check_void_fall_returns_to_door()
	await _check_lethal_void_fall_is_death()
	await _check_chests_stay_open()
	await _check_raid_chest_stays_open()
	_check_old_save_migrates()
	await _check_prop_slots()
	_check(sandbox.teardown(), "real user saves are untouched")
	print("Room state failures: ", failures)
	quit(1 if failures > 0 else 0)


func _check_respawn_before_any_rest() -> void:
	var player: Player = sandbox.manager.player
	var inventory := player.get_node("Inventory") as Inventory
	inventory.add_item(SaveContentCatalog.find_item("coral"), 3)
	var coral := inventory.count_item(&"coral")
	_check(sandbox.manager.room_states.rest_location.is_empty(), "new game: no rest yet")
	await _die_and_respawn("fallback")
	player = sandbox.manager.player
	_check(current_scene.scene_file_path == HUB, "fallback: respawn in the hub")
	_check_at_rest_point("fallback")
	_check(
		player.hp.get_current_hp() == player.hp.get_max_hp() and not player.dead,
		"fallback: full HP and alive"
	)
	_check(
		(player.get_node("Inventory") as Inventory).count_item(&"coral") == coral,
		"fallback: progress is kept"
	)


func _check_rooms_keep_state() -> void:
	await _enter_cycle_with_enemy()
	var enemy := _stateful(current_scene, EnemyBase)[0] as EnemyBase
	var enemy_key := _key(enemy)
	var layout := _layout()
	var props := _stateful(current_scene, DestructibleProp)
	var prop_key := ""
	if not props.is_empty():
		prop_key = _key(props[0])
		_break(props[0] as DestructibleProp)
	enemy.hp.take_damage(KILLING_DAMAGE)
	var dropped := ITEM_PICKUP.instantiate() as ItemPickup
	dropped.item = SaveContentCatalog.find_item("coral")
	current_scene.add_child(dropped)
	await sandbox.frames(5)
	await _go(OTHER_ROOM)
	await _go(RANDOM_ROOM)
	var after := _layout()
	_check(not after.has(enemy_key), "killed enemy stays dead after leaving")
	_check(prop_key.is_empty() or not after.has(prop_key), "broken prop stays broken")
	var expected := layout.duplicate()
	expected.erase(enemy_key)
	expected.erase(prop_key)
	_check(after == expected, "the rest of the room keeps its layout")
	_check(
		current_scene.find_children("*", "ItemPickup", true, false).is_empty(),
		"loot left on the ground is gone"
	)


func _check_rest_resets_rooms() -> void:
	await _go(HUB)
	var registry: RoomStateRegistry = sandbox.manager.room_states
	var seed_before := registry.cycle_seed
	var rest_point: CampfireRestPoint = sandbox.find_rest_points(current_scene)[0]
	_check(rest_point.rest(sandbox.manager.player), "rest at the hub campfire")
	_check(await sandbox.choose_rest_and_wait(rest_point, false), "REST finishes after the fade")
	_check(not rest_point.is_menu_open(), "REST closes the menu")
	_check(registry.cycle_seed != seed_before, "rest starts a new cycle")
	_check(registry.rest_location == rest_point.get_location(), "rest sets the respawn point")
	_check(not FileAccess.file_exists(sandbox.slot_path), "resting alone does not save")
	await _enter_cycle_with_enemy()
	var full_layout := _layout()
	var enemy := _stateful(current_scene, EnemyBase)[0] as EnemyBase
	var enemy_key := _key(enemy)
	enemy.hp.take_damage(KILLING_DAMAGE)
	await sandbox.frames(3)
	var killed_seed := registry.cycle_seed
	registry.begin_new_cycle(registry.rest_location)
	# Pin the old seed so the layout cannot reshuffle: only the reset itself is observed.
	registry.cycle_seed = killed_seed
	await _go(OTHER_ROOM)
	await _go(RANDOM_ROOM)
	_check(_layout() == full_layout and _layout().has(enemy_key), "reset brings enemies back")
	registry.begin_new_cycle(registry.rest_location)
	var layouts := {}
	for index: int in LAYOUT_CYCLES:
		await _go(RANDOM_ROOM)
		var layout := _layout()
		_check(not layout.is_empty(), "cycle %d: the room is populated" % index)
		await _go(OTHER_ROOM)
		await _go(RANDOM_ROOM)
		_check(_layout() == layout, "cycle %d: layout is stable between visits" % index)
		layouts[var_to_str(layout)] = true
		registry.begin_new_cycle(registry.rest_location)
	_check(layouts.size() > 1, "new cycles reshuffle the random layout")


func _check_death_resets_rooms() -> void:
	await _enter_cycle_with_enemy()
	var enemy := _stateful(current_scene, EnemyBase)[0] as EnemyBase
	var enemy_key := _key(enemy)
	enemy.hp.take_damage(KILLING_DAMAGE)
	await sandbox.frames(3)
	var cycle_before: int = sandbox.manager.room_states.cycle
	await _die_and_respawn("death")
	_check(current_scene.scene_file_path == HUB, "death: back to the latest rest")
	_check_at_rest_point("death")
	_check(sandbox.manager.room_states.cycle > cycle_before, "death starts a new cycle")
	_check(
		not sandbox.manager.room_states.is_cleared(RANDOM_ROOM, enemy_key),
		"death: killed enemies are no longer remembered"
	)


func _check_void_fall_returns_to_door() -> void:
	await _go(RANDOM_ROOM)
	var room := current_scene as BaseRoom
	var player: Player = sandbox.manager.player
	var cycle_before: int = sandbox.manager.room_states.cycle
	var hp_before := player.hp.get_current_hp()
	var fall_from := player.global_position
	await _drop_into_void(room)
	_check(player.falling_into_void, "void: the fall sequence starts")
	var sequence := room.get_node_or_null("VoidFallSequence") as VoidFallSequence
	_check(sequence != null, "void: the screen closes on Foxy")
	if sequence != null:
		await sequence.finished
	_check(current_scene == room, "void: still in the same room")
	_check(not player.dead and not player.falling_into_void, "void: Foxy is back in control")
	_check(
		is_equal_approx(player.hp.get_current_hp(), hp_before - room.void_fall_damage),
		"void: the fall costs void_fall_damage HP"
	)
	var ground_mask := player.collision_mask & ~CombatLayers.PLAYER_BOUNDARY
	var expected := room.get_void_respawn_position(fall_from, ground_mask)
	_check(player.global_position.distance_to(expected) < SPAWN_TOLERANCE, "void: back at a door")
	_check(sandbox.manager.room_states.cycle == cycle_before, "void: no new cycle")
	await sandbox.frames(30)
	_check(
		player.is_on_floor() and not player.falling_into_void, "void: stands on ground at the door"
	)


func _check_lethal_void_fall_is_death() -> void:
	await _go(RANDOM_ROOM)
	var room := current_scene as BaseRoom
	var player: Player = sandbox.manager.player
	player.hp.set_current_hp(room.void_fall_damage)
	await _drop_into_void(room)
	var sequence := room.get_node_or_null("VoidFallSequence") as VoidFallSequence
	while is_instance_valid(player) and not player.dead and is_instance_valid(sequence):
		await process_frame
	_check(is_instance_valid(player) and player.dead, "lethal void: Foxy dies")
	await _wait_respawn()
	_check(current_scene.scene_file_path == HUB, "lethal void: respawn at the latest rest")
	_check_at_rest_point("lethal void")


func _drop_into_void(room: BaseRoom) -> void:
	var player: Player = sandbox.manager.player
	player.global_position = room.to_global(Vector3(0, room.void_height - VOID_DROP_METERS, 0))
	player.reset_physics_interpolation()
	await sandbox.frames(3)


func _check_chests_stay_open() -> void:
	await _go(CHEST_ROOM)
	var chest := current_scene.get_node(CHEST_KEY) as TreasureChest
	_check(not _is_open(chest), "chest starts closed")
	_break(chest)
	await sandbox.frames(3)
	_check(_is_open(chest), "chest opens")
	await _go(OTHER_ROOM)
	await _go(CHEST_ROOM)
	_check(_is_open(current_scene.get_node(CHEST_KEY)), "chest stays open after leaving")
	await _rest_in_hub_and_save()
	await _go(CHEST_ROOM)
	_check(_is_open(current_scene.get_node(CHEST_KEY)), "chest stays open after a rest")
	var saved: Dictionary = sandbox.read_slot_payload()
	_check(
		(
			saved.get("version") == GameSaveSnapshot.VERSION
			and Array(saved.world.rooms.permanent.get(CHEST_ROOM, [])).has(CHEST_KEY)
		),
		"the opened chest is saved"
	)
	_check(sandbox.manager.return_to_main_menu(), "back to the main menu")
	await sandbox.wait_transition()
	(current_scene.get_node("%ContinueButton") as Button).pressed.emit()
	var load_error: Error = await sandbox.manager.saved_game_loaded
	_check(load_error == OK, "continue the saved game")
	await sandbox.frames(2)
	_check(
		sandbox.manager.room_states.rest_location.get("scene") == HUB,
		"continue: respawn point is the saved campfire"
	)
	await _go(CHEST_ROOM)
	_check(_is_open(current_scene.get_node(CHEST_KEY)), "chest stays open after Continue")
	_check(sandbox.manager.start_new_game(HUB), "new game")
	await sandbox.wait_transition()
	await _go(CHEST_ROOM)
	_check(not _is_open(current_scene.get_node(CHEST_KEY)), "new game: chest is closed again")


func _check_raid_chest_stays_open() -> void:
	var raid := (load(RAID_ROOM) as PackedScene).instantiate()
	var flag: StringName = raid.get_node("Raid/Stage").stage_id
	raid.free()
	sandbox.manager.set_story_flag(flag)
	await _go(RAID_ROOM)
	var chest := _find_chest()
	_check(chest != null and not _is_open(chest), "cleared raid shows its reward chest")
	if chest == null:
		return
	_break(chest)
	await sandbox.frames(3)
	await _go(OTHER_ROOM)
	await _go(RAID_ROOM)
	var again := _find_chest()
	_check(again != null and _is_open(again), "raid reward chest stays open")


func _check_old_save_migrates() -> void:
	var payload: Dictionary = sandbox.read_slot_payload()
	payload.version = GameSaveSnapshot.VERSION_WITHOUT_ROOMS
	payload.world.erase("rooms")
	sandbox.write_slot_payload(payload)
	var result: SaveGameFile.ReadResult = sandbox.manager.save_slot.read()
	_check(result.error == OK, "version 1 save still loads")
	_check(
		(
			result.payload.version == GameSaveSnapshot.VERSION
			and result.payload.world.rooms.permanent.is_empty()
		),
		"version 1 save gains an empty room section"
	)


func _check_prop_slots() -> void:
	var registry: RoomStateRegistry = sandbox.manager.room_states
	var first := await _slot_layout()
	_check(first == await _slot_layout(), "prop slots repeat within a cycle")
	var room := await _add_slot_room()
	for slot: PropSlot in _slots(room):
		if slot.name == "EmptySlot":
			_check(slot.prop == null, "empty-chance slot stays empty")
			continue
		_check(slot.prop != null, "%s places a prop" % slot.name)
		var offset := slot.prop.position
		_check(
			Vector2(offset.x, offset.z).length() <= slot.jitter_radius_meters + 0.001,
			"%s stays inside its jitter radius" % slot.name
		)
		var breakable := slot.prop as DestructibleProp
		var expected_item: BaseItem = slot.drop_item
		_check(
			(
				breakable.drop_item == expected_item
				and breakable.drop_chance == (slot.drop_chance if expected_item != null else 0.0)
			),
			"%s loot comes from the slot" % slot.name
		)
	var broken: DestructibleProp = (room.get_node("Slots/SlotA") as PropSlot).prop
	_break(broken)
	await sandbox.frames(3)
	room.queue_free()
	await sandbox.frames(2)
	room = await _add_slot_room()
	_check(
		(
			(room.get_node("Slots/SlotA") as PropSlot).prop == null
			or not is_instance_valid((room.get_node("Slots/SlotA") as PropSlot).prop)
			or (room.get_node("Slots/SlotA") as PropSlot).prop.is_queued_for_deletion()
		),
		"a broken slot prop stays broken within the cycle"
	)
	room.queue_free()
	await sandbox.frames(2)
	var layouts := {var_to_str(first): true}
	for index: int in LAYOUT_CYCLES:
		registry.begin_new_cycle(registry.rest_location)
		layouts[var_to_str(await _slot_layout())] = true
	_check(layouts.size() > 1, "prop slots change with new cycles")


func _slot_layout() -> Array[String]:
	var room := await _add_slot_room()
	var layout: Array[String] = []
	for slot: PropSlot in _slots(room):
		if slot.prop == null:
			layout.append("%s:empty" % slot.name)
			continue
		layout.append(
			(
				"%s:%s@%s*%s"
				% [
					slot.name,
					slot.prop.scene_file_path,
					slot.prop.position.snapped(Vector3.ONE * 0.001),
					slot.prop.scale.snapped(Vector3.ONE * 0.001)
				]
			)
		)
	room.queue_free()
	await sandbox.frames(2)
	return layout


func _add_slot_room() -> BaseRoom:
	var room := PROP_SLOT_ROOM.instantiate() as BaseRoom
	root.add_child(room)
	await sandbox.frames(1)
	return room


func _slots(room: Node) -> Array[PropSlot]:
	var slots: Array[PropSlot] = []
	for node: Node in room.get_node("Slots").get_children():
		slots.append(node as PropSlot)
	return slots


## Re-rolls cycles until the random room has a living enemy (hand-placed in room_14).
func _enter_cycle_with_enemy() -> void:
	var registry: RoomStateRegistry = sandbox.manager.room_states
	for attempt: int in MAX_CYCLE_SEARCH:
		await _go(RANDOM_ROOM)
		if not _stateful(current_scene, EnemyBase).is_empty():
			return
		registry.begin_new_cycle(registry.rest_location)
	_check(false, "found a random-room layout with enemies")


func _rest_in_hub_and_save() -> void:
	await _go(HUB)
	var rest_point: CampfireRestPoint = sandbox.find_rest_points(current_scene)[0]
	_check(rest_point.rest(sandbox.manager.player), "open the hub campfire menu")
	await sandbox.choose_rest_and_wait(rest_point, true)
	rest_point.close_menu()


func _die_and_respawn(label: String) -> void:
	var player: Player = sandbox.manager.player
	player.die()
	await sandbox.frames(2)
	_check(player.dead, label + ": Foxy dies")
	await _wait_respawn()


## The death state waits for its animation, then the respawn transition runs to the end.
func _wait_respawn() -> void:
	await sandbox.wait_transition()
	var player: Player = sandbox.manager.player
	_check(
		is_instance_valid(player) and not player.dead and current_scene.is_ancestor_of(player),
		"respawned Foxy is alive in the new room"
	)


func _check_at_rest_point(label: String) -> void:
	var rest_point: CampfireRestPoint = sandbox.find_rest_points(current_scene)[0]
	var player: Player = sandbox.manager.player
	_check(
		player.global_position.distance_to(rest_point.get_spawn_position()) < SPAWN_TOLERANCE,
		label + ": beside the campfire"
	)


func _go(scene_path: String) -> void:
	_check(sandbox.manager.change_scene(scene_path), "enter " + scene_path.get_file())
	await sandbox.wait_transition()


## Which objects exist and what they are; props also by position. Enemies start walking
## as soon as they spawn, so their position says nothing about the layout.
func _layout() -> Dictionary:
	var layout := {}
	for node: Node in _stateful(current_scene, Node):
		var entry := node.scene_file_path
		if node is DestructibleProp:
			entry += "@%s" % (node as Node3D).position.snapped(Vector3.ONE * 0.001)
		layout[_key(node)] = entry
	return layout


## Enemies and breakable props that the room tracks, excluding ones already removed.
func _stateful(scene: Node, type: Variant) -> Array[Node]:
	var result: Array[Node] = []
	for node: Node in scene.find_children("*", "", true, false):
		if not (node is EnemyBase or node is DestructibleProp) or node is TreasureChest:
			continue
		if node.is_queued_for_deletion() or not is_instance_of(node, type):
			continue
		if node is EnemyBase and (node as EnemyBase).hp.get_current_hp() <= 0.0:
			continue
		result.append(node)
	return result


func _key(node: Node) -> String:
	return String(current_scene.get_path_to(node))


func _break(prop: DestructibleProp) -> void:
	var damage := DamageContext.new()
	damage.source_team = CombatTeams.PLAYER
	damage.amount_hp = KILLING_DAMAGE
	damage.base_amount_hp = KILLING_DAMAGE
	prop.receive_damage(damage)


func _is_open(chest: Node) -> bool:
	var sprite := (chest as TreasureChest).visual_root as Sprite3D
	return sprite != null and sprite.texture == (chest as TreasureChest).depleted_texture


func _find_chest() -> TreasureChest:
	for node: Node in current_scene.find_children("*", "", true, false):
		if node is TreasureChest:
			return node as TreasureChest
	return null


func _check(condition: bool, label: String) -> bool:
	if condition:
		print("PASS ", label)
		return true
	failures += 1
	push_warning("FAIL " + label)
	print("FAIL ", label)
	return false
