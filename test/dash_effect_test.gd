extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := load("res://gameplay/player/foxy.tscn").instantiate() as Player
	root.add_child(player)
	player.set_physics_process(false)
	var effect = player.get_node("Effects/DashEffect")
	effect.shake_pixels = 0.0
	var sprite: Sprite3D = player.visual.sprite
	var authored_scale: Vector3 = sprite.scale
	var dash_distance: float = player.data.dash_distance
	var dash_duration: float = player.data.dash_duration
	player.last_facing_direction = Vector3.RIGHT
	player.dash_started.emit()
	_check(effect._dashing and effect.dash_particle.emitting, "Dash starts trail")
	_check(effect.ghosts.size() == 8, "Eight pooled afterimages")
	_check(effect.ghosts[0].visible, "First afterimage appears immediately")
	_check(effect._rings[0].visible, "Departure shock ring appears")
	_check(effect._rings[0].global_position.y < player.global_position.y, "Ring at feet")
	var ghost_start: Vector3 = effect.ghosts[0].global_position
	var ring_start: Vector3 = effect._rings[0].global_position
	effect._sprite_tween.pause()
	effect._sprite_tween.custom_step(0.05)
	_check(sprite.scale.x > authored_scale.x, "Dash stretches side-facing sprite")
	player.position.x += 2.0
	effect._process(0.03)
	_check(effect.ghosts[0].global_position == ghost_start, "Ghost stays at previous position")
	_check(effect._rings[0].global_position == ring_start, "Departure ring stays behind")
	_check(effect.ghosts[1].visible, "Trail adds another afterimage")
	paused = true
	_check(not effect.can_process(), "Dash effects respect gameplay pause")
	paused = false
	player.dash_finished.emit(false)
	_check(not effect._dashing and not effect.dash_particle.emitting, "Stop emitting at dash end")
	_check(effect._rings[1].visible, "Completed dash has arrival ring")
	effect._sprite_tween.pause()
	effect._sprite_tween.custom_step(0.11)
	_check(sprite.scale.is_equal_approx(authored_scale), "Restore sprite proportions")
	for tween: Tween in effect._ghost_tweens:
		if tween != null and tween.is_valid():
			tween.pause()
			tween.custom_step(effect.ghost_lifetime + 0.01)
	for ghost: Sprite3D in effect.ghosts:
		_check(not ghost.visible, "Ghost fades and hides")
	_check(is_zero_approx(effect.ghosts[0].modulate.a), "Ghost fades completely before hiding")
	for tween: Tween in effect._ring_tweens:
		if tween != null and tween.is_valid():
			tween.pause()
			tween.custom_step(0.23)
	player.last_facing_direction = Vector3.BACK
	player.dash_started.emit()
	effect._sprite_tween.pause()
	effect._sprite_tween.custom_step(0.05)
	_check(
		is_equal_approx(sprite.scale.y, authored_scale.y * effect.stretch_amount),
		"Forward/back dash uses configured stretch"
	)
	player.dash_finished.emit(true)
	var child_count: int = effect.get_child_count()
	for repeat in 12:
		player.dash_started.emit()
		effect._process(0.03)
		player.dash_finished.emit(true)
	_check(effect.get_child_count() == child_count, "Repeated dashes reuse effect nodes")
	_check(sprite.scale.is_equal_approx(authored_scale), "Interrupted dash restores immediately")
	_check(not effect._rings[1].visible, "Interrupted dash does not play arrival ring")
	_check(player.data.dash_distance == dash_distance, "Dash distance remains unchanged")
	_check(player.data.dash_duration == dash_duration, "Dash duration remains unchanged")
	player.free()
	if _failures == 0:
		print("Dash VFX pooling, fade and cleanup checks passed")
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
