extends RefCounted
## Non-damaging feedback shared by boss behaviors.


static func shockwave(parent: Node, at: Vector3, radius: float, color: Color) -> void:
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.85
	mesh.outer_radius = 1.0
	ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	ring.material_override = material
	parent.add_child(ring)
	ring.global_position = at + Vector3.UP * 0.08
	ring.scale = Vector3(0.1, 0.1, 0.1)
	var tween := ring.create_tween().set_parallel(true)
	(
		tween
		. tween_property(ring, "scale", Vector3.ONE * radius, 0.45)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.45)
	tween.chain().tween_callback(ring.queue_free)


## A self-cleaning burst: its particles never deal damage or change attack timing.
static func burst(
	parent: Node, at: Vector3, color: Color, amount: int, spread_radius: float, force: float
) -> void:
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	var particles := CPUParticles3D.new()
	particles.name = "BossBurst"
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = 0.75
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = spread_radius
	particles.direction = Vector3.UP
	particles.spread = 95.0
	particles.initial_velocity_min = force * 0.4
	particles.initial_velocity_max = force
	particles.gravity = Vector3(0, -5, 0)
	particles.scale_amount_min = 0.4
	particles.scale_amount_max = 1.2
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color.r, color.g * 0.3, color.b * 0.3, 0.0))
	particles.color_ramp = gradient
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.16, 0.16, 0.16)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	particles.mesh = mesh
	parent.add_child(particles)
	particles.global_position = at
	particles.emitting = true
	var tween := particles.create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(particles.queue_free)
