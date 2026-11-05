extends HarpoonThrust
## The locked direction drives the recoil, piercing dash, and world-safe stop.

const TRAIL: PackedScene = preload("res://gameplay/weapons/bow_energy_trail.tscn")
const CHARGE_VFX: PackedScene = preload("res://gameplay/weapons/bow_charge_vfx.tscn")
const FINISH_VFX: PackedScene = preload("res://gameplay/weapons/bow_impact_vfx.tscn")
const DASH_SOUND: AudioStream = preload("res://assets/audio/combat/bow_release.wav")

@export_range(0.05, 0.5, 0.01) var sweep_step: float = 0.18
@export_range(0.2, 3.0, 0.1) var maximum_ground_drop: float = 1.4
@export_range(0.0, 1.0, 0.01) var recoil_distance: float = 0.38
@export_range(0.1, 1.0, 0.01) var recoil_phase: float = 0.4
@export_range(0.1, 1.0, 0.01) var afterimage_spacing: float = 0.42
@export_range(0.0, 3.0, 0.05) var crate_knockback_distance: float = 1.1

var _body: CharacterBody3D
var _saved_mask: int = 0
var _owns_mask: bool = false
var _protected: bool = false
var _ended: bool = false
var _distance: float = 0.0
var _last_afterimage_distance: float = 0.0
var _windup_elapsed: float = 0.0
var _windup_duration: float = 0.5
var _recoil_blocked: bool = false
var _trail: Node3D
var _charge_effect: Node3D


func begin_windup() -> void:
	_body = context.actor as CharacterBody3D
	if not is_instance_valid(_body):
		return
	_windup_elapsed = 0.0
	_recoil_blocked = false
	var player := _body as Player
	if player != null and is_instance_valid(player.weapon_controller):
		_windup_duration = maxf(0.01, player.weapon_controller.get_attack_windup_duration())
	super.begin_windup()
	_charge_effect = CHARGE_VFX.instantiate() as Node3D
	_charge_effect.set("effect_color", Color(1.0, 0.7, 0.08, 0.95))
	_charge_effect.set("core_color", Color(1.0, 1.0, 0.72, 1.0))
	_charge_effect.set("light_color", Color(1.0, 0.76, 0.18))
	_charge_effect.set("ring_count", 0)
	_charge_effect.set("spark_count", 14)
	_charge_effect.set("spark_inflow_seconds", 0.42)
	_charge_effect.set("tick_steps", 3)
	_charge_effect.set("tick_volume_db", -22.0)
	_charge_effect.set("focus_forward_offset", 0.0)
	get_parent().add_child(_charge_effect)
	_sync_charge_effect()


func tick_windup(delta: float) -> void:
	if not is_instance_valid(_body):
		return
	var recoil_time := _windup_duration * recoil_phase
	var before := clampf(_windup_elapsed / recoil_time, 0.0, 1.0)
	_windup_elapsed = minf(_windup_duration, _windup_elapsed + maxf(0.0, delta))
	var after := clampf(_windup_elapsed / recoil_time, 0.0, 1.0)
	var step := recoil_distance * ((1.0 - before) * (1.0 - before) - (1.0 - after) * (1.0 - after))
	if step > 0.0 and not _recoil_blocked:
		var motion := -context.direction * step
		if not _has_ground(_body.global_position + motion) or _body.move_and_collide(motion) != null:
			_recoil_blocked = true
	super.tick_windup(delta)
	_vfx.call("set_charge_progress", _windup_elapsed / _windup_duration)
	_sync_charge_effect()
	if is_instance_valid(_charge_effect):
		_charge_effect.call("set_progress", _windup_elapsed / _windup_duration)


func _sync_charge_effect() -> void:
	if is_instance_valid(_charge_effect) and is_instance_valid(_body):
		_charge_effect.global_position = _body.global_position + Vector3.UP * 0.82
		_charge_effect.global_position += context.direction * 1.0


func activate() -> void:
	_body = context.actor as CharacterBody3D
	if not is_instance_valid(_body):
		return
	_saved_mask = _body.collision_mask
	_owns_mask = true
	_body.collision_mask = CombatLayers.WORLD
	_protected = true
	_ended = false
	_distance = 0.0
	_last_afterimage_distance = 0.0
	if is_instance_valid(_charge_effect):
		_charge_effect.call("burst", 0.9)
		_charge_effect = null
	_trail = TRAIL.instantiate() as Node3D
	_trail.set("strength", 1.0)
	_trail.set("head_color", Color(1.0, 0.86, 0.32, 1.0))
	_trail.set("tail_color", Color(1.0, 0.45, 0.04, 0.0))
	_trail.set("core_color", Color(1.0, 1.0, 0.9, 1.0))
	_trail.set("base_width", 0.055)
	_trail.set("charge_width_bonus", 0.12)
	_trail.set("max_points", 64)
	_trail.set("fade_seconds", 0.38)
	get_parent().add_child(_trail)
	_trail.call("push_point", _body.global_position + Vector3.UP * 0.8 + context.direction)
	context.crate_knockback_distance = crate_knockback_distance
	super.activate()
	get_node("/root/AudioManager").play_sfx_3d(DASH_SOUND, _body.global_position, -9.0, 0.9)
	get_node("/root/ScreenShakeController").request(3.5, 0.13)


func tick_active(delta: float) -> void:
	if not active or _ended or not is_instance_valid(_body):
		return
	if bool(_body.get("dead")) or bool(_body.call("is_gameplay_input_blocked")):
		_stop_dash()
		return
	_elapsed = minf(context.active_seconds, _elapsed + maxf(0.0, delta))
	var progress := clampf(_elapsed / context.active_seconds, 0.0, 1.0)
	# Ease out over the fixed route so the final frames read as a short brake.
	var target_distance := context.range_units * (1.0 - (1.0 - progress) * (1.0 - progress))
	var travel := maxf(0.0, target_distance - _distance)
	var remaining: float = travel
	while remaining > 0.0001 and active:
		var step: float = minf(sweep_step, remaining)
		var motion: Vector3 = context.direction * step
		if not _has_ground(_body.global_position + motion):
			_stop_dash()
			return
		var before := _body.global_position
		var collision := _body.move_and_collide(motion)
		_distance += before.distance_to(_body.global_position)
		_sync_transform()
		hitbox.sample_shape()
		if not active or not is_instance_valid(_body):
			return
		_trail.call("push_point", _body.global_position + Vector3.UP * 0.8 + context.direction)
		if _distance - _last_afterimage_distance >= afterimage_spacing:
			_spawn_afterimage()
			_last_afterimage_distance = _distance
		if collision != null:
			_stop_dash()
			return
		remaining -= step
	_vfx.call("set_progress", progress)
	if _distance >= context.range_units - 0.0001:
		_stop_dash()


func _has_ground(at: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
		at + Vector3.UP * 0.4, at + Vector3.DOWN * maximum_ground_drop, CombatLayers.WORLD
	)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func is_invulnerable() -> bool:
	return active and _protected and not _ended


func has_finished_active() -> bool:
	return _ended


func _stop_dash() -> void:
	_ended = true
	deactivate()


func _spawn_afterimage() -> void:
	var player := _body as Player
	if player == null or not is_instance_valid(player.visual):
		return
	var source := player.visual.get("_active_sprite") as Sprite3D
	if not is_instance_valid(source) or source.texture == null:
		return
	var ghost := Sprite3D.new()
	ghost.texture = source.texture
	ghost.pixel_size = source.pixel_size
	ghost.axis = source.axis
	ghost.billboard = source.billboard
	ghost.flip_h = source.flip_h
	ghost.centered = source.centered
	ghost.offset = source.offset
	ghost.modulate = Color(1.0, 0.83, 0.38, 0.42)
	ghost.no_depth_test = true
	ghost.top_level = true
	get_parent().add_child(ghost)
	ghost.global_transform = source.global_transform
	var fade := ghost.create_tween()
	fade.tween_property(ghost, "modulate:a", 0.0, 0.22)
	fade.tween_callback(ghost.queue_free)


func _spawn_finish_effect() -> void:
	var dust := FINISH_VFX.instantiate() as Node3D
	dust.set("effect_color", Color(1.0, 0.65, 0.25, 0.45))
	dust.set("core_color", Color(1.0, 0.87, 0.62, 0.65))
	dust.set("ring_count", 0)
	dust.set("spark_count", 8)
	dust.set("core_burst_size", 0.3)
	dust.set("spark_streak_length", 1.2)
	get_parent().add_child(dust)
	dust.global_position = _body.global_position + Vector3.UP * 0.12
	dust.scale = Vector3.ONE * 0.25
	dust.call("burst", 0.35)


func deactivate() -> void:
	if active and is_instance_valid(_body) and not bool(_body.get("dead")):
		_spawn_finish_effect()
	_protected = false
	if _owns_mask and is_instance_valid(_body):
		_body.collision_mask = _saved_mask
		_body.velocity.x = 0.0
		_body.velocity.z = 0.0
	_owns_mask = false
	if is_instance_valid(_trail):
		_trail.call("finish")
		_trail = null
	if is_instance_valid(_charge_effect):
		_charge_effect.queue_free()
		_charge_effect = null
	super.deactivate()


func _exit_tree() -> void:
	deactivate()
	super._exit_tree()
