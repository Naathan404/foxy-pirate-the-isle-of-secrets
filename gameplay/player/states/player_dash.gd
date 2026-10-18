extends PlayerState


var direction: Vector3 = Vector3.ZERO
var active: bool = false
var completed: bool = false


func _enter() -> void:
	active = false
	completed = false
	player.dash_buffer_remaining = 0.0
	
	var free_dash = player.pending_free_dash
	var free_direction = player.pending_free_dash_direction
	player.pending_free_dash = false

	if player.dead:
		return

	if not player.is_on_floor() or (not free_dash and not is_instance_valid(player.stamina)):
		return_to_locomotion()
		return
	if not free_dash and not player.stamina.call("try_consume", player.data.dash_cost):
		player.action_rejected.emit(&"dash")
		return_to_locomotion()
		return

	direction = free_direction if free_dash else player.last_facing_direction.normalized()

	if free_dash:
		player.last_facing_direction = direction
	timer = player.data.dash_duration
	active = true
	player.play_directional_animation("dash", true)
	player.dash_started.emit()


func _update(delta: float) -> void:
	if player.dead or not active:
		player.set_horizontal_velocity(Vector3.ZERO)
		return
	var step_fraction := minf(timer, delta) / delta if delta > 0.0 else 0.0
	player.set_horizontal_velocity(
		direction * player.data.dash_distance / player.data.dash_duration * step_fraction
	)
	if update_timer(delta):
		completed = true
		active = false
		return_to_locomotion()


func _exit() -> void:
	if active or completed:
		player.dash_finished.emit(not completed)
	active = false
	completed = false
	player.set_horizontal_velocity(Vector3.ZERO)
