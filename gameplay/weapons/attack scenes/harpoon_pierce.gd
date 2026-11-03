extends HarpoonThrust
## Movement belongs to this execution: world collision stops it, enemy bodies do not.

const TRAIL: PackedScene = preload("res://gameplay/weapons/bow_energy_trail.tscn")

@export_range(0.05, 0.5, 0.01) var sweep_step: float = 0.18
@export_range(0.2, 3.0, 0.1) var maximum_ground_drop: float = 1.4

var _body: CharacterBody3D
var _saved_mask: int = 0
var _owns_mask: bool = false
var _protected: bool = false
var _ended: bool = false
var _distance: float = 0.0
var _trail: Node3D


func activate() -> void:
	_body = context.actor as CharacterBody3D
	if not is_instance_valid(_body):
		return

	_saved_mask = _body.collision_mask
	_owns_mask = true
	_body.collision_mask = CombatLayers.WORLD
	_protected = true
	_ended = false
	_distance = 0.0
	_trail = TRAIL.instantiate() as Node3D
	_trail.set("strength", 1.0)
	_trail.set("head_color", Color(1.0, 0.76, 0.18, 1.0))
	_trail.set("tail_color", Color(1.0, 0.35, 0.02, 0.0))
	_trail.set("core_color", Color(1.0, 1.0, 0.8, 1.0))
	_trail.set("charge_width_bonus", 0.24)
	get_parent().add_child(_trail)
	_trail.call("push_point", _body.global_position + Vector3.UP * 0.8)
	super.activate()
	get_node("/root/ScreenShakeController").request(3.5, 0.13)


func tick_active(delta: float) -> void:
	if not active or _ended or not is_instance_valid(_body):
		return
	if bool(_body.get("dead")) or bool(_body.call("is_gameplay_input_blocked")):
		_stop_dash()
		return
	var travel := minf(
		context.range_units - _distance,
		context.range_units * maxf(0.0, delta) / context.active_seconds
	)
	var remaining: float = travel
	while remaining > 0.0001 and active:
		var step: float = minf(sweep_step, remaining)
		var motion: Vector3 = context.direction * step
		if not _has_ground(_body.global_position + motion):
			_stop_dash()
			return
		var before := _body.global_position
		var collision := _body.move_and_collide(motion)
		_distance += before.distance_to(_body.global_position)
		_sync_transform()
		hitbox.sample_shape()
		if not active or not is_instance_valid(_body):
			return
		_trail.call("push_point", _body.global_position + Vector3.UP * 0.8)
		if collision != null:
			_stop_dash()
			return
		remaining -= step
	_elapsed += maxf(0.0, delta)
	_vfx.call("set_progress", clampf(_elapsed / context.active_seconds, 0.0, 1.0))
	if _distance >= context.range_units - 0.0001:
		_stop_dash()


func _has_ground(at: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
		at + Vector3.UP * 0.4, at + Vector3.DOWN * maximum_ground_drop, CombatLayers.WORLD
	)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func is_invulnerable() -> bool:
	return active and _protected and not _ended


func has_finished_active() -> bool:
	return _ended


func _stop_dash() -> void:
	_ended = true
	deactivate()


func deactivate() -> void:
	_protected = false
	if _owns_mask and is_instance_valid(_body):
		_body.collision_mask = _saved_mask
		_body.velocity.x = 0.0
		_body.velocity.z = 0.0
	_owns_mask = false
	if is_instance_valid(_trail):
		_trail.call("finish")
		_trail = null
	super.deactivate()


func _exit_tree() -> void:
	deactivate()
	super._exit_tree()
