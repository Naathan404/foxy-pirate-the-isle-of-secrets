class_name RewardHighlight
extends Node3D
## Beam and ground halo that mark a special reward lying among ordinary loot. Presentation only;
## the pickup owns it and hides it while the reward is being collected.

const SHADER := preload("res://gameplay/inventory/reward_highlight.gdshader")
const BEAM_SIZE_METERS := Vector2(1.3, 4.0)
const RING_SIZE_METERS := 2.4
const RING_LIFT_METERS := 0.06
const FADE_IN_SECONDS := 0.2
const BURST_SECONDS := 0.55

var _materials: Array[ShaderMaterial] = []


static func attach(pickup: Node3D, tint: Color) -> RewardHighlight:
	var highlight := RewardHighlight.new()
	pickup.add_child(highlight)
	highlight._build(tint)
	return highlight


## Fades the halo in with a ring spreading out from the landing spot.
func burst() -> void:
	show()
	var tween := create_tween().set_parallel()
	for material in _materials:
		material.set_shader_parameter("strength", 0.0)
		material.set_shader_parameter("burst", 0.0)
		tween.tween_property(material, "shader_parameter/strength", 1.0, FADE_IN_SECONDS)
		tween.tween_property(material, "shader_parameter/burst", 1.0, BURST_SECONDS)


func _build(tint: Color) -> void:
	var beam := QuadMesh.new()
	beam.size = BEAM_SIZE_METERS
	beam.center_offset = Vector3(0.0, BEAM_SIZE_METERS.y * 0.5, 0.0)
	var beam_material := _material(tint, false)
	_add_part(beam, beam_material, Vector3.ZERO)
	var ring := PlaneMesh.new()
	ring.size = Vector2.ONE * RING_SIZE_METERS
	_add_part(ring, _material(tint, true), Vector3.UP * RING_LIFT_METERS)


func _add_part(mesh: Mesh, material: ShaderMaterial, at: Vector3) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(part)


func _material(tint: Color, ground_ring: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("ground_ring", ground_ring)
	_materials.append(material)
	return material


func _process(_delta: float) -> void:
	# The beam turns with the camera about the vertical only, so it always stands on the ground.
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var toward := camera.global_basis.z
		(get_child(0) as Node3D).global_rotation.y = atan2(toward.x, toward.z)
