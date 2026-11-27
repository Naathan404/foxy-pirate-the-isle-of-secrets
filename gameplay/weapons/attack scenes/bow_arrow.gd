extends WeaponAttack
## One snapshotted arrow; swept collision prevents tunnelling through thin targets/walls.

const SPRITE_FEEDBACK: Script = preload("res://gameplay/weapons/dagger_sprite_feedback.gd")
const IMPACT_SOUND: AudioStream = preload("res://assets/audio/combat/bow_impact.wav")
const CURVE_SAMPLES: int = 32
## Extra time after the longest ribbon has faded before the fire trail node is freed.
const FIRE_TRAIL_FREE_MARGIN_SECONDS := 0.1
const STORM_BURST: PackedScene = preload("res://gameplay/weapons/stormstring_burst.tscn")
const STORM_PARTICLES: PackedScene = preload(
	"res://gameplay/weapons/stormstring_flight_particles.tscn"
)

@export var hitbox: HitBox
@export_range(1.0, 60.0, 0.1) var speed: float = 18.0
@export_range(0.0, 3.0, 0.05) var release_height: float = 0.9
@export_range(0.1, 10.0, 0.1) var lifetime: float = 4.0

@export_group("Low Destructible Sweep")
## Breakable props shorter than the flight height are caught by a vertical sweep from the
## shooter's floor up to the arrow, so grass, logs and shells are never flown over.
@export_range(0.02, 1.0, 0.01, "suffix:m") var low_sweep_width: float = 0.14
## Reaches slightly below the shooter's feet for props sitting on a lower patch of floor.
@export_range(0.0, 1.0, 0.01, "suffix:m") var low_sweep_floor_margin: float = 0.2

@export_group("Stormstring Targeting")
## Full horizontal acquisition cone, centered on the arrow's current heading.
@export_range(1.0, 180.0, 1.0) var homing_cone_degrees: float = 120.0
@export_range(0.0, 1.0, 0.01) var homing_acquire_delay: float = 0.12
@export_range(0.1, 20.0, 0.1) var homing_tracking_speed: float = 5.0

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
## Blue fire ribbon behind every arrow, charged or not. Empty disables it.
@export var fire_trail_scene: PackedScene = preload(
	"res://assets/vfx/fire_trails/Blue_Fire_Trail.tscn"
)
## The fire trail is authored for slow, large effects; these shrink it to arrow size.
@export_range(0.05, 1.0, 0.01) var fire_trail_width_scale: float = 0.5
@export_range(0.05, 1.0, 0.01) var fire_trail_time_scale: float = 0.24
## Where the flame leaves the arrow art, in Arrow.png pixels: the back of the fletching, on the
## shaft line (the art points left).
@export var fire_trail_anchor_pixel: Vector2 = Vector2(1800, 618)

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
var _fire_trail: Node3D
var _curve_lengths: PackedFloat32Array = []
var _path_length: float = 0.0
var _floor_height: float = 0.0
var _low_sweep_shape := BoxShape3D.new()

var _travelled: float = 0.0
var _age: float = 0.0
var _finished: bool = false
var _previous_position: Vector3
var _sprite_offset: Vector3
var _homing_target: Node3D
var _had_homing_target: bool = false

@onready var _sprite: Sprite3D = $Sprite3D
@onready var _sprite_scale: Vector3 = _sprite.scale


func _ready() -> void:
	# The sprite already interpolates itself between physics steps in _process.
	_sprite.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
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
	_floor_height = context.actor.global_position.y - low_sweep_floor_margin
	look_at(global_position + context.direction, Vector3.UP)
	_sprite_offset = _sprite.position
	_update_sprite_angle(context.direction)
	_start = global_position
	_previous_position = global_position
	_spawn_fire_trail()
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
	if converge_on_target and _age >= homing_acquire_delay:
		_update_homing(delta)
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
		var low_prop := _sweep_low_destructible(destination)
		if not low_prop.is_empty() and (
			collision.is_empty()
			or (
				global_position.distance_squared_to(low_prop.position)
				< global_position.distance_squared_to(collision.position)
			)
		):
			collision = low_prop
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


## Returns {collider, position} for the nearest DestructibleProp HurtBox below this step.
func _sweep_low_destructible(destination: Vector3) -> Dictionary:
	var motion := destination - global_position
	var height := global_position.y - _floor_height
	var horizontal := Vector3(motion.x, 0.0, motion.z)
	if height <= 0.0 or horizontal.is_zero_approx():
		return {}
	var width := low_sweep_width * context.hitbox_multiplier
	# One box spanning this frame's step, from the floor up to the arrow.
	_low_sweep_shape.size = Vector3(width, height, horizontal.length() + width)
	var center := global_position + motion * 0.5
	center.y = _floor_height + height * 0.5
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _low_sweep_shape
	query.transform = Transform3D(Basis.looking_at(horizontal, Vector3.UP), center)
	query.collision_mask = CombatLayers.ENEMY_HURTBOX
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var heading := horizontal.normalized()
	var nearest := {}
	var nearest_along := INF
	for result in get_world_3d().direct_space_state.intersect_shape(query):
		var hurtbox := result.collider as HurtBox
		if hurtbox == null or not hurtbox.actor is DestructibleProp:
			continue
		var along := heading.dot(hurtbox.global_position - global_position)
		if along < nearest_along:
			nearest_along = along
			nearest = {"collider": hurtbox}
	if nearest.is_empty():
		return {}
	var fraction := clampf(nearest_along / horizontal.length(), 0.0, 1.0)
	nearest["position"] = global_position + motion * fraction
	return nearest


func _build_flight_path() -> void:
	var forward := (_end - _start).normalized()
	var span := _start.distance_to(_end)
	var side := forward.cross(Vector3.UP)
	var width := clampf(curve_offset, -span * 0.45, span * 0.45)
	# Separate departure/convergence controls keep each lane on its own side of aim.
	_control = _start.lerp(_end, 0.24) + side * width + Vector3.UP * curve_height
	_control_end = _start.lerp(_end, 0.76) + side * width * 0.3
	_measure_flight_path()


func _measure_flight_path() -> void:
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


func _find_homing_target() -> Node3D:
	var heading := -global_basis.z
	heading.y = 0.0
	if heading.is_zero_approx():
		return null
	heading = heading.normalized()
	var min_dot := cos(deg_to_rad(clampf(homing_cone_degrees, 1.0, 180.0) * 0.5))
	var closest_distance := context.range_units * context.range_units
	var closest: Node3D
	var candidates := get_tree().get_nodes_in_group("enemy")
	candidates.append_array(get_tree().get_nodes_in_group("training_dummy"))
	for node in candidates:
		var target := node as Node3D
		if not _is_homing_target_valid(target):
			continue
		var offset := target.global_position - global_position
		offset.y = 0.0
		var distance := offset.length_squared()
		if distance > closest_distance or distance < 0.0001:
			continue
		if heading.dot(offset.normalized()) < min_dot:
			continue
		closest = target
		closest_distance = distance
	return closest


func _is_homing_target_valid(target: Node3D) -> bool:
	if not is_instance_valid(target) or target.is_queued_for_deletion() or not target.is_inside_tree():
		return false
	if target is EnemyBase:
		return not (target as EnemyBase).dead
	return target.is_in_group("training_dummy")


func _update_homing(delta: float) -> void:
	if not _is_homing_target_valid(_homing_target):
		_homing_target = _find_homing_target()
		if not is_instance_valid(_homing_target) and _had_homing_target:
			# Continue forward along the last heading if the target disappears.
			var remaining := maxf(0.0, _path_length - _travelled)
			_start = global_position
			_end = _start - global_basis.z * remaining
			curve_offset = 0.0
			curve_height = 0.0
			_travelled = 0.0
			_build_flight_path()
			_had_homing_target = false
	if not is_instance_valid(_homing_target):
		return
	_had_homing_target = true
	# Split the existing curve at the current position. Its remaining control points
	# preserve the tangent, so retargeting does not teleport or snap the arrow.
	var progress := _progress_at_distance(_travelled)
	var b := _control.lerp(_control_end, progress)
	var c := _control_end.lerp(_end, progress)
	var e := b.lerp(c, progress)
	_start = global_position
	_control = e
	_control_end = c
	var target_position := _homing_target.global_position
	target_position.y = _start.y
	var new_end := _end.lerp(target_position, 1.0 - exp(-homing_tracking_speed * maxf(delta, 0.0)))
	_control_end += (new_end - _end) * 0.5
	_end = new_end
	_travelled = 0.0
	_measure_flight_path()


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
		if is_instance_valid(_fire_trail):
			_fire_trail.global_position = _fire_trail_anchor()


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
	# After the art is placed, so the flame ends at the stuck arrow's fletching.
	_release_fire_trail()
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
	_release_fire_trail()
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
	_release_fire_trail()
	hitbox.end_attack()
	set_physics_process(false)
	queue_free()


func _exit_tree() -> void:
	_finish_flight_particles()
	_release_fire_trail()
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


func _spawn_fire_trail() -> void:
	if fire_trail_scene == null:
		return
	_fire_trail = fire_trail_scene.instantiate() as Node3D
	for ribbon in _fire_trail_ribbons():
		ribbon.set("width", float(ribbon.get("width")) * fire_trail_width_scale)
		ribbon.set("time", float(ribbon.get("time")) * fire_trail_time_scale)
	# Parented beside the arrow so the flame fades out on its own after the arrow is freed.
	get_parent().add_child(_fire_trail)
	_fire_trail.global_position = _fire_trail_anchor()


## Stops recording points where the arrow ended, and frees the whole trail once its longest
## ribbon has faded. (A ribbon's own autodestruct frees only its holder node, not the root.)
func _release_fire_trail() -> void:
	if not is_instance_valid(_fire_trail):
		return
	_fire_trail.global_position = _fire_trail_anchor()
	var fade_seconds := 0.0
	for ribbon in _fire_trail_ribbons():
		ribbon.set("emitting", false)
		fade_seconds = maxf(fade_seconds, float(ribbon.get("time")))
	# A scene-tree timer outlives this arrow, which is usually freed right after.
	get_tree().create_timer(fade_seconds + FIRE_TRAIL_FREE_MARGIN_SECONDS).timeout.connect(
		_fire_trail.queue_free
	)
	_fire_trail = null


## The fletching end of the drawn arrow in world space. The sprite is a camera-facing quad offset
## from this node, so the flame must follow the art rather than the flight point.
func _fire_trail_anchor() -> Vector3:
	var texture_size := _sprite.texture.get_size()
	var local := Vector3(
		(fire_trail_anchor_pixel.x - texture_size.x * 0.5) * _sprite.pixel_size,
		(texture_size.y * 0.5 - fire_trail_anchor_pixel.y) * _sprite.pixel_size,
		0.0
	)
	return _sprite.global_transform * (local + Vector3(_sprite.offset.x, _sprite.offset.y, 0.0))


func _fire_trail_ribbons() -> Array[Node]:
	var ribbons: Array[Node] = []
	for node in _fire_trail.find_children("*", "MeshInstance3D", true, false):
		if "emitting" in node and "autodestruct" in node:
			ribbons.append(node)
	return ribbons


func _finish_flight_particles() -> void:
	if not is_instance_valid(_flight_particles):
		return
	_flight_particles.emitting = false
	_flight_particles.get_node("HeadGlint").hide()
	var fade := _flight_particles.create_tween()
	fade.tween_interval(_flight_particles.lifetime)
	fade.tween_callback(_flight_particles.queue_free)
	_flight_particles = null
