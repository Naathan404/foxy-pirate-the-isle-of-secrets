extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var visual := PlayerVisual.new()
	_check(visual.get_current_animation_duration() == 0.0, "Missing animator has no duration")
	visual.free()
	var player := load("res://gameplay/player/foxy.tscn").instantiate() as Player
	root.add_child(player)
	player.set_physics_process(false)
	var animator := player.visual.animation_player
	var library := AnimationLibrary.new()
	var clip := Animation.new()
	clip.length = 2.0
	library.add_animation(&"duration", clip)
	animator.add_animation_library(&"state_test", library)
	player.visual.play_animation(&"state_test/duration", true)
	animator.speed_scale = 2.0
	_check(
		is_equal_approx(player.visual.get_current_animation_duration(), 1.0),
		"Duration accounts for playback speed"
	)
	animator.pause()
	_check(
		is_equal_approx(player.visual.get_current_animation_duration(), 1.0),
		"Paused clip retains its full duration"
	)
	player.visual.reset_animation_speed()
	# A long hit clip must not extend the authored stun duration.
	var hit_clip := animator.get_animation("hit_down").duplicate() as Animation
	hit_clip.length = 2.0
	var default_library := animator.get_animation_library(&"").duplicate(true) as AnimationLibrary
	animator.remove_animation_library(&"")
	animator.add_animation_library(&"", default_library)
	default_library.remove_animation(&"hit_down")
	default_library.add_animation(&"hit_down", hit_clip)
	player.pending_hit_duration = 0.02
	var hit := player.get_node("States/Hit")
	hit._enter()
	hit._update(0.03)
	_check(player.fsm.next_state.name == &"Fall", "Hit exits when stun expires")
	var death := player.get_node("States/Death")
	death.reload_delay = 0.01
	death._enter()
	_check(
		is_equal_approx(
			death.timer, maxf(death.reload_delay, player.visual.get_current_animation_duration())
		),
		"Death waits for its animation through the visual API"
	)
	player.free()
	if _failures == 0:
		print("Player visual duration, hit recovery and death timing passed")
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
