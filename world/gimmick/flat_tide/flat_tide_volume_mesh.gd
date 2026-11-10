@tool
extends RefCounted
## Generates a subdivided top and four vertical sides. Vertex color records
## surface height and side membership for the water shader.


static func build(size: Vector2, depth: float, segments_x: int, segments_z: int) -> ArrayMesh:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := size * 0.5
	_add_quad(
		builder,
		size,
		depth,
		Vector3(-half.x, 0.0, -half.y),
		Vector3(half.x, 0.0, -half.y),
		Vector3(half.x, 0.0, half.y),
		Vector3(-half.x, 0.0, half.y),
		true
	)
	for x in range(segments_x):
		var x0 := lerpf(-half.x, half.x, float(x) / segments_x)
		var x1 := lerpf(-half.x, half.x, float(x + 1) / segments_x)
		for z in range(segments_z):
			var z0 := lerpf(-half.y, half.y, float(z) / segments_z)
			var z1 := lerpf(-half.y, half.y, float(z + 1) / segments_z)
			_add_quad(
				builder,
				size,
				depth,
				Vector3(x0, depth, z0),
				Vector3(x1, depth, z0),
				Vector3(x1, depth, z1),
				Vector3(x0, depth, z1),
				false
			)
		_add_quad(
			builder,
			size,
			depth,
			Vector3(x0, 0.0, -half.y),
			Vector3(x1, 0.0, -half.y),
			Vector3(x1, depth, -half.y),
			Vector3(x0, depth, -half.y),
			true
		)
		_add_quad(
			builder,
			size,
			depth,
			Vector3(x0, 0.0, half.y),
			Vector3(x1, 0.0, half.y),
			Vector3(x1, depth, half.y),
			Vector3(x0, depth, half.y),
			true
		)
	for z in range(segments_z):
		var z0 := lerpf(-half.y, half.y, float(z) / segments_z)
		var z1 := lerpf(-half.y, half.y, float(z + 1) / segments_z)
		_add_quad(
			builder,
			size,
			depth,
			Vector3(-half.x, 0.0, z0),
			Vector3(-half.x, 0.0, z1),
			Vector3(-half.x, depth, z1),
			Vector3(-half.x, depth, z0),
			true
		)
		_add_quad(
			builder,
			size,
			depth,
			Vector3(half.x, 0.0, z0),
			Vector3(half.x, 0.0, z1),
			Vector3(half.x, depth, z1),
			Vector3(half.x, depth, z0),
			true
		)
	return builder.commit()


static func _add_quad(
	builder: SurfaceTool,
	size: Vector2,
	depth: float,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	side: bool
) -> void:
	for vertex in [a, b, c, a, c, d]:
		builder.set_uv(Vector2(vertex.x / size.x + 0.5, vertex.z / size.y + 0.5))
		builder.set_color(Color(vertex.y / depth, 1.0 if side else 0.0, 0.0))
		builder.add_vertex(vertex)
