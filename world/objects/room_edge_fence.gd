class_name RoomEdgeFence
extends Node3D
## Draws a rope fence along the room's invisible player boundaries, so every edge that stops
## Foxy shows why. Visual only: BaseRoom's walls do the blocking, and the fence is rebuilt with
## them, so openings (bridges, open exits) can never drift apart from the collision.

## Wall ends closer than this belong to the same run of fence.
const JOIN_DISTANCE_METERS := 0.35
## A boundary wall's centre sits this far above the floor it closes.
const WALL_CENTER_HEIGHT_METERS := 1.45
const ROPE_SEGMENTS := 6
const ROPE_SIDES := 5

@export var room: BaseRoom

@export_group("Layout")
@export_range(0.8, 6.0, 0.1, "suffix:m") var post_spacing_meters: float = 2.4
## Moves the posts from the wall line back onto the floor.
@export_range(0.0, 0.6, 0.01, "suffix:m") var inset_meters: float = 0.16
## Runs shorter than this are corner slivers and get no fence.
@export_range(0.0, 3.0, 0.05, "suffix:m") var minimum_run_meters: float = 0.6

@export_group("Post")
@export_range(0.2, 2.0, 0.05, "suffix:m") var post_height_meters: float = 0.85
@export_range(0.04, 0.4, 0.01, "suffix:m") var post_radius_meters: float = 0.17
@export var wood_color: Color = Color(0.84, 0.68, 0.52)
@export var cap_color: Color = Color(0.29, 0.31, 0.34)
@export var ink_color: Color = Color(0.21, 0.13, 0.15)
## Self-light that keeps the flat colours readable on the side the sun misses.
@export_range(0.0, 1.0, 0.05) var fill_light: float = 0.25
@export_range(0.0, 0.08, 0.005, "suffix:m") var outline_meters: float = 0.025

@export_group("Rope")
@export var rope_color: Color = Color(0.93, 0.78, 0.52)
@export_range(0.01, 0.15, 0.005, "suffix:m") var rope_radius_meters: float = 0.06
@export_range(0.0, 0.6, 0.01, "suffix:m") var rope_sag_meters: float = 0.14
## Where the rope is tied, as a share of the post height.
@export_range(0.2, 1.0, 0.05) var rope_height_ratio: float = 0.75


func _ready() -> void:
	if room == null:
		push_error("RoomEdgeFence: assign the room.")
		return
	room.player_boundaries_rebuilt.connect(_rebuild)


func _rebuild(walls: StaticBody3D) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var posts: Array[Vector3] = []
	var ropes := SurfaceTool.new()
	ropes.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rope_count := 0
	for run: PackedVector3Array in _collect_runs(walls):
		var points := _space_posts(run)
		for i in points.size():
			# Runs meet at corners; one post there is enough.
			if not _has_post_near(posts, points[i]):
				posts.append(points[i])
			if i > 0:
				_add_rope(ropes, points[i - 1], points[i])
				rope_count += 1
	if posts.is_empty():
		return
	_add_posts(posts)
	if rope_count > 0:
		ropes.generate_normals()
		var rope_mesh := MeshInstance3D.new()
		rope_mesh.name = "Ropes"
		rope_mesh.mesh = ropes.commit()
		rope_mesh.material_override = _material(rope_color, outline_meters * 0.6)
		add_child(rope_mesh)


## Chains the wall segments into polylines on the floor, in this node's space.
func _collect_runs(walls: StaticBody3D) -> Array[PackedVector3Array]:
	var segments: Array[PackedVector3Array] = []
	var to_local_space := global_transform.affine_inverse()
	for node in walls.get_children():
		var shape_node := node as CollisionShape3D
		if shape_node == null or not shape_node.shape is BoxShape3D:
			continue
		var half := (shape_node.shape as BoxShape3D).size.x * 0.5
		var xform := to_local_space * shape_node.global_transform
		# BaseRoom builds every wall with its local +Z facing back onto the floor.
		var shift := (
			xform.basis.z.normalized() * inset_meters + Vector3.DOWN * WALL_CENTER_HEIGHT_METERS
		)
		segments.append(
			PackedVector3Array(
				[xform * Vector3(-half, 0.0, 0.0) + shift, xform * Vector3(half, 0.0, 0.0) + shift]
			)
		)
	var runs: Array[PackedVector3Array] = []
	while not segments.is_empty():
		var run: PackedVector3Array = segments.pop_back()
		var grew := true
		while grew:
			grew = false
			for i in range(segments.size() - 1, -1, -1):
				if _try_join(run, segments[i]):
					segments.remove_at(i)
					grew = true
		runs.append(run)
	return runs


func _try_join(run: PackedVector3Array, segment: PackedVector3Array) -> bool:
	var head := run[0]
	var tail := run[run.size() - 1]
	for end_index in 2:
		var near := segment[end_index]
		var far := segment[1 - end_index]
		if tail.distance_to(near) <= JOIN_DISTANCE_METERS:
			run.append(far)
			return true
		if head.distance_to(near) <= JOIN_DISTANCE_METERS:
			run.insert(0, far)
			return true
	return false


## Even post positions along a run, always keeping both ends.
func _space_posts(run: PackedVector3Array) -> PackedVector3Array:
	var lengths := PackedFloat32Array([0.0])
	for i in range(1, run.size()):
		lengths.append(lengths[i - 1] + run[i - 1].distance_to(run[i]))
	var total := lengths[lengths.size() - 1]
	var result := PackedVector3Array()
	if total < minimum_run_meters:
		return result
	var spans := maxi(1, ceili(total / post_spacing_meters))
	var index := 1
	for step in spans + 1:
		var distance := total * float(step) / spans
		while index < run.size() - 1 and lengths[index] < distance:
			index += 1
		var span := maxf(lengths[index] - lengths[index - 1], 0.0001)
		result.append(run[index - 1].lerp(run[index], (distance - lengths[index - 1]) / span))
	return result


func _has_post_near(posts: Array[Vector3], point: Vector3) -> bool:
	for post: Vector3 in posts:
		if post.distance_to(point) <= JOIN_DISTANCE_METERS:
			return true
	return false


func _add_posts(posts: Array[Vector3]) -> void:
	var body := CylinderMesh.new()
	body.top_radius = post_radius_meters * 0.9
	body.bottom_radius = post_radius_meters
	body.height = post_height_meters
	body.radial_segments = 10
	body.rings = 1
	_add_multimesh(
		"Posts", body, _material(wood_color, outline_meters), posts, post_height_meters * 0.5
	)
	var cap := CylinderMesh.new()
	cap.top_radius = post_radius_meters * 0.75
	cap.bottom_radius = post_radius_meters * 1.05
	cap.height = post_height_meters * 0.16
	cap.radial_segments = 10
	cap.rings = 1
	_add_multimesh(
		"Caps",
		cap,
		_material(cap_color, outline_meters),
		posts,
		post_height_meters + cap.height * 0.5
	)
	var wrap := CylinderMesh.new()
	wrap.top_radius = post_radius_meters * 1.12
	wrap.bottom_radius = post_radius_meters * 1.12
	wrap.height = rope_radius_meters * 2.6
	wrap.radial_segments = 10
	wrap.rings = 1
	_add_multimesh(
		"Wraps",
		wrap,
		_material(rope_color, outline_meters * 0.6),
		posts,
		post_height_meters * rope_height_ratio
	)


func _add_multimesh(
	node_name: String, mesh: Mesh, material: Material, posts: Array[Vector3], lift: float
) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = posts.size()
	for i in posts.size():
		multimesh.set_instance_transform(
			i, Transform3D(Basis.IDENTITY, posts[i] + Vector3.UP * lift)
		)
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	add_child(instance)


## A flat-coloured prop with the dark ink outline the other Coral Valley props have.
func _material(color: Color, outline: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = fill_light
	if outline > 0.0:
		var ink := StandardMaterial3D.new()
		ink.albedo_color = ink_color
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.cull_mode = BaseMaterial3D.CULL_FRONT
		ink.grow = true
		ink.grow_amount = outline
		material.next_pass = ink
	return material


func _add_rope(surface: SurfaceTool, from: Vector3, to: Vector3) -> void:
	var tie := Vector3.UP * post_height_meters * rope_height_ratio
	var rings: Array[PackedVector3Array] = []
	for i in ROPE_SEGMENTS + 1:
		var t := float(i) / ROPE_SEGMENTS
		var center := from.lerp(to, t) + tie + Vector3.DOWN * rope_sag_meters * 4.0 * t * (1.0 - t)
		var side := (to - from).cross(Vector3.UP).normalized()
		var ring := PackedVector3Array()
		for k in ROPE_SIDES:
			var angle := TAU * k / ROPE_SIDES
			ring.append(center + (side * cos(angle) + Vector3.UP * sin(angle)) * rope_radius_meters)
		rings.append(ring)
	for i in ROPE_SEGMENTS:
		for k in ROPE_SIDES:
			var next := (k + 1) % ROPE_SIDES
			for point: Vector3 in [
				rings[i][k],
				rings[i + 1][k],
				rings[i][next],
				rings[i][next],
				rings[i + 1][k],
				rings[i + 1][next],
			]:
				surface.add_vertex(point)
