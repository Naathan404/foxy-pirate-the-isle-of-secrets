class_name DestructibleFragments
extends Node3D

## Each piece is an irregular, texture-mapped polygon cut from an opaque part of the sprite.

const MIN_SIDES: int = 5
const MAX_SIDES: int = 8
const CENTER_ATTEMPTS: int = 48
const FragmentSettings = preload("res://world/objects/destructible_fragment_settings.gd")

var _pieces: Array[MeshInstance3D] = []
var _origins: Array[Vector3] = []
var _velocities: Array[Vector3] = []
var _spins: Array[float] = []
var _gravity: float
var _lifetime: float
var _elapsed: float = 0.0
var _fade_start: float


func burst_from_sprite(source: Sprite3D, settings: FragmentSettings) -> void:
	if source == null or source.texture == null:
		queue_free()
		return
	var image := source.texture.get_image()
	if image == null or image.is_empty():
		queue_free()
		return
	if image.is_compressed() and image.decompress() != OK:
		push_warning("DestructibleFragments: cannot read the source texture's alpha")
		queue_free()
		return
	var frame_size := Vector2i(
		image.get_width() / maxi(1, source.hframes), image.get_height() / maxi(1, source.vframes)
	)
	var frame_origin := Vector2i(
		(source.frame % maxi(1, source.hframes)) * frame_size.x,
		(source.frame / maxi(1, source.hframes)) * frame_size.y
	)
	_gravity = settings.gravity
	_lifetime = settings.lifetime
	_fade_start = settings.fade_start
	var camera := get_viewport().get_camera_3d()
	var camera_basis := camera.global_basis if camera != null else Basis.IDENTITY
	var right := camera_basis.x
	var up := camera_basis.y
	var pixel_scale_x := source.global_basis.x.length() * source.pixel_size
	var pixel_scale_y := source.global_basis.y.length() * source.pixel_size
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = source.texture
	material.albedo_color = source.modulate
	for index in settings.count:
		var center := _pick_opaque_center(image, frame_origin, frame_size, settings.alpha_threshold)
		if center.x < 0.0:
			continue
		var diameter := (
			float(mini(frame_size.x, frame_size.y))
			* randf_range(settings.min_size, settings.max_size)
		)
		var piece := MeshInstance3D.new()
		piece.mesh = _make_piece_mesh(
			center,
			diameter,
			image.get_size(),
			pixel_scale_x,
			pixel_scale_y,
			source.flip_h,
			source.flip_v
		)
		piece.material_override = material
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(piece)
		piece.basis = camera_basis
		var local_center := center - Vector2(frame_origin)
		var offset := local_center - Vector2(frame_size) * 0.5 + source.offset
		piece.position = right * (offset.x * pixel_scale_x) - up * (offset.y * pixel_scale_y)
		_pieces.append(piece)
		_origins.append(piece.position)
		var angle := TAU * float(index) / float(settings.count) + randf_range(-0.45, 0.45)
		var horizontal_speed := randf_range(
			settings.min_horizontal_speed, settings.max_horizontal_speed
		)
		_velocities.append(
			Vector3(
				cos(angle) * horizontal_speed,
				randf_range(settings.min_launch_speed, settings.max_launch_speed),
				sin(angle) * horizontal_speed
			)
		)
		_spins.append(randf_range(-settings.max_spin, settings.max_spin))
	if _pieces.is_empty():
		queue_free()


func _pick_opaque_center(
	image: Image, frame_origin: Vector2i, frame_size: Vector2i, threshold: float
) -> Vector2:
	for attempt in CENTER_ATTEMPTS:
		var pixel := (
			frame_origin
			+ Vector2i(randi_range(0, frame_size.x - 1), randi_range(0, frame_size.y - 1))
		)
		if image.get_pixelv(pixel).a >= threshold:
			return Vector2(pixel)
	return Vector2(-1.0, -1.0)


func _make_piece_mesh(
	center: Vector2,
	diameter: float,
	texture_size: Vector2i,
	pixel_scale_x: float,
	pixel_scale_y: float,
	flip_h: bool,
	flip_v: bool
) -> ArrayMesh:
	var sides := randi_range(MIN_SIDES, MAX_SIDES)
	var radius_x := diameter * randf_range(0.35, 0.65)
	var radius_y := diameter * randf_range(0.3, 0.6)
	var phase := randf_range(0.0, TAU)
	var outline: Array[Vector2] = []
	for side in sides:
		var angle := phase + TAU * float(side) / float(sides)
		var jitter := randf_range(0.62, 1.18)
		outline.append(Vector2(cos(angle) * radius_x, sin(angle) * radius_y) * jitter)
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	for side in sides:
		for point in [Vector2.ZERO, outline[side], outline[(side + 1) % sides]]:
			vertices.append(Vector3(point.x * pixel_scale_x, point.y * pixel_scale_y, 0.0))
			var texel := (
				center + Vector2(-point.x if flip_h else point.x, point.y if flip_v else -point.y)
			)
			uvs.append(Vector2(texel.x / float(texture_size.x), texel.y / float(texture_size.y)))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _lifetime:
		queue_free()
		return
	var fade := 1.0
	if _elapsed > _fade_start:
		fade = 1.0 - (_elapsed - _fade_start) / maxf(_lifetime - _fade_start, 0.001)
	for index in _pieces.size():
		_pieces[index].position = (
			_origins[index]
			+ _velocities[index] * _elapsed
			- Vector3.UP * (0.5 * _gravity * _elapsed * _elapsed)
		)
		_pieces[index].rotation.z += _spins[index] * delta
		_pieces[index].transparency = 1.0 - fade
