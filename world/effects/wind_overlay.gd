extends Node2D
## Wind and foliage move across a room-sized world plane, projected onto the screen.

const WRAP_MARGIN := 100.0
const LEAF_PROFILE := [
	Vector2(-1.0, 0.0),
	Vector2(-0.45, -0.8),
	Vector2(0.15, -1.0),
	Vector2(0.7, -0.55),
	Vector2(1.0, 0.0),
	Vector2(0.45, 0.8),
	Vector2(-0.15, 1.0),
	Vector2(-0.7, 0.55),
]

@export_group("Motion")
@export var reference_size := Vector2(1920, 1080)
## Used when the room has no CameraBounds markers.
@export var fallback_field_size := Vector2(60.0, 60.0)
@export var field_height: float = 1.0
@export var wind_velocity := Vector2(85, 24)
@export_range(0.0, 100.0, 1.0) var sway: float = 22.0
@export_range(0.1, 4.0, 0.05) var sway_speed: float = 0.8

@export_group("Leaves")
@export_range(0, 40) var leaf_count: int = 12
@export var leaf_color := Color(0.48, 0.38, 0.19, 0.55)
@export_range(2.0, 40.0, 1.0) var leaf_size: float = 15.0
@export_range(0.1, 1.0, 0.05) var leaf_min_scale: float = 0.7
@export_range(0.1, 1.0, 0.05) var leaf_width_ratio: float = 0.45
@export_range(0.0, 3.0, 0.05) var leaf_rotation_speed: float = 0.8
@export_range(0.05, 1.0, 0.05) var leaf_flutter_min: float = 0.35

@export_group("Wind Trails")
@export_range(0, 12) var trail_count: int = 4
@export var trail_color := Color(0.77, 0.82, 0.71, 0.12)
@export_range(30.0, 500.0, 5.0) var trail_length: float = 200.0
@export_range(1.0, 30.0, 0.5) var trail_width: float = 5.0
@export_range(0.0, 100.0, 1.0) var trail_wave_height: float = 18.0
@export_range(0.1, 4.0, 0.1) var trail_wave_cycles: float = 1.2
@export_range(0.1, 4.0, 0.05) var trail_wave_speed: float = 0.65
@export_range(0.5, 20.0, 0.5) var gust_period: float = 7.0
@export_range(0.1, 1.0, 0.05) var gust_duration: float = 0.55
@export_range(8, 64, 1) var trail_segments: int = 32

var _elapsed := 0.0
var _seeds: Array[Vector2] = []
var _field_center := Vector3.ZERO
var _field_size := Vector2.ZERO
var _reference_camera_size := 0.0
var _reference_camera_fov := 0.0
var _reference_depth := 0.0


func _ready() -> void:
	# Run after the follow camera updates, avoiding a one-frame screen-space lag.
	process_priority = 110
	_configure_field()
	var random := RandomNumberGenerator.new()
	random.randomize()
	for index in range(leaf_count + trail_count):
		_seeds.append(Vector2(random.randf(), random.randf()))


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


func _draw() -> void:
	if reference_size.x <= 0.0 or reference_size.y <= 0.0:
		return
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		return
	var ratio := get_viewport_rect().size / reference_size
	if ratio.x <= 0.0 or ratio.y <= 0.0:
		return
	if _reference_camera_size <= 0.0:
		_reference_camera_size = camera.size
		_reference_camera_fov = camera.fov
		_reference_depth = maxf(
			camera.to_local(_field_center + Vector3.UP * field_height).z * -1.0, camera.near
		)
	for index in range(_seeds.size()):
		var seed := _seeds[index]
		var phase := seed.x * TAU
		var field_point := _position_for(seed, phase)
		var world_point := _world_position(field_point)
		if camera.is_position_behind(world_point):
			continue
		var zoom_scale := _projection_scale(camera, world_point)
		var screen_point := camera.unproject_position(world_point)
		# Draw shapes around the projected world point; camera zoom scales them too.
		var point := screen_point / (ratio * zoom_scale)
		if index < leaf_count:
			_draw_leaf(point, ratio * zoom_scale, seed, phase)
		else:
			_draw_trail(point, ratio * zoom_scale, seed, phase)


func _projection_scale(camera: Camera3D, world_point: Vector3) -> float:
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		return _reference_camera_size / maxf(camera.size, 0.01)
	var depth := maxf(-camera.to_local(world_point).z, camera.near)
	var fov_scale := (
		tan(deg_to_rad(_reference_camera_fov) * 0.5) / tan(deg_to_rad(camera.fov) * 0.5)
	)
	return _reference_depth / depth * fov_scale


func _world_position(field_point: Vector2) -> Vector3:
	return (
		_field_center
		+ Vector3(
			(field_point.x / reference_size.x - 0.5) * _field_size.x,
			field_height,
			(field_point.y / reference_size.y - 0.5) * _field_size.y
		)
	)


func _configure_field() -> void:
	_field_size = fallback_field_size.abs()
	var room := get_parent().get_parent().get_parent() as Node3D
	if room == null:
		return
	_field_center = room.global_position
	var corner_a := room.get_node_or_null("CameraBounds/CornerA") as Node3D
	var corner_b := room.get_node_or_null("CameraBounds/CornerB") as Node3D
	if corner_a == null or corner_b == null:
		return
	_field_center = (corner_a.global_position + corner_b.global_position) * 0.5
	_field_center.y = room.global_position.y
	var extent := corner_b.global_position - corner_a.global_position
	if not is_zero_approx(extent.x) and not is_zero_approx(extent.z):
		_field_size = Vector2(absf(extent.x), absf(extent.z))


func _position_for(seed: Vector2, phase: float) -> Vector2:
	var point := seed * reference_size + wind_velocity * _elapsed
	point.y += sin(_elapsed * sway_speed + phase) * sway
	# Keep the entire trail outside the viewport before wrapping its head.
	var margin := maxf(WRAP_MARGIN, trail_length + trail_wave_height)
	point.x = fposmod(point.x + margin, reference_size.x + margin * 2.0) - margin
	point.y = fposmod(point.y + margin, reference_size.y + margin * 2.0) - margin
	return point


func _draw_leaf(point: Vector2, ratio: Vector2, seed: Vector2, phase: float) -> void:
	var angle := _elapsed * leaf_rotation_speed + phase
	var flutter := lerpf(leaf_flutter_min, 1.0, absf(sin(angle)))
	var size := leaf_size * lerpf(leaf_min_scale, 1.0, seed.y)
	var polygon := PackedVector2Array()
	for vertex in LEAF_PROFILE:
		var shape := Vector2(vertex.x, vertex.y * leaf_width_ratio * flutter)
		polygon.append((point + shape.rotated(angle) * size) * ratio)
	draw_colored_polygon(polygon, leaf_color)


func _draw_trail(point: Vector2, ratio: Vector2, seed: Vector2, phase: float) -> void:
	var cycle := fposmod(_elapsed / maxf(gust_period, 0.01) + seed.y, 1.0)
	if cycle >= gust_duration:
		return
	var gust := sin(PI * cycle / gust_duration)
	var direction := (
		wind_velocity.normalized() if not wind_velocity.is_zero_approx() else Vector2.RIGHT
	)
	var normal := Vector2(-direction.y, direction.x)
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	for step in range(trail_segments + 1):
		var progress := float(step) / float(trail_segments)
		var envelope := sin(PI * progress)
		var wave := sin(progress * TAU * trail_wave_cycles - _elapsed * trail_wave_speed + phase)
		var center := (
			point
			- direction * trail_length * progress
			+ normal * wave * trail_wave_height * envelope
		)
		var half_width := trail_width * envelope * 0.5
		var color := trail_color
		color.a *= envelope * gust
		var edge_color := color
		edge_color.a = 0.0
		vertices.append((center - normal * half_width) * ratio)
		vertices.append(center * ratio)
		vertices.append((center + normal * half_width) * ratio)
		colors.append(edge_color)
		colors.append(color)
		colors.append(edge_color)
	# Individual quads interpolate alpha along the ribbon and taper at both ends.
	# The end vertices converge to a point; omit the degenerate end quads.
	for step in range(1, trail_segments - 1):
		for side in range(2):
			var i := step * 3 + side
			draw_polygon(
				PackedVector2Array(
					[vertices[i], vertices[i + 1], vertices[i + 4], vertices[i + 3]]
				),
				PackedColorArray([colors[i], colors[i + 1], colors[i + 4], colors[i + 3]])
			)
