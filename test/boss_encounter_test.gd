extends SceneTree

const ROOM := preload("res://world/coral_valley/scenes/stages/blubberbeard_room.tscn")
const STAGE := preload("res://world/coral_valley/scenes/stages/stage5.tscn")
const EXIT_CATALOG := preload("res://world/components/scene_exit_catalog.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := root.get_node("GameManager")
	manager.boss_encounters.clear()
	var stage := STAGE.instantiate() as Node3D
	root.add_child(stage)
	var gate := stage.get_node("BossGate") as SceneChangeTrigger
	_check(stage.has_node("Foxy"), "Stage 5 has no player for the boss route")
	_check(
		(
			(
				gate.destination_scene
				== "res://world/coral_valley/scenes/stages/blubberbeard_room.tscn"
			)
			and EXIT_CATALOG.get_exit_ids(gate.destination_scene).has(
				String(gate.destination_trigger_id)
			)
		),
		"Boss gate points to a missing entrance"
	)
	stage.queue_free()
	await process_frame
	var room := _new_room()
	await process_frame
	var boss := room.get_node("CaptainBlubberbeard") as BossBase
	var player := room.get_node("Foxy") as Player
	player.set_physics_process(false)
	_check_size(boss, player)
	_check(
		(
			(
				room.get("left_destination_scene")
				== "res://world/coral_valley/scenes/stages/stage5.tscn"
			)
			and EXIT_CATALOG.get_exit_ids(room.get("left_destination_scene")).has("stage5_boss")
		),
		"The boss room return gate is invalid"
	)
	boss.take_damage(500.0)
	(boss as BlubberbeardBoss).sound.stop()
	room.queue_free()
	await process_frame
	room = _new_room()
	await process_frame
	await process_frame
	_check(
		not is_instance_valid(room.get_node_or_null("CaptainBlubberbeard")),
		"Defeated boss respawned"
	)
	var chest := room.get_node_or_null("BossRewardChest") as BossRewardChest
	_check(chest != null, "Unopened boss chest was not restored")
	if chest != null:
		var damage := DamageContext.new()
		damage.source_team = CombatTeams.PLAYER
		damage.amount_hp = 100.0
		chest.receive_damage(damage)
		var key := _find_pickup(room, "ancient_key_of_tides")
		_check(key != null, "Chest did not drop Ancient Key of Tides")
		if key != null:
			key._finish_drop_animation()
			key._collect(room.get_node("Foxy") as Player)
			var inventory := room.get_node("Foxy/Inventory") as Inventory
			_check(inventory.count_item(&"ancient_key_of_tides") == 1, "Key was not collected")
	room.queue_free()
	await process_frame
	room = _new_room()
	await process_frame
	await process_frame
	chest = room.get_node_or_null("BossRewardChest") as BossRewardChest
	_check(chest != null and chest._destroyed, "Opened chest was not restored opened")
	_check(_find_pickup(room, "ancient_key_of_tides") == null, "Collected key respawned")
	_check(_find_pickup(room, "coral") != null, "Uncollected coral was lost")
	_check(_find_pickup(room, "gunpowder_bag") != null, "Uncollected gunpowder was lost")
	room.queue_free()
	await process_frame
	if failures.is_empty():
		print("Boss room, scale and reward persistence tests passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _new_room() -> Node3D:
	var room := ROOM.instantiate() as Node3D
	root.add_child(room)
	current_scene = room
	return room


func _find_pickup(room: Node3D, id: String) -> ItemPickup:
	for child in room.get_children():
		if child is ItemPickup and child.item != null and child.item.item_id == id:
			return child
	return null


func _check_size(boss: BossBase, player: Player) -> void:
	var preview := player.get_node("Visual/SpineIdlePreview") as Node3D
	var player_height := float(preview.get("_reference_height"))
	player_height *= preview.scale.y * player.scale.y * float(preview.get("size_multiplier"))
	var sprite := boss.get_node("Sprite3D") as Sprite3D
	var image := sprite.texture.get_image()
	if image.is_compressed():
		image.decompress()
	var width := image.get_width() / sprite.hframes
	var row_height := image.get_height() / sprite.vframes
	var top := row_height
	var bottom := 0
	for y in row_height:
		for x in width:
			if image.get_pixel(x, y).a > 0.5:
				top = mini(top, y)
				bottom = maxi(bottom, y)
	var ratio := (bottom - top + 1) * sprite.pixel_size / player_height
	_check(ratio >= 3.0 and ratio <= 4.0, "Boss idle size is outside 3–4 times Foxy")
	top = row_height
	bottom = 0
	for y in row_height:
		for x in width:
			if image.get_pixel(x + width * 3, y).a > 0.5:
				top = mini(top, y)
				bottom = maxi(bottom, y)
	var final_ratio := (bottom - top + 1) * sprite.pixel_size * 1.1 / player_height
	_check(
		final_ratio >= 3.0 and final_ratio <= 4.0, "Boss final phase size is outside 3–4 times Foxy"
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
