class_name CameraBounds3D
extends Node3D

## Move CornerA and CornerB in the level to define the visible X/Z rectangle.
## Their Y positions define the ground plane used for the camera's view footprint.
@export_range(0.0, 20.0, 0.25) var edge_padding: float = 1.0

@onready var corner_a: Marker3D = get_node_or_null("CornerA") as Marker3D
@onready var corner_b: Marker3D = get_node_or_null("CornerB") as Marker3D


func clamp_camera_position(camera: Camera3D, desired_position: Vector3) -> Vector3:
	if (
		not is_instance_valid(camera)
		or not is_instance_valid(corner_a)
		or not is_instance_valid(corner_b)
	):
		return desired_position

	var first := corner_a.global_position
	var second := corner_b.global_position
	var minimum := Vector2(minf(first.x, second.x), minf(first.z, second.z))
	var maximum := Vector2(maxf(first.x, second.x), maxf(first.z, second.z))
	var ground_y := (first.y + second.y) * 0.5
	var view_min := Vector2.ZERO
	var view_max := Vector2.ZERO
	var viewport_size := Vector2(camera.get_viewport().get_visible_rect().size)
	var has_view_footprint := false

	for screen_point in [
		Vector2.ZERO,
		Vector2(viewport_size.x, 0.0),
		Vector2(0.0, viewport_size.y),
		viewport_size,
	]:
		var ray_origin := camera.project_ray_origin(screen_point)
		var ray_direction := camera.project_ray_normal(screen_point)
		if ray_direction.y >= -0.0001:
			continue
		var distance := (ground_y - desired_position.y) / ray_direction.y
		if distance <= 0.0:
			continue
		var offset := ray_origin + ray_direction * distance - camera.global_position
		var horizontal_offset := Vector2(offset.x, offset.z)
		if not has_view_footprint:
			view_min = horizontal_offset
			view_max = horizontal_offset
			has_view_footprint = true
		else:
			view_min = view_min.min(horizontal_offset)
			view_max = view_max.max(horizontal_offset)

	var left := minimum.x + edge_padding - view_min.x
	var right := maximum.x - edge_padding - view_max.x
	var near_edge := minimum.y + edge_padding - view_min.y
	var far_edge := maximum.y - edge_padding - view_max.y
	var result := desired_position
	result.x = (left + right) * 0.5 if left > right else clampf(result.x, left, right)
	result.z = (
		(near_edge + far_edge) * 0.5
		if near_edge > far_edge
		else clampf(result.z, near_edge, far_edge)
	)
	return result
