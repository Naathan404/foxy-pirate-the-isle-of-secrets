extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var player := load("res://gameplay/player/foxy.tscn").instantiate() as Player
	root.add_child(player)
	player.set_physics_process(false)
	var visual := player.visual
	var preview := visual.get_node("SpineIdlePreview")
	visual.play_directional(&"idle", Vector3.BACK, player.camera)
	await process_frame
	var available := ClassDB.class_exists("SpineBridge")
	_check(preview.visible == available, "Idle down uses Spine only when runtime is available")
	_check(visual.sprite.visible != available, "Exactly one idle renderer is visible")
	if available:
		await _check_playback(player, preview)
		_check_idle_facing(player, preview)
	for direction in [Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT]:
		visual.play_directional(&"idle", direction, player.camera)
		_check(not preview.visible and visual.sprite.visible, "Other directions use the old sprite")
	for action in [&"run", &"attack_dagger", &"attack_bow", &"dash", &"hit", &"fall"]:
		_check(visual.play_directional(action, Vector3.BACK, player.camera), "Action clip exists")
		_check(not preview.visible, "Non-idle actions hide the Spine preview")
		var expected_sprite := (
			visual.get_node("BowSprite") if action == &"attack_bow" else visual.sprite
		)
		_check(expected_sprite.visible, "Non-idle actions use the correct old sprite")
	visual.play_directional(&"idle", Vector3.BACK, player.camera)
	preview.enabled = false
	visual.play_directional(&"idle", Vector3.BACK, player.camera)
	_check(not preview.visible and visual.sprite.visible, "Toggle restores the old idle sprite")
	preview.enabled = true
	visual.play_directional(&"idle", Vector3.BACK, player.camera)
	_check(preview.visible == available, "Toggle can enable the preview again")
	_check(visual.animation_player.assigned_animation == &"idle_down", "Old animation clock stays")
	player.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("Spine idle preview: ", "PASS" if _failures.is_empty() else "FAIL")
	quit(0 if _failures.is_empty() else 1)


func _check_playback(player: Player, preview: Node3D) -> void:
	var spine: Node3D = preview.get("_spine")
	_check(is_instance_valid(spine) and spine.is_loaded(), "Spine skeleton loads")
	if not is_instance_valid(spine):
		return
	var core := spine.get_node("_SpineSpriteCore3D")
	var before: Array = core._get_render_commands_for_external_consumer().duplicate(true)
	await create_timer(0.15).timeout
	var after: Array = core._get_render_commands_for_external_consumer()
	_check(before[0]["positions"] != after[0]["positions"], "Idle vertices advance automatically")
	var hitstop := root.get_node("HitstopController")
	hitstop.request_local(player, player, 0.12)
	await process_frame
	await process_frame
	_check(not spine.get("is_playing"), "Local hitstop pauses Spine playback")
	hitstop.cancel()
	await process_frame
	await process_frame
	_check(spine.get("is_playing"), "Spine resumes after hitstop")
	_check(root.get_node("GameManager").enter_inventory(), "Inventory opens")
	before = core._get_render_commands_for_external_consumer().duplicate(true)
	await create_timer(0.05, true).timeout
	after = core._get_render_commands_for_external_consumer()
	_check(before[0]["positions"] == after[0]["positions"], "Inventory pause freezes Spine")
	root.get_node("GameManager").exit_inventory()


func _check_idle_facing(player: Player, preview: Node3D) -> void:
	var visual := player.visual
	var spine: Node3D = preview.get("_spine")
	visual.play_directional(&"run", Vector3.RIGHT, player.camera)
	visual.play_directional(&"idle", Vector3.BACK, player.camera)
	_check(spine.transform.basis.x.x < 0.0, "Right then down mirrors the left-facing artwork")
	var right_offset := spine.position.x
	visual.play_directional(&"idle", Vector3.ZERO, player.camera)
	_check(spine.transform.basis.x.x < 0.0, "Standing still preserves the last horizontal facing")
	visual.play_directional(&"idle", Vector3(-0.25, 0.0, 1.0), player.camera)
	_check(preview.visible, "Down-left still uses the Spine idle")
	_check(spine.transform.basis.x.x > 0.0, "Down-left restores the original left-facing artwork")
	_check(
		is_equal_approx(spine.position.x + right_offset, 2.0 * visual.sprite.position.x),
		"Mirroring also offsets the skeleton so the character stays centered"
	)
	visual.play_directional(&"idle", Vector3.BACK, player.camera)
	_check(spine.transform.basis.x.x > 0.0, "Straight down retains the previous left facing")
	visual.play_directional(&"idle", Vector3(0.25, 0.0, 1.0), player.camera)
	_check(spine.transform.basis.x.x < 0.0, "Down-right flips during idle without changing clips")
	for direction in [Vector3.LEFT, Vector3.RIGHT, Vector3.LEFT, Vector3.RIGHT]:
		visual.play_directional(&"run", direction, player.camera)
		visual.play_directional(&"idle", Vector3.BACK, player.camera)
		_check(
			(spine.transform.basis.x.x < 0.0) == (direction.x > 0.0),
			"Repeated idle entry keeps the correct mirror"
		)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
