class_name KrakenTentacleMesh
extends MeshInstance3D
## Camera-facing ribbon around a 3D spine rooted at this node. The spine bends in world space,
## so a whip really lands on the ground in front of the tentacle from any camera angle.

const SEGMENTS := 30
## Rows past the flesh tip that carry only the flame fringe, so the tip ends in a point.
const TIP_FLARE_METERS := 0.12
const ROOT_SINK_METERS := 0.12
const MIN_SPINE_HEIGHT_METERS := 0.1
const FRINGE_METERS := 0.23
## Height the fringe size was drawn for; other sizes scale it.
const REFERENCE_HEIGHT_METERS := 3.4
const TIP_FRINGE_RATIO := 0.35
const ROOT_FLARE_SHARE := 0.16
const ROOT_FLARE_WIDTH := 0.3
const TIP_WIDTH_RATIO := 0.03
const TAPER_POWER := 0.78
const SWAY_FREQUENCY := 5.2
const CURL_START := 0.58
## Share of the length over which a whip reaches its full bend.
const BEND_END := 0.85
const CULL_MARGIN_METERS := 5.0

var height := 3.4
var base_half_width := 0.46
## Visible share of the full length; the rest is still under the ground.
var growth := 0.0
## Radians toward `bend_direction`; negative draws the tentacle back before a whip.
var bend := 0.0
var bend_direction := Vector3.BACK
## Constant sideways lean and tip curl, in radians; the sign picks the screen side.
var lean := 0.0
var curl := 1.25
var sway := 0.3
var sway_speed := 4.0
var phase := 0.0

var _mesh := ImmediateMesh.new()
var _time := 0.0


func _init() -> void:
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = CULL_MARGIN_METERS


func advance(delta: float) -> void:
	_time += delta
	rebuild()


func rebuild() -> void:
	_mesh.clear_surfaces()
	var length := height * growth
	if length <= 0.01 or not is_inside_tree():
		return
	var camera := get_viewport().get_camera_3d()
	var right := camera.global_basis.x if camera != null else Vector3.RIGHT
	var toward_camera := camera.global_basis.z if camera != null else Vector3.BACK
	right = Vector3(right.x, 0.0, right.z).normalized()
	var points := _spine(length, right)
	var to_local_basis := global_basis.inverse()

	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for index in points.size():
		var tangent := points[mini(index + 1, points.size() - 1)] - points[maxi(index - 1, 0)]
		var across := tangent.cross(toward_camera)
		across = right if across.is_zero_approx() else across.normalized()
		if across.dot(right) < 0.0:
			across = -across
		# The last point is the fringe flare beyond the flesh.
		var is_flare := index == points.size() - 1
		var share := float(index) / SEGMENTS
		var from_tip := -TIP_FLARE_METERS if is_flare else length * (1.0 - share)
		var core := 0.0 if is_flare else _half_width(from_tip, share)
		var fringe := FRINGE_METERS * lerpf(TIP_FRINGE_RATIO, 1.0, minf(1.0, from_tip / height))
		fringe = maxf(fringe, FRINGE_METERS * TIP_FRINGE_RATIO) * height / REFERENCE_HEIGHT_METERS
		var half := core + fringe
		for side: float in [-1.0, 1.0]:
			_mesh.surface_set_uv(Vector2(side * half, from_tip))
			_mesh.surface_set_uv2(Vector2(core, fringe))
			_mesh.surface_add_vertex(to_local_basis * (points[index] + across * half * side))
	_mesh.surface_end()


## World-space offsets from the root, one per segment boundary plus the tip flare.
func _spine(length: float, right: Vector3) -> PackedVector3Array:
	var points := PackedVector3Array()
	var step := length / SEGMENTS
	var at := Vector3.DOWN * ROOT_SINK_METERS
	var direction := Vector3.UP
	points.append(at)
	for index in range(1, SEGMENTS + 1):
		var share := float(index) / SEGMENTS
		var wave := sin(share * SWAY_FREQUENCY - _time * sway_speed + phase) * sway * share
		var curl_share := maxf(0.0, share - CURL_START) / (1.0 - CURL_START)
		var side_angle := lean + wave + curl * curl_share * curl_share
		var whip := bend * smoothstep(0.0, BEND_END, share)
		var upward := cos(side_angle)
		direction = (
			(
				Vector3.UP * upward * cos(whip)
				+ bend_direction * upward * sin(whip)
				+ right * sin(side_angle)
			)
			. normalized()
		)
		at += direction * step
		if share > ROOT_FLARE_SHARE:
			at.y = maxf(at.y, MIN_SPINE_HEIGHT_METERS)
		points.append(at)
	points.append(at + direction * TIP_FLARE_METERS)
	return points


func _half_width(from_tip: float, share: float) -> float:
	var along_full := clampf(from_tip / height, 0.0, 1.0)
	var taper := lerpf(TIP_WIDTH_RATIO, 1.0, pow(along_full, TAPER_POWER))
	var flare := maxf(0.0, 1.0 - share / ROOT_FLARE_SHARE) * ROOT_FLARE_WIDTH
	return base_half_width * taper * (1.0 + flare)
