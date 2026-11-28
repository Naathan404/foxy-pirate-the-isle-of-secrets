class_name KrakenDebris
extends Node3D
## Chunky, ink-outlined rocks thrown out of the torn ground. Presentation only.

const ROCK_COLORS: Array[Color] = [
	Color("b39470"), Color("8f7258"), Color("c9ab83"), Color("6d5a4c")
]
const INK := Color("17080d")
const SHADE_AMOUNT := 0.28
const OUTLINE_SCALE := 1.32
const OUTLINE_DEPTH := 0.004
const MIN_CORNERS := 5
const MAX_CORNERS := 7
const MIN_SIZE_METERS := 0.09
const MAX_SIZE_METERS := 0.23
const MIN_LAUNCH_SPEED := 3.5
const MAX_LAUNCH_SPEED := 7.5
const MIN_OUT_SPEED := 0.8
const MAX_OUT_SPEED := 2.8
const MAX_SPIN := 12.0
const GRAVITY := 17.0
const BOUNCE := 0.32
const GROUND_FRICTION := 0.5
const START_RADIUS_METERS := 0.45
const LIFETIME_SECONDS := 1.15
const SHRINK_SECONDS := 0.25

static var _material: StandardMaterial3D

var _chunks: Array[MeshInstance3D] = []
var _velocities: Array[Vector3] = []
var _spins: Array[float] = []
var _angles: Array[float] = []
var _age := 0.0


static func spawn(parent: Node3D, at: Vector3, count: int, size_scale: float = 1.0) -> void:
	var debris := KrakenDebris.new()
	parent.add_child(debris)
	debris.global_position = at
	for index in count:
		debris._throw(size_scale)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME_SECONDS:
		queue_free()
		return
	var shrink := clampf((LIFETIME_SECONDS - _age) / SHRINK_SECONDS, 0.0, 1.0)
	var camera := get_viewport().get_camera_3d()
	var facing := camera.global_basis.orthonormalized() if camera != null else Basis.IDENTITY
	for index in _chunks.size():
		var velocity := _velocities[index]
		velocity.y -= GRAVITY * delta
		var at := _chunks[index].position + velocity * delta
		# The burst's own height is the floor: rocks hop once or twice and settle there.
		if at.y < 0.0 and velocity.y < 0.0:
			at.y = 0.0
			velocity = Vector3(
				velocity.x * GROUND_FRICTION, -velocity.y * BOUNCE, velocity.z * GROUND_FRICTION
			)
			_spins[index] *= GROUND_FRICTION
		_velocities[index] = velocity
		_angles[index] += _spins[index] * delta
		_chunks[index].position = at
		_chunks[index].global_basis = (
			facing * Basis(Vector3.BACK, _angles[index]) * Basis.from_scale(Vector3.ONE * shrink)
		)


func _throw(size_scale: float) -> void:
	var chunk := MeshInstance3D.new()
	chunk.mesh = _rock_mesh(randf_range(MIN_SIZE_METERS, MAX_SIZE_METERS) * size_scale)
	chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var heading := Vector3.RIGHT.rotated(Vector3.UP, randf() * TAU)
	chunk.position = heading * randf() * START_RADIUS_METERS * size_scale
	add_child(chunk)
	_chunks.append(chunk)
	_velocities.append(
		(
			heading * randf_range(MIN_OUT_SPEED, MAX_OUT_SPEED)
			+ Vector3.UP * randf_range(MIN_LAUNCH_SPEED, MAX_LAUNCH_SPEED)
		)
	)
	_spins.append(randf_range(-MAX_SPIN, MAX_SPIN))
	_angles.append(randf() * TAU)


## A flat polygon over a larger ink copy; the lower half is darker to read as a facet.
func _rock_mesh(radius: float) -> ArrayMesh:
	var corners := PackedVector2Array()
	var count := randi_range(MIN_CORNERS, MAX_CORNERS)
	for index in count:
		var angle := TAU * index / count
		corners.append(Vector2.from_angle(angle) * radius * randf_range(0.7, 1.15))
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var color: Color = ROCK_COLORS.pick_random()
	for index in count:
		var a := corners[index]
		var b := corners[(index + 1) % count]
		var facet := color.darkened(SHADE_AMOUNT) if a.y + b.y < 0.0 else color
		for corner: Vector2 in [Vector2.ZERO, a * OUTLINE_SCALE, b * OUTLINE_SCALE]:
			vertices.append(Vector3(corner.x, corner.y, -OUTLINE_DEPTH))
			colors.append(INK)
		for corner: Vector2 in [Vector2.ZERO, a, b]:
			vertices.append(Vector3(corner.x, corner.y, OUTLINE_DEPTH))
			colors.append(facet)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var rock := ArrayMesh.new()
	rock.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	rock.surface_set_material(0, _rock_material())
	return rock


static func _rock_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
	return _material
