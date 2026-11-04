class_name AbyssalWhirlpoolEffect
extends CharmEffect
## Pulls ordinary enemies for a short window, then resolves one AoE blast.

var _zone: Area3D
var _remaining: float = 0.0
var _exploded: bool = false


func activate(context: CharmActivationContext) -> bool:
	if not super.can_activate(context) or not context.has_target or not is_instance_valid(actor):
		return false
	_zone = Area3D.new()
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	var radius := definition.get_param_float(&"radius_units", 2.5)
	sphere.radius = radius
	shape.shape = sphere
	_zone.add_child(shape)
	_zone.collision_layer = 0
	_zone.collision_mask = 16
	_zone.global_position = context.target_position
	actor.get_parent().add_child(_zone)
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.05
	visual.mesh = mesh
	visual.modulate = Color(0.15, 0.4, 0.9, 0.5)
	_zone.add_child(visual)
	_remaining = definition.get_param_float(&"duration_seconds", 1.5)
	_exploded = false
	set_physics_process(true)
	return true


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_zone) or not is_instance_valid(actor) or bool(actor.get("dead")):
		cancel_active()
		return
	for area: Area3D in _zone.get_overlapping_areas():
		var hurtbox := area as HurtBox
		if hurtbox == null or not is_instance_valid(hurtbox.actor) or not hurtbox.actor is Node3D:
			continue
		var target := hurtbox.actor as Node3D
		if (
			target.is_in_group("boss")
			or target.is_in_group("large")
			or target.is_in_group("immovable")
		):
			continue
		var direction := _zone.global_position - target.global_position
		direction.y = 0.0
		if direction.length() > 0.05:
			target.global_position += direction.normalized() * minf(direction.length(), delta * 3.0)
	_remaining -= maxf(0.0, delta)
	if _remaining <= 0.0 and not _exploded:
		_explode()


func _explode() -> void:
	_exploded = true
	var radius := definition.get_param_float(&"radius_units", 2.5)
	var damage := _get_base_damage() * definition.get_param_float(&"damage_multiplier", 1.0)
	for node in actor.get_tree().get_nodes_in_group("enemy"):
		if not node is Node3D or node.is_in_group("boss"):
			continue
		if (node as Node3D).global_position.distance_to(_zone.global_position) > radius:
			continue
		if node.has_method("receive_damage"):
			var context := DamageContext.new()
			context.source = actor
			context.source_team = actor.get("team")
			context.amount_hp = damage
			context.base_amount_hp = damage
			context.tag = definition.charm_id
			node.call("receive_damage", context)
	cancel_active()


func cancel_active() -> void:
	set_physics_process(false)
	if is_instance_valid(_zone):
		_zone.queue_free()
	_zone = null
	_remaining = 0.0
	_exploded = false


func _get_base_damage() -> float:
	var weapon_controller := actor.get("weapon_controller") as WeaponController
	if is_instance_valid(weapon_controller) and weapon_controller.equipped != null:
		var attack := weapon_controller.equipped.get_attack(&"normal")
		if attack != null:
			return attack.damage_hp
	return 1.0
