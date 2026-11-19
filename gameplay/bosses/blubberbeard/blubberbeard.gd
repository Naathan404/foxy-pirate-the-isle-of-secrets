class_name BlubberbeardBoss
extends BossBase
## Điều khiển hành vi chiến đấu, bộ kỹ năng và AI động của Captain Blubberbeard.

enum State {
	WAIT,
	WINDUP,
	SKYDIVE_LEAP,
	SPIKY_HOLD,
	WHIRLWIND,
	COUNTER_SHOCK,
	STAGGERED,
	RECOVERY,
}

const AI_CLASS = preload("res://gameplay/bosses/blubberbeard/blubberbeard_ai.gd")
const SKYDIVE_CTRL = preload("res://gameplay/bosses/blubberbeard/blubberbeard_skydive.gd")
const SIZE_RIG = preload("res://gameplay/bosses/blubberbeard/blubberbeard_size_rig.gd")
const HAZARD = preload("res://gameplay/bosses/blubberbeard/boss_hazard.gd")
const VENOM_HAZARD = preload("res://gameplay/bosses/blubberbeard/blubberbeard_venom_hazard.gd")
const WHIRLWIND_RIG = preload("res://gameplay/bosses/blubberbeard/anchor_whirlwind_rig.gd")
const EFFECTS = preload("res://gameplay/bosses/boss_effects.gd")

const BARREL_BURST_SPREAD_SEPARATION := 2.2
const COUNTER_SHOCK_DURATION := 0.22
const COUNTER_SHOCK_RECOIL_SPEED := 4.2
const COUNTER_PUFF_WINDUP := 0.36
const SPIKY_THORN_BODY_RADIUS := 2.15

@export_group("Movement & AI")
@export_range(0.5, 2.0, 0.05) var boss_size_scale: float = 1.0:
	set(value):
		boss_size_scale = clampf(value, 0.5, 2.0)
		if is_instance_valid(_size_rig):
			_size_rig.apply_base_scale(boss_size_scale)
@export_range(1.0, 100.0, 1.0) var recovery_deceleration: float = 80.0
@export_range(0.0, 12.0, 0.1, "suffix:m/s") var move_speed: float = 4.6
@export_range(1.0, 20.0, 0.5, "suffix:m") var preferred_distance: float = 2.8
@export_range(3.0, 20.0, 0.5, "suffix:m") var circle_outer_distance: float = 7.4
@export_range(0.0, 0.5, 0.02) var wait_jitter: float = 0.22
@export var smart_skill_selection: bool = true
@export_range(0.0, 1.0, 0.05) var phase2_chain_chance: float = 0.22
@export_range(2.0, 8.0, 0.1, "suffix:m") var ai_close_range: float = 4.5
@export_range(5.0, 15.0, 0.5, "suffix:m") var ai_mid_range: float = 9.5
@export_range(1.0, 8.0, 0.2, "suffix:m") var ai_boundary_margin: float = 3.6

@export_group("Spiky Counter & Armor")
@export var super_armor_during_attacks: bool = true
## Số hit trúng ở trạng thái hở đòn trước khi đòn tiếp theo kích hoạt Phình Gai phản công.
@export_range(0, 20, 1) var hits_before_counter: int = 5
@export_range(0.5, 15.0, 0.1, "suffix:s") var counter_cooldown: float = 6.5
@export_range(0.0, 10.0, 0.1, "suffix:m") var spiky_close_burst_radius: float = 3.1
@export_range(0.3, 3.0, 0.05, "suffix:s") var spiky_hold_duration: float = 1.25

@export_group("Anchor Slam")
@export var anchor_slam_enabled: bool = true
@export_range(1.0, 12.0, 0.1, "suffix:m") var anchor_slam_trigger_range: float = 2.8
@export_range(1.0, 10.0, 0.1, "suffix:m") var anchor_slam_radius: float = 2.6
@export_range(0.0, 5.0, 0.1, "suffix:m") var anchor_slam_forward_offset: float = 1.25
@export_range(0.5, 20.0, 0.5) var anchor_slam_damage: float = 2.5
@export_range(0.5, 20.0, 0.5) var anchor_slam_enraged_damage: float = 3.5
@export_range(0.2, 3.0, 0.05, "suffix:s") var anchor_slam_windup: float = 0.65
@export_range(0.2, 3.0, 0.05, "suffix:s") var anchor_slam_enraged_windup: float = 0.52
@export_range(0.1, 3.0, 0.05, "suffix:s") var anchor_slam_recovery: float = 0.55
@export_range(0.5, 15.0, 0.1, "suffix:s") var anchor_slam_cooldown: float = 7.5

var state: State = State.WAIT
var timer: float = 0.85
var skill: BlubberbeardSkillData
var next_skill: int = 0
var forced_skill_index: int = -1
var aim_direction: Vector3 = Vector3.BACK
var visual: BlubberbeardVisual
var feedback: BlubberbeardFeedback
var charge_hitbox: HitBox
var sound: AudioStreamPlayer3D
var dust: CPUParticles3D

var _ai: BlubberbeardAI
var _skydive: BlubberbeardSkydiveController
var _whirlwind_rig: BlubberbeardWhirlwindRig
var _barrel_pending_hazards: Array[Node3D] = []
var _barrel_wave_queue: Array[int] = []
var _barrel_wave_index: int = 0
var _barrel_released: bool = false
var _barrel_step_duration: float = 0.56
var _barrel_step_elapsed: float = 0.0
var _barrel_gap_remaining: float = 0.0
var _barrel_used_spots: Array[Vector3] = []
var _hits_since_counter: int = 0
var _counter_cooldown_left: float = 0.0
var _counter_shock_velocity: Vector3 = Vector3.ZERO
var _pending_counter_burst: bool = false
var _hurt_remaining: float = 0.0
var _hurt_flinch_cooldown_left: float = 0.0
var _walk_dust_timer: float = 0.0
var _walk_dust_side: float = 1.0
var _strafe_sign: float = 1.0
var _strafe_flip_timer: float = 1.4
var _aoe_hitbox: HitBox
var _aoe_shape: SphereShape3D
var _slam_impact_position: Vector3 = Vector3.ZERO
var _anchor_slam_active: bool = false
var _anchor_slam_cooldown_left: float = 0.0
var _ground_y: float = 0.0
var _size_rig: BlubberbeardSizeRig


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
	charge_hitbox.damage_applied.connect(_on_attack_damage_applied)
	damaged.connect(_hit_feedback)
	_ground_y = global_position.y
	_ai = AI_CLASS.new()
	_ai.close_range_meters = ai_close_range
	_ai.mid_range_meters = ai_mid_range
	_skydive = SKYDIVE_CTRL.new()
	_skydive.name = "SkydiveController"
	add_child(_skydive)
	_skydive.setup(self, visual)
	_create_aoe_hitbox()
	feedback.create_slam_warning(anchor_slam_radius)
	_create_whirlwind_rig()
	dust = feedback.create_dust_emitter()
	_size_rig = SIZE_RIG.new()
	_size_rig.setup(self, visual)
	_size_rig.apply_base_scale(boss_size_scale)


func _on_fight_started() -> void:
	_ground_y = global_position.y
	_ai.reset()
	feedback.fight_started()


func _on_can_receive_damage(_damage: DamageContext) -> bool:
	return not (state == State.SKYDIVE_LEAP and _skydive.is_high_airborne)


func _on_fight_tick(delta: float) -> void:
	fight_tick(delta)


func fight_tick(delta: float) -> void:
	var step := maxf(0.0, delta)
	update_stagger(step)
	_ai.tick(step)
	_hurt_flinch_cooldown_left = maxf(0.0, _hurt_flinch_cooldown_left - step)
	_counter_cooldown_left = maxf(0.0, _counter_cooldown_left - step)
	_anchor_slam_cooldown_left = maxf(0.0, _anchor_slam_cooldown_left - step)
	_apply_gravity_to_floor(step)
	if state == State.STAGGERED:
		_update_staggered(step)
		return
	if state == State.COUNTER_SHOCK:
		_update_counter_shock(step)
		return
	if _hurt_remaining > 0.0:
		_hurt_remaining = maxf(0.0, _hurt_remaining - step)
		_halt_locomotion()
		move_and_slide()
		return
	timer -= step
	match state:
		State.SKYDIVE_LEAP:
			_update_skydive_leap(step)
			return
		State.SPIKY_HOLD:
			_update_spiky_hold()
			return
		State.WHIRLWIND:
			_update_whirlwind_spin(step)
			return
	if state == State.WINDUP:
		_halt_locomotion()
		move_and_slide()
		if _anchor_slam_active:
			_update_anchor_slam_windup()
		elif skill != null and skill.kind == BlubberbeardSkillData.Kind.POWDER_BARREL:
			_update_barrel_barrage(step)
		else:
			_update_standard_windup()
		return
	if timer > 0.0:
		if state == State.WAIT:
			_update_patrol_movement(step)
		else:
			_halt_locomotion()
		move_and_slide()
		if state == State.WAIT and is_on_wall():
			_strafe_sign = -_strafe_sign
		return
	if state == State.RECOVERY:
		_enter_wait()
		return
	_choose_next_action()


func current_phase() -> BossPhaseData:
	if boss_data == null or boss_data.phases.is_empty():
		return null
	return boss_data.phases[mini(phase_index, boss_data.phases.size() - 1)]


func get_debug_combat_summary() -> String:
	var armor := "ON" if _has_super_armor() else "OFF"
	return (
		"%s | Armor: %s | Counter: %d/%d"
		% [State.keys()[state], armor, _hits_since_counter, hits_before_counter]
	)


func roll_barrel_throw_count() -> int:
	if skill == null:
		return 1
	if not skill.randomize_barrel_throws:
		return clampi(skill.barrel_throw_count, 1, 8)
	var low := mini(skill.barrel_throw_min, skill.barrel_throw_max)
	var high := maxi(skill.barrel_throw_min, skill.barrel_throw_max)
	return randi_range(clampi(low, 1, 8), clampi(high, 1, 8))


func _choose_next_action() -> void:
	if _should_trigger_anchor_slam():
		_begin_anchor_slam()
		return
	_choose_skill()


func _choose_skill() -> void:
	_hurt_remaining = 0.0
	var phase := current_phase()
	if phase == null or phase.skills.is_empty() or not is_instance_valid(target):
		state = State.WAIT
		timer = 0.25
		return
	var chosen_idx := _pick_skill_slot(phase)
	next_skill = (chosen_idx + 1) % phase.skills.size()
	skill = phase.skills[chosen_idx] as BlubberbeardSkillData
	if skill == null:
		state = State.WAIT
		timer = 0.25
		return
	_ai.mark_used(skill.kind)
	_anchor_slam_active = false
	_pending_counter_burst = false
	feedback.hide_slam_warning()
	state = State.WINDUP
	timer = skill.windup
	aim_direction = _flat_direction_to(target.global_position)
	visual.face_direction(aim_direction)
	visual.begin_windup(skill.kind)
	match skill.kind:
		BlubberbeardSkillData.Kind.POWDER_BARREL:
			_begin_barrel_barrage()
		BlubberbeardSkillData.Kind.SKY_DIVE:
			_skydive.begin_windup(_ground_y)
			_play_sound(1.0)
		BlubberbeardSkillData.Kind.SPIKY_INFLATION:
			_show_aoe_warning(
				global_position, _current_spike_burst_radius(), Color(1.0, 0.25, 0.08)
			)
			_play_sound(1.1)
		BlubberbeardSkillData.Kind.ANCHOR_SLAM:
			_begin_anchor_slam()
		BlubberbeardSkillData.Kind.ANCHOR_WHIRLWIND:
			var reach := maxf(2.0, skill.whirlwind_reach_radius * _current_damage_size_scale())
			_whirlwind_rig.begin_windup(
				reach, atan2(aim_direction.z, aim_direction.x), phase_index > 0
			)
			feedback.emit_skill_cue(&"whirlwind_windup", global_position)
		BlubberbeardSkillData.Kind.VENOM_SPIT:
			_play_sound(1.25)


func _pick_skill_slot(phase: BossPhaseData) -> int:
	if forced_skill_index >= 0 and forced_skill_index < phase.skills.size():
		var idx := forced_skill_index
		forced_skill_index = -1
		return idx
	if not smart_skill_selection:
		return next_skill % phase.skills.size()
	_ai.close_range_meters = ai_close_range
	_ai.mid_range_meters = ai_mid_range
	var near_boundary := (
		_is_position_near_boundary(target.global_position, ai_boundary_margin)
		if is_instance_valid(target)
		else false
	)
	return _ai.select_skill_index(
		phase, phase_index, _flat_distance_to_target(), next_skill, near_boundary
	)


func _execute_skill() -> void:
	_hurt_remaining = 0.0
	if skill == null:
		_enter_recovery()
		return
	match skill.kind:
		BlubberbeardSkillData.Kind.SKY_DIVE:
			_enter_skydive_leap()
		BlubberbeardSkillData.Kind.SPIKY_INFLATION:
			_execute_spiky_burst()
		BlubberbeardSkillData.Kind.ANCHOR_WHIRLWIND:
			_enter_whirlwind_spin()
		BlubberbeardSkillData.Kind.VENOM_SPIT:
			_execute_venom_spit()
		_:
			_enter_recovery()


func _begin_barrel_barrage() -> void:
	_clear_pending_barrels()
	_barrel_used_spots.clear()
	_barrel_gap_remaining = 0.0
	_barrel_wave_index = 0
	_barrel_wave_queue = _build_barrel_wave_queue()
	_start_next_barrel_wave()


func _build_barrel_wave_queue() -> Array[int]:
	if skill != null and skill.barrel_escalating_burst:
		var fmin := clampi(mini(skill.barrel_final_burst_min, skill.barrel_final_burst_max), 1, 8)
		var fmax := clampi(maxi(skill.barrel_final_burst_min, skill.barrel_final_burst_max), 1, 8)
		return [1, 2, randi_range(fmin, fmax)]
	var count := roll_barrel_throw_count()
	var queue: Array[int] = []
	for _i in count:
		queue.append(1)
	return queue


func _start_next_barrel_wave() -> void:
	if not is_instance_valid(target) or _barrel_wave_index >= _barrel_wave_queue.size():
		_enter_recovery()
		return
	_clear_pending_barrels()
	var spots := _pick_barrel_wave_spots(_barrel_wave_queue[_barrel_wave_index])
	for spot in spots:
		_barrel_used_spots.append(spot)
	aim_direction = _flat_direction_to(spots[0])
	visual.face_direction(aim_direction)
	_barrel_released = false
	_barrel_step_elapsed = 0.0
	_barrel_step_duration = maxf(0.25, skill.barrel_throw_duration if skill != null else 0.56)
	visual.begin_windup(BlubberbeardSkillData.Kind.POWDER_BARREL)
	_play_sound(1.15 + float(_barrel_wave_index) * 0.08)
	for spot in spots:
		var barrel := _spawn_barrel(spot, true)
		if is_instance_valid(barrel):
			_barrel_pending_hazards.append(barrel)


func _pick_barrel_wave_spots(count: int) -> Array[Vector3]:
	if not is_instance_valid(target):
		return [global_position]
	var spots: Array[Vector3] = []
	var player_now := target.global_position
	var r_min := maxf(0.8, skill.barrel_spread_min_radius if skill != null else 2.0)
	var r_max := maxf(r_min + 0.4, skill.barrel_spread_max_radius if skill != null else 4.6)
	# First waves/throws follow the player directly; subsequent barrels scatter randomly nearby.
	var track_player_directly := (
		_barrel_wave_index <= 1
		if (skill == null or skill.barrel_escalating_burst)
		else _barrel_wave_index == 0
	)
	for idx in count:
		if idx == 0 and track_player_directly:
			spots.append(player_now)
		else:
			spots.append(_pick_spaced_spot(player_now, r_min, r_max, spots, idx, count))
	return spots


func _pick_spaced_spot(
	anchor: Vector3,
	r_min: float,
	r_max: float,
	existing: Array[Vector3],
	slot_idx: int,
	slot_count: int
) -> Vector3:
	var fallback_angle := TAU * float(slot_idx) / float(maxi(1, slot_count))
	var best := anchor + Vector3.RIGHT.rotated(Vector3.UP, fallback_angle) * r_min
	var best_dist := -1.0
	var space := get_world_3d().direct_space_state if is_inside_tree() and get_world_3d() else null
	var excluded := _ray_excludes()
	for _attempt in 14:
		var ang := randf() * TAU
		var rad := randf_range(r_min, r_max)
		var candidate := anchor + Vector3(cos(ang), 0.0, sin(ang)) * rad
		if AI_CLASS.spot_crosses_boundary(space, anchor, candidate, _ground_y, excluded):
			continue
		var min_sep := INF
		for prev in existing:
			min_sep = minf(min_sep, Vector2(candidate.x - prev.x, candidate.z - prev.z).length())
		if min_sep > best_dist:
			best_dist = min_sep
			best = candidate
		if min_sep >= BARREL_BURST_SPREAD_SEPARATION:
			break
	return best


func _update_barrel_barrage(delta: float) -> void:
	if _barrel_gap_remaining > 0.0:
		_barrel_gap_remaining = maxf(0.0, _barrel_gap_remaining - delta)
		if _barrel_gap_remaining <= 0.0:
			_start_next_barrel_wave()
		return
	_barrel_step_elapsed += delta
	visual.windup_progress = clampf(
		_barrel_step_elapsed / maxf(0.05, _barrel_step_duration), 0.0, 1.0
	)
	if not _barrel_released and visual.windup_progress >= visual.THROW_RELEASE_PROGRESS:
		_release_pending_barrels()
	if _barrel_step_elapsed >= _barrel_step_duration:
		_barrel_wave_index += 1
		if _barrel_wave_index < _barrel_wave_queue.size():
			var g_min := minf(skill.barrel_throw_gap_min, skill.barrel_throw_gap_max)
			var g_max := maxf(skill.barrel_throw_gap_min, skill.barrel_throw_gap_max)
			_barrel_gap_remaining = randf_range(g_min, g_max)
			visual.begin_recovery(BlubberbeardSkillData.Kind.POWDER_BARREL)
			if _barrel_gap_remaining <= 0.0:
				_start_next_barrel_wave()
		else:
			_enter_recovery()


func _spawn_barrel(at: Vector3, hold_until_release: bool = false) -> Node3D:
	if not is_instance_valid(get_parent()) or skill == null:
		return null
	var hazard := HAZARD.new()
	hazard.source = self
	hazard.damage = skill.damage
	hazard.radius = skill.radius * boss_size_scale
	hazard.remaining = maxf(0.55, skill.windup)
	hazard.detonated.connect(_on_barrel_detonated.bind(hazard, hazard.radius))
	get_parent().add_child(hazard)
	hazard.global_position = Vector3(at.x, _ground_y + 0.08, at.z)
	if hold_until_release:
		hazard.hold_barrel_for_throw()
	else:
		hazard.animate_barrel(global_position + Vector3.UP * 0.6)
	return hazard


func _release_pending_barrels() -> void:
	_barrel_released = true
	var hand_pos := visual.get_barrel_release_world_position()
	for barrel in _barrel_pending_hazards:
		if is_instance_valid(barrel):
			barrel.release_barrel_from(hand_pos)
	_barrel_pending_hazards.clear()
	visual.impact(0.14, 0.14)
	_play_sound(1.38)


func _clear_pending_barrels() -> void:
	for barrel in _barrel_pending_hazards:
		if is_instance_valid(barrel):
			barrel.queue_free()
	_barrel_pending_hazards.clear()


func _update_standard_windup() -> void:
	if timer > 0.0:
		if skill == null:
			return
		var progress := 1.0 - clampf(timer / maxf(0.05, skill.windup), 0.0, 1.0)
		visual.windup_progress = progress
		match skill.kind:
			BlubberbeardSkillData.Kind.ANCHOR_WHIRLWIND:
				_whirlwind_rig.update_windup(progress)
			BlubberbeardSkillData.Kind.SPIKY_INFLATION:
				feedback.update_slam_warning_alpha(0.14 + progress * 0.34)
		return
	_execute_skill()


func _enter_skydive_leap() -> void:
	state = State.SKYDIVE_LEAP
	var rad := (skill.radius if skill != null else 2.5) * _current_damage_size_scale()
	var leap_pos := _skydive.begin_leap(
		target,
		skill.skydive_max_range if skill != null else 13.5,
		skill.skydive_peak_height if skill != null else 4.2,
		skill.skydive_leap_duration if skill != null else 0.88,
		rad,
		_current_damage_size_scale()
	)
	aim_direction = _flat_direction_to(leap_pos)
	visual.face_direction(aim_direction)
	_show_aoe_warning(leap_pos, rad, Color(1.0, 0.14, 0.04))
	feedback.emit_skill_cue(&"skydive_launch", global_position)


func _update_skydive_leap(delta: float) -> void:
	feedback.skydive_flight_tick(delta, visual.airborne_height, aim_direction)
	if _skydive.tick_leap(delta):
		feedback.hide_slam_warning()
		var dmg := skill.damage if skill != null else 3.0
		var rad := (skill.radius if skill != null else 2.5) * _current_damage_size_scale()
		var impact_pos := _skydive.target_position
		_trigger_aoe_hit(impact_pos, rad, dmg, &"boss_skydive", 1.75)
		visual.impact(0.34, 0.34)
		feedback.emit_skill_cue(&"skydive_slam", impact_pos, rad)
		_enter_recovery()


func _enter_whirlwind_spin() -> void:
	state = State.WHIRLWIND
	var r_min := mini(skill.whirlwind_rotations_min, skill.whirlwind_rotations_max)
	var r_max := maxi(skill.whirlwind_rotations_min, skill.whirlwind_rotations_max)
	var rotations := randi_range(maxi(1, r_min), maxi(1, r_max))
	var reach := maxf(2.0, skill.whirlwind_reach_radius * _current_damage_size_scale())
	var ang_speed := maxf(2.0, skill.whirlwind_angular_speed)
	_whirlwind_rig.begin_spin(
		reach,
		atan2(aim_direction.z, aim_direction.x),
		ang_speed,
		rotations,
		skill.damage,
		phase_index > 0
	)
	visual.begin_whirlwind_spin(aim_direction)


func _update_whirlwind_spin(delta: float) -> void:
	if is_instance_valid(target):
		var step_dir := _flat_direction_to(target.global_position)
		_set_horizontal_velocity(step_dir * move_speed * 0.42)
		visual.face_direction(step_dir)
	else:
		_halt_locomotion()
	move_and_slide()
	feedback.whirlwind_spin_tick(delta, global_position)
	if not _whirlwind_rig.tick_spin(delta):
		_whirlwind_rig.hide_all()
		visual.impact(0.22, 0.24)
		_enter_recovery()


func _execute_spiky_burst() -> void:
	feedback.spikes_release()
	visual.impact(0.28, 0.30)
	_play_sound(1.55)
	var dmg := skill.damage if skill != null else (3.5 if phase_index > 0 else 2.5)
	var rad := _current_spike_burst_radius()
	var hold_dur := _current_spiky_hold_duration()
	var thorn_rad := SPIKY_THORN_BODY_RADIUS * _current_damage_size_scale()
	_trigger_aoe_hit(global_position, rad, dmg, &"boss_spiky_burst", 1.8)
	_begin_spiky_thorn_hitbox(dmg, thorn_rad)
	state = State.SPIKY_HOLD
	timer = hold_dur
	visual.begin_spike_burst(hold_dur)
	_size_rig.sync(boss_size_scale)
	_show_aoe_warning(global_position, thorn_rad, Color(1.0, 0.25, 0.08))
	feedback.update_slam_warning_alpha(0.24)
	_pending_counter_burst = false


func _update_spiky_hold() -> void:
	_halt_locomotion()
	move_and_slide()
	var hold_dur := maxf(0.1, _current_spiky_hold_duration())
	var pulse := 0.18 + absf(sin((1.0 - clampf(timer / hold_dur, 0.0, 1.0)) * TAU)) * 0.14
	feedback.update_slam_warning_alpha(pulse)
	if timer <= 0.0:
		if is_instance_valid(_aoe_hitbox):
			_aoe_hitbox.end_attack()
		feedback.hide_slam_warning()
		_enter_recovery()


func _begin_spiky_thorn_hitbox(dmg: float, thorn_rad: float) -> void:
	if not is_instance_valid(_aoe_hitbox) or _aoe_shape == null:
		return
	_aoe_hitbox.global_position = global_position
	_aoe_shape.radius = thorn_rad
	var context := DamageContext.new()
	context.source = self
	context.source_team = CombatTeams.ENEMY
	context.base_amount_hp = dmg * 0.65
	context.amount_hp = dmg * 0.65
	context.tag = &"boss_spiky_burst"
	context.origin = global_position
	context.knockback_multiplier = 1.6
	_aoe_hitbox.begin_attack_with_context(context, HitBox.RehitPolicy.ONCE_PER_CONTACT)


func _execute_venom_spit() -> void:
	if not is_instance_valid(get_parent()) or skill == null:
		_enter_recovery()
		return
	var origin := visual.get_venom_release_world_position()
	aim_direction = VENOM_HAZARD.fire_fan_volley(
		self, target, origin, _ground_y, skill, boss_size_scale, _on_venom_splashed
	)
	visual.face_direction(aim_direction)
	feedback.emit_skill_cue(&"venom_spit", global_position)
	_enter_recovery()


func _begin_spiky_counter() -> void:
	_hits_since_counter = 0
	_hurt_remaining = 0.0
	_counter_cooldown_left = counter_cooldown
	_pending_counter_burst = true
	_counter_shock_velocity = (
		-_flat_direction_to(target.global_position) * COUNTER_SHOCK_RECOIL_SPEED
	)
	state = State.COUNTER_SHOCK
	timer = COUNTER_SHOCK_DURATION
	visual.begin_counter_shock()
	feedback.emit_skill_cue(&"spiky_counter_shock", global_position)


func _update_counter_shock(delta: float) -> void:
	_counter_shock_velocity = _counter_shock_velocity.move_toward(Vector3.ZERO, 24.0 * delta)
	_set_horizontal_velocity(_counter_shock_velocity)
	move_and_slide()
	timer -= delta
	if timer <= 0.0:
		_halt_locomotion()
		skill = _find_spike_skill()
		state = State.WINDUP
		timer = COUNTER_PUFF_WINDUP
		visual.begin_windup(BlubberbeardSkillData.Kind.SPIKY_INFLATION)
		_show_aoe_warning(global_position, _current_spike_burst_radius(), Color(1.0, 0.25, 0.08))


func _enter_recovery() -> void:
	_cancel_active_attacks_for_interrupt(false)
	var prev_kind := skill.kind if skill != null else BlubberbeardSkillData.Kind.POWDER_BARREL
	_size_rig.sync(boss_size_scale)
	state = State.RECOVERY
	var is_slam := prev_kind == BlubberbeardSkillData.Kind.ANCHOR_SLAM
	timer = anchor_slam_recovery if is_slam else (skill.recovery if skill != null else 0.55)
	visual.begin_recovery(prev_kind, timer)


func _enter_wait() -> void:
	state = State.WAIT
	var phase := current_phase()
	var base_wait := phase.skill_interval if phase != null else 1.5
	var wait_time := randf_range(base_wait * (1.0 - wait_jitter), base_wait * (1.0 + wait_jitter))
	if phase_index > 0 and randf() < phase2_chain_chance:
		wait_time *= 0.5
	timer = maxf(0.55, wait_time)
	_strafe_sign = -1.0 if randf() < 0.5 else 1.0
	_strafe_flip_timer = randf_range(1.1, 2.0)


func _has_super_armor() -> bool:
	if not super_armor_during_attacks:
		return false
	return (
		state
		in [
			State.WINDUP,
			State.SKYDIVE_LEAP,
			State.SPIKY_HOLD,
			State.WHIRLWIND,
			State.COUNTER_SHOCK,
		]
	)


func _on_can_stagger_break() -> bool:
	return not (state == State.SKYDIVE_LEAP and position.y > _ground_y + 0.35)


func _on_stagger_broken(duration_seconds: float) -> void:
	_cancel_active_attacks_for_interrupt()
	_hits_since_counter = mini(_hits_since_counter, maxi(0, hits_before_counter - 2))
	_hurt_remaining = 0.0
	_pending_counter_burst = false
	state = State.STAGGERED
	timer = duration_seconds
	_halt_locomotion()
	if is_instance_valid(visual):
		visual.begin_staggered(duration_seconds)
	if is_instance_valid(feedback):
		feedback.emit_skill_cue(&"stagger_broken", global_position)


func _update_staggered(delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(
		Vector3.ZERO, recovery_deceleration * delta
	)
	_set_horizontal_velocity(horizontal)
	move_and_slide()
	timer -= delta
	if timer <= 0.0:
		_enter_wait()


func _cancel_active_attacks_for_interrupt(clear_barrels: bool = true) -> void:
	charge_hitbox.end_attack()
	if is_instance_valid(_aoe_hitbox):
		_aoe_hitbox.end_attack()
	if is_instance_valid(_whirlwind_rig):
		_whirlwind_rig.hide_all()
	if is_instance_valid(_skydive):
		_skydive.hide_all()
	if clear_barrels:
		_clear_pending_barrels()
	_anchor_slam_active = false
	feedback.hide_slam_warning()
	dust.emitting = false


func _hit_feedback(_amount: float) -> void:
	if dead:
		return
	visual.flash_hit()
	var can_counter := not (_has_super_armor() or state == State.STAGGERED)
	if _hits_since_counter < hits_before_counter:
		_hits_since_counter += 1
	elif can_counter and _counter_cooldown_left <= 0.0 and is_instance_valid(target):
		_begin_spiky_counter()
		return
	var in_open_state := state == State.WAIT or state == State.RECOVERY
	if can_counter and _hurt_flinch_cooldown_left <= 0.0 and in_open_state:
		_hurt_remaining = visual.HURT_DURATION
		_hurt_flinch_cooldown_left = 2.4


func _on_phase_entered(index: int) -> void:
	visual.set_enraged(index > 0)
	_size_rig.sync(boss_size_scale)
	feedback.phase_changed()
	visual.impact(0.32, 0.45)
	EFFECTS.shockwave(get_parent(), global_position, 3.0, Color(0.9, 0.2, 0.4, 0.8))
	_play_sound(0.55)


func _on_fight_ended() -> void:
	_cancel_active_attacks_for_interrupt()
	if is_inside_tree():
		get_tree().call_group(VENOM_HAZARD.HAZARD_GROUP, "queue_free")
	feedback.death()
	EFFECTS.shockwave(get_parent(), global_position, 3.0, Color(1.0, 0.65, 0.2, 0.8))
	_play_sound(0.4)
	visual.play_death(queue_free)


func _apply_gravity_to_floor(delta: float) -> void:
	if state == State.SKYDIVE_LEAP:
		velocity.y = 0.0
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0


func _set_horizontal_velocity(horizontal: Vector3) -> void:
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _halt_locomotion() -> void:
	visual.moving = false
	dust.emitting = false
	_walk_dust_timer = 0.0
	_set_horizontal_velocity(Vector3.ZERO)


func _update_patrol_movement(delta: float) -> void:
	if not is_instance_valid(target):
		_halt_locomotion()
		return
	_strafe_flip_timer -= delta
	if _strafe_flip_timer <= 0.0:
		_strafe_flip_timer = randf_range(1.2, 2.2)
		_strafe_sign = -_strafe_sign
	var delta_pos := target.global_position - global_position
	delta_pos.y = 0.0
	var dist := delta_pos.length()
	if delta_pos.is_zero_approx():
		_halt_locomotion()
		return
	var to_target := delta_pos / dist
	var tangent := Vector3(-to_target.z, 0.0, to_target.x) * _strafe_sign
	var move_dir := to_target
	var speed_scale := 0.85
	if dist > circle_outer_distance:
		move_dir = (to_target * 0.9 + tangent * 0.35).normalized()
		speed_scale = 1.0
	elif dist >= preferred_distance:
		# Trong tầm trung/gần: đi bộ vòng vòng quanh Player để giữ nhịp đấu và mở góc ra chiêu.
		move_dir = (tangent * 0.9 + to_target * 0.2).normalized()
		speed_scale = 0.72
	else:
		# Quá sát người chơi: lách ngang và lùi nhẹ ra rìa cận chiến.
		move_dir = (tangent * 0.85 - to_target * 0.35).normalized()
		speed_scale = 0.65
	_set_horizontal_velocity(move_dir * move_speed * speed_scale)
	visual.moving = true
	visual.face_direction(to_target)
	dust.emitting = true
	_walk_dust_timer -= delta
	if _walk_dust_timer <= 0.0:
		_walk_dust_timer = 0.28
		_walk_dust_side = -_walk_dust_side
		var perp := Vector3(-move_dir.z, 0.0, move_dir.x) * (_walk_dust_side * 0.55)
		feedback.spawn_move_dust(global_position + perp, move_dir, false)


func _should_trigger_anchor_slam() -> bool:
	if not anchor_slam_enabled or _anchor_slam_cooldown_left > 0.0:
		return false
	if not is_instance_valid(target):
		return false
	if _is_position_near_boundary(target.global_position, ai_boundary_margin):
		return false
	return _flat_distance_to_target() <= anchor_slam_trigger_range and randf() < 0.22


func _begin_anchor_slam() -> void:
	_anchor_slam_active = true
	state = State.WINDUP
	timer = anchor_slam_enraged_windup if phase_index > 0 else anchor_slam_windup
	visual.moving = false
	aim_direction = _flat_direction_to(
		target.global_position if is_instance_valid(target) else global_position + Vector3.BACK
	)
	visual.face_direction(aim_direction)
	visual.begin_windup(BlubberbeardSkillData.Kind.ANCHOR_SLAM)
	var forward_dist := anchor_slam_forward_offset * _current_damage_size_scale()
	var slam_rad := _current_anchor_slam_radius()
	_slam_impact_position = global_position + aim_direction * forward_dist
	_slam_impact_position.y = _ground_y + 0.05
	_show_aoe_warning(_slam_impact_position, slam_rad, Color(1.0, 0.22, 0.04))
	_play_sound(0.95)


func _update_anchor_slam_windup() -> void:
	var windup := maxf(0.05, anchor_slam_enraged_windup if phase_index > 0 else anchor_slam_windup)
	var progress := 1.0 - clampf(timer / windup, 0.0, 1.0)
	visual.windup_progress = progress
	feedback.update_slam_warning_alpha(0.16 + progress * 0.34)
	if timer <= 0.0:
		feedback.hide_slam_warning()
		_anchor_slam_cooldown_left = anchor_slam_cooldown
		var dmg := anchor_slam_enraged_damage if phase_index > 0 else anchor_slam_damage
		var slam_rad := _current_anchor_slam_radius()
		_trigger_aoe_hit(_slam_impact_position, slam_rad, dmg, &"boss_anchor_slam", 1.35)
		visual.impact(0.3, 0.3)
		feedback.anchor_slam(_slam_impact_position, slam_rad)
		_enter_recovery()


func _find_spike_skill() -> BlubberbeardSkillData:
	var phase := current_phase()
	if phase != null:
		for candidate in phase.skills:
			var data := candidate as BlubberbeardSkillData
			if data != null and data.kind == BlubberbeardSkillData.Kind.SPIKY_INFLATION:
				return data
	var fallback := BlubberbeardSkillData.new()
	fallback.kind = BlubberbeardSkillData.Kind.SPIKY_INFLATION
	fallback.damage = 3.5 if phase_index > 0 else 2.5
	fallback.radius = spiky_close_burst_radius
	fallback.spiky_hold_duration = spiky_hold_duration
	return fallback


func _current_damage_size_scale() -> float:
	if _size_rig == null:
		return boss_size_scale
	return _size_rig.get_damage_scale(boss_size_scale, phase_index)


func _current_spike_burst_radius() -> float:
	var base := spiky_close_burst_radius
	if skill != null and skill.kind == BlubberbeardSkillData.Kind.SPIKY_INFLATION:
		base = maxf(spiky_close_burst_radius, skill.radius)
	return base * boss_size_scale


func _current_anchor_slam_radius() -> float:
	return anchor_slam_radius * _current_damage_size_scale()


func _current_spiky_hold_duration() -> float:
	var is_spiky := skill != null and skill.kind == BlubberbeardSkillData.Kind.SPIKY_INFLATION
	return maxf(0.4, skill.spiky_hold_duration) if is_spiky else spiky_hold_duration


func _trigger_aoe_hit(
	at: Vector3, radius: float, amount: float, tag: StringName, knockback: float = 1.4
) -> void:
	if not is_instance_valid(_aoe_hitbox) or _aoe_shape == null or amount <= 0.0:
		return
	_aoe_hitbox.global_position = at
	_aoe_shape.radius = maxf(0.1, radius)
	var context := DamageContext.new()
	context.source = self
	context.source_team = CombatTeams.ENEMY
	context.base_amount_hp = amount
	context.amount_hp = amount
	context.tag = tag
	context.origin = at
	context.knockback_multiplier = knockback
	_aoe_hitbox.begin_attack_with_context(context, HitBox.RehitPolicy.ONCE_PER_ATTACK)
	_aoe_hitbox.sample_shape()
	_aoe_hitbox.end_attack()


func _flat_distance_to_target() -> float:
	if not is_instance_valid(target):
		return 0.0
	var flat := target.global_position - global_position
	flat.y = 0.0
	return flat.length()


func _flat_direction_to(world_pos: Vector3) -> Vector3:
	var flat := world_pos - global_position
	flat.y = 0.0
	return flat.normalized() if not flat.is_zero_approx() else aim_direction


func _is_position_near_boundary(pos: Vector3, margin_meters: float) -> bool:
	var space := get_world_3d().direct_space_state if is_inside_tree() and get_world_3d() else null
	return AI_CLASS.is_position_near_boundary(space, pos, _ground_y, margin_meters, _ray_excludes())


func _ray_excludes() -> Array[RID]:
	var excluded: Array[RID] = [get_rid()]
	if is_instance_valid(target) and target is CollisionObject3D:
		excluded.append((target as CollisionObject3D).get_rid())
	return excluded


func _on_barrel_detonated(hazard: Node3D, radius: float) -> void:
	if is_instance_valid(hazard) and not dead:
		feedback.barrel_explosion(hazard.global_position, radius)


func _on_venom_splashed(at: Vector3, pool_radius: float) -> void:
	if not dead:
		feedback.emit_skill_cue(&"venom_splash", at, pool_radius)


func _on_attack_damage_applied(_damage: DamageContext, hit_target: Node, _amount: float) -> void:
	feedback.aoe_hit(hit_target)


func _on_whirlwind_hit(hit_target: Node) -> void:
	feedback.emit_skill_cue(&"whirlwind_hit", global_position, 0.0, hit_target)


func _play_sound(pitch: float) -> void:
	if is_instance_valid(sound):
		sound.pitch_scale = pitch
		sound.play()


func _create_whirlwind_rig() -> void:
	_whirlwind_rig = WHIRLWIND_RIG.new()
	_whirlwind_rig.name = "WhirlwindRig"
	add_child(_whirlwind_rig)
	_whirlwind_rig.setup(self)
	_whirlwind_rig.whirlwind_hit.connect(_on_whirlwind_hit)


func _create_aoe_hitbox() -> void:
	_aoe_hitbox = HitBox.new()
	_aoe_hitbox.name = "AoeHitBox"
	_aoe_hitbox.top_level = true
	_aoe_hitbox.actor = self
	_aoe_hitbox.team = CombatTeams.ENEMY
	_aoe_hitbox.collision_layer = CombatLayers.ENEMY_ATTACK
	_aoe_hitbox.collision_mask = CombatLayers.PLAYER_HURTBOX
	_aoe_hitbox.damage_applied.connect(_on_attack_damage_applied)
	var collider := CollisionShape3D.new()
	_aoe_shape = SphereShape3D.new()
	_aoe_shape.radius = anchor_slam_radius
	collider.shape = _aoe_shape
	_aoe_hitbox.add_child(collider)
	add_child(_aoe_hitbox)


func _show_aoe_warning(at: Vector3, radius: float, ring_color: Color) -> void:
	feedback.show_slam_warning(at, _ground_y, radius, anchor_slam_radius, ring_color)
