class_name DeadMansAnchorEffect
extends CharmEffect
## Two-stage marker and collision-safe return.

var _marker: CharmVfx
var _window_remaining: float = 0.0
var _armed: bool = false


func get_cooldown_policy() -> StringName:
	return &"manual"


func get_activation_cost(_context: CharmActivationContext) -> float:
	return 0.0 if _armed else definition.resource_cost


func can_bypass_cooldown(_context: CharmActivationContext) -> bool:
	return _armed


func activate(context: CharmActivationContext) -> bool:
	if not is_instance_valid(actor):
		return false
	if _armed:
		var recalled := _recast()
		if recalled:
			_play_cast_animation(&"recall", context.direction, 0.3)
		return recalled
	_window_remaining = definition.get_param_float(&"recast_window_seconds", 5.0)
	_marker = CharmVfx.spawn(
		actor.get_parent(),
		actor.global_position,
		CharmVfx.TIDE,
		1.1,
		_window_remaining,
		CharmVfx.Style.ANCHOR
	)
	_marker.sustained = true
	# The surface carries clearance; the stored return position must remain on the ground.
	_marker.global_position = actor.global_position
	CharmVfx.spawn(actor.get_parent(), actor.global_position, CharmVfx.TIDE, 0.8)
	_armed = true
	set_physics_process(true)
	_play_cast_animation(&"cast", context.direction, 0.3)
	return true


func _physics_process(delta: float) -> void:
	if not _armed or not is_instance_valid(actor) or bool(actor.get("dead")):
		cancel_active()
		return
	_window_remaining -= maxf(0.0, delta)
	if _window_remaining <= 0.0:
		runtime.start_cooldown()
		cancel_active()


func _recast() -> bool:
	if not is_instance_valid(_marker):
		cancel_active()
		return false
	var destination := _marker.global_position
	if (
		actor is CharacterBody3D
		and (actor as CharacterBody3D).test_move(
			actor.global_transform, destination - actor.global_position
		)
	):
		return false
	CharmVfx.spawn(actor.get_parent(), actor.global_position, CharmVfx.TIDE, 1.0)
	CharmVfx.streak(
		actor.get_parent(),
		actor.global_position + Vector3.UP * 0.5,
		destination + Vector3.UP * 0.5,
		CharmVfx.TIDE,
		0.7,
		0.24
	)
	actor.global_position = destination
	CharmVfx.spawn(actor.get_parent(), destination, CharmVfx.TIDE, 1.35)
	get_node("/root/ScreenShakeController").request(2.5, 0.12)
	runtime.start_cooldown()
	cancel_active()
	return true


func cancel_active() -> void:
	_stop_cast_animation()
	set_physics_process(false)
	_window_remaining = 0.0
	_armed = false
	if is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null
