extends SceneTree

const STAGE := preload("res://world/coral_valley/scenes/stages/stage5.tscn")
const BOSS_ROOM := "res://world/coral_valley/scenes/stages/blubberbeard_room.tscn"
const STAGE_PATH := "res://world/coral_valley/scenes/stages/stage5.tscn"
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := root.get_node("GameManager")
	manager.boss_encounters.clear()
	var stage := STAGE.instantiate() as Node3D
	root.add_child(stage)
	current_scene = stage
	await physics_frame
	var gate := stage.get_node("BossGate") as SceneChangeTrigger
	var ground_query := PhysicsRayQueryParameters3D.create(
		gate.global_position + Vector3.UP * 5.0, gate.global_position + Vector3.DOWN * 3.0, 1
	)
	_check(
		not stage.get_world_3d().direct_space_state.intersect_ray(ground_query).is_empty(),
		"Boss gate is not above walkable ground"
	)
	gate._on_body_entered(stage.get_node("Foxy") as Player)
	await manager.scene_transition_finished
	var room := current_scene as Node3D
	_check(room != null and room.scene_file_path == BOSS_ROOM, "Boss room failed to load")
	var boss := room.get_node_or_null("CaptainBlubberbeard") as BossBase
	if boss == null:
		_fail_and_quit("Boss is missing after entrance")
		return
	var player := room.get_node("Foxy") as Player
	_check(manager.player == player, "Boss room player was not registered")
	boss.take_damage(500.0)
	(boss.behavior as BlubberbeardBehavior).sound.stop()
	await process_frame
	var chest := room.get_node_or_null("BossRewardChest") as BossRewardChest
	if chest == null:
		_fail_and_quit("Boss did not spawn a reward chest")
		return
	var damage := DamageContext.new()
	damage.source_team = CombatTeams.PLAYER
	damage.amount_hp = 100.0
	chest.receive_damage(damage)
	for node in room.get_children():
		if node is ItemPickup and node.item.item_id == "ancient_key_of_tides":
			node._finish_drop_animation()
			node._collect(player)
	await create_timer(0.2).timeout
	var exit := room.get_node("Exits/LeftPath/SceneChangeTrigger") as SceneChangeTrigger
	exit._on_body_entered(player)
	await manager.scene_transition_finished
	_check(current_scene.scene_file_path == STAGE_PATH, "Return gate did not load Stage 5")
	var inventory := manager.player.get_node("Inventory") as Inventory
	_check(inventory.count_item(&"ancient_key_of_tides") == 1, "Key did not survive the transition")
	_check(manager.change_scene(BOSS_ROOM, &"left"), "Could not return to the boss room")
	await manager.scene_transition_finished
	room = current_scene as Node3D
	await process_frame
	_check(room.get_node_or_null("CaptainBlubberbeard") == null, "Defeated boss respawned")
	var open_chest := room.get_node_or_null("BossRewardChest") as BossRewardChest
	_check(open_chest != null and open_chest._destroyed, "Opened chest did not persist")
	var pending := 0
	for node in room.get_children():
		if node is ItemPickup:
			pending += 1
			_check(node.item.item_id != "ancient_key_of_tides", "Collected key duplicated")
	_check(pending == 2, "Uncollected items did not persist")
	room.queue_free()
	await process_frame
	if failures.is_empty():
		print("Boss room scene transition test passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _fail_and_quit(message: String) -> void:
	push_error(message)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
