@tool
extends MeshInstance3D
## Unity TrailRenderer: a ribbon through the world positions this node passed through during the last `time`
## seconds, rebuilt every frame.
##
## A point is recorded when the node has moved more than `min_vertex_distance` from the last recorded point; points
## older than `time` seconds are dropped. The head of the ribbon is always the node's current position. Along the
## ribbon t runs from 0 at the head to 1 at the tail (by length): width = width * width_samples(t), vertex color =
## color_samples(t) (linear, like Unity's "Apply Active Color Space"). UV.x follows Unity's Texture Mode (stretch:
## t, tile: world distance from the head, distribute per segment: segment index / count, repeat per segment: segment
## index), UV.y = 0 on one edge and 1 on the other; both scaled by texture_scale. UV2 = Unity (0, 0) (a Unity trail
## has no second UV channel). The ribbon faces the camera
## (alignment 0, Unity "View") or lies across the node's Z axis (alignment 1, "Transform Z").
## The vertices are stored in this node's space and recomputed every frame, so the node's own scale does not change
## the width (Unity trails ignore the transform scale too).

## Seconds a point lives (Unity Time).
@export var time := 5.0
## Distance the node must travel before a new point is recorded (Unity Min Vertex Distance).
@export var min_vertex_distance := 0.1
@export var width := 1.0
## The width curve sampled evenly over the trail (t = 0 head .. 1 tail).
@export var width_samples := PackedFloat32Array([1.0])
## The color gradient sampled evenly over the trail (t = 0 head .. 1 tail), linear colors.
@export var color_samples := PackedColorArray([Color.WHITE])
## Unity Texture Mode: 0 stretch, 1 tile, 2 distribute per segment, 3 repeat per segment.
@export var texture_mode := 0
@export var texture_scale := Vector2.ONE
## 0 view (faces the camera), 1 transform Z.
@export var alignment := 0
## New points are only recorded while emitting (the existing ones still fade out).
@export var emitting := true
## Frees the parent node once the trail has been idle and empty for `time` seconds (Unity Autodestruct).
@export var autodestruct := false

var _mesh := ArrayMesh.new()
var _points := PackedVector3Array()
var _born := PackedFloat64Array()
var _now := 0.0
var _idle := 0.0
var _last_head := Vector3.INF


func _ready() -> void:
	mesh = _mesh
	# After the scripts that move the node, like Unity's trail update after Update().
	process_priority = 1000


## Removes every recorded point (Unity TrailRenderer.Clear()).
func clear() -> void:
	_points.clear()
	_born.clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		clear()
		_mesh.clear_surfaces()


func _sample_f(arr: PackedFloat32Array, t: float) -> float:
	if arr.is_empty():
		return 1.0
	if arr.size() == 1:
		return arr[0]
	var x := clampf(t, 0.0, 1.0) * float(arr.size() - 1)
	var i := mini(int(x), arr.size() - 2)
	return lerpf(arr[i], arr[i + 1], x - float(i))


func _sample_c(arr: PackedColorArray, t: float) -> Color:
	if arr.is_empty():
		return Color.WHITE
	if arr.size() == 1:
		return arr[0]
	var x := clampf(t, 0.0, 1.0) * float(arr.size() - 1)
	var i := mini(int(x), arr.size() - 2)
	return arr[i].lerp(arr[i + 1], x - float(i))


func _camera() -> Camera3D:
	if Engine.is_editor_hint():
		var vp = EditorInterface.get_editor_viewport_3d(0)
		return vp.get_camera_3d() if vp else null
	return get_viewport().get_camera_3d()


func _process(delta: float) -> void:
	_now += delta
	var head := global_position
	# Drop the points older than `time` (the oldest are first).
	var drop := 0
	while drop < _born.size() and _now - _born[drop] > time:
		drop += 1
	if drop > 0:
		_points = _points.slice(drop)
		_born = _born.slice(drop)
	if emitting and is_visible_in_tree():
		if _points.is_empty() or _points[_points.size() - 1].distance_to(head) > min_vertex_distance:
			_points.append(head)
			_born.append(_now)
	if autodestruct and not Engine.is_editor_hint():
		_idle = _idle + delta if head.is_equal_approx(_last_head) else 0.0
		if _idle > time and _points.is_empty() and get_parent():
			get_parent().queue_free()
	_last_head = head
	_rebuild(head)


func _rebuild(head: Vector3) -> void:
	_mesh.clear_surfaces()
	# World positions from the head (newest) to the tail (oldest).
	var pts := PackedVector3Array()
	if emitting and is_visible_in_tree() and (_points.is_empty() or not _points[_points.size() - 1].is_equal_approx(head)):
		pts.append(head)
	for i in range(_points.size() - 1, -1, -1):
		pts.append(_points[i])
	var n := pts.size()
	if n < 2:
		return
	var cam := _camera()
	var cam_pos := cam.global_position if cam else head + Vector3(0, 0, 10)
	var z_axis := global_basis.z.normalized()
	var inv := global_transform.affine_inverse()
	var dist := PackedFloat32Array()
	dist.resize(n)
	dist[0] = 0.0
	for i in range(1, n):
		dist[i] = dist[i - 1] + pts[i].distance_to(pts[i - 1])
	var total := maxf(dist[n - 1], 1e-6)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var tans := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var inv_basis := inv.basis
	for i in n:
		var tan := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var facing := (cam_pos - pts[i]).normalized() if alignment == 0 else z_axis
		var side := tan.cross(facing)
		if side.length_squared() < 1e-12:
			side = tan.cross(Vector3.UP if absf(tan.y) < 0.99 else Vector3.RIGHT)
		side = side.normalized()
		var t := dist[i] / total
		var hw := 0.5 * width * _sample_f(width_samples, t)
		var u := t
		match texture_mode:
			1:
				u = dist[i]
			2:
				u = float(i) / float(n - 1)
			3:
				u = float(i)
		u *= texture_scale.x
		var c := _sample_c(color_samples, t)
		var n_local := (inv_basis * facing).normalized()
		var t_local := (inv_basis * tan).normalized()
		for k in 2:
			var s := -1.0 if k == 0 else 1.0
			verts.append(inv * (pts[i] + side * hw * s))
			norms.append(n_local)
			tans.append_array([t_local.x, t_local.y, t_local.z, 1.0])
			# Godot UV.y = 1 - Unity v (the shaders flip it back).
			uvs.append(Vector2(u, 1.0 - float(k) * texture_scale.y))
			# Unity trails have no TEXCOORD1: shaders reading it get (0, 0) (Godot UV2.y = 1 - Unity v).
			uv2s.append(Vector2(0.0, 1.0))
			cols.append(c)
		if i > 0:
			var a := (i - 1) * 2
			# Clockwise seen from the camera: Godot's front faces (the materials cull back faces like Unity's).
			idx.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TANGENT] = tans
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
