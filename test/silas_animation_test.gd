extends SceneTree

const NPC_SCENE: PackedScene = preload("res://gameplay/npcs/silas/silas_npc.tscn")
const PANEL_SCENE: PackedScene = preload("res://gameplay/merchant/silas_shop_panel.tscn")
const PROBE_SCRIPT: Script = preload("res://test/mocks/silas_animation_probe.gd")
const SILAS_DATA: SilasNpcData = preload("res://data/npcs/silas_npc_data.tres")
const SILAS_CATALOG: MerchantCatalog = preload("res://data/merchants/silas_catalog.tres")

var _failures := 0


func _initialize() -> void:
	await _run()
	print("Silas animation tests: %s" % ("passed" if _failures == 0 else "failed"))
	quit(0 if _failures == 0 else 1)


func _run() -> void:
	var fixture := Node3D.new()
	var panel := PANEL_SCENE.instantiate()
	panel.name = "SilasShopPanel"
	fixture.add_child(panel)
	var npc := NPC_SCENE.instantiate() as SilasNpc
	npc.set_script(PROBE_SCRIPT)
	npc.data = SILAS_DATA
	npc.catalog = SILAS_CATALOG
	npc.shop_panel_path = NodePath("../SilasShopPanel")
	fixture.add_child(npc)
	root.add_child(fixture)
	await process_frame
	var probe := npc as SilasAnimationProbe
	_check(probe != null, "animation probe loads")
	if probe == null:
		fixture.free()
		return
	var player := Player.new()
	var player_visual := _make_player_visual(fixture)
	player.visual = player_visual
	var player_camera := Camera3D.new()
	fixture.add_child(player_camera)
	player.camera = player_camera
	player.play_directional_animation("run")
	player.velocity = Vector3(2.0, 0.0, 3.0)
	var spawn_position := probe.global_position
	_check(probe.get_node_or_null("States/Hidden") == null, "Silas has no hidden state")
	_check(probe.sprite.animation == &"idle_close", "Silas starts closed")
	probe._on_interaction_requested(player)
	_check(probe.sprite.animation == &"open", "interaction starts Open")
	_check(probe.started_timelines.is_empty(), "dialogue waits for Open")
	_check(player.blocked, "player waits during Open")
	_check(
		player_visual.animation_player.assigned_animation.begins_with("idle_"),
		"Foxy switches from run to idle when interaction starts"
	)
	_check(Vector2(player.velocity.x, player.velocity.z) == Vector2.ZERO, "Foxy stops moving")
	await create_timer(1.0).timeout
	_check(probe.sprite.animation == &"idle_open", "Silas idles open after Open")
	_check(probe.started_timelines.size() == 1, "dialogue starts after Open")
	_check(not player.blocked, "Open restores player control before dialogue")
	probe._on_dialogue_finished(player)
	await process_frame
	_check(probe.shop_opened, "shop opens after greeting")
	_check(probe.sprite.animation == &"idle_open", "Silas stays open during shop")
	probe.is_talking = false
	player.play_directional_animation("run")
	probe._on_shop_closed()
	_check(probe.started_timelines.size() == 2, "farewell starts after shop")
	_check(
		player_visual.animation_player.assigned_animation.begins_with("idle_"),
		"Foxy returns to idle for farewell"
	)
	probe._on_dialogue_finished(player)
	_check(probe.sprite.animation == &"close", "farewell starts Close")
	_check(
		(
			Vector2(probe.global_position.x, probe.global_position.z)
			== Vector2(spawn_position.x, spawn_position.z)
		),
		"Silas stays at spawn during Close"
	)
	await create_timer(1.0).timeout
	_check(
		(
			Vector2(probe.global_position.x, probe.global_position.z)
			== Vector2(spawn_position.x, spawn_position.z)
		),
		"Silas stays at spawn after Close"
	)
	_check(probe.sprite.visible, "Silas remains visible after Close")
	_check(probe.interaction_area._enabled, "Silas can be interacted with again")
	_check(probe.sprite.animation == &"idle_close", "Silas idles closed after Close")
	await _test_camera(probe, player, fixture)
	player.free()
	fixture.free()


func _make_player_visual(fixture: Node3D) -> PlayerVisual:
	var player_visual := PlayerVisual.new()
	var animation_player := AnimationPlayer.new()
	var library := AnimationLibrary.new()
	for action in ["idle", "run"]:
		for direction in ["down", "up", "side"]:
			library.add_animation(action + "_" + direction, Animation.new())
	animation_player.add_animation_library(&"", library)
	player_visual.animation_player = animation_player
	player_visual.add_child(animation_player)
	fixture.add_child(player_visual)
	return player_visual


func _test_camera(probe: SilasAnimationProbe, player: Player, fixture: Node3D) -> void:
	var camera := Camera3D.new()
	fixture.add_child(camera)
	camera.global_position = Vector3(0.0, 3.0, 10.0)
	player.camera = camera
	player.global_position = Vector3(-8.0, 0.0, 0.0)
	var initial_position := camera.global_position
	var initial_fov := camera.fov
	probe._dialogue_intent = SilasNpc.DialogueIntent.OPEN_FIRST_SHOP
	probe._focus_dialogue_camera(player)
	await create_timer(probe.dialogue_camera_transition_duration + 0.05).timeout
	_check(camera.fov < initial_fov, "greeting focuses camera")
	probe._restore_dialogue_camera()
	await create_timer(0.05).timeout
	probe._dialogue_intent = SilasNpc.DialogueIntent.CLOSE
	var fov_before_farewell := camera.fov
	probe._focus_dialogue_camera(player)
	await create_timer(0.12).timeout
	_check(camera.fov >= fov_before_farewell, "farewell does not start another camera zoom")
	probe._restore_dialogue_camera()
	await create_timer(probe.dialogue_camera_transition_duration + 0.05).timeout
	_check(is_equal_approx(camera.fov, initial_fov), "farewell restores original FOV")
	_check(
		camera.global_position.is_equal_approx(initial_position),
		"farewell restores original camera position"
	)
	probe._dialogue_intent = SilasNpc.DialogueIntent.OPEN_RETURNING_SHOP
	probe._focus_dialogue_camera(player)
	await create_timer(probe.dialogue_camera_transition_duration + 0.05).timeout
	probe._restore_dialogue_camera()
	await create_timer(probe.dialogue_camera_transition_duration + 0.05).timeout
	_check(is_equal_approx(camera.fov, initial_fov), "repeated interaction keeps original FOV")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("Silas animation test failed: %s" % message)
