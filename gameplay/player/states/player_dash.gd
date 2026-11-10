extends PlayerState

var direction: Vector3 = Vector3.ZERO
var active: bool = false
var completed: bool = false
var _dash_distance: float = 0.0
var _saved_floor_snap_length: float = 0.0
var _floor_snap_suspended: bool = false


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
	_dash_distance = player.data.dash_distance * player.environment_dash_distance_multiplier

	if free_dash:
		player.last_facing_direction = direction
	timer = player.data.dash_duration
	active = true
	_saved_floor_snap_length = player.floor_snap_length
	player.floor_snap_length = 0.0
	_floor_snap_suspended = true
	player.velocity.y = 0.0
	player.play_directional_animation("dash", true)
	if is_instance_valid(player.visual):
		player.visual.fit_dash_duration(timer)
	player.dash_started.emit()


func _update(delta: float) -> void:
	if player.dead or not active:
		player.set_horizontal_velocity(Vector3.ZERO)
		return
	var step_fraction := minf(timer, delta) / delta if delta > 0.0 else 0.0
	player.set_horizontal_velocity(
		direction * _dash_distance / player.data.dash_duration * step_fraction
	)
	if update_timer(delta):
		completed = true
		active = false
		return_to_locomotion()


func _exit() -> void:
	if _floor_snap_suspended:
		player.floor_snap_length = _saved_floor_snap_length
		_floor_snap_suspended = false
	if is_instance_valid(player.visual):
		player.visual.reset_animation_speed()
	if active or completed:
		player.dash_finished.emit(not completed)
	active = false
	completed = false
	player.set_horizontal_velocity(Vector3.ZERO)
