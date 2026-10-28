extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20, 1, 20)
	collider.shape = shape
	floor_body.add_child(collider)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	var player := load("res://gameplay/player/foxy.tscn").instantiate() as Player
	player.position.y = 0.7
	root.add_child(player)
	for frame in 12:
		await physics_frame
	player.set_physics_process(false)
	var effect = player.get_node("Effects/HitEffect")
	effect.hitstop_duration = 0.0
	effect.shake_pixels = 0.0
	var visual: PlayerVisual = player.visual
	var rest_scale: Vector3 = visual.scale
	var rest_position: Vector3 = visual.position
	var sprite_scale: Vector3 = visual.sprite.scale
	var rest_color: Color = visual.sprite.modulate
	var rest_shaded: bool = visual.sprite.shaded
	var hp_before: int = player.hp.current_hp
	_check(player.is_on_floor(), "Test Player is grounded")
	_check(not effect._vignette_overlay.visible, "No overlay cost while not hit")
	_check(player.take_damage(0) == 0 and effect._next_spark == 0, "Zero damage has no feedback")
	var ignored := DamageContext.new()
	ignored.source = player
	_check(player.receive_damage(ignored) == 0, "Self damage is rejected")
	_check(effect._next_spark == 0, "Rejected damage has no feedback")
	player.take_damage(1)
	_check(player.hp.current_hp == hp_before - 1, "Damage amount is unchanged")
	_check(effect._next_spark == 1, "Real damage emits impact sparks")
	_check(effect._dust.emitting, "Grounded hit emits dust")
	_check(visual.sprite.modulate != rest_color and not visual.sprite.shaded, "Bright hit flash")
	_check(visual.scale.y < rest_scale.y, "Hit squashes visual")
	_check(effect._vignette_overlay.visible, "Hit shows screen edge reaction")
	_check(visual.sprite.scale == sprite_scale, "Hit does not overwrite dash sprite scale")
	_finish_feedback(effect)
	_check(visual.scale.is_equal_approx(rest_scale), "Restore visual scale")
	_check(visual.position.is_equal_approx(rest_position), "Restore visual position")
	_check(visual.sprite.modulate == rest_color, "Restore sprite color")
	_check(visual.sprite.shaded == rest_shaded, "Restore sprite shading")
	_check(not effect._vignette_overlay.visible, "Hide screen reaction when finished")
	var pool_size: int = effect.get_child_count()
	for repeat in 6:
		player.take_damage(1)
		player.hp.heal(1)
	_check(effect.get_child_count() == pool_size, "Repeated hits reuse effect nodes")
	_finish_feedback(effect)
	_check(visual.scale.is_equal_approx(rest_scale), "Repeated hits do not accumulate scale")
	player.dash_started.emit()
	player.take_damage(1)
	player.dash_finished.emit(true)
	_finish_feedback(effect)
	_check(visual.sprite.scale.is_equal_approx(sprite_scale), "Hit interrupt restores dash scale")
	_check(visual.scale.is_equal_approx(rest_scale), "Hit interrupt restores visual scale")
	effect.hitstop_duration = 0.055
	player.take_damage(1)
	_check(Engine.time_scale < 1.0, "Hit requests hitstop")
	root.get_node("HitstopController").cancel()
	player.free()
	floor_body.free()
	_check(is_equal_approx(Engine.time_scale, 1.0), "Leave normal game speed on cleanup")
	if _failures == 0:
		print("Player hit VFX, damage gating and cleanup checks passed")
	quit(0 if _failures == 0 else 1)


func _finish_feedback(effect: Node) -> void:
	for tween: Tween in [effect._flash_tween, effect._pose_tween, effect._vignette_tween]:
		if tween != null and tween.is_valid():
			tween.pause()
			tween.custom_step(0.4)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
