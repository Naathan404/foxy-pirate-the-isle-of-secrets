extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var visual := _create_visual()
	var camera := Camera3D.new()
	root.add_child(camera)
	_expect(visual.has_directional_animation(&"idle"), "Idle has all directions")
	_expect(not visual.has_attack_animation(&"idle"), "Looping animations cannot be attacks")
	_expect(visual.has_attack_animation(&"hit"), "One-shot animation validation")
	_expect(not visual.has_directional_animation(&"missing"), "Missing animation is rejected")
	visual.play_directional(&"idle", Vector3.BACK, camera)
	_expect(visual.animation_player.assigned_animation == &"idle_down", "Facing down")
	visual.play_directional(&"idle", Vector3.LEFT, camera)
	_expect(visual.animation_player.assigned_animation == &"idle_side", "Facing sideways")
	_expect(visual.sprite.flip_h, "Left-facing sprite is flipped")
	visual.animation_player.advance(0.25)
	visual.play_directional(&"idle", Vector3.RIGHT, camera)
	_expect(not visual.sprite.flip_h, "Right-facing sprite is not flipped")
	_expect(
		is_equal_approx(visual.animation_player.current_animation_position, 0.25),
		"Updating facing does not restart the same animation"
	)
	visual.play_directional(&"idle", Vector3.FORWARD, camera)
	_expect(visual.animation_player.assigned_animation == &"idle_up", "Facing up")
	camera.rotate_y(PI / 2.0)
	visual._process(0.0)
	_expect(visual.animation_player.assigned_animation == &"idle_side", "Camera changes facing")
	visual.play_directional(&"hit", Vector3.BACK, null, true)
	visual.animation_player.advance(2.0)
	visual._process(0.0)
	_expect(not visual.animation_player.is_playing(), "Completed one-shot does not restart")
	visual.play_directional(&"hit", Vector3.BACK, null, true)
	_expect(visual.animation_player.is_playing(), "Explicit restart replays one-shot")
	_expect(not visual.play_animation(&"missing"), "Missing animation fails safely")
	visual.free()
	camera.free()

	var scene := load("res://gameplay/player/foxy.tscn") as PackedScene
	var player := scene.instantiate() as Player
	root.add_child(player)
	player.set_physics_process(false)
	_expect(is_instance_valid(player.visual), "Foxy scene links PlayerVisual")
	player.play_directional_animation("idle")
	_expect(
		player.visual.animation_player.assigned_animation == &"idle_down",
		"Player delegates animation to the scene's PlayerVisual"
	)
	player.free()
	print("Player visual tests: ", _failures, " failures")
	quit(0 if _failures == 0 else 1)


func _create_visual() -> PlayerVisual:
	var visual := PlayerVisual.new()
	visual.sprite = Sprite3D.new()
	visual.sprite.name = &"Sprite3D"
	visual.add_child(visual.sprite)
	visual.animation_player = AnimationPlayer.new()
	visual.add_child(visual.animation_player)
	var library := AnimationLibrary.new()
	for action in ["idle", "hit"]:
		for suffix in ["down", "up", "side"]:
			var animation := Animation.new()
			animation.length = 1.0
			animation.loop_mode = Animation.LOOP_LINEAR if action == "idle" else Animation.LOOP_NONE
			var track := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(track, NodePath("Sprite3D:modulate"))
			animation.track_insert_key(track, 0.0, Color.WHITE)
			library.add_animation(action + "_" + suffix, animation)
	visual.animation_player.add_animation_library(&"", library)
	root.add_child(visual)
	return visual


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
