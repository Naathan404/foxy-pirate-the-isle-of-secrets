extends WeaponAttack
## One snapshotted arrow; swept collision prevents tunnelling through thin targets/walls.

const SPRITE_FEEDBACK: Script = preload("res://gameplay/weapons/dagger_sprite_feedback.gd")
const IMPACT_SOUND: AudioStream = preload("res://assets/audio/combat/bow_impact.wav")
const CURVE_SAMPLES: int = 32
const STORM_BURST: PackedScene = preload("res://gameplay/weapons/stormstring_burst.tscn")
const STORM_PARTICLES: PackedScene = preload(
	"res://gameplay/weapons/stormstring_flight_particles.tscn"
)

@export var hitbox: HitBox
@export_range(1.0, 60.0, 0.1) var speed: float = 18.0
@export_range(0.0, 3.0, 0.05) var release_height: float = 0.9
@export_range(0.1, 10.0, 0.1) var lifetime: float = 4.0

@export_group("Hit Feedback")
@export var impact_scene: PackedScene = preload("res://gameplay/weapons/bow_impact_vfx.tscn")
@export_range(0.0, 0.1, 0.001) var hitstop_seconds: float = 0.045
@export_range(0.0, 8.0, 0.1) var hit_shake_pixels: float = 2.0
@export_range(0.0, 0.2, 0.005) var hit_kick_distance: float = 0.075
@export_range(0.1, 1.0, 0.05) var impact_scale: float = 0.5
@export var impact_charge_scale_bonus: float = 0.5
@export_range(0.0, 1.0, 0.01) var impact_base_strength: float = 0.35
@export_range(0.0, 1.0, 0.01) var impact_charge_strength_bonus: float = 0.4
@export var hit_charge_kick_bonus: float = 0.5
@export var hit_charge_hitstop_bonus: float = 0.5
@export var hit_charge_shake_bonus: float = 1.0
@export_range(0.0, 1.0, 0.01) var hit_shake_seconds: float = 0.12

@export_group("Hit Particles")
@export
var hit_particles_scene: PackedScene = preload("res://gameplay/weapons/bow_hit_particles.tscn")
@export_range(1, 64, 1) var hit_particle_count: int = 28
@export_range(0, 32, 1) var hit_charge_particle_bonus: int = 12

@export_group("Hit Audio")
@export var hit_sound: AudioStream = IMPACT_SOUND
@export_range(-80.0, 6.0, 1.0) var hit_volume_db: float = -12.0
@export var hit_charge_volume_bonus_db: float = 2.0
@export var hit_pitch_base: float = 1.15
@export var hit_charge_pitch_offset: float = -0.1

@export_group("Trail")
@export var trail_scene: PackedScene = preload("res://gameplay/weapons/bow_energy_trail.tscn")

@export_group("Range Expiry")
@export_range(0.05, 0.5, 0.01) var expiry_fade_seconds: float = 0.18
@export_range(0.05, 0.5, 0.01) var expiry_effect_scale: float = 0.18

@export_group("Wall Hit")
@export_range(0.0, 2.0, 0.05) var wall_hold_seconds: float = 0.6
@export_range(0.05, 0.5, 0.01) var wall_fade_seconds: float = 0.22
@export_range(0.0, 2.0, 0.01) var wall_tip_distance: float = 0.55
@export var wall_hit_sound: AudioStream = IMPACT_SOUND
@export_range(-80.0, 6.0, 1.0) var wall_hit_volume_db: float = -20.0
@export var wall_particles_scene: PackedScene = preload(
	"res://gameplay/weapons/bow_wall_hit_particles.tscn"
)

var curve_offset: float = 0.0
var curve_height: float = 0.0
var energy_strength: float = 0.0
var converge_on_target: bool = false
var arrival_seconds: float = 0.0
var storm_burst_state: Dictionary = {}
var _start: Vector3
var _control: Vector3
var _control_end: Vector3
var _end: Vector3
var _trail: Node3D
var _flight_particles: GPUParticles3D
var _curve_lengths: PackedFloat32Array = []
var _path_length: float = 0.0

var _travelled: float = 0.0
var _age: float = 0.0
var _finished: bool = false
var _previous_position: Vector3
var _sprite_offset: Vector3

@onready var _sprite: Sprite3D = $Sprite3D
@onready var _sprite_scale: Vector3 = _sprite.scale


func _ready() -> void:
	hide()
	set_physics_process(false)
	hitbox.damage_prepared.connect(_on_damage_prepared)
	hitbox.damage_applied.connect(_on_damage_applied)


func validate() -> bool:
	return (
		is_instance_valid(hitbox)
		and speed > 0.0
		and lifetime > 0.0
		and trail_scene != null
		and impact_scene != null
	)


func activate() -> void:
	if context == null or not is_instance_valid(context.actor) or context.range_units <= 0.0:
		return
	super.activate()
	speed *= context.projectile_speed_multiplier
	show()
	global_position = context.actor.global_position + Vector3.UP * release_height
	look_at(global_position + context.direction, Vector3.UP)
	_sprite_offset = _sprite.position
	_update_sprite_angle(context.direction)
	_start = global_position
	_previous_position = global_position
	_end = _start + context.direction * context.range_units
	if converge_on_target and context.has_target:
		var offset := context.target_position - _start
		offset.y = 0.0
		_end = _start + offset.limit_length(context.range_units)
	_build_flight_path()
	if arrival_seconds > 0.0:
		speed = _path_length / arrival_seconds
	if energy_strength > 0.0:
		_trail = trail_scene.instantiate() as Node3D
		_trail.set("strength", energy_strength)
		get_parent().add_child(_trail)
		_trail.call("push_point", global_position)
		_flight_particles = STORM_PARTICLES.instantiate() as GPUParticles3D
		get_parent().add_child(_flight_particles)
		_flight_particles.global_position = global_position
		_flight_particles.emitting = true
	_travelled = 0.0
	_age = 0.0
	_finished = false
	hitbox.scale = Vector3.ONE * context.hitbox_multiplier
	hitbox.begin_attack_with_context(context.create_damage_context())
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not launched or _finished:
		return
	if not is_instance_valid(context.actor) or bool(context.actor.get("dead")):
		_finish_projectile()
		return
	_age += maxf(0.0, delta)
	_previous_position = global_position
	var distance := minf(speed * maxf(0.0, delta), _path_length - _travelled)
	var progress := _progress_at_distance(_travelled + distance)
	var destination := _start.bezier_interpolate(_control, _control_end, _end, progress)
	if distance > 0.0:
		var query := PhysicsRayQueryParameters3D.create(
			global_position, destination, CombatLayers.WORLD | CombatLayers.ENEMY_HURTBOX
		)
		query.collide_with_areas = true
		if context.actor is CollisionObject3D:
			query.exclude = [(context.actor as CollisionObject3D).get_rid()]
		var collision := get_world_3d().direct_space_state.intersect_ray(query)
		if not collision.is_empty():
			var impact_direction := (destination - global_position).normalized()
			global_position = collision.position
			if is_instance_valid(_trail):
				_trail.call("push_point", global_position)
			if collision.collider is HurtBox:
				hitbox.try_hit(collision.collider as HurtBox)
				_finish_projectile()
			else:
				_stick_in_wall(collision.normal, impact_direction)
			return
	global_position = destination
	var tangent := _start.bezier_derivative(_control, _control_end, _end, progress)
	if not tangent.is_zero_approx():
		look_at(global_position + tangent, Vector3.UP)
	if is_instance_valid(_trail):
		_trail.call("push_point", global_position)
	if is_instance_valid(_flight_particles):
		_flight_particles.global_position = global_position
	_travelled += distance
	if _travelled >= _path_length - 0.0001 or _age >= lifetime:
		_expire_projectile()


func _build_flight_path() -> void:
	var forward := (_end - _start).normalized()
	var span := _start.distance_to(_end)
	var side := forward.cross(Vector3.UP)
	var width := clampf(curve_offset, -span * 0.45, span * 0.45)
	# Separate departure/convergence controls keep each lane on its own side of aim.
	_control = _start.lerp(_end, 0.24) + side * width + Vector3.UP * curve_height
	_control_end = _start.lerp(_end, 0.76) + side * width * 0.3
	_curve_lengths.clear()
	_curve_lengths.append(0.0)
	_path_length = 0.0
	var previous := _start
	for index in range(1, CURVE_SAMPLES + 1):
		var point := _start.bezier_interpolate(
			_control, _control_end, _end, float(index) / CURVE_SAMPLES
		)
		_path_length += previous.distance_to(point)
		_curve_lengths.append(_path_length)
		previous = point


## Arc-length lookup avoids slowing at the bend and accelerating out of it.
func _progress_at_distance(distance: float) -> float:
	var low: int = 0
	var high: int = CURVE_SAMPLES
	while high - low > 1:
		var middle: int = floori(float(low + high) / 2.0)
		if _curve_lengths[middle] < distance:
			low = middle
		else:
			high = middle
	var segment: float = _curve_lengths[high] - _curve_lengths[low]
	var fraction := clampf((distance - _curve_lengths[low]) / maxf(segment, 0.0001), 0.0, 1.0)
	return (low + fraction) / CURVE_SAMPLES


func _process(_delta: float) -> void:
	if launched and not _finished:
		_sprite.global_position = (
			_previous_position.lerp(global_position, Engine.get_physics_interpolation_fraction())
			+ global_basis * _sprite_offset
		)
		_update_sprite_angle(-global_basis.z)


func _on_damage_prepared(damage: DamageContext, target: Node) -> void:
	context.damage_prepared.emit(damage, target)


func _on_damage_applied(damage: DamageContext, target: Node, applied_hp: float) -> void:
	if _finished or applied_hp <= 0.0:
		return
	context.damage_applied.emit(damage, target, applied_hp)
	_play_hit_feedback(target, damage.get_impact_scale())
	_finish_projectile()


func _play_hit_feedback(target: Node, knockback_scale: float) -> void:
	var strength := clampf(energy_strength, 0.0, 1.0)
	if target is EnemyBase and is_instance_valid(target.visual.sprite):
		var sprite: Sprite3D = target.visual.sprite
		# Reuse the sprite-owned kick/flash so it survives arrow deletion and stacks safely
		# with melee hits instead of creating competing overlay materials.
		var feedback := sprite.get_node_or_null("DaggerFeedback")
		if feedback == null:
			feedback = SPRITE_FEEDBACK.new()
			feedback.name = "DaggerFeedback"
			sprite.add_child(feedback)
		feedback.kick(
			context.direction,
			hit_kick_distance * (1.0 + strength * hit_charge_kick_bonus) * knockback_scale,
			true,
			knockback_scale
		)

	var impact := impact_scene.instantiate() as Node3D
	get_parent().add_child(impact)
	impact.global_position = global_position
	impact.call("set_aim", context.direction)
	impact.scale = (
		Vector3.ONE * impact_scale * (1.0 + strength * impact_charge_scale_bonus) * knockback_scale
	)
	impact.call("burst", impact_base_strength + strength * impact_charge_strength_bonus)
	_spawn_hit_particles(strength, knockback_scale)
	_spawn_storm_burst()
	get_node("/root/AudioManager").play_sfx_3d(
		hit_sound,
		global_position,
		hit_volume_db + strength * hit_charge_volume_bonus_db + linear_to_db(knockback_scale),
		hit_pitch_base + strength * hit_charge_pitch_offset
	)
	# Ranged impacts briefly stop the target while the shooter remains responsive.
	get_node("/root/HitstopController").request_local(
		null,
		target as Node3D,
		hitstop_seconds * (1.0 + strength * hit_charge_hitstop_bonus) * knockback_scale
	)
	get_node("/root/ScreenShakeController").request(
		hit_shake_pixels * (1.0 + strength * hit_charge_shake_bonus) * knockback_scale,
		hit_shake_seconds
	)


func _spawn_hit_particles(strength: float, impact_multiplier: float) -> void:
	if hit_particles_scene == null:
		return
	var particles := hit_particles_scene.instantiate() as GPUParticles3D
	particles.amount = hit_particle_count + roundi(strength * hit_charge_particle_bonus)
	var material := particles.process_material as ParticleProcessMaterial
	# Each burst owns its material so simultaneous hits can have different directions.
	material = material.duplicate() as ParticleProcessMaterial
	particles.process_material = material
	material.direction = (context.direction + Vector3.UP * 0.45).normalized()
	var power := (1.0 + strength * 0.4) * clampf(impact_multiplier, 0.75, 1.5)
	material.initial_velocity_min *= power
	material.initial_velocity_max *= power
	material.scale_min *= power
	material.scale_max *= power
	# Parent the emitter beside the projectile so its particles survive arrow cleanup.
	particles.finished.connect(particles.queue_free)
	get_parent().add_child(particles)
	particles.global_transform = Transform3D(Basis.IDENTITY, global_position)
	var camera := get_viewport().get_camera_3d()
	if is_instance_valid(camera):
		particles.global_position += camera.global_basis.z * 0.04
	particles.restart()
	particles.emitting = true


func _update_sprite_angle(direction: Vector3) -> void:
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		return
	var screen_x := direction.dot(camera.global_basis.x)
	var screen_y := direction.dot(camera.global_basis.y)
	if is_zero_approx(screen_x) and is_zero_approx(screen_y):
		return
	# Arrow.png points left in its source image, so flip its axis by PI.
	var angle := atan2(screen_y, screen_x) + PI
	# Set the world basis explicitly so the parent's heading cannot override the roll.
	_sprite.global_basis = (
		camera.global_basis.orthonormalized()
		* Basis(Vector3.BACK, angle)
		* Basis.from_scale(_sprite_scale)
	)


func _stick_in_wall(normal: Vector3, direction: Vector3) -> void:
	if _finished:
		return
	_finished = true
	_finish_flight_particles()
	hitbox.end_attack()
	set_physics_process(false)
	set_process(false)
	_update_sprite_angle(direction)
	# The source image's tip is left of its center; keep that tip at the contact.
	var tip_direction := -_sprite.global_basis.x.normalized()
	_sprite.global_position = global_position - tip_direction * wall_tip_distance + normal * 0.015
	if is_instance_valid(_trail):
		_trail.call("finish")
		_trail = null

	_spawn_wall_particles(normal)
	_spawn_storm_burst()
	if wall_hit_sound != null:
		get_node("/root/AudioManager").play_sfx_3d(
			wall_hit_sound, global_position, wall_hit_volume_db, 1.35
		)

	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	var fade := create_tween()
	fade.tween_interval(wall_hold_seconds)
	fade.tween_property(_sprite, "modulate:a", 0.0, wall_fade_seconds)
	fade.tween_callback(queue_free)


func _spawn_wall_particles(normal: Vector3) -> void:
	if wall_particles_scene == null:
		return
	var particles := wall_particles_scene.instantiate() as GPUParticles3D
	particles.emitting = false
	get_parent().add_child(particles)
	particles.global_position = global_position + normal * 0.04
	# Aim the emission cone away from the wall, including horizontal surfaces.
	var up := Vector3.FORWARD if absf(normal.dot(Vector3.UP)) > 0.98 else Vector3.UP
	particles.look_at(particles.global_position + normal, up)
	particles.restart()
	particles.emitting = true


func _expire_projectile() -> void:
	if _finished:
		return
	_finished = true
	_finish_flight_particles()
	hitbox.end_attack()
	set_physics_process(false)
	set_process(false)
	_sprite.global_position = global_position + global_basis * _sprite_offset
	_update_sprite_angle(-global_basis.z)
	if converge_on_target:
		_spawn_storm_burst(true)
	if is_instance_valid(_trail):
		_trail.call("finish")
		_trail = null

	# Reuse the impact visuals as a small, quiet puff at the end of the flight.
	var puff := impact_scene.instantiate() as Node3D
	puff.set("ring_count", 0)
	puff.set("spark_count", 6)
	puff.set("burst_duration", expiry_fade_seconds + 0.06)
	puff.set("effect_brightness", 0.8)
	puff.set("light_base_energy", 0.0)
	puff.set("light_charge_energy_bonus", 0.0)
	get_parent().add_child(puff)
	puff.global_position = _sprite.global_position
	puff.scale = Vector3.ONE * expiry_effect_scale
	puff.call("set_aim", -global_basis.z)
	puff.call("burst", 0.05 + clampf(energy_strength, 0.0, 1.0) * 0.15)

	# Alpha scissor would clip the sprite abruptly instead of allowing a soft fade.
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	var fade := create_tween().set_parallel(true)
	fade.tween_property(_sprite, "modulate:a", 0.0, expiry_fade_seconds)
	fade.tween_property(_sprite, "scale", _sprite.scale * 0.65, expiry_fade_seconds)
	fade.chain().tween_callback(queue_free)


func _finish_projectile() -> void:
	if _finished:
		return
	_finished = true
	_finish_flight_particles()
	hitbox.end_attack()
	set_physics_process(false)
	queue_free()


func _exit_tree() -> void:
	_finish_flight_particles()
	if is_instance_valid(_trail):
		_trail.call("finish")
	if is_instance_valid(hitbox):
		hitbox.end_attack()


func _spawn_storm_burst(terminal_sound: bool = false) -> void:
	if energy_strength <= 0.0:
		return
	var now: int = Time.get_ticks_msec()
	if storm_burst_state.has("position"):
		var previous: Vector3 = storm_burst_state["position"]
		var previous_time: int = storm_burst_state["time"]
		# Six converging arrows share one large flash; individual hit feedback still plays.
		if now - previous_time < 120 and previous.distance_squared_to(global_position) < 0.64:
			return
	storm_burst_state["position"] = global_position
	storm_burst_state["time"] = now
	var burst := STORM_BURST.instantiate() as Node3D
	get_parent().add_child(burst)
	burst.global_position = global_position
	burst.call("burst", energy_strength)
	if terminal_sound:
		get_node("/root/AudioManager").play_sfx_3d(
			hit_sound, global_position, hit_volume_db - 2.0, 0.8
		)


func _finish_flight_particles() -> void:
	if not is_instance_valid(_flight_particles):
		return
	_flight_particles.emitting = false
	_flight_particles.get_node("HeadGlint").hide()
	var fade := _flight_particles.create_tween()
	fade.tween_interval(_flight_particles.lifetime)
	fade.tween_callback(_flight_particles.queue_free)
	_flight_particles = null
