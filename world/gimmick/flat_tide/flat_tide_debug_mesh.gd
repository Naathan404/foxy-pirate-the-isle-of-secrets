@tool
extends RefCounted
## Builds a line box for the full potential area, independent of current tide.


static func build(
	size: Vector2,
	depth: float,
	color: Color,
	height_offset: float,
	active_color: Color,
	shoreline: PackedVector3Array
) -> ImmediateMesh:
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES, _make_material(color))
	var half := size * 0.5
	var corners := [
		Vector3(-half.x, height_offset, -half.y),
		Vector3(half.x, height_offset, -half.y),
		Vector3(half.x, height_offset, half.y),
		Vector3(-half.x, height_offset, half.y)
	]
	for index in range(corners.size()):
		var next := (index + 1) % corners.size()
		lines.surface_add_vertex(corners[index])
		lines.surface_add_vertex(corners[next])
		lines.surface_add_vertex(corners[index])
		lines.surface_add_vertex(corners[index] + Vector3.UP * depth)
		lines.surface_add_vertex(corners[index] + Vector3.UP * depth)
		lines.surface_add_vertex(corners[next] + Vector3.UP * depth)
	lines.surface_end()
	if shoreline.size() >= 2:
		lines.surface_begin(Mesh.PRIMITIVE_LINES, _make_material(active_color))
		for index in range(shoreline.size() - 1):
			lines.surface_add_vertex(shoreline[index])
			lines.surface_add_vertex(shoreline[index + 1])
		var sea_start := Vector3(half.x, height_offset, -half.y)
		var sea_end := Vector3(half.x, height_offset, half.y)
		for pair in [
			[shoreline[0], sea_start],
			[sea_start, sea_end],
			[sea_end, shoreline[shoreline.size() - 1]]
		]:
			lines.surface_add_vertex(pair[0])
			lines.surface_add_vertex(pair[1])
		lines.surface_end()
	return lines


static func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.albedo_color = color
	return material
