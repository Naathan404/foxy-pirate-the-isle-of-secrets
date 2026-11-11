extends SceneTree

const ZONE_SCRIPT := preload("res://world/gimmick/flat_tide/flat_tide_zone.gd")
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var zone := ZONE_SCRIPT.new() as FlatTideZone
	root.add_child(zone)
	_check(zone.mesh != null, "Water volume mesh is created")
	_check(not zone._preview_mesh.visible, "Editor preview does not appear while playing")
	_check(zone.size == Vector2(12.0, 12.0), "Default water area is square")
	var vertices: PackedVector3Array = zone.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var has_bottom := false
	var has_top := false
	for vertex in vertices:
		has_bottom = has_bottom or is_zero_approx(vertex.y)
		has_top = has_top or is_equal_approx(vertex.y, zone.volume_depth)
	_check(has_top and has_bottom, "Mesh has a top and bottom with nonzero depth")

	zone.set_coverage(0.0, false, 0.0)
	_check(not zone.contains_flooded_point(Vector3.ZERO), "Low tide stays dry")
	zone.set_coverage(0.0, true, 0.0, 0.25)
	var shader := zone.material_override as ShaderMaterial
	_check(
		is_equal_approx(shader.get_shader_parameter("warning"), 0.25),
		"Warning fades independently of flooded area"
	)
	_check(not zone.contains_flooded_point(Vector3.ZERO), "Warning does not flood dry ground")
	zone.set_coverage(1.0, false, 0.0)
	_check(
		zone.contains_flooded_point(Vector3(-5.9, 0.0, -5.9)), "Full tide covers the square corner"
	)
	_check(
		zone.contains_flooded_point(Vector3(-5.9, 0.0, 5.9)),
		"Both sides of the area have the same width"
	)
	_check(
		not zone.contains_flooded_point(Vector3(0.0, zone.floor_tolerance + 1.0, 0.0)),
		"Higher floors remain dry"
	)

	zone.set_coverage(0.5, false, 0.0)
	_check(zone.contains_flooded_point(Vector3(0.05, 0.0, 0.0)), "Point behind shoreline is wet")
	_check(
		not zone.contains_flooded_point(Vector3(-0.05, 0.0, 0.0)), "Point before shoreline is dry"
	)
	var quarter_wave_time: float = PI / (2.0 * zone.shore_wave_speed)
	zone.set_coverage(0.5, false, quarter_wave_time)
	_check(
		not zone.contains_flooded_point(Vector3(0.15, 0.0, 0.0)),
		"Moving shoreline updates the affected area"
	)
	_check(zone.contains_flooded_point(Vector3(0.4, 0.0, 0.0)), "Water follows the moving edge")
	_check(
		is_equal_approx(shader.get_shader_parameter("fill"), 0.5), "Shader uses the same coverage"
	)
	_check(
		is_equal_approx(shader.get_shader_parameter("tide_time"), quarter_wave_time),
		"Shader uses the same wave time"
	)
	_check(zone.get_surface_height_at(Vector3.ZERO) > 0.0, "Footsteps have a surface height")
	zone.size = Vector2(20.0, 12.0)
	for direction in range(4):
		zone.flow_direction = direction as FlatTideZone.FlowDirection
		zone.set_coverage(0.5, false, 0.0)
		var wet := zone._from_flow(Vector3(1.0, 0.0, 0.0))
		var dry := zone._from_flow(Vector3(-1.0, 0.0, 0.0))
		_check(zone.contains_flooded_point(wet), "Direction %d keeps the wet side" % direction)
		_check(not zone.contains_flooded_point(dry), "Direction %d keeps the dry side" % direction)
		_check(
			zone.get_flow_direction().dot((dry - wet).normalized()) > 0.99,
			"Direction %d points toward shore" % direction
		)
	zone.flow_direction = FlatTideZone.FlowDirection.NEGATIVE_X
	zone.size = Vector2(12.0, 12.0)
	zone.position = Vector3(3.0, 1.0, -2.0)
	zone.rotation.y = PI / 3.0
	var wet_point := zone.to_global(Vector3(0.5, 0.0, 0.0))
	var dry_point := zone.to_global(Vector3(-0.5, 0.0, 0.0))
	_check(zone.contains_flooded_point(wet_point), "Rotated zone retains its wet side")
	_check(not zone.contains_flooded_point(dry_point), "Rotated zone retains its dry side")
	zone.debug_in_game = true
	zone._rebuild_debug()
	_check(
		zone._debug_mesh.visible and zone._debug_mesh.mesh != null,
		"Debug area is available in game"
	)
	_check(
		zone._debug_mesh.mesh.get_surface_count() == 2,
		"Debug draws both the full area and active water"
	)
	zone.set_coverage(0.0, false, 0.0)
	_check(
		zone._debug_mesh.mesh.get_surface_count() == 1, "Low tide debug no longer shows a wet area"
	)
	zone.queue_free()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("Flat tide zone checks: PASS")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
