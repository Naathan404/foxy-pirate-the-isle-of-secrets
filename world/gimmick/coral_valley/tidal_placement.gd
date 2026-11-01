extends RefCounted
## Shared terrain/body validation for new spawns and returning survivors.

static func find_floor(context: Node3D, origin: Vector3, mask: int,
		above: float = 2.0, below: float = 128.0, clearance: float = 0.03) -> Variant:
	var query := PhysicsRayQueryParameters3D.create(
		origin + Vector3.UP * above, origin + Vector3.DOWN * below, mask)
	query.collide_with_areas = false
	# Floating crates and other moving bodies are not permanent seabed.
	for attempt in range(16):
		var hit := context.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return null
		var body = hit.collider
		if body is PhysicsBody3D and not body is StaticBody3D:
			var excluded := query.exclude
			excluded.append(body.get_rid())
			query.exclude = excluded
			continue
		if (hit.normal as Vector3).y < 0.7:
			return null
		return (hit.position as Vector3) + Vector3.UP * clearance
	return null


static func body_radius(enemy: EnemyBase) -> float:
	var radius := 0.4
	for child: Node in enemy.get_children():
		var collider := child as CollisionShape3D
		if collider == null or collider.disabled or collider.shape == null:
			continue
		var shape := collider.shape
		var extent := 0.4
		if shape is CapsuleShape3D or shape is CylinderShape3D or shape is SphereShape3D:
			extent = shape.radius
		elif shape is BoxShape3D:
			extent = maxf(shape.size.x, shape.size.z) * 0.5
		radius = maxf(radius, extent * maxf(absf(collider.scale.x), absf(collider.scale.z)))
	var scale := enemy.global_basis.get_scale() if enemy.is_inside_tree() else enemy.basis.get_scale()
	return radius * maxf(absf(scale.x), absf(scale.z))


static func can_stand(context: Node3D, enemy: EnemyBase, position: Vector3,
		ground_mask: int, clearance: float = 0.03, player_distance: float = 1.5) -> bool:
	var radius := body_radius(enemy)
	# A center ray alone can put a wide Crab half over a cliff or narrow ledge.
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var sample := position + Vector3(cos(angle), 0, sin(angle)) * radius * 0.85
		var floor_point = find_floor(context, sample, ground_mask, 0.4, 0.8, clearance)
		if not floor_point is Vector3 or absf(floor_point.y - position.y) > 0.35:
			return false
	var basis := enemy.global_basis if enemy.is_inside_tree() else context.global_basis * enemy.basis
	var pose := Transform3D(basis, position)
	for child: Node in enemy.get_children():
		var collider := child as CollisionShape3D
		if collider == null or collider.disabled or collider.shape == null:
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = collider.shape
		query.transform = pose * collider.transform
		query.collision_mask = ground_mask | CombatLayers.PLAYER_BODY | CombatLayers.ENEMY_BODY
		query.collide_with_areas = false
		query.margin = 0.005
		if enemy.is_inside_tree():
			query.exclude = [enemy.get_rid()]
		if not context.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return false
	for node: Node in context.get_tree().get_nodes_in_group(&"player"):
		if node is Node3D and horizontal_distance(position, node.global_position) < player_distance:
			return false
	# Hidden bodies have collision_layer=0, so reserve their resting places explicitly.
	for node: Node in context.get_tree().get_nodes_in_group(&"tidal_enemies"):
		var other := node as EnemyBase
		if other == null or other == enemy or other.dead or other.is_queued_for_deletion():
			continue
		if absf(other.global_position.y - position.y) > 2.0:
			continue
		if horizontal_distance(position, other.global_position) < radius + body_radius(other) + 0.1:
			return false
	return true


static func horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func can_step(context: Node3D, enemy: EnemyBase, destination: Vector3,
		ground_mask: int, clearance: float = 0.03) -> bool:
	var ground = find_floor(context, destination, ground_mask, 0.4, 0.8, clearance)
	if not ground is Vector3 or absf(ground.y - enemy.global_position.y) > 0.35:
		return false
	if not can_stand(context, enemy, ground, ground_mask, clearance):
		return false
	for child: Node in enemy.get_children():
		var collider := child as CollisionShape3D
		if collider == null or collider.disabled or collider.shape == null:
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = collider.shape
		query.transform = enemy.global_transform * collider.transform
		query.motion = ground - enemy.global_position
		query.collision_mask = ground_mask | CombatLayers.PLAYER_BODY | CombatLayers.ENEMY_BODY
		query.collide_with_areas = false
		query.exclude = [enemy.get_rid()]
		var result := context.get_world_3d().direct_space_state.cast_motion(query)
		if result[0] < 0.99:
			return false
	return true
