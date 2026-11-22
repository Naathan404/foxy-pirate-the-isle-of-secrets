@tool
extends RefCounted
## Builds the single water sheet used by FlatTideZone. UV.x runs from the waterline (0) to the
## sea edge (1); the shader places each row along the flow axis every frame, so the mesh never
## needs rebuilding while the tide moves. Z holds the real position across the flow.


static func build(width: float, segments_flow: int, segments_across: int) -> ArrayMesh:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_width := width * 0.5
	for row in range(segments_flow):
		var u0 := float(row) / segments_flow
		var u1 := float(row + 1) / segments_flow
		for column in range(segments_across):
			var z0 := lerpf(-half_width, half_width, float(column) / segments_across)
			var z1 := lerpf(-half_width, half_width, float(column + 1) / segments_across)
			var a := Vector3(0.0, 0.0, z0)
			var b := Vector3(0.0, 0.0, z1)
			for vertex in [[a, u0], [b, u0], [b, u1], [a, u0], [b, u1], [a, u1]]:
				builder.set_uv(Vector2(vertex[1], 0.0))
				builder.set_normal(Vector3.UP)
				builder.add_vertex(vertex[0])
	return builder.commit()
