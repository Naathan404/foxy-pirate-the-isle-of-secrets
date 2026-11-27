class_name RoomEdgeFence
extends Node3D
## Draws a driftwood rope fence along the room's invisible player boundaries, so every edge that
## stops Foxy shows why. Visual only: BaseRoom's walls do the blocking, and the fence is rebuilt
## with them, so openings (bridges, open exits) can never drift apart from the collision.
##
## Stakes are hand-painted camera-facing sprites (art from make_fence_post.py in the
## coral-valley-room-art skill), drawn as one MultiMesh per variant and pivoting at their foot
## like every tall Coral Valley prop. Ropes are textured tubes between the lashings.

## Wall ends closer than this belong to the same run of fence.
const JOIN_DISTANCE_METERS := 0.35
## A boundary wall's centre sits this far above the floor it closes.
const WALL_CENTER_HEIGHT_METERS := 1.45
const ROPE_SEGMENTS := 6
const ROPE_SIDES := 6
## Height share of the stake art, from its foot, where the lashing is painted (TIE_RATIO).
const LASHING_RATIO := 0.66
## Gameplay camera pitch below the horizon, used when no camera exists yet.
const DEFAULT_CAMERA_PITCH_DEGREES := 40.0
const POST_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/biomes/coral_valley/fence_post_1.png"),
	preload("res://assets/sprites/biomes/coral_valley/fence_post_2.png"),
	preload("res://assets/sprites/biomes/coral_valley/fence_post_3.png"),
]
const ROPE_TEXTURE: Texture2D = preload("res://assets/sprites/biomes/coral_valley/fence_rope.png")

@export var room: BaseRoom

@export_group("Layout")
@export_range(0.8, 6.0, 0.1, "suffix:m") var post_spacing_meters: float = 2.4
## Moves the posts from the wall line back onto the floor.
@export_range(0.0, 0.6, 0.01, "suffix:m") var inset_meters: float = 0.18
## Runs shorter than this are corner slivers and get no fence.
@export_range(0.0, 3.0, 0.05, "suffix:m") var minimum_run_meters: float = 0.6
## Same layout on every visit; change it to reshuffle the stake variants.
@export var variant_seed: int = 7

@export_group("Stake")
## On-screen height of the stake sprite.
@export_range(0.3, 2.5, 0.05, "suffix:m") var post_height_meters: float = 1.4
## Sinks the foot a little so the stake reads as driven into the sand.
@export_range(0.0, 0.3, 0.01, "suffix:m") var post_sink_meters: float = 0.04

@export_group("Rope")
@export_range(0.01, 0.15, 0.005, "suffix:m") var rope_radius_meters: float = 0.06
@export_range(0.0, 0.6, 0.01, "suffix:m") var rope_sag_meters: float = 0.16
@export var rope_ink_color: Color = Color(0.21, 0.13, 0.15)
@export_range(0.0, 0.05, 0.002, "suffix:m") var rope_outline_meters: float = 0.018


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
	var spans: Array[PackedVector3Array] = []
	for run: PackedVector3Array in _collect_runs(walls):
		var points := _space_posts(run)
		for i in points.size():
			# Runs meet at corners; one stake there is enough.
			if not _has_post_near(posts, points[i]):
				posts.append(points[i])
			if i > 0:
				spans.append(PackedVector3Array([points[i - 1], points[i]]))
	if posts.is_empty():
		return
	_add_posts(posts)
	if not spans.is_empty():
		_add_ropes(spans)


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
	var random := RandomNumberGenerator.new()
	random.seed = variant_seed
	var by_variant: Array[Array] = []
	for texture in POST_TEXTURES:
		by_variant.append([])
	for post: Vector3 in posts:
		by_variant[random.randi_range(0, POST_TEXTURES.size() - 1)].append(post)
	for variant in POST_TEXTURES.size():
		var group: Array = by_variant[variant]
		if group.is_empty():
			continue
		var texture := POST_TEXTURES[variant]
		var quad := QuadMesh.new()
		var width := post_height_meters * texture.get_width() / texture.get_height()
		quad.size = Vector2(width, post_height_meters)
		# Pivot at the foot, so the billboard tilt never drags the base towards the camera.
		quad.center_offset = Vector3(0.0, post_height_meters * 0.5 - post_sink_meters, 0.0)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = quad
		multimesh.instance_count = group.size()
		for i in group.size():
			multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, group[i]))
		var instance := MultiMeshInstance3D.new()
		instance.name = "Stakes%d" % (variant + 1)
		instance.multimesh = multimesh
		instance.material_override = _stake_material(texture)
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)


func _stake_material(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.roughness = 1.0
	return material


## A camera-facing sprite point at height h reads like a world point at h / cos(pitch).
func _tie_height() -> float:
	var pitch := deg_to_rad(DEFAULT_CAMERA_PITCH_DEGREES)
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if is_instance_valid(camera):
		# The camera looks along -Z, so its +Z axis rises by the pitch.
		pitch = asin(clampf(camera.global_basis.z.y, 0.1, 0.99))
	var lashing := post_height_meters * LASHING_RATIO - post_sink_meters
	return lashing / maxf(cos(pitch), 0.2)


func _add_ropes(spans: Array[PackedVector3Array]) -> void:
	var tie := Vector3.UP * _tie_height()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for span: PackedVector3Array in spans:
		var from := span[0] + tie
		var to := span[1] + tie
		var side := (to - from).cross(Vector3.UP).normalized()
		var length := from.distance_to(to)
		var base := vertices.size()
		for i in ROPE_SEGMENTS + 1:
			var t := float(i) / ROPE_SEGMENTS
			var center := from.lerp(to, t) + Vector3.DOWN * rope_sag_meters * 4.0 * t * (1.0 - t)
			for k in ROPE_SIDES + 1:
				var angle := TAU * k / ROPE_SIDES
				var normal := side * cos(angle) + Vector3.UP * sin(angle)
				vertices.append(center + normal * rope_radius_meters)
				normals.append(normal)
				uvs.append(Vector2(t * length / 0.6, float(k) / ROPE_SIDES))
		for i in ROPE_SEGMENTS:
			for k in ROPE_SIDES:
				var a := base + i * (ROPE_SIDES + 1) + k
				var b := a + ROPE_SIDES + 1
				indices.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.albedo_texture = ROPE_TEXTURE
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Ink outline like the painted props.
	var ink := StandardMaterial3D.new()
	ink.albedo_color = rope_ink_color
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.cull_mode = BaseMaterial3D.CULL_FRONT
	ink.grow = true
	ink.grow_amount = rope_outline_meters
	material.next_pass = ink
	var rope_mesh := MeshInstance3D.new()
	rope_mesh.name = "Ropes"
	rope_mesh.mesh = mesh
	rope_mesh.material_override = material
	rope_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rope_mesh)
