extends SceneTree

const ZONE_SCRIPT := preload("res://world/gimmick/flat_tide/flat_tide_zone.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not Engine.is_editor_hint():
		push_error("Run this check with --editor")
		quit(1)
		return
	var zone := ZONE_SCRIPT.new() as FlatTideZone
	root.add_child(zone)
	await process_frame
	if (
		not is_instance_valid(zone._debug_mesh)
		or not zone._debug_mesh.visible
		or zone._debug_mesh.mesh == null
	):
		push_error("The editor must show the tide area debug box")
		quit(1)
		return
	if (
		not is_instance_valid(zone._preview_mesh)
		or not zone._preview_mesh.visible
		or zone._preview_mesh.mesh == null
		or zone._preview_mesh.material_override == null
	):
		push_error("The editor must show a water volume preview")
		quit(1)
		return
	zone.editor_preview_coverage = 0.5
	if not is_equal_approx(zone._material.get_shader_parameter("fill"), 0.5):
		push_error("Changing editor preview coverage must update the water")
		quit(1)
		return
	zone.start_coverage = 0.25
	if not is_equal_approx(zone._material.get_shader_parameter("fill"), 1.0 / 3.0):
		push_error("Changing the start coverage must update the editor preview")
		quit(1)
		return
	var existing_debug: MeshInstance3D = zone._debug_mesh
	var existing_preview: MeshInstance3D = zone._preview_mesh
	zone._debug_mesh = null
	zone._preview_mesh = null
	zone._refresh_helpers()
	if zone._debug_mesh != existing_debug or zone._preview_mesh != existing_preview:
		push_error("Refreshing an open scene must reuse its preview helpers")
		quit(1)
		return
	zone.show_editor_preview = false
	await process_frame
	await process_frame
	if zone._preview_mesh.visible or zone._preview_mesh.mesh != null:
		push_error("The water preview must respect Show Editor Preview")
		quit(1)
		return
	zone.show_debug_area = false
	zone._rebuild_debug()
	if zone._debug_mesh.visible:
		push_error("The editor debug box must respect Show Debug Area")
		quit(1)
		return
	print("Flat tide editor checks: PASS")
	quit(0)
