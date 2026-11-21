class_name EliteVenomVine
extends VenomVine
## Biến thể Elite: Bramble Pod Split, Thorny Snare, Smart Tunnel Relocate & Thorn Tendril.

const ELITE_ROOTS_SHEET := preload(
	"res://assets/sprites/enemies/venom_vine/venom_vine_elite_roots.png"
)
const RELOCATE_HELPER := preload("res://gameplay/enemies/venom_vine/venom_vine_relocate_helper.gd")

const TENDRIL_PRIORITY := 55
const TENDRIL_MIN_TRIGGER_DISTANCE_METERS := 1.9
const RELOCATE_EVADE_HOLD_SECONDS := 0.65
const RELOCATE_HIDDEN_JITTER_SECONDS := 0.35
const TUNNEL_PIT_HOLD_SECONDS := 3.8
const TUNNEL_DOT_HOLD_SECONDS := 0.85
const TUNNEL_DOT_FADE_SECONDS := 0.45
const TRAIL_PARTIAL_HP_RATIO := 0.75
const TRAIL_CRITICAL_HP_RATIO := 0.4
const TUNNEL_DOT_SPACING_HIGH_HP := 1.05
const TUNNEL_DOT_SPACING_LOW_HP := 1.45
const TUNNEL_MID_START_FRAC := 0.22
const TUNNEL_MID_END_FRAC := 0.85
const TUNNEL_DECOY_LENGTH_MIN := 3.4
const TUNNEL_DECOY_LENGTH_MAX := 5.6
const TUNNEL_DECOY_SPREAD_MIN_RAD := 0.68
const TUNNEL_DECOY_SPREAD_MAX_RAD := 1.45
const EMERGE_AMBUSH_CHARGE_SECONDS := 0.32

@export_group("Bramble Pod & Thorny Snare")
@export_range(0.0, 0.85, 0.05) var snare_slow_ratio: float = 0.72
@export_range(0.0, 5.0, 0.05) var snare_tick_damage_multiplier: float = 0.8
@export_range(0, 6, 1) var split_pod_count_phase1: int = 2
@export_range(0, 6, 1) var split_pod_count_phase2: int = 3
@export_range(0.4, 3.0, 0.05, "suffix:m") var split_pool_radius_meters: float = 0.85
@export_range(0.8, 5.0, 0.1, "suffix:m") var split_distance_meters: float = 2.0
@export_range(0.0, 5.0, 0.05) var split_tick_damage_multiplier: float = 0.6
@export_range(0.5, 15.0, 0.25, "suffix:s") var split_cooldown_seconds: float = 2.8

@export_group("Thorn Tendril Line")
@export_range(0.1, 1.0, 0.05) var tendril_unlock_hp_ratio: float = 0.5
@export_range(2, 14, 1) var tendril_segment_count: int = 9
@export_range(0.5, 3.5, 0.05, "suffix:m") var tendril_start_distance_meters: float = 1.35
@export_range(0.6, 3.0, 0.05, "suffix:m") var tendril_segment_spacing_meters: float = 1.15
@export_range(0.04, 0.5, 0.02, "suffix:s") var tendril_segment_interval_seconds: float = 0.14
@export_range(0.15, 1.5, 0.02, "suffix:s") var tendril_windup_seconds: float = 0.72
@export_range(0.15, 1.5, 0.02, "suffix:s") var tendril_segment_telegraph_seconds: float = 0.62
@export_range(0.08, 1.5, 0.02, "suffix:s") var tendril_segment_active_seconds: float = 0.78
@export_range(0.1, 1.2, 0.02, "suffix:s") var tendril_segment_retract_seconds: float = 0.42
@export_range(0.3, 2.5, 0.05, "suffix:m") var tendril_visual_radius_meters: float = 0.96
@export_range(0.2, 2.0, 0.05, "suffix:m") var tendril_hitbox_radius_meters: float = 0.68
@export_range(0.2, 5.0, 0.05) var tendril_damage_multiplier: float = 1.6
@export_range(0.0, 2.5, 0.05) var tendril_knockback_multiplier: float = 0.75
@export_range(1.5, 20.0, 0.25, "suffix:s") var tendril_cooldown_seconds: float = 6.5
@export_range(0.1, 2.0, 0.05, "suffix:s") var tendril_recovery_seconds: float = 0.48
@export_range(0.2, 3.0, 0.05, "suffix:s") var tendril_post_attack_delay_seconds: float = 1.1
@export var tendril_spawn_end_pool: bool = true
@export_range(0.4, 2.5, 0.05, "suffix:m") var tendril_end_pool_radius_meters: float = 0.95

@export_group("Smart Tunnel Relocate")
@export_range(1.5, 12.0, 0.25, "suffix:m") var relocate_min_distance_meters: float = 5.4
@export_range(2.5, 16.0, 0.25, "suffix:m") var relocate_max_distance_meters: float = 10.6
@export_range(3.0, 20.0, 0.25, "suffix:m") var relocate_anchor_radius_meters: float = 13.5
@export_range(1.5, 8.0, 0.25, "suffix:m") var relocate_evade_distance_meters: float = 2.65
@export_range(0.1, 1.0, 0.05) var relocate_phase_hp_ratio: float = 0.5
@export_range(0.2, 5.0, 0.05, "suffix:s") var relocate_telegraph_seconds: float = 2.65

var _spawn_anchor_position: Vector3 = Vector3.ZERO
var _base_visual_pos: Vector3 = Vector3(0.0, 0.0, 0.14)
var _base_visual_scale: Vector3 = Vector3(1.38, 1.38, 1.38)
var _burrow_pit_base_pos: Vector3 = Vector3(0.0, 0.035, 0.04)
var _burrow_pit_base_scale: Vector3 = Vector3(1.06, 1.06, 1.06)
var _burrow_pit_base_modulate: Color = Color.WHITE
var _tendril_cooldown_remaining: float = 0.0
var _split_cooldown_remaining: float = 0.0
var _close_pressure_seconds: float = 0.0
var _half_hp_relocate_done: bool = false
var _pending_relocate_move: bool = false
var _relocate_crack_mound: Sprite3D
var _tunnel_tween: Tween
var _burrow_pit_tween: Tween
var _tunnel_stamp_tweens: Array[Tween] = []
var _last_retreat_spray_bucket: int = -1
var _last_emerge_spray_bucket: int = -1

@onready var elite_feedback: EliteFeedback = get_node_or_null(^"EliteFeedback") as EliteFeedback
@onready var _burrow_pit: Sprite3D = get_node_or_null(^"BurrowPit") as Sprite3D


func _ready() -> void:
	_spawn_anchor_position = global_position
	super()
	if is_instance_valid(visual):
		_base_visual_pos = visual.position
		_base_visual_scale = visual.scale
	if is_instance_valid(_burrow_pit):
		_burrow_pit_base_pos = _burrow_pit.position
		_burrow_pit_base_scale = _burrow_pit.scale
		_burrow_pit_base_modulate = _burrow_pit.modulate
		_burrow_pit.visible = false


func _exit_tree() -> void:
	_clear_relocate_telegraph()
	_hide_burrow_pit_immediately()


func _physics_process(delta: float) -> void:
	var step := maxf(0.0, delta)
	_tendril_cooldown_remaining = maxf(0.0, _tendril_cooldown_remaining - step)
	_split_cooldown_remaining = maxf(0.0, _split_cooldown_remaining - step)
	super(delta)


func build_pool_config() -> Dictionary:
	var cfg := super()
	cfg["tick_damage_hp"] = resolve_attack_damage(snare_tick_damage_multiplier)
	cfg["snare_slow_ratio"] = snare_slow_ratio
	cfg["split_pod_count"] = _get_active_split_pod_count()
	cfg["split_pool_radius"] = split_pool_radius_meters
	cfg["split_distance_meters"] = split_distance_meters
	cfg["split_tick_damage_hp"] = resolve_attack_damage(split_tick_damage_multiplier)
	cfg["use_thorny_pod"] = true
	return cfg


func fire_shot_at(landing_target: Vector3, custom_pool_config: Dictionary = {}) -> void:
	var cfg := custom_pool_config.duplicate(true)
	if cfg.is_empty():
		cfg = build_pool_config()
	elif not cfg.has("snare_slow_ratio"):
		cfg["snare_slow_ratio"] = snare_slow_ratio
	var pod_count := int(cfg.get("split_pod_count", 0))
	if pod_count > 0:
		_split_cooldown_remaining = split_cooldown_seconds
	super(landing_target, cfg)


func get_tendril_cooldown_remaining() -> float:
	return _tendril_cooldown_remaining


func start_tendril_cooldown() -> void:
	_tendril_cooldown_remaining = tendril_cooldown_seconds


func begin_elite_telegraph() -> void:
	if is_instance_valid(elite_feedback):
		elite_feedback.begin_telegraph()


func end_elite_telegraph() -> void:
	if is_instance_valid(elite_feedback):
		elite_feedback.end_telegraph()


func spawn_snare_pool_at(world_spot: Vector3, radius_meters: float) -> void:
	var parent := get_parent()
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	var pool := ACID_POOL_SCRIPT.new() as VenomAcidPool
	var cfg := build_pool_config()
	cfg["split_pod_count"] = 0
	pool.setup(
		self,
		team,
		radius_meters,
		float(cfg.get("pool_duration_seconds", pool_duration_seconds)),
		float(cfg.get("tick_interval_seconds", pool_tick_interval_seconds)),
		resolve_attack_damage(snare_tick_damage_multiplier),
		cfg
	)
	pool.position = (parent as Node3D).to_local(world_spot) if parent is Node3D else world_spot
	parent.add_child(pool)
	pool.global_position = world_spot
	_register_spawned_pool(pool)


func _uses_purple_acid() -> bool:
	return true


func _get_relocate_telegraph_seconds() -> float:
	return relocate_telegraph_seconds


func _get_burrow_hidden_duration() -> float:
	var jitter := minf(RELOCATE_HIDDEN_JITTER_SECONDS, burrow_duration_seconds * 0.28)
	return maxf(0.05, burrow_duration_seconds + randf_range(-jitter, jitter))


func _should_always_relocate() -> bool:
	return true


func _on_vigilant_timeout() -> void:
	ambushed_wake = false
	set_awake(false)
	request_state(&"dormant")


func _consume_relocate_target() -> Variant:
	_pending_relocate_move = false
	var space := (
		get_world_3d().direct_space_state if is_inside_tree() and get_world_3d() != null else null
	)
	var excluded: Array[RID] = [get_rid()]
	var has_tgt := has_target() and is_instance_valid(target)
	if has_tgt and target is CollisionObject3D:
		excluded.append((target as CollisionObject3D).get_rid())
	return (
		RELOCATE_HELPER
		. find_relocate_spot(
			{
				"origin": global_position,
				"anchor": _spawn_anchor_position,
				"has_target": has_tgt,
				"target_pos": target.global_position if has_tgt else Vector3.ZERO,
				"space": space,
				"excluded": excluded,
				"min_distance": relocate_min_distance_meters,
				"max_distance": relocate_max_distance_meters,
				"anchor_radius": relocate_anchor_radius_meters,
			}
		)
	)


func _try_custom_hit_reaction(_was_charging: bool, melee_combo_reached: bool) -> bool:
	if not _half_hp_relocate_done and get_hp_ratio() <= relocate_phase_hp_ratio:
		_half_hp_relocate_done = true
		_pending_relocate_move = true
		if _request_burrow(false):
			return true
	if melee_combo_reached:
		_pending_relocate_move = true
	return false


func _try_stalk_special_action(step: float) -> bool:
	if not has_target() or dead:
		_close_pressure_seconds = 0.0
		return false
	if not _half_hp_relocate_done and get_hp_ratio() <= relocate_phase_hp_ratio:
		_half_hp_relocate_done = true
		_pending_relocate_move = true
		if _request_burrow(false):
			return true

	var dist := _distance_to_target()
	if (
		dist <= relocate_evade_distance_meters
		and _burrow_cooldown_remaining <= 0.0
		and not has_pending_counter()
	):
		_close_pressure_seconds += step
		if _close_pressure_seconds >= RELOCATE_EVADE_HOLD_SECONDS:
			_close_pressure_seconds = 0.0
			if _request_burrow(false):
				return true
	else:
		_close_pressure_seconds = 0.0

	if (
		attack_cooldown_remaining <= 0.0
		and get_hp_ratio() <= tendril_unlock_hp_ratio
		and _tendril_cooldown_remaining <= 0.0
		and dist > TENDRIL_MIN_TRIGGER_DISTANCE_METERS
	):
		if request_state(&"thorntendril", TENDRIL_PRIORITY):
			return true
	return false


func _spawn_relocate_telegraph(
	old_pos: Vector3, next_pos: Vector3, duration_seconds: float
) -> void:
	_clear_relocate_telegraph()
	var hp_ratio := get_hp_ratio()
	var detailed_trail := hp_ratio > TRAIL_PARTIAL_HP_RATIO
	var critical_trail := hp_ratio <= TRAIL_CRITICAL_HP_RATIO
	var crack_reveal_ratio := 0.74 if detailed_trail else (0.86 if not critical_trail else 0.9)
	var crawl_seconds := clampf(
		duration_seconds * crack_reveal_ratio, 0.16, maxf(0.18, duration_seconds - 0.12)
	)
	var pit_offset := Vector3(_burrow_pit_base_pos.x, 0.0, _burrow_pit_base_pos.z)
	var old_pit_pos := old_pos + pit_offset
	var next_pit_pos := next_pos + pit_offset

	_relocate_crack_mound = Sprite3D.new()
	_relocate_crack_mound.name = "RelocateCrackMound"
	_relocate_crack_mound.texture = ELITE_ROOTS_SHEET
	_relocate_crack_mound.hframes = 4
	_relocate_crack_mound.vframes = 2
	_relocate_crack_mound.frame = 4
	_relocate_crack_mound.offset = Vector2(0.0, 146.0)
	_relocate_crack_mound.pixel_size = 0.0068
	_relocate_crack_mound.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_relocate_crack_mound.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_relocate_crack_mound.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_relocate_crack_mound.modulate = Color(1.08, 1.0, 0.92, 0.94)
	_relocate_crack_mound.position = pit_offset + Vector3.UP * 0.04
	_relocate_crack_mound.visible = false
	add_child(_relocate_crack_mound)

	var parent := get_parent()
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		if is_instance_valid(_relocate_crack_mound):
			_relocate_crack_mound.visible = true
		return

	var space := (
		get_world_3d().direct_space_state if is_inside_tree() and get_world_3d() != null else null
	)
	var excluded: Array[RID] = [get_rid()]
	var polyline := RELOCATE_HELPER.build_tunnel_polyline(
		space, excluded, old_pit_pos, next_pit_pos
	)
	var total_len := RELOCATE_HELPER.polyline_length(polyline)
	_tunnel_tween = create_tween()
	_tunnel_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tunnel_tween.tween_interval(crawl_seconds)

	# Giảm dần tổng số chấm thật khi HP tụt: >75% (6-8 chấm), 40-75% (3-4 chấm), <=40% (2-3 chấm).
	# Chỉ hiện lên rồi chìm xuống tại chỗ chứ không tạo mô đất di chuyển trên cỏ.
	var dot_spacing := TUNNEL_DOT_SPACING_HIGH_HP if detailed_trail else TUNNEL_DOT_SPACING_LOW_HP
	var step_count := clampi(int(roundf(total_len / dot_spacing)), 6, 9)
	var mid_dot_spawned := false
	for idx in range(step_count):
		var frac := float(idx + 1) / float(step_count + 1)
		var is_early := frac < TUNNEL_MID_START_FRAC
		var is_mid := frac >= TUNNEL_MID_START_FRAC and frac <= TUNNEL_MID_END_FRAC
		if not detailed_trail:
			if critical_trail:
				# Máu <= 40%: tối đa 1 chấm đầu + 1 chấm thật mờ đoạn giữa + 1 bụi rung nhẹ báo còn sống.
				if is_early and idx > 0:
					continue
				if is_mid:
					if not mid_dot_spawned and idx == int(step_count / 2):
						mid_dot_spawned = true
					else:
						if idx == step_count - 2:
							_schedule_mid_tremor_dust(
								parent,
								RELOCATE_HELPER.sample_polyline(polyline, frac),
								crawl_seconds * frac
							)
						continue
				if not is_early and not is_mid and idx > step_count - 1:
					continue
			else:
				# Máu 40% - 75%: thưa dần đoạn giữa và vẫn còn chấm đầu + chấm báo sống mờ.
				if is_early and idx > 1:
					continue
				if is_mid:
					if not mid_dot_spawned and idx % 3 == 2:
						mid_dot_spawned = true
					else:
						if idx % 3 == 1:
							_schedule_mid_tremor_dust(
								parent,
								RELOCATE_HELPER.sample_polyline(polyline, frac),
								crawl_seconds * frac
							)
						continue
		var dot_pos := RELOCATE_HELPER.sample_polyline(polyline, frac)
		var look_pos := RELOCATE_HELPER.sample_polyline(polyline, minf(1.0, frac + 0.04))
		var seg_vec := look_pos - dot_pos
		seg_vec.y = 0.0
		var norm_dir := seg_vec.normalized() if not seg_vec.is_zero_approx() else Vector3.BACK
		var dot_scale := 0.88 if detailed_trail else (0.76 if is_early else 0.56)
		var dot_alpha := 0.9 if detailed_trail else (0.82 if is_early else 0.56)
		_schedule_tunnel_dot(
			parent,
			dot_pos,
			norm_dir,
			crawl_seconds * frac,
			{
				"name": "TunnelTrailDot",
				"scale": dot_scale,
				"alpha": dot_alpha,
				"hold": TUNNEL_DOT_HOLD_SECONDS,
				"fade": TUNNEL_DOT_FADE_SECONDS,
			}
		)

	if not detailed_trail:
		var decoy_branches := 3 if critical_trail else 2
		_spawn_decoy_dotted_trails(
			parent, polyline, crawl_seconds, decoy_branches, 2 if critical_trail else 1
		)

	_tunnel_tween.tween_callback(
		func() -> void:
			if is_instance_valid(_relocate_crack_mound):
				_relocate_crack_mound.scale = Vector3(0.45, 0.14, 0.45)
				_relocate_crack_mound.visible = true
				var rise_tween := _relocate_crack_mound.create_tween()
				rise_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
				(
					rise_tween
					. tween_property(_relocate_crack_mound, "scale", Vector3.ONE, 0.18)
					. set_trans(Tween.TRANS_BACK)
					. set_ease(Tween.EASE_OUT)
				)
	)


func _schedule_tunnel_dot(
	parent: Node, dot_pos: Vector3, move_dir: Vector3, delay_seconds: float, dot_config: Dictionary
) -> void:
	var stamp_tween := create_tween()
	stamp_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tunnel_stamp_tweens.append(stamp_tween)
	stamp_tween.tween_interval(delay_seconds)
	stamp_tween.tween_callback(
		func() -> void:
			if not is_instance_valid(parent) or parent.is_queued_for_deletion():
				return
			VFX_SCRIPT.spawn_tunnel_trail_dot(parent, dot_pos, dot_config)
			VFX_SCRIPT.spawn_dirt_dust_burst(
				parent,
				"TunnelCrawlDirt",
				dot_pos,
				(-move_dir * 0.35 + Vector3.UP * 0.9).normalized(),
				6,
				0.38
			)
	)


func _schedule_mid_tremor_dust(parent: Node, pos: Vector3, delay_seconds: float) -> void:
	var puff_tween := create_tween()
	puff_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tunnel_stamp_tweens.append(puff_tween)
	puff_tween.tween_interval(delay_seconds)
	puff_tween.tween_callback(
		func() -> void:
			if not is_instance_valid(parent) or parent.is_queued_for_deletion():
				return
			VFX_SCRIPT.spawn_dirt_dust_burst(
				parent, "TunnelFaintTremorDirt", pos, Vector3.UP, 5, 0.35
			)
	)


func _spawn_decoy_dotted_trails(
	parent: Node,
	main_polyline: Array[Vector3],
	crawl_seconds: float,
	decoy_count: int,
	tease_mound_count: int
) -> void:
	var branch_origin := RELOCATE_HELPER.sample_polyline(main_polyline, randf_range(0.16, 0.28))
	var branch_next := RELOCATE_HELPER.sample_polyline(main_polyline, 0.42)
	var base_vec := branch_next - branch_origin
	base_vec.y = 0.0
	var base_dir := base_vec.normalized() if not base_vec.is_zero_approx() else Vector3.BACK
	var first_sign := 1.0 if randf() < 0.5 else -1.0
	var space := (
		get_world_3d().direct_space_state if is_inside_tree() and get_world_3d() != null else null
	)
	var excluded: Array[RID] = [get_rid()]

	for d_idx in range(maxi(1, decoy_count)):
		var side_sign := first_sign if d_idx % 2 == 0 else -first_sign
		var extra_fan := 0.48 if d_idx >= 2 else 0.0
		var spread_rad := randf_range(
			TUNNEL_DECOY_SPREAD_MIN_RAD + extra_fan, TUNNEL_DECOY_SPREAD_MAX_RAD + extra_fan
		)
		var decoy_dir := base_dir.rotated(Vector3.UP, side_sign * spread_rad)
		var decoy_len := randf_range(TUNNEL_DECOY_LENGTH_MIN, TUNNEL_DECOY_LENGTH_MAX)
		var dots_on_branch := 3
		var branch_tip := branch_origin
		var tip_valid := false
		for step_i in range(dots_on_branch):
			var seg_frac := float(step_i + 1) / float(dots_on_branch)
			var raw_pt := branch_origin + decoy_dir * (decoy_len * seg_frac)
			if space != null:
				var hit_y: Variant = RELOCATE_HELPER.probe_ground_height(
					space, raw_pt, raw_pt.y, excluded
				)
				if not (hit_y is float):
					break
				raw_pt.y = hit_y as float
			branch_tip = raw_pt
			tip_valid = true
			var timing := crawl_seconds * clampf(0.2 + seg_frac * 0.56, 0.14, 0.88)
			_schedule_tunnel_dot(
				parent,
				raw_pt,
				decoy_dir,
				timing,
				{
					"name": "TunnelDecoyDot",
					"scale": lerpf(0.84, 0.68, seg_frac),
					"alpha": lerpf(0.84, 0.6, seg_frac),
					"hold": TUNNEL_DOT_HOLD_SECONDS * 0.88,
					"fade": TUNNEL_DOT_FADE_SECONDS,
				}
			)
		if tip_valid and d_idx < tease_mound_count:
			var tease_delay := crawl_seconds * (0.48 if d_idx == 0 else 0.72)
			_schedule_decoy_tease_mound(parent, branch_tip, tease_delay)


func _schedule_decoy_tease_mound(parent: Node, pos: Vector3, delay_seconds: float) -> void:
	var tease_tween := create_tween()
	tease_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tunnel_stamp_tweens.append(tease_tween)
	tease_tween.tween_interval(delay_seconds)
	tease_tween.tween_callback(
		func() -> void:
			if not is_instance_valid(parent) or parent.is_queued_for_deletion():
				return
			# Đụn đất nhử trồi nhẹ tại chỗ rồi tự tụt xuống đất chứ không có cây ngoi ra.
			(
				VFX_SCRIPT
				. spawn_tunnel_tease_mound(
					parent,
					ELITE_ROOTS_SHEET,
					pos,
					{
						"name": "TunnelDecoyTease",
						"scale": 0.9,
						"alpha": 0.9,
						"hold": 0.34,
						"fade": 0.28,
					}
				)
			)
			VFX_SCRIPT.spawn_dirt_dust_burst(
				parent, "TunnelDecoyTeaseDirt", pos, Vector3.UP, 7, 0.4
			)
	)


func _clear_relocate_telegraph() -> void:
	for tween in _tunnel_stamp_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tunnel_stamp_tweens.clear()
	if _tunnel_tween != null and _tunnel_tween.is_valid():
		_tunnel_tween.kill()
	_tunnel_tween = null
	if is_instance_valid(_relocate_crack_mound):
		_relocate_crack_mound.queue_free()
	_relocate_crack_mound = null


func _on_relocate_emerged() -> bool:
	_clear_relocate_telegraph()
	if dead or not has_target() or get_current_zone() == VenomVineAI.Zone.OUT_OF_RANGE:
		return false
	face_target()
	attack_cooldown_remaining = 0.0
	var plan := build_attack_plan()
	var mode := int(plan.get("mode", VenomVineAI.AttackMode.NONE))
	if mode != VenomVineAI.AttackMode.ACID_SINGLE and mode != VenomVineAI.AttackMode.ACID_FAN:
		return false
	plan["charge_seconds"] = EMERGE_AMBUSH_CHARGE_SECONDS
	var attack_state := (
		fsm.states.get("attack") as VenomVineAttack if is_instance_valid(fsm) else null
	)
	if attack_state == null:
		return false
	attack_state.set_pending_plan(plan)
	return request_state(&"attack")


func _on_burrow_retreat_started() -> void:
	_last_retreat_spray_bucket = -1
	_hide_burrow_pit_immediately()
	var parent := get_parent()
	if is_instance_valid(parent) and not parent.is_queued_for_deletion():
		var pit_center := (
			global_position + Vector3(_burrow_pit_base_pos.x, 0.0, _burrow_pit_base_pos.z)
		)
		if is_instance_valid(_burrow_pit):
			VFX_SCRIPT.spawn_burrow_pit_from_template(
				parent, _burrow_pit, burrow_transition_seconds + TUNNEL_PIT_HOLD_SECONDS, 0.85
			)
		else:
			VFX_SCRIPT.spawn_burrow_pit(
				parent, pit_center, 2.85, burrow_transition_seconds + TUNNEL_PIT_HOLD_SECONDS, 0.85
			)
		_spawn_dirt_burst(parent, pit_center, "BurrowSinkStartDirt", 16)


func _update_burrow_retreat_visual(progress: float) -> void:
	if is_instance_valid(visual):
		var sink_ease := pow(progress, 1.3)
		var tremor := sin(progress * TAU * 7.0) * 0.065 * (1.0 - progress * 0.4)
		visual.position = Vector3(
			_base_visual_pos.x + tremor, _base_visual_pos.y - 1.45 * sink_ease, _base_visual_pos.z
		)
		if is_instance_valid(visual.sprite) and progress > 0.72:
			visual.sprite.modulate.a = clampf(1.0 - (progress - 0.72) / 0.2, 0.0, 1.0)
		if progress >= 0.9:
			visual.visible = false
	var bucket := int(progress * 4.0)
	if bucket > _last_retreat_spray_bucket:
		_last_retreat_spray_bucket = bucket
		var pit_center := (
			global_position + Vector3(_burrow_pit_base_pos.x, 0.0, _burrow_pit_base_pos.z)
		)
		_spawn_dirt_burst(get_parent(), pit_center, "BurrowSinkStepDirt", 10)


func _on_burrow_emerge_started(_from_relocate: bool) -> void:
	_clear_relocate_telegraph()
	_last_emerge_spray_bucket = -1
	if is_instance_valid(visual):
		visual.visible = true
		visual.position = Vector3(_base_visual_pos.x, _base_visual_pos.y - 1.45, _base_visual_pos.z)
		if is_instance_valid(visual.sprite):
			visual.sprite.modulate.a = 0.0
	var parent := get_parent()
	var pit_center := global_position + Vector3(_burrow_pit_base_pos.x, 0.0, _burrow_pit_base_pos.z)
	if is_instance_valid(_burrow_pit):
		_play_emerge_pit_animation(burrow_transition_seconds + 0.45, 0.75)
	elif is_instance_valid(parent) and not parent.is_queued_for_deletion():
		VFX_SCRIPT.spawn_burrow_pit(
			parent, pit_center, 2.85, burrow_transition_seconds + 0.45, 0.75
		)
	if is_instance_valid(parent) and not parent.is_queued_for_deletion():
		_spawn_dirt_burst(parent, pit_center, "BurrowEmergeBurstDirt", 20)


func _play_emerge_pit_animation(hold_seconds: float, fade_seconds: float) -> void:
	if not is_instance_valid(_burrow_pit):
		return
	_hide_burrow_pit_immediately()
	_burrow_pit.visible = true
	_burrow_pit.scale = _burrow_pit_base_scale * 0.42
	_burrow_pit.modulate = Color(
		_burrow_pit_base_modulate.r, _burrow_pit_base_modulate.g, _burrow_pit_base_modulate.b, 0.96
	)
	_burrow_pit_tween = create_tween()
	(
		_burrow_pit_tween
		. tween_property(_burrow_pit, "scale", _burrow_pit_base_scale, 0.24)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	_burrow_pit_tween.tween_interval(maxf(0.05, hold_seconds))
	_burrow_pit_tween.tween_property(_burrow_pit, "modulate:a", 0.0, maxf(0.15, fade_seconds))
	_burrow_pit_tween.tween_callback(_hide_burrow_pit_immediately)


func _hide_burrow_pit_immediately() -> void:
	if _burrow_pit_tween != null and _burrow_pit_tween.is_valid():
		_burrow_pit_tween.kill()
	_burrow_pit_tween = null
	if is_instance_valid(_burrow_pit):
		_burrow_pit.visible = false
		_burrow_pit.position = _burrow_pit_base_pos
		_burrow_pit.scale = _burrow_pit_base_scale
		_burrow_pit.modulate = _burrow_pit_base_modulate


func _update_burrow_emerge_visual(progress: float, _from_relocate: bool) -> void:
	if is_instance_valid(visual):
		var rise := 1.0 - pow(1.0 - progress, 2.2)
		var tremor := sin(progress * TAU * 6.0) * 0.055 * (1.0 - progress)
		visual.position = Vector3(
			_base_visual_pos.x + tremor,
			lerpf(_base_visual_pos.y - 1.45, _base_visual_pos.y, rise),
			_base_visual_pos.z
		)
		if is_instance_valid(visual.sprite):
			visual.sprite.modulate.a = clampf(progress / 0.26, 0.0, 1.0)
	var bucket := int(progress * 4.0)
	if bucket > _last_emerge_spray_bucket:
		_last_emerge_spray_bucket = bucket
		var pit_center := (
			global_position + Vector3(_burrow_pit_base_pos.x, 0.0, _burrow_pit_base_pos.z)
		)
		_spawn_dirt_burst(get_parent(), pit_center, "BurrowEmergeStepDirt", 10)


func _reset_burrow_visual_state() -> void:
	super()
	if is_instance_valid(visual):
		visual.position = _base_visual_pos
		visual.scale = _base_visual_scale


func _spawn_dirt_burst(parent: Node, world_pos: Vector3, node_name: String, count: int) -> void:
	VFX_SCRIPT.spawn_dirt_dust_burst(parent, node_name, world_pos, Vector3.UP, count, 0.42)


func _get_active_split_pod_count() -> int:
	if _split_cooldown_remaining > 0.0:
		return 0
	return (
		split_pod_count_phase2
		if get_hp_ratio() <= tendril_unlock_hp_ratio
		else split_pod_count_phase1
	)
