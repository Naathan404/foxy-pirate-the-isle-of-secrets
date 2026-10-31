extends SceneTree

const DESTINATION := "res://test/fixtures/scene_transition_destination.tscn"
const ARRIVAL_MAP := "res://test/fixtures/scene_transition_arrival.tscn"

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()
	create_timer(10.0, true, false, true).timeout.connect(
		func() -> void:
			push_error("Scene transition test timed out")
			quit(1)
	)


func _run() -> void:
	for scene_path: String in [DESTINATION, ARRIVAL_MAP]:
		if not ResourceLoader.exists(scene_path, "PackedScene"):
			push_error("Missing scene transition fixture: %s" % scene_path)
			quit(1)
			return
	var manager := root.get_node("GameManager")
	manager.fade_out_seconds = 0.03
	manager.fade_in_seconds = 0.03
	_check(not manager.change_scene("res://missing_scene.tscn"), "Reject missing scene")
	_check(not manager.change_scene("res://data/weapon/weapon_dagger.tres"), "Reject non-scene")
	_check(manager.enter_inventory(), "Can open inventory before transition")
	_check(manager.change_scene(DESTINATION), "Accept destination")
	_check(not manager.change_scene(DESTINATION), "Reject simultaneous request")
	await scene_changed
	_check(paused, "Gameplay paused while screen is black")
	_check(manager.state == manager.State.TRANSITION, "Transition state survives scene change")
	_check(not manager.enter_inventory(), "Inventory blocked during transition")
	var overlay := manager.get_node("SceneTransition") as CanvasLayer
	var fade := overlay.get_node("Fade") as ColorRect
	_check(overlay.visible and is_equal_approx(fade.color.a, 1.0), "Scene changes at full black")
	_check(current_scene.scene_file_path == DESTINATION, "Destination is current scene")
	await manager.scene_transition_finished
	_check(not paused and manager.state == manager.State.PLAYING, "Gameplay resumes")
	_check(not overlay.visible and is_zero_approx(fade.color.a), "Overlay clears after fade-in")
	var previous_scene: WeakRef = weakref(current_scene)
	# Tween must continue independently of slow motion and SceneTree pause.
	Engine.time_scale = 0.01
	manager.reload_current_scene()
	await manager.scene_transition_finished
	Engine.time_scale = 1.0
	_check(previous_scene.get_ref() == null, "Reload frees the old scene")
	_check(current_scene.scene_file_path == DESTINATION, "Reload preserves destination")
	_check(not paused and not overlay.visible, "Reload restores gameplay and overlay")
	_check(manager.change_scene(DESTINATION), "Can transition again after completion")
	await manager.scene_transition_finished
	await _check_trigger(manager)
	for failure: String in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("Scene transition checks: PASS")
	quit(0 if _failures.is_empty() else 1)


func _check_trigger(manager: Node) -> void:
	var world := Node3D.new()
	current_scene.add_child(world)
	var trigger := load("res://world/components/scene_change_trigger.tscn").instantiate() as Area3D
	trigger.set("trigger_id", &"to_hub")
	trigger.set("destination_scene", ARRIVAL_MAP)
	trigger.set("destination_trigger_id", &"from_hub")
	world.add_child(trigger)
	var other_body := CharacterBody3D.new()
	other_body.collision_layer = CombatLayers.PLAYER_BODY
	var collider := CollisionShape3D.new()
	collider.shape = SphereShape3D.new()
	other_body.add_child(collider)
	world.add_child(other_body)
	await _physics_frames()
	_check(not manager.get("_transition_pending"), "Non-Player body cannot trigger transition")
	var player := load("res://gameplay/player/foxy.tscn").instantiate() as Player
	player.position.x = 4.0
	world.add_child(player)
	player.set_physics_process(false)
	trigger.set("enabled", false)
	player.position.x = 0.0
	await _physics_frames()
	_check(not manager.get("_transition_pending"), "Disabled trigger ignores Player")
	player.position.x = 4.0
	await _physics_frames()
	trigger.set("enabled", true)
	player.dead = true
	player.position.x = 0.0
	await _physics_frames()
	_check(not manager.get("_transition_pending"), "Dead Player cannot trigger transition")
	player.position.x = 4.0
	await _physics_frames()
	player.dead = false
	var previous_world: WeakRef = weakref(world)
	# Keep the destination Player stationary so spawn assertions are independent of gravity.
	var freeze_player := func(active_player: Player) -> void:
		if active_player != null:
			active_player.set_physics_process(false)
	manager.player_changed.connect(freeze_player)
	player.position.x = 0.0
	await scene_changed
	await process_frame
	var arrival_player := manager.get("player") as Player
	var marker := current_scene.get_node("ArrivalGate/ExitPosition") as Marker3D
	_check(
		arrival_player.global_position.is_equal_approx(marker.global_position),
		"Correct destination ID places Player at global Marker3D position before fade-in"
	)
	_check(arrival_player.velocity.is_zero_approx(), "Arrival clears Player velocity")
	_check(paused, "Player placed before gameplay resumes")
	await manager.scene_transition_finished
	_check(previous_world.get_ref() == null, "Player overlap replaces source scene")
	_check(current_scene.scene_file_path == ARRIVAL_MAP, "Trigger reaches destination")
	_check(not paused, "Trigger resumes gameplay after fade")
	await _physics_frames()
	_check(not manager.get("_transition_pending"), "Exit marker avoids immediate return trigger")
	manager.reload_current_scene()
	await manager.scene_transition_finished
	arrival_player = manager.get("player") as Player
	_check(
		arrival_player.position.is_equal_approx(Vector3(-5, 0, 0)),
		"Reload does not reuse the previous arrival trigger ID"
	)
	_check(manager.change_scene(ARRIVAL_MAP, &"missing_gate"), "Accept optional arrival ID")
	await manager.scene_transition_finished
	arrival_player = manager.get("player") as Player
	_check(
		arrival_player.position.is_equal_approx(Vector3(-5, 0, 0)),
		"Missing arrival ID preserves authored spawn"
	)
	_check(not paused, "Missing arrival ID still completes fade")
	manager.player_changed.disconnect(freeze_player)


func _physics_frames() -> void:
	for frame in 4:
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
