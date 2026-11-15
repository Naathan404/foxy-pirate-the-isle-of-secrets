extends Node3D

const SMOKE_TEXTURE := preload("res://assets/sprites/effects/smoke/smoke_04.png")

## Transient particles are children of the scene, so they can finish after the enemy or bullet.
var effect: StringName = &"impact"


func _ready() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "Particles"
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-4, -2, -4), Vector3(8, 8, 8))
	var process := ParticleProcessMaterial.new()
	var color := Color(0.42, 0.58, 0.27, 0.95)
	var end_color := Color(color.r, color.g, color.b, 0.0)
	var size := 0.22
	var use_smoke_texture := false
	particles.lifetime = 0.35
	particles.amount = 10
	process.direction = Vector3.UP
	process.spread = 100.0
	process.gravity = Vector3(0, -1.2, 0)
	process.initial_velocity_min = 0.5
	process.initial_velocity_max = 1.8
	match effect:
		&"alert":
			color = Color(0.35, 0.92, 0.85, 0.95)
			size = 0.13
			particles.amount = 12
			particles.lifetime = 0.55
			process.gravity = Vector3(0, 0.5, 0)
		&"dust":
			color = Color(0.77, 0.73, 0.59, 0.7)
			particles.amount = 6
			particles.lifetime = 0.4
			size = 0.18
			process.initial_velocity_max = 0.65
			process.gravity = Vector3(0, 0.1, 0)
		&"muzzle":
			particles.amount = 12
			particles.lifetime = 0.22
			process.initial_velocity_max = 2.6
		&"smoke":
			color = Color(0.68, 0.74, 0.62, 0.85)
			end_color = Color(0.42, 0.46, 0.4, 0.0)
			size = 0.34
			use_smoke_texture = true
			particles.amount = 8
			particles.lifetime = 0.6
			particles.explosiveness = 0.75
			process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			process.emission_sphere_radius = 0.16
			process.spread = 32.0
			process.gravity = Vector3(0, 1.3, 0)
			process.initial_velocity_min = 0.7
			process.initial_velocity_max = 1.5
			process.damping_min = 0.6
			process.damping_max = 1.2
		&"hit":
			color = Color(1.0, 0.9, 0.71, 0.9)
			size = 0.13
			particles.amount = 9
		&"death":
			color = Color(0.92, 0.78, 0.62, 0.95)
			particles.amount = 24
			particles.lifetime = 0.7
			size = 0.17
			process.initial_velocity_max = 2.7
	if not use_smoke_texture:
		end_color = Color(color.r, color.g, color.b, 0.0)
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, end_color)
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	process.scale_min = 0.8 if use_smoke_texture else 0.6
	process.scale_max = 1.5 if use_smoke_texture else 1.4
	particles.process_material = process
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if use_smoke_texture:
		material.albedo_texture = SMOKE_TEXTURE
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = material
	particles.draw_pass_1 = quad
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.2).timeout.connect(queue_free)
