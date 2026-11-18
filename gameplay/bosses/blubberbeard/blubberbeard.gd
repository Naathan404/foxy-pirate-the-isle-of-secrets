class_name BlubberbeardBoss
extends BossBase

enum State { WAIT, WINDUP, CHARGE, RECOVERY }

const HAZARD = preload("res://gameplay/bosses/blubberbeard/boss_hazard.gd")
const EFFECTS = preload("res://gameplay/bosses/boss_effects.gd")
const MOVE_DUST_SHEET = preload("res://assets/sprites/bosses/blubberbeard/boss_move_dust.png")

const EVADE_DURATION := 1.9
const EVADE_DEFLATE_TIME := 0.3
const EVADE_REINFLATE_TIME := 0.35
const EVADE_JUMP_SPEED := 5.2
const EVADE_GRAVITY_SCALE := 2.2
const EVADE_AIR_DRAG := 1.2
const EVADE_GROUND_FRICTION := 8.5
const EVADE_WALL_RESTITUTION := 0.3
const EVADE_GROUND_RESTITUTION := 0.15

@export_group("Movement & Charge")
@export_range(1.0, 100.0, 1.0) var charge_acceleration: float = 70.0
@export_range(1.0, 100.0, 1.0) var recovery_deceleration: float = 80.0
@export_range(0.0, 12.0, 0.1) var move_speed: float = 5.2
@export_range(1.0, 20.0, 0.5) var preferred_distance: float = 2.6

@export_group("Evasion")
@export_range(0.0, 30.0, 0.5) var evade_speed: float = 18.5
@export_range(0.5, 10.0, 0.1) var evade_cooldown: float = 2.5
## Number of damaging hits that show hurt before the next hit triggers an evade.
@export_range(0, 20, 1) var hits_before_evade: int = 2
@export var evade_drops_barrels: bool = true
@export var super_armor_during_attacks: bool = false

@export_group("Anchor Slam")
@export var anchor_slam_enabled: bool = true
@export_range(1.0, 12.0, 0.1, "suffix:m") var anchor_slam_trigger_range: float = 4.0
@export_range(1.0, 10.0, 0.1, "suffix:m") var anchor_slam_radius: float = 4.2
@export_range(0.0, 5.0, 0.1, "suffix:m") var anchor_slam_forward_offset: float = 1.8
@export_range(0.5, 20.0, 0.5) var anchor_slam_damage: float = 3.5
@export_range(0.5, 20.0, 0.5) var anchor_slam_enraged_damage: float = 5.0
@export_range(0.2, 3.0, 0.05, "suffix:s") var anchor_slam_windup: float = 0.65
@export_range(0.2, 3.0, 0.05, "suffix:s") var anchor_slam_enraged_windup: float = 0.5
@export_range(0.1, 3.0, 0.05, "suffix:s") var anchor_slam_recovery: float = 0.45
@export_range(0.5, 15.0, 0.1, "suffix:s") var anchor_slam_cooldown: float = 3.6

@export_group("Combat Escalation")
@export var smart_skill_selection: bool = true
@export_range(0.0, 1.0, 0.05) var charge_aim_track_fraction: float = 0.65
@export_range(0.0, 12.0, 0.1) var charge_aim_turn_speed: float = 4.5
@export_range(0.0, 10.0, 0.1, "suffix:m") var charge_wall_slam_radius: float = 4.0
@export_range(0.0, 10.0, 0.1, "suffix:m") var spiky_close_burst_radius: float = 4.8
@export_range(0.05, 1.5, 0.01, "suffix:s") var spiky_second_wave_delay: float = 0.28
@export_range(0.0, 1.0, 0.05) var phase2_chain_chance: float = 0.55

var state: State = State.WAIT
var timer: float = 1.0
var skill: BlubberbeardSkillData
var next_skill: int = 0
var charge_direction := Vector3.ZERO
var charge_speed: float = 0.0
var visual: BlubberbeardVisual
var feedback: BlubberbeardFeedback
var charge_hitbox: HitBox
var sound: AudioStreamPlayer3D
var dust: CPUParticles3D
var _evade_steam: CPUParticles3D
var _barrel_hazard: Node3D
var _barrel_released: bool = false
var _barrel_throws_total: int = 0
var _barrel_throws_done: int = 0
var _barrel_step_duration: float = 0.72
var _barrel_step_elapsed: float = 0.0
var _barrel_gap_remaining: float = 0.0
var _barrel_used_spots: Array[Vector3] = []
var _barrel_anchor := Vector3.ZERO
var _evade_remaining: float = 0.0
var _evade_cooldown_left: float = 0.0
var _evade_direction := Vector3.ZERO
var _evade_horizontal_velocity := Vector3.ZERO
var _evade_bounced := false
var _evade_launched := false
var _hits_since_evade := 0
var _hurt_remaining: float = 0.0
var _walk_dust_timer: float = 0.0
var _walk_dust_side: float = 1.0
var _aoe_hitbox: HitBox
var _aoe_shape: SphereShape3D
var _slam_warning: Node3D
var _slam_warning_material: StandardMaterial3D
var _slam_impact_position := Vector3.ZERO
var _anchor_slam_active: bool = false
var _anchor_slam_cooldown_left: float = 0.0
var _pending_second_spike_wave: float = -1.0
var _pending_second_spike_damage: float = 0.0
var _pending_second_spike_speed: float = 0.0
var _pending_second_spike_duration: float = 0.0
var _last_skill_kind: int = -1
var _same_skill_streak: int = 0


func _on_boss_setup() -> void:
	visual = get_node("Sprite3D") as BlubberbeardVisual
	feedback = get_node("Feedback") as BlubberbeardFeedback
	feedback.setup(self, visual)
	charge_hitbox = get_node("ChargeHitBox") as HitBox
	sound = get_node("Sound") as AudioStreamPlayer3D
	charge_hitbox.actor = self
	charge_hitbox.team = CombatTeams.ENEMY
	charge_hitbox.collision_layer = CombatLayers.ENEMY_ATTACK
	charge_hitbox.collision_mask = CombatLayers.PLAYER_HURTBOX
	charge_hitbox.damage_applied.connect(_on_charge_damage)
	damaged.connect(_hit_feedback)
	_create_aoe_hitbox()
	_create_slam_warning()
	_create_dust()
	_create_evade_steam()


func _on_fight_started() -> void:
	feedback.fight_started()


func _on_can_receive_damage(_damage: DamageContext) -> bool:
	return _evade_remaining <= 0.0


func _on_fight_tick(delta: float) -> void:
	fight_tick(delta)


func fight_tick(delta: float) -> void:
	_evade_cooldown_left = maxf(0.0, _evade_cooldown_left - delta)
	_anchor_slam_cooldown_left = maxf(0.0, _anchor_slam_cooldown_left - delta)
	_tick_second_spike_wave(delta)
	if not is_on_floor():
		var gravity_scale := (
			EVADE_GRAVITY_SCALE if _evade_remaining > 0.0 and _evade_launched else 1.0
		)
		velocity += get_gravity() * delta * gravity_scale
	elif _evade_remaining <= 0.0:
		velocity.y = 0.0
	if _evade_remaining > 0.0:
		_update_evade(delta)
		return
	if _hurt_remaining > 0.0:
		_hurt_remaining = maxf(0.0, _hurt_remaining - delta)
		visual.moving = false
		dust.emitting = false
		charge_speed = 0.0
		_set_horizontal_velocity(Vector3.ZERO)
		move_and_slide()
		return
	timer -= delta
	if state == State.CHARGE:
		_update_charge(delta)
		return
	charge_speed = move_toward(charge_speed, 0.0, recovery_deceleration * delta)
	if charge_speed > 0.1 or state == State.WINDUP:
		visual.moving = false
		dust.emitting = false
		_walk_dust_timer = 0.0
		_set_horizontal_velocity(charge_direction * charge_speed)
	else:
		_update_patrol_movement(delta)
	move_and_slide()
	if state == State.WINDUP and _anchor_slam_active:
		_update_anchor_slam_windup()
		return
	if (
		state == State.WINDUP
		and skill != null
		and skill.kind == BlubberbeardSkillData.Kind.POWDER_BARREL
	):
		_update_barrel_barrage(delta)
		return
	if timer > 0.0:
		if state == State.WINDUP and skill != null:
			var progress := 1.0 - clampf(timer / skill.windup, 0.0, 1.0)
			visual.windup_progress = progress
			if skill.kind == BlubberbeardSkillData.Kind.BELLY_CHARGE:
				_steer_charge_windup(delta, progress)
		return
	match state:
		State.WAIT, State.RECOVERY:
			if _should_trigger_anchor_slam():
				_begin_anchor_slam()
			else:
				_choose_skill()
		State.WINDUP:
			_execute_skill()


func _update_evade(delta: float) -> void:
	_evade_remaining = maxf(0.0, _evade_remaining - delta)
	visual.moving = false
	dust.emitting = false
	charge_speed = 0.0
	var elapsed := EVADE_DURATION - _evade_remaining
	var flying := elapsed >= EVADE_DEFLATE_TIME and _evade_remaining > EVADE_REINFLATE_TIME
	if flying and not _evade_launched:
		_evade_launched = true
		velocity.y = EVADE_JUMP_SPEED
		_evade_horizontal_velocity = _evade_direction * evade_speed
	if flying:
		var drag := EVADE_GROUND_FRICTION if is_on_floor() and velocity.y <= 0.0 else EVADE_AIR_DRAG
		_evade_horizontal_velocity *= exp(-drag * delta)
	elif _evade_launched:
		_evade_horizontal_velocity = _evade_horizontal_velocity.move_toward(
			Vector3.ZERO, 20.0 * delta
		)
	else:
		_evade_horizontal_velocity = Vector3.ZERO
	_set_horizontal_velocity(_evade_horizontal_velocity)
	if not flying and _evade_launched:
		_evade_steam.emitting = false
	var vertical_before_move := velocity.y
	move_and_slide()
	if flying and is_on_wall():
		for index in get_slide_collision_count():
			var normal := get_slide_collision(index).get_normal()
			normal.y = 0.0
			if not normal.is_zero_approx() and _evade_horizontal_velocity.dot(normal) < -0.05:
				_evade_horizontal_velocity = (
					_evade_horizontal_velocity.bounce(normal.normalized()) * EVADE_WALL_RESTITUTION
				)
				_evade_direction = _evade_horizontal_velocity.normalized()
				_evade_steam.direction = (-_evade_direction + Vector3.UP * 0.3).normalized()
				break
	if flying and is_on_floor() and not _evade_bounced and vertical_before_move < -0.2:
		_evade_bounced = true
		velocity.y = -vertical_before_move * EVADE_GROUND_RESTITUTION
		_evade_horizontal_velocity *= 0.65
		feedback.spawn_move_dust(global_position, -_evade_direction, true)
		feedback.evade_land()
	if _evade_remaining <= 0.0:
		_set_horizontal_velocity(Vector3.ZERO)
		_evade_steam.emitting = false


func _update_charge(delta: float) -> void:
	charge_speed = move_toward(charge_speed, skill.speed, charge_acceleration * delta)
	_set_horizontal_velocity(charge_direction * charge_speed)
	move_and_slide()
	feedback.charge_tick(delta)
	if timer <= 0.0 or is_on_wall():
		charge_hitbox.end_attack()
		var wall_impact := is_on_wall()
		feedback.charge_end(wall_impact)
		visual.impact(0.2, 0.24)
		if wall_impact:
			charge_speed = 0.0
			if charge_wall_slam_radius > 0.0 and skill != null:
				_trigger_aoe_hit(
					global_position, charge_wall_slam_radius, skill.damage * 0.6, &"boss_wall_slam"
				)
		_enter_recovery()


func _update_patrol_movement(delta: float) -> void:
	if not is_instance_valid(target):
		visual.moving = false
		dust.emitting = false
		_walk_dust_timer = 0.0
		_set_horizontal_velocity(Vector3.ZERO)
		return
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance <= preferred_distance or move_speed <= 0.0:
		visual.moving = false
		dust.emitting = false
		_walk_dust_timer = 0.0
		_set_horizontal_velocity(Vector3.ZERO)
		return
	var step_dir := to_target.normalized()
	visual.face_direction(step_dir)
	visual.moving = true
	if dust.amount != 19:
		dust.amount = 19
	dust.emitting = true
	_set_horizontal_velocity(step_dir * move_speed)
	_walk_dust_timer -= maxf(0.0, delta)
	if _walk_dust_timer <= 0.0:
		_walk_dust_timer = 0.22
		var side_offset := step_dir.cross(Vector3.UP).normalized() * 1.45 * _walk_dust_side
		_walk_dust_side = -_walk_dust_side
		if is_instance_valid(feedback):
			feedback.spawn_move_dust(
				global_position + side_offset - step_dir * 0.4, step_dir, false
			)


func _set_horizontal_velocity(horizontal: Vector3) -> void:
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _choose_skill() -> void:
	var phase := boss_data.phases[phase_index]
	if phase.skills.is_empty():
		timer = 1.0
		return
	skill = phase.skills[next_skill % phase.skills.size()] as BlubberbeardSkillData
	if skill == null:
		next_skill += 1
		push_warning("Captain Blubberbeard requires BlubberbeardSkillData")
		timer = 1.0
		return
	if skill.kind == _last_skill_kind:
		_same_skill_streak += 1
	else:
		_last_skill_kind = skill.kind
		_same_skill_streak = 1
	if smart_skill_selection:
		next_skill = _pick_next_skill_index(phase)
	else:
		next_skill += 1
	_anchor_slam_active = false
	_hide_slam_warning()
	state = State.WINDUP
	timer = skill.windup
	visual.moving = false
	_barrel_hazard = null
	_barrel_released = false
	charge_direction = target.global_position - global_position
	charge_direction.y = 0.0
	charge_direction = charge_direction.normalized()
	if charge_direction.is_zero_approx():
		charge_direction = Vector3.FORWARD
	if skill.kind == BlubberbeardSkillData.Kind.POWDER_BARREL:
		_begin_barrel_barrage()
		return
	visual.face_direction(charge_direction)
	visual.begin_windup(skill.kind)
	_play_sound(1.2)


func roll_barrel_throw_count() -> int:
	if skill == null:
		return 3
	if not skill.randomize_barrel_throws:
		return maxi(1, skill.barrel_throw_count)
	var lo := maxi(1, mini(skill.barrel_throw_min, skill.barrel_throw_max))
	var hi := maxi(lo, maxi(skill.barrel_throw_min, skill.barrel_throw_max))
	return randi_range(lo, hi)


func _begin_barrel_barrage() -> void:
	_barrel_throws_total = roll_barrel_throw_count()
	_barrel_throws_done = 0
	_barrel_used_spots.clear()
	_barrel_gap_remaining = 0.0
	_barrel_anchor = target.global_position
	_start_next_barrel_throw()


func _start_next_barrel_throw() -> void:
	if not is_instance_valid(target):
		_enter_recovery()
		return
	var landing := _pick_barrel_landing_spot()
	_barrel_used_spots.append(landing)
	var to_spot := landing - global_position
	to_spot.y = 0.0
	if not to_spot.is_zero_approx():
		charge_direction = to_spot.normalized()
	visual.face_direction(charge_direction)
	_barrel_released = false
	_barrel_step_elapsed = 0.0
	_barrel_step_duration = maxf(0.25, skill.barrel_throw_duration)
	visual.begin_windup(BlubberbeardSkillData.Kind.POWDER_BARREL)
	_play_sound(1.2)
	_spawn_barrel(landing, true)


func _pick_barrel_landing_spot() -> Vector3:
	if _barrel_throws_done == 0:
		return target.global_position
	var lead_offset := Vector3.ZERO
	if target is CharacterBody3D:
		var vel := (target as CharacterBody3D).velocity
		vel.y = 0.0
		lead_offset = (vel * 0.42).limit_length(4.5)
	var anchor := _barrel_anchor.lerp(target.global_position + lead_offset, 0.65)
	var r_min := maxf(0.5, skill.barrel_spread_min_radius)
	var r_max := maxf(r_min + 0.2, skill.barrel_spread_max_radius)
	var best := anchor + Vector3(r_min, 0.0, 0.0)
	var best_clearance := -1.0
	for _attempt in 10:
		var angle := randf() * TAU
		var radius := randf_range(r_min, r_max)
		var candidate := anchor + Vector3(cos(angle), 0.0, sin(angle)) * radius
		var clearance := INF
		for prev in _barrel_used_spots:
			var flat_delta := Vector2(candidate.x - prev.x, candidate.z - prev.z)
			clearance = minf(clearance, flat_delta.length())
		if clearance > best_clearance:
			best_clearance = clearance
			best = candidate
		if clearance >= 2.0:
			return candidate
	return best


func _update_barrel_barrage(delta: float) -> void:
	var step := maxf(0.0, delta)
	if _barrel_gap_remaining > 0.0:
		_barrel_gap_remaining = maxf(0.0, _barrel_gap_remaining - step)
		if _barrel_gap_remaining <= 0.0:
			_start_next_barrel_throw()
		return
	_barrel_step_elapsed += step
	visual.windup_progress = clampf(
		_barrel_step_elapsed / maxf(0.05, _barrel_step_duration), 0.0, 1.0
	)
	if not _barrel_released and visual.windup_progress >= visual.THROW_RELEASE_PROGRESS:
		_release_pending_barrel()
	if _barrel_step_elapsed >= _barrel_step_duration:
		_barrel_throws_done += 1
		if _barrel_throws_done < _barrel_throws_total:
			var g_min := minf(skill.barrel_throw_gap_min, skill.barrel_throw_gap_max)
			var g_max := maxf(skill.barrel_throw_gap_min, skill.barrel_throw_gap_max)
			_barrel_gap_remaining = randf_range(g_min, g_max)
			visual.begin_recovery(BlubberbeardSkillData.Kind.POWDER_BARREL)
			if _barrel_gap_remaining <= 0.0:
				_start_next_barrel_throw()
		else:
			_enter_recovery()


func _execute_skill() -> void:
	match skill.kind:
		BlubberbeardSkillData.Kind.BELLY_CHARGE:
			state = State.CHARGE
			timer = skill.duration
			charge_hitbox.begin_attack(skill.damage, 0, &"boss_charge")
			visual.begin_charge(charge_direction)
			visual.impact(0.15, 0.15)
			if dust.amount != 48:
				dust.amount = 48
			dust.emitting = true
			feedback.charge_start()
			_play_sound(0.7)
		BlubberbeardSkillData.Kind.SPIKY_INFLATION:
			feedback.spikes_release()
			visual.impact(0.22, 0.25)
			EFFECTS.shockwave(get_parent(), global_position, 2.0, Color(1.0, 0.55, 0.12, 0.8))
			if spiky_close_burst_radius > 0.0:
				_trigger_aoe_hit(
					global_position, spiky_close_burst_radius, skill.damage, &"boss_spike_burst"
				)
			for index in 8:
				_spawn_spike(Vector3(cos(TAU * index / 8.0), 0.0, sin(TAU * index / 8.0)))
			if phase_index > 0:
				_pending_second_spike_wave = spiky_second_wave_delay
				_pending_second_spike_damage = skill.damage
				_pending_second_spike_speed = skill.speed
				_pending_second_spike_duration = skill.duration
			_play_sound(1.6)
			_enter_recovery()
		BlubberbeardSkillData.Kind.ANCHOR_SLAM:
			_execute_anchor_slam()
		_:
			_enter_recovery()


func _spawn_barrel(where: Vector3, hold_until_release: bool = false) -> void:
	var hazard := HAZARD.new()
	hazard.source = self
	hazard.damage = skill.damage
	hazard.radius = skill.radius
	hazard.remaining = skill.windup
	hazard.detonated.connect(_on_barrel_detonated.bind(hazard, skill.radius))
	get_parent().add_child(hazard)
	hazard.global_position = Vector3(where.x, global_position.y + 0.08, where.z)
	if hold_until_release:
		hazard.hold_barrel_for_throw()
		_barrel_hazard = hazard
	else:
		hazard.animate_barrel(global_position)


func _release_pending_barrel() -> void:
	_barrel_released = true
	if is_instance_valid(_barrel_hazard) and _barrel_hazard.has_method("release_barrel_from"):
		_barrel_hazard.release_barrel_from(visual.get_barrel_release_world_position())
		visual.impact(0.12, 0.14)
		_play_sound(1.35)


func _spawn_spike(spike_dir: Vector3) -> void:
	var hazard := HAZARD.new()
	hazard.source = self
	hazard.spike = true
	hazard.direction = spike_dir
	hazard.damage = skill.damage
	hazard.speed = skill.speed
	hazard.remaining = skill.duration
	get_parent().add_child(hazard)
	hazard.global_position = global_position + Vector3.UP * 1.2 + spike_dir * 2.5


func _enter_recovery() -> void:
	state = State.RECOVERY
	var was_slam := _anchor_slam_active
	_anchor_slam_active = false
	_hide_slam_warning()
	var recovery_time := anchor_slam_recovery if was_slam else skill.recovery
	var wait_time := recovery_time + boss_data.phases[phase_index].skill_interval
	var chain_ready := (
		was_slam or (skill != null and skill.kind == BlubberbeardSkillData.Kind.BELLY_CHARGE)
	)
	if phase_index > 0 and chain_ready and randf() < phase2_chain_chance:
		wait_time = 0.25
	timer = wait_time
	dust.emitting = false
	var recovery_kind := BlubberbeardSkillData.Kind.ANCHOR_SLAM if was_slam else skill.kind
	visual.begin_recovery(recovery_kind)


func _on_phase_entered(index: int) -> void:
	visual.set_enraged(index > 0)
	feedback.phase_changed()
	visual.impact(0.32, 0.45)
	EFFECTS.shockwave(get_parent(), global_position, 3.0, Color(0.9, 0.2, 0.4, 0.8))
	_play_sound(0.55)


func _on_fight_ended() -> void:
	charge_hitbox.end_attack()
	if is_instance_valid(_aoe_hitbox):
		_aoe_hitbox.end_attack()
	_anchor_slam_active = false
	_pending_second_spike_wave = -1.0
	_hide_slam_warning()
	dust.emitting = false
	_evade_steam.emitting = false
	feedback.death()
	EFFECTS.shockwave(get_parent(), global_position, 3.0, Color(1.0, 0.65, 0.2, 0.8))
	_play_sound(0.4)
	visual.play_death(queue_free)


func _has_super_armor() -> bool:
	if not super_armor_during_attacks:
		return false
	return state == State.WINDUP or state == State.CHARGE


func _hit_feedback(_amount: float) -> void:
	if dead:
		return
	visual.flash_hit()
	var armored := _has_super_armor()
	if _hits_since_evade < hits_before_evade:
		_hits_since_evade += 1
		if not armored and (state == State.WAIT or state == State.RECOVERY):
			_hurt_remaining = visual.HURT_DURATION
		return
	if armored:
		return
	if _evade_cooldown_left <= 0.0 and is_instance_valid(target):
		_begin_evade()
	elif state == State.WAIT or state == State.RECOVERY:
		_hurt_remaining = visual.HURT_DURATION


func _begin_evade() -> void:
	var away := global_position - target.global_position
	away.y = 0.0
	if away.is_zero_approx():
		away = Vector3.BACK
	away = away.normalized()
	# Find space to start; the character body still collides with arena boundaries.
	for angle in [0.55, -0.55, 1.2, -1.2, 0.0]:
		var candidate := away.rotated(Vector3.UP, angle)
		if not test_move(global_transform, candidate * 1.5):
			_hits_since_evade = 0
			_hurt_remaining = 0.0
			_anchor_slam_active = false
			_hide_slam_warning()
			if state == State.WINDUP and is_instance_valid(_barrel_hazard) and not _barrel_released:
				_barrel_hazard.queue_free()
				_barrel_hazard = null
			charge_hitbox.end_attack()
			if evade_drops_barrels and fighting and is_instance_valid(get_parent()):
				_spawn_evade_barrel(global_position)
			if skill != null:
				visual.begin_recovery(skill.kind)
			state = State.RECOVERY
			timer = 0.35
			_evade_direction = candidate
			_evade_remaining = EVADE_DURATION
			_evade_cooldown_left = evade_cooldown
			_evade_bounced = false
			_evade_launched = false
			_evade_horizontal_velocity = Vector3.ZERO
			visual.begin_deflate_evade(EVADE_DURATION)
			_evade_steam.direction = (-candidate + Vector3.UP * 0.3).normalized()
			_evade_steam.restart()
			_evade_steam.emitting = true
			feedback.spawn_move_dust(global_position, -candidate, true)
			return


func _create_evade_steam() -> void:
	_evade_steam = CPUParticles3D.new()
	_evade_steam.name = "DeflateSteam"
	_evade_steam.emitting = false
	_evade_steam.amount = 24
	_evade_steam.lifetime = 0.5
	_evade_steam.local_coords = false
	_evade_steam.spread = 30.0
	_evade_steam.initial_velocity_min = 1.2
	_evade_steam.initial_velocity_max = 2.8
	_evade_steam.gravity = Vector3(0, 0.7, 0)
	_evade_steam.scale_amount_min = 0.45
	_evade_steam.scale_amount_max = 0.85
	var colors := Gradient.new()
	colors.set_color(0, Color(0.9, 0.98, 1.0, 0.7))
	colors.set_color(1, Color(0.9, 0.98, 1.0, 0.0))
	_evade_steam.color_ramp = colors
	var mesh := SphereMesh.new()
	mesh.radius = 0.28
	mesh.height = 0.56
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	_evade_steam.mesh = mesh
	add_child(_evade_steam)
	_evade_steam.position.y = 3.5


func _on_barrel_detonated(hazard: Node3D, radius: float) -> void:
	if is_instance_valid(hazard) and not dead:
		feedback.barrel_explosion(hazard.global_position, radius)


func _on_charge_damage(_damage: DamageContext, hit_target: Node, _amount: float) -> void:
	feedback.charge_hit(hit_target)


func _on_aoe_damage(_damage: DamageContext, hit_target: Node, _amount: float) -> void:
	feedback.aoe_hit(hit_target)


func _play_sound(pitch: float) -> void:
	if is_instance_valid(sound):
		sound.pitch_scale = pitch
		sound.play()


func _create_dust() -> void:
	dust = CPUParticles3D.new()
	dust.name = "ChargeDust"
	dust.emitting = false
	dust.amount = 48
	dust.lifetime = 0.5
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(1.8, 0.18, 1.8)
	dust.local_coords = false
	dust.direction = Vector3.UP
	dust.spread = 75.0
	dust.initial_velocity_min = 0.8
	dust.initial_velocity_max = 3.2
	dust.gravity = Vector3(0, -1.6, 0)
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 1.75
	dust.color = Color(1.0, 0.96, 0.88, 0.92)
	dust.anim_speed_min = 1.0
	dust.anim_speed_max = 1.2
	dust.sorting_offset = 1.0
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.75, 1.75)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.render_priority = 1
	material.albedo_texture = MOVE_DUST_SHEET
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.particles_anim_h_frames = 4
	material.particles_anim_v_frames = 1
	material.particles_anim_loop = false
	mesh.material = material
	dust.mesh = mesh
	add_child(dust)
	dust.position.y = 0.75


func _should_trigger_anchor_slam() -> bool:
	if not anchor_slam_enabled or _anchor_slam_cooldown_left > 0.0:
		return false
	if not is_instance_valid(target):
		return false
	var delta := target.global_position - global_position
	delta.y = 0.0
	return delta.length() <= anchor_slam_trigger_range


func _begin_anchor_slam() -> void:
	_anchor_slam_active = true
	state = State.WINDUP
	timer = _current_slam_windup()
	visual.moving = false
	var dir := charge_direction if not charge_direction.is_zero_approx() else Vector3.BACK
	if is_instance_valid(target):
		var delta := target.global_position - global_position
		delta.y = 0.0
		if not delta.is_zero_approx():
			dir = delta.normalized()
	charge_direction = dir
	visual.face_direction(charge_direction)
	visual.begin_windup(BlubberbeardSkillData.Kind.ANCHOR_SLAM)
	_slam_impact_position = global_position + charge_direction * anchor_slam_forward_offset
	_slam_impact_position.y = global_position.y + 0.05
	if is_instance_valid(_slam_warning):
		_slam_warning.global_position = _slam_impact_position
		_slam_warning.visible = true
	_play_sound(0.95)


func _update_anchor_slam_windup() -> void:
	var windup := maxf(0.05, _current_slam_windup())
	var progress := 1.0 - clampf(timer / windup, 0.0, 1.0)
	visual.windup_progress = progress
	if is_instance_valid(_slam_warning_material):
		_slam_warning_material.albedo_color.a = 0.16 + progress * 0.32
	if timer <= 0.0:
		_execute_anchor_slam()


func _execute_anchor_slam() -> void:
	_hide_slam_warning()
	_anchor_slam_cooldown_left = anchor_slam_cooldown
	var dmg := anchor_slam_enraged_damage if phase_index > 0 else anchor_slam_damage
	_trigger_aoe_hit(_slam_impact_position, anchor_slam_radius, dmg, &"boss_anchor_slam")
	visual.impact(0.3, 0.3)
	if is_instance_valid(feedback):
		feedback.anchor_slam(_slam_impact_position, anchor_slam_radius)
	_enter_recovery()


func _current_slam_windup() -> float:
	return anchor_slam_enraged_windup if phase_index > 0 else anchor_slam_windup


func _steer_charge_windup(delta: float, progress: float) -> void:
	if progress >= charge_aim_track_fraction or not is_instance_valid(target):
		return
	var desired := target.global_position - global_position
	desired.y = 0.0
	if desired.is_zero_approx():
		return
	desired = desired.normalized()
	var angle_diff := charge_direction.signed_angle_to(desired, Vector3.UP)
	var max_step := charge_aim_turn_speed * maxf(0.0, delta)
	var step := clampf(angle_diff, -max_step, max_step)
	charge_direction = charge_direction.rotated(Vector3.UP, step)
	visual.face_direction(charge_direction)


func _pick_next_skill_index(phase: BossPhaseData) -> int:
	if phase.skills.size() <= 1 or not is_instance_valid(target):
		return next_skill + 1
	var flat := target.global_position - global_position
	flat.y = 0.0
	var dist := flat.length()
	var weights: Array[float] = []
	var total := 0.0
	for index in phase.skills.size():
		var candidate := phase.skills[index] as BlubberbeardSkillData
		var weight := 1.0
		if candidate != null:
			weight = _score_skill_weight(candidate.kind, dist)
			if candidate.kind == _last_skill_kind:
				weight *= 0.0 if _same_skill_streak >= 2 else 0.3
		weights.append(weight)
		total += weight
	if total <= 0.0:
		return (next_skill + 1) % phase.skills.size()
	var roll := randf() * total
	var accum := 0.0
	for index in weights.size():
		accum += weights[index]
		if roll <= accum:
			return index
	return phase.skills.size() - 1


func _score_skill_weight(kind: int, dist: float) -> float:
	match kind:
		BlubberbeardSkillData.Kind.POWDER_BARREL:
			if dist >= 9.0:
				return 3.0
			return 1.2 if dist >= 5.0 else 0.45
		BlubberbeardSkillData.Kind.BELLY_CHARGE:
			if dist >= 4.5 and dist <= 11.5:
				return 3.0
			return 1.5 if dist > 11.5 else 0.8
		BlubberbeardSkillData.Kind.SPIKY_INFLATION:
			return 3.2 if dist <= 7.0 else 0.5
		BlubberbeardSkillData.Kind.ANCHOR_SLAM:
			return 3.2 if dist <= anchor_slam_trigger_range + 1.0 else 0.25
		_:
			return 1.0


func _tick_second_spike_wave(delta: float) -> void:
	if _pending_second_spike_wave < 0.0:
		return
	_pending_second_spike_wave -= maxf(0.0, delta)
	if _pending_second_spike_wave > 0.0:
		return
	_pending_second_spike_wave = -1.0
	if dead or not is_instance_valid(get_parent()):
		return
	for index in 8:
		var angle := TAU * (float(index) + 0.5) / 8.0
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var hazard := HAZARD.new()
		hazard.source = self
		hazard.spike = true
		hazard.direction = dir
		hazard.damage = _pending_second_spike_damage
		hazard.speed = _pending_second_spike_speed
		hazard.remaining = _pending_second_spike_duration
		get_parent().add_child(hazard)
		hazard.global_position = global_position + Vector3.UP * 1.2 + dir * 2.5
	_play_sound(1.85)


func _spawn_evade_barrel(at: Vector3) -> void:
	var hazard := HAZARD.new()
	hazard.source = self
	hazard.damage = 4.5 if phase_index > 0 else 3.0
	hazard.radius = 2.6
	hazard.remaining = 0.95
	hazard.detonated.connect(_on_barrel_detonated.bind(hazard, hazard.radius))
	get_parent().add_child(hazard)
	hazard.global_position = Vector3(at.x, global_position.y + 0.08, at.z)
	hazard.animate_barrel(global_position + Vector3.UP * 0.6)


func _trigger_aoe_hit(at: Vector3, radius: float, amount: float, tag: StringName) -> void:
	if not is_instance_valid(_aoe_hitbox) or _aoe_shape == null or amount <= 0.0:
		return
	_aoe_hitbox.global_position = at
	_aoe_shape.radius = maxf(0.1, radius)
	_aoe_hitbox.begin_attack(amount, 0, tag)
	_aoe_hitbox.sample_shape()
	_aoe_hitbox.end_attack()


func _create_aoe_hitbox() -> void:
	_aoe_hitbox = HitBox.new()
	_aoe_hitbox.name = "AoeHitBox"
	_aoe_hitbox.top_level = true
	_aoe_hitbox.actor = self
	_aoe_hitbox.team = CombatTeams.ENEMY
	_aoe_hitbox.collision_layer = CombatLayers.ENEMY_ATTACK
	_aoe_hitbox.collision_mask = CombatLayers.PLAYER_HURTBOX
	_aoe_hitbox.damage_applied.connect(_on_aoe_damage)
	var collider := CollisionShape3D.new()
	_aoe_shape = SphereShape3D.new()
	_aoe_shape.radius = anchor_slam_radius
	collider.shape = _aoe_shape
	_aoe_hitbox.add_child(collider)
	add_child(_aoe_hitbox)


func _create_slam_warning() -> void:
	_slam_warning = Node3D.new()
	_slam_warning.name = "AnchorSlamWarning"
	_slam_warning.top_level = true
	_slam_warning.visible = false
	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = anchor_slam_radius
	disc_mesh.bottom_radius = anchor_slam_radius
	disc_mesh.height = 0.02
	disc.mesh = disc_mesh
	_slam_warning_material = StandardMaterial3D.new()
	_slam_warning_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_slam_warning_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_slam_warning_material.albedo_color = Color(1.0, 0.2, 0.04, 0.16)
	disc.material_override = _slam_warning_material
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_slam_warning.add_child(disc)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = maxf(0.05, anchor_slam_radius - 0.12)
	ring_mesh.outer_radius = anchor_slam_radius
	ring.mesh = ring_mesh
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(1.0, 0.28, 0.05)
	ring.material_override = ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = 0.02
	_slam_warning.add_child(ring)
	add_child(_slam_warning)


func _hide_slam_warning() -> void:
	if is_instance_valid(_slam_warning):
		_slam_warning.visible = false
