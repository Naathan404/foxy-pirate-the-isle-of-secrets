@tool
class_name MultiMeshDecorator
extends Area3D

enum SurfaceDirection {
	UP,
	ALL,
}

enum SourceUpAxis {
	UP,
	DOWN,
	LEFT,
	RIGHT,
	FORWARD,
	BACK,
}
@export_storage var generated_multimesh: MultiMesh
@export_tool_button("Populate") var populate_action = populate
@export_tool_button("Clear") var clear_action = clear_instances

@export_group("Source")
@export var source_mesh: Mesh
@export var source_up_axis: SourceUpAxis = SourceUpAxis.UP

@export_group("Surface")
@export var surface_direction: SurfaceDirection = SurfaceDirection.UP
@export_range(-1.0, 1.0, 0.01) var up_normal_threshold: float = 0.6

@export_group("Population")
@export_range(0, 100000, 1) var instance_count: int = 100
@export var randomize_on_populate: bool = true
@export var seed: int = 0
@export_range(0.0, 360.0, 0.1, "suffix:deg") var random_rotation: float = 360.0
@export_range(0.0, 90.0, 0.1, "suffix:deg") var random_tilt: float = 0.0
@export var base_scale: Vector3 = Vector3.ONE
@export_range(0.01, 10.0, 0.01) var random_scale_min: float = 1.0
@export_range(0.01, 10.0, 0.01) var random_scale_max: float = 1.0

@export_group("Position Distribution")
@export_range(0.0, 1.0, 0.01) var position_evenness: float = 0.7
@export_range(1, 32, 1) var position_attempts: int = 8

var _random := RandomNumberGenerator.new()
var _generated_output: MultiMeshInstance3D


func _ready() -> void:
	_ensure_generated_output()


func populate() -> void:
	var surface_collision := _get_surface_collision()
	if source_mesh == null or surface_collision == null or surface_collision.shape == null:
		push_warning("Assign Source Mesh and CollisionShape3D before populating.")
		return
	var triangles := _collect_surface_triangles(surface_collision)
	if triangles.is_empty():
		push_warning("CollisionShape3D has no eligible surface.")
		return
	if randomize_on_populate != false:
		_random.randomize()
	else:
		_random.seed = seed
	var result := MultiMesh.new()
	result.transform_format = MultiMesh.TRANSFORM_3D
	result.mesh = source_mesh
	result.instance_count = instance_count
	result.visible_instance_count = -1
	var total_weight := _total_weight(triangles)
	var minimum_distance := _minimum_position_distance(total_weight)
	var position_grid: Dictionary = {}
	for index in instance_count:
		var placement := _pick_spaced_placement(
			triangles, total_weight, minimum_distance, position_grid
		)
		result.set_instance_transform(index, _make_transform(placement))
	generated_multimesh = result
	_ensure_generated_output()
	_generated_output.multimesh = generated_multimesh


func clear_instances() -> void:
	generated_multimesh = null
	if is_instance_valid(_generated_output):
		_generated_output.multimesh = null


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if source_mesh == null:
		warnings.append("Assign a Mesh resource to Source Mesh.")
	var surface_collision := _get_surface_collision()
	if surface_collision == null or surface_collision.shape == null:
		warnings.append("Assign a shape to CollisionShape3D before populating.")
	return warnings


func _ensure_generated_output() -> void:
	if is_instance_valid(_generated_output):
		return
	_generated_output = MultiMeshInstance3D.new()
	_generated_output.name = "_GeneratedMultiMesh"
	add_child(_generated_output, false, Node.INTERNAL_MODE_BACK)
	_generated_output.multimesh = generated_multimesh


func _get_surface_collision() -> CollisionShape3D:
	return get_node_or_null(^"CollisionShape3D") as CollisionShape3D


func _collect_surface_triangles(collision: CollisionShape3D) -> Array[Dictionary]:
	var debug_mesh := collision.shape.get_debug_mesh()
	var triangles: Array[Dictionary] = []
	for surface_index in debug_mesh.get_surface_count():
		if debug_mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := debug_mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for vertex_index in range(0, vertices.size() - 2, 3):
				_add_triangle(
					triangles,
					collision.global_transform,
					vertices,
					vertex_index,
					vertex_index + 1,
					vertex_index + 2
				)
		else:
			for index_offset in range(0, indices.size() - 2, 3):
				_add_triangle(
					triangles,
					collision.global_transform,
					vertices,
					indices[index_offset],
					indices[index_offset + 1],
					indices[index_offset + 2]
				)
	return triangles


func _add_triangle(
	triangles: Array[Dictionary],
	collision_transform: Transform3D,
	vertices: PackedVector3Array,
	first_index: int,
	second_index: int,
	third_index: int
) -> void:
	var first := collision_transform * vertices[first_index]
	var second := collision_transform * vertices[second_index]
	var third := collision_transform * vertices[third_index]
	var normal := (second - first).cross(third - first)
	var double_area := normal.length()
	if double_area <= 0.00001:
		return
	normal /= double_area
	if surface_direction == SurfaceDirection.UP and normal.dot(Vector3.UP) < up_normal_threshold:
		return
	(
		triangles
		. append(
			{
				"first": first,
				"second": second,
				"third": third,
				"normal": normal,
				"weight": double_area * 0.5,
			}
		)
	)


func _total_weight(triangles: Array[Dictionary]) -> float:
	var total := 0.0
	for triangle in triangles:
		total += triangle.weight
	return total


func _pick_triangle(triangles: Array[Dictionary], total_weight: float) -> Dictionary:
	var remaining_weight := _random.randf() * total_weight
	for triangle in triangles:
		remaining_weight -= triangle.weight
		if remaining_weight <= 0.0:
			return triangle
	return triangles.back()


func _minimum_position_distance(total_weight: float) -> float:
	var evenness: float = 0.7 if position_evenness == null else position_evenness
	if instance_count <= 1 or is_zero_approx(evenness):
		return 0.0
	return sqrt(total_weight / float(instance_count)) * evenness


func _pick_spaced_placement(
	triangles: Array[Dictionary],
	total_weight: float,
	minimum_distance: float,
	position_grid: Dictionary
) -> Dictionary:
	var placement: Dictionary = {}
	var attempt_count: int = 8 if position_attempts == null else position_attempts
	for _attempt in maxi(1, attempt_count):
		placement = _sample_placement(_pick_triangle(triangles, total_weight))
		var position: Vector3 = placement["position"]
		if (
			minimum_distance <= 0.0
			or _is_position_available(position, minimum_distance, position_grid)
		):
			_register_position(position, minimum_distance, position_grid)
			return placement
	var fallback_position: Vector3 = placement["position"]
	_register_position(fallback_position, minimum_distance, position_grid)
	return placement


func _sample_placement(triangle: Dictionary) -> Dictionary:
	var first: Vector3 = triangle.first
	var second: Vector3 = triangle.second
	var third: Vector3 = triangle.third
	var root := sqrt(_random.randf())
	var triangle_random := _random.randf()
	var second_weight := root * (1.0 - triangle_random)
	var third_weight := root * triangle_random
	var world_position := first * (1.0 - root) + second * second_weight + third * third_weight
	return {"position": world_position, "normal": triangle.normal}


func _is_position_available(
	position: Vector3, minimum_distance: float, position_grid: Dictionary
) -> bool:
	var cell_size := maxf(minimum_distance, 0.001)
	var cell := _position_cell(position, cell_size)
	var minimum_distance_squared := minimum_distance * minimum_distance
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				var nearby_cell := cell + Vector3i(x, y, z)
				if not position_grid.has(nearby_cell):
					continue
				for nearby_position: Vector3 in position_grid[nearby_cell]:
					if position.distance_squared_to(nearby_position) < minimum_distance_squared:
						return false
	return true


func _register_position(
	position: Vector3, minimum_distance: float, position_grid: Dictionary
) -> void:
	if minimum_distance <= 0.0:
		return
	var cell := _position_cell(position, maxf(minimum_distance, 0.001))
	var positions: Array = position_grid.get(cell, [])
	positions.append(position)
	position_grid[cell] = positions


func _position_cell(position: Vector3, cell_size: float) -> Vector3i:
	return Vector3i(
		floori(position.x / cell_size),
		floori(position.y / cell_size),
		floori(position.z / cell_size)
	)


func _make_transform(placement: Dictionary) -> Transform3D:
	var world_position: Vector3 = placement["position"]
	var normal: Vector3 = placement["normal"]
	var basis := _basis_aligned_to(normal)
	basis = _apply_random_rotation(basis, normal)
	basis = _apply_random_tilt(basis, normal)
	var scale_factor := _random.randf_range(
		minf(random_scale_min, random_scale_max), maxf(random_scale_min, random_scale_max)
	)
	basis = basis.scaled(base_scale * scale_factor)
	return global_transform.affine_inverse() * Transform3D(basis, world_position)


func _basis_aligned_to(normal: Vector3) -> Basis:
	var source_up := _source_up_vector()
	var alignment := clampf(source_up.dot(normal), -1.0, 1.0)
	if alignment >= 0.99999:
		return Basis.IDENTITY
	if alignment <= -0.99999:
		var axis := source_up.cross(Vector3.RIGHT)
		if axis.is_zero_approx():
			axis = source_up.cross(Vector3.FORWARD)
		return Basis(axis.normalized(), PI)
	return Basis(Quaternion(source_up, normal))


func _apply_random_rotation(basis: Basis, normal: Vector3) -> Basis:
	if is_zero_approx(random_rotation):
		return basis
	return Basis(normal, deg_to_rad(_random.randf_range(-random_rotation, random_rotation))) * basis


func _apply_random_tilt(basis: Basis, normal: Vector3) -> Basis:
	if is_zero_approx(random_tilt):
		return basis
	var tangent := normal.cross(Vector3.UP)
	if tangent.is_zero_approx():
		tangent = normal.cross(Vector3.RIGHT)
	tangent = tangent.normalized().rotated(normal, _random.randf_range(0.0, TAU))
	return Basis(tangent, deg_to_rad(_random.randf_range(0.0, random_tilt))) * basis


func _source_up_vector() -> Vector3:
	match source_up_axis:
		SourceUpAxis.DOWN:
			return Vector3.DOWN
		SourceUpAxis.LEFT:
			return Vector3.LEFT
		SourceUpAxis.RIGHT:
			return Vector3.RIGHT
		SourceUpAxis.FORWARD:
			return Vector3.FORWARD
		SourceUpAxis.BACK:
			return Vector3.BACK
		_:
			return Vector3.UP
