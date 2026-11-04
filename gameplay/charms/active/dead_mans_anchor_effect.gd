class_name DeadMansAnchorEffect
extends CharmEffect
## Two-stage marker and collision-safe return.

var _marker: MeshInstance3D
var _window_remaining: float = 0.0
var _armed: bool = false


func get_cooldown_policy() -> StringName:
	return &"manual"


func get_activation_cost(_context: CharmActivationContext) -> float:
	return 0.0 if _armed else definition.resource_cost


func can_bypass_cooldown(_context: CharmActivationContext) -> bool:
	return _armed


func activate(_context: CharmActivationContext) -> bool:
	if not is_instance_valid(actor):
		return false
	if _armed:
		return _recast()
	_marker = MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.35
	mesh.height = 1.2
	_marker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.8, 1.0, 0.65)
	material.emission_enabled = true
	material.emission = Color(0.05, 0.4, 0.9, 1.0)
	material.emission_energy_multiplier = 2.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker.material_override = material
	_marker.global_position = actor.global_position
	actor.get_parent().add_child(_marker)
	_window_remaining = definition.get_param_float(&"recast_window_seconds", 5.0)
	_armed = true
	set_physics_process(true)
	return true


func _physics_process(delta: float) -> void:
	if not _armed or not is_instance_valid(actor) or bool(actor.get("dead")):
		cancel_active()
		return
	_window_remaining -= maxf(0.0, delta)
	if is_instance_valid(_marker):
		_marker.rotation.y += delta * 2.0
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
	actor.global_position = destination
	runtime.start_cooldown()
	cancel_active()
	return true


func cancel_active() -> void:
	set_physics_process(false)
	_window_remaining = 0.0
	_armed = false
	if is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null
