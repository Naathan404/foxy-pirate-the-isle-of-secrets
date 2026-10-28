extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := load("res://gameplay/player/foxy.tscn").instantiate() as Player
	root.add_child(player)
	player.set_physics_process(false)
	var effect = player.get_node("Effects/RunDustEffect")
	effect.set_process(false)
	var original_scale: Vector3 = player.visual.sprite.scale
	var move_speed: float = player.data.move_speed
	_check(effect._bursts.size() == 5, "Five fixed pooled dust emitters")
	_check(not effect.particle.local_coords, "Trail particles stay in world space")
	_check(
		effect._bursts[0].process_material != effect._bursts[1].process_material,
		"Footstep emitters have independent materials"
	)
	effect._update_running(Vector3.RIGHT * move_speed, 0.01)
	_check(effect._was_running and effect.particle.emitting, "Running starts trail")
	_check(effect._bursts[3].emitting, "Running starts with a launch puff")
	_check(effect._bursts[3].global_position.y < player.global_position.y, "Dust is at feet")
	var launch_origin: Vector3 = effect._bursts[3].global_position
	var full_speed_amount: float = effect.particle.amount_ratio
	player.position.x += 2.0
	effect._update_running(Vector3.RIGHT * move_speed, 0.2)
	_check(effect._next_step == 1, "Movement distance triggers first footstep")
	_check(effect._bursts[3].global_position == launch_origin, "Old launch dust stays behind")
	var foot: Vector3 = effect._get_foot_position()
	var first_side: float = effect._bursts[0].global_position.z - foot.z
	effect._update_running(Vector3.RIGHT * move_speed, 0.2)
	var second_side: float = effect._bursts[1].global_position.z - foot.z
	_check(first_side * second_side < 0.0, "Footstep dust alternates sides")
	var material := effect.particle.process_material as ParticleProcessMaterial
	var emitted_direction: Vector3 = effect.particle.global_basis * material.direction
	_check(emitted_direction.x < 0.0, "Trail blows opposite travel direction")
	effect._update_running(Vector3.RIGHT * move_speed * 0.25, 0.01)
	_check(effect.particle.amount_ratio < full_speed_amount, "Trail density follows speed")
	effect._stop_running(true)
	_check(not effect.particle.emitting and not effect._was_running, "Stop ends continuous trail")
	_check(effect._bursts[4].emitting, "Stopping emits a braking puff")
	effect._bursts[4].emitting = false
	effect._update_running(Vector3.RIGHT * move_speed, 0.01)
	effect._stop_running(false)
	_check(not effect._bursts[4].emitting, "Dash/fall transitions skip braking puff")
	var pool_size: int = effect.get_child_count()
	for step in 30:
		effect._update_running(Vector3.RIGHT * move_speed, 0.2)
	_check(effect.get_child_count() == pool_size, "Many footsteps reuse pooled nodes")
	paused = true
	_check(not effect.can_process(), "Running feedback pauses with gameplay")
	paused = false
	effect._process(0.016)
	_check(not effect.particle.emitting, "Airborne or non-running Player does not emit trail")
	_check(player.visual.sprite.scale == original_scale, "Run feedback does not fight dash scale")
	_check(player.data.move_speed == move_speed, "Movement speed stays unchanged")
	player.free()
	if _failures == 0:
		print("Run dust, footsteps and transition checks passed")
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
