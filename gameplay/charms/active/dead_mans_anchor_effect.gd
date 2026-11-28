class_name DeadMansAnchorEffect
extends CharmEffect
## Two-stage marker and collision-safe return.

const MARKER := preload("res://gameplay/charms/active/dead_mans_anchor_marker.tscn")
const DROP_HEIGHT_UNITS := 1.6
const DROP_SECONDS := 0.22
const RECALL_TRAIL_SECONDS := 0.24

var _marker: Sprite3D
var _return_position := Vector3.ZERO
var _window_duration := 0.0
var _window_remaining: float = 0.0
var _armed: bool = false


func get_recast_remaining() -> float:
	return _window_remaining if _armed else 0.0


func get_recast_fraction() -> float:
	return get_recast_remaining() / _window_duration if _window_duration > 0.0 else 0.0


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
			_play_cast_animation(&"recall", context.direction, RECALL_TRAIL_SECONDS)
		return recalled
	_window_duration = definition.get_param_float(&"recast_window_seconds", 5.0)
	_window_remaining = _window_duration
	_return_position = actor.global_position
	_marker = MARKER.instantiate() as Sprite3D
	actor.get_parent().add_child(_marker)
	_marker.global_position = _return_position + Vector3.UP * DROP_HEIGHT_UNITS
	var drop := _marker.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	(
		drop
		. tween_property(_marker, "global_position", _return_position, DROP_SECONDS)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	drop.tween_callback(_on_anchor_landed.bind(context.direction))
	_armed = true
	set_physics_process(true)
	_play_cast_animation(&"cast", context.direction, DROP_SECONDS)
	return true


func _physics_process(delta: float) -> void:
	if not _armed or not is_instance_valid(actor) or bool(actor.get("dead")):
		cancel_active()
		return
	_window_remaining -= maxf(0.0, delta)
	if _window_remaining <= 0.0:
		runtime.start_cooldown()
		cancel_active()


func _on_anchor_landed(direction: Vector3) -> void:
	if _armed:
		_play_cast_animation(&"land", direction, 0.0, true)
		CharmVfx.spawn(actor.get_parent(), _return_position, CharmVfx.TIDE, 0.75)
		CharmBlastVfx.burst(
			actor.get_parent(), _return_position, CharmBlastVfx.Kind.TIDE, 1.2, CharmVfx.TIDE
		)
		CharmFeel.shake(actor, 3.0, 0.12)
		CharmFeel.sound(actor, CharmFeel.IMPACT_SOUND, _return_position, -8.0, 0.8)


func _recast() -> bool:
	if not is_instance_valid(_marker):
		cancel_active()
		return false
	var destination := _return_position
	if (
		actor is CharacterBody3D
		and (actor as CharacterBody3D).test_move(
			actor.global_transform, destination - actor.global_position
		)
	):
		runtime.proc_triggered.emit("BLOCKED", Color.ORANGE)
		return false
	CharmVfx.spawn(actor.get_parent(), actor.global_position, CharmVfx.TIDE, 1.0)
	CharmVfx.streak(
		actor.get_parent(),
		actor.global_position + Vector3.UP * 0.5,
		destination + Vector3.UP * 0.5,
		CharmVfx.TIDE,
		0.7,
		RECALL_TRAIL_SECONDS
	)
	actor.global_position = destination
	actor.reset_physics_interpolation()
	CharmVfx.spawn(actor.get_parent(), destination, CharmVfx.TIDE, 1.35)
	CharmBlastVfx.burst(
		actor.get_parent(), destination, CharmBlastVfx.Kind.TIDE, 1.6, CharmVfx.TIDE
	)
	CharmFeel.shake(actor, 4.0, 0.14)
	CharmFeel.flash(actor, CharmVfx.TIDE, 0.08, 0.12)
	CharmFeel.shockwave(actor, destination + Vector3.UP * 0.6, CharmVfx.TIDE, 130.0)
	CharmFeel.sound(actor, CharmFeel.WHOOSH_SOUND, destination, -5.0, 1.2)
	runtime.start_cooldown()
	cancel_active()
	return true


func on_input_cancelled() -> void:
	# Releasing or blocking input does not remove an anchor already in the world.
	pass


func cancel_active() -> void:
	_stop_cast_animation()
	set_physics_process(false)
	_window_remaining = 0.0
	_armed = false
	if is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null
