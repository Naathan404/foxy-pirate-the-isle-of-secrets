class_name VenomVine
extends EnemyBase
## Cây dây leo bắn axit cố định cho vùng Forest: ngụy trang theo cự ly, AI đón đầu & tránh chồng.

const AI_CLASS := preload("res://gameplay/enemies/venom_vine/venom_vine_ai.gd")
const PROJECTILE_SCRIPT := preload("res://gameplay/enemies/venom_vine/venom_pool_projectile.gd")
const ACID_POOL_SCRIPT := preload("res://gameplay/enemies/venom_vine/venom_acid_pool.gd")
const VFX_SCRIPT := preload("res://gameplay/enemies/venom_vine/venom_vine_vfx.gd")
const GLOW_SHADER := preload("res://gameplay/enemies/venom_vine/venom_vine_glow.gdshader")
const DORMANT_TEXTURE := preload("res://assets/sprites/enemies/venom_vine/venom_vine_dormant.png")
const ACTIVE_TEXTURE := preload(
	"res://assets/sprites/enemies/venom_vine/venom_vine_active_sheet.png"
)
const BURROW_TEXTURE := preload("res://assets/sprites/enemies/venom_vine/venom_vine_burrow.png")

const AGITATION_DECAY_PER_SECOND := 0.12
const AGITATION_PER_HIT := 0.35
const AGITATION_INNER_GAIN_PER_SECOND := 0.15
const MIN_FLIGHT_SECONDS := 0.32
const MAX_FLIGHT_SECONDS := 0.85
const IDLE_GLOW_AWAKE := 0.55
const LIGHT_ENERGY_AWAKE := 0.6
const LIGHT_ENERGY_CHARGE_BONUS := 1.15
const AMBIENT_SPORE_COUNT := 56
const AMBIENT_SPORE_LIFETIME_SECONDS := 1.45
const HIT_GLOW_BOOST := 1.1
const HIT_COUNTER_GLOW_BOOST := 1.65
const HIT_GLOW_DECAY_PER_SECOND := 3.2
const HIT_RECOIL_TILT_RADIANS := 0.16
const BURROW_PRIORITY := 70
const MELEE_COMBO_HIT_LIMIT := 2
const NORMAL_GLOW_COLOR := Color(0.55, 1.0, 0.25)
const COUNTER_GLOW_COLOR := Color(1.0, 0.45, 0.18)

@export_group("Detection & Ambush")
## Bán kính nhận diện ngoài (m): vào vòng này cây bắt đầu xét phục kích và tỉnh dậy.
@export_range(1.0, 30.0, 0.1, "suffix:m") var outer_detection_radius_meters: float = 6.5:
	set(value):
		outer_detection_radius_meters = maxf(1.0, value)
		_queue_detection_update()
## Bán kính vùng cận (m): vào vòng này cây chuyển sang bắn nhiều đạn & nhịp nhanh hơn.
@export_range(0.5, 20.0, 0.1, "suffix:m") var inner_attack_radius_meters: float = 3.5
## Cự ly tỉnh ngay lập tức (m) bỏ qua thời gian giả vờ ngụy trang.
@export_range(0.5, 20.0, 0.1, "suffix:m") var ambush_wake_distance_meters: float = 4.0
## Độ mở trễ (m) khi đã thức để tránh nhấp nháy state ở mép vòng nhận diện.
@export_range(0.0, 6.0, 0.1, "suffix:m") var detection_hysteresis_meters: float = 1.0:
	set(value):
		detection_hysteresis_meters = maxf(0.0, value)
		_queue_detection_update()
@export_range(0.0, 3.0, 0.05, "suffix:s") var ambush_delay_min_seconds: float = 0.25
@export_range(0.0, 3.0, 0.05, "suffix:s") var ambush_delay_max_seconds: float = 0.65
@export_range(0.1, 3.0, 0.05, "suffix:s") var wake_duration_seconds: float = 0.45
## Thời gian tối thiểu sau khi mở nụ trước phát bắn đầu tiên (trừ khi bị đánh lén).
@export_range(0.0, 5.0, 0.05, "suffix:s") var wake_attack_delay_seconds: float = 0.42
@export_range(0.2, 15.0, 0.1, "suffix:s") var vigilant_duration_seconds: float = 3.5
@export_range(0.1, 2.0, 0.05, "suffix:s") var retract_duration_seconds: float = 0.35
## Độ mở rộng bán kính nhận diện tạm thời (m) khi bị đánh tầm xa.
@export_range(0.0, 15.0, 0.5, "suffix:m") var anger_radius_bonus_meters: float = 2.5
@export_range(0.5, 20.0, 0.5, "suffix:s") var anger_detect_duration_seconds: float = 6.0

@export_group("Outer Ring Attack")
@export_range(1, 5, 1) var outer_shots_per_volley: int = 1
@export_range(0.5, 10.0, 0.1, "suffix:s") var outer_cooldown_seconds: float = 2.6
@export_range(0.05, 2.0, 0.05, "suffix:s") var outer_shot_interval_seconds: float = 0.28

@export_group("Inner Ring Attack")
@export_range(2, 10, 1) var inner_shots_per_volley: int = 3
@export_range(10.0, 180.0, 2.0, "suffix:deg") var inner_fan_degrees: float = 64.0
@export_range(0.5, 10.0, 0.1, "suffix:s") var inner_cooldown_seconds: float = 1.6
@export_range(0.05, 2.0, 0.05, "suffix:s") var inner_shot_interval_seconds: float = 0.16

@export_group("Charge & Prediction")
@export_range(0.2, 3.0, 0.05, "suffix:s") var charge_duration_seconds: float = 0.75
@export_range(0.1, 3.0, 0.05, "suffix:s") var recover_duration_seconds: float = 0.45
@export_range(0.0, 1.2, 0.05) var lead_accuracy: float = 0.75
@export_range(0.0, 6.0, 0.1, "suffix:m") var max_lead_meters: float = 2.0
## Khoảng lệch tối thiểu/tối đa quanh Player (m) để bắn vùng lân cận thay vì bắn trực diện.
@export_range(0.3, 5.0, 0.05, "suffix:m") var aim_scatter_min_meters: float = 1.5
@export_range(0.5, 6.0, 0.05, "suffix:m") var aim_scatter_max_meters: float = 2.5
## Xác suất mỗi lượt bắn thường nhắm thẳng vị trí Player thay vì bắn lệch xung quanh.
@export_range(0.0, 1.0, 0.05) var direct_aim_chance: float = 0.3
## Giới hạn khoảng cách rơi đạn tính từ gốc cây (m).
@export_range(0.5, 10.0, 0.1, "suffix:m") var min_shot_distance_meters: float = 1.6
@export_range(1.0, 20.0, 0.1, "suffix:m") var max_shot_distance_meters: float = 6.2

@export_group("Acid Projectile & Pool")
## Sát thương va chạm trực tiếp trên không (mặc định 0 để chỉ vũng độc mặt đất gây sát thương).
@export_range(0.0, 10.0, 0.1) var projectile_direct_damage_hp: float = 0.0
@export_range(0.5, 6.0, 0.1, "suffix:m") var projectile_arc_height_meters: float = 2.4
@export_range(0.4, 5.0, 0.05, "suffix:m") var pool_radius_meters: float = 1.05
@export_range(0.5, 15.0, 0.1, "suffix:s") var pool_duration_seconds: float = 4.2
@export_range(0.1, 4.0, 0.05, "suffix:s") var pool_tick_interval_seconds: float = 0.85
@export_range(0.0, 5.0, 0.05) var pool_tick_damage_multiplier: float = 1.0
@export_range(1, 12, 1) var max_active_pools: int = 4

@export_group("Hit Reaction & Counter")
## Số đòn trúng từ Player để kích hoạt phản công (đánh trúng lúc đang gồng tính gấp đôi).
@export_range(1, 10, 1) var hits_before_counter: int = 2
@export_range(0.5, 15.0, 0.1, "suffix:s") var counter_cooldown_seconds: float = 1.65
@export_range(0.15, 2.0, 0.05, "suffix:s") var counter_charge_seconds: float = 0.28
@export_range(1, 8, 1) var counter_inner_shots: int = 3
@export_range(1, 6, 1) var counter_outer_shots: int = 2
@export_range(0.4, 3.0, 0.05, "suffix:m") var counter_pool_radius_meters: float = 0.95
@export_range(0.05, 1.0, 0.01, "suffix:s") var hit_flinch_seconds: float = 0.22

@export_group("Burrow Defense")
@export_range(0.2, 3.0, 0.05, "suffix:s") var burrow_duration_seconds: float = 1.1
@export_range(1.0, 15.0, 0.25, "suffix:s") var burrow_cooldown_seconds: float = 4.5
@export_range(0.1, 2.0, 0.05, "suffix:s") var burrow_transition_seconds: float = 0.4
@export_range(0.2, 3.0, 0.05, "suffix:s") var post_emerge_attack_delay_seconds: float = 0.7
## Khoảng cách thời gian tối đa giữa hai đòn cận chiến liên tiếp.
@export_range(0.3, 5.0, 0.1, "suffix:s") var melee_combo_window_seconds: float = 2.0
## Quên các đòn cũ sau khoảng nghỉ để phản công dựa trên áp lực gần đây.
@export_range(0.5, 8.0, 0.1, "suffix:s") var counter_hit_window_seconds: float = 3.0

@export_group("Tactical Idle")
## Thời gian tối thiểu quan sát sau khi phun hoặc trồi lên, trừ khi phản công.
@export_range(0.1, 3.0, 0.05, "suffix:s") var idle_min_duration_seconds: float = 0.65
## Khoảng cách giữa các lần cân nhắc chui trong lúc đang đứng quan sát.
@export_range(0.2, 4.0, 0.1, "suffix:s") var idle_decision_interval_seconds: float = 1.0

var ai: VenomVineAI
var is_awake: bool = false
var ambushed_wake: bool = false
var agitation: float = 0.0
var attack_cooldown_remaining: float = 0.0
var last_known_target_position: Vector3 = Vector3.ZERO
var is_burrowed: bool = false
var _active_pools: Array[VenomAcidPool] = []
var _active_projectiles: Array[VenomPoolProjectile] = []
var _burrow_cooldown_remaining: float = 0.0
var _melee_combo_hits: int = 0
var _melee_combo_remaining_seconds: float = 0.0
var _counter_hit_remaining_seconds: float = 0.0
var _counter_after_burrow: bool = false
var _burrow_saved_hurtbox_enabled: bool = true
var _burrow_saved_hurtbox_layer: int = 0
var _burrow_saved_hurtbox_mask: int = 0
var _last_tracked_target_pos: Vector3 = Vector3.ZERO
var _has_tracked_target_pos: bool = false
var _estimated_target_velocity: Vector3 = Vector3.ZERO
var _is_dormant_sheet: bool = true
var _anger_detect_remaining_seconds: float = 0.0
var _hits_toward_counter: int = 0
var _counter_cooldown_remaining_seconds: float = 0.0
var _pending_counter: bool = false
var _flinch_remaining_seconds: float = 0.0
var _glow_material: ShaderMaterial
var _ambient_spores: GPUParticles3D
var _venom_light: OmniLight3D
var _charge_glow_strength: float = 0.0
var _charge_counter_mix: float = 0.0
var _hit_glow_boost: float = 0.0
var _hit_recoil_tween: Tween

@onready var bullet_spawn: Marker3D = $Direction/BulletSpawn


func _ready() -> void:
	ai = AI_CLASS.new()
	_apply_detection_radius()
	super()
	set_sprite_sheet_mode(true)
	_setup_luminous_vfx()
	damaged.connect(_on_vine_damaged)


func _process(delta: float) -> void:
	if _hit_glow_boost > 0.0:
		_hit_glow_boost = maxf(0.0, _hit_glow_boost - maxf(0.0, delta) * HIT_GLOW_DECAY_PER_SECOND)
	_sync_glow_vfx()


func _physics_process(delta: float) -> void:
	var step := maxf(0.0, delta)
	attack_cooldown_remaining = maxf(0.0, attack_cooldown_remaining - step)
	_burrow_cooldown_remaining = maxf(0.0, _burrow_cooldown_remaining - step)
	_melee_combo_remaining_seconds = maxf(0.0, _melee_combo_remaining_seconds - step)
	if _melee_combo_remaining_seconds <= 0.0:
		_melee_combo_hits = 0
	_counter_cooldown_remaining_seconds = maxf(0.0, _counter_cooldown_remaining_seconds - step)
	_counter_hit_remaining_seconds = maxf(0.0, _counter_hit_remaining_seconds - step)
	if _counter_hit_remaining_seconds <= 0.0:
		_hits_toward_counter = 0
	_flinch_remaining_seconds = maxf(0.0, _flinch_remaining_seconds - step)
	agitation = maxf(0.0, agitation - AGITATION_DECAY_PER_SECOND * step)
	if _anger_detect_remaining_seconds > 0.0:
		_anger_detect_remaining_seconds = maxf(0.0, _anger_detect_remaining_seconds - step)
		if _anger_detect_remaining_seconds <= 0.0:
			_queue_detection_update()
	_update_target_velocity_estimate(step)
	super(delta)


func receive_damage(damage: DamageContext) -> float:
	if is_burrowed:
		return 0.0
	var attack_state := (
		fsm.current_state as VenomVineAttack
		if is_instance_valid(fsm) and fsm.current_state is VenomVineAttack
		else null
	)
	var was_charging := attack_state != null and attack_state.is_charging()
	var applied := super(damage)
	if applied <= 0.0 or damage == null or damage.source_team != CombatTeams.PLAYER:
		return applied

	var counter_triggered := false
	if not dead and hp.is_alive():
		var force_hide := _record_melee_hit(damage)
		_hits_toward_counter += 2 if was_charging else 1
		_counter_hit_remaining_seconds = counter_hit_window_seconds
		if _try_custom_hit_reaction(was_charging, force_hide):
			_trigger_hit_recoil()
			_hit_glow_boost = HIT_COUNTER_GLOW_BOOST
			_spawn_hit_impact_vfx(true)
			return applied
		var reaction := (
			ai
			. choose_hit_reaction(
				{
					"melee_combo_limit_reached": force_hide,
					"counter_pending": _pending_counter,
					"counter_ready":
					(
						_counter_cooldown_remaining_seconds <= 0.0
						and _hits_toward_counter >= maxi(1, hits_before_counter)
					),
					"burrow_ready": _burrow_cooldown_remaining <= 0.0,
					"distance_meters": _distance_to_target(),
					"inner_radius_meters": inner_attack_radius_meters,
					"hp_ratio": get_hp_ratio(),
					"agitation": agitation,
					"was_charging": was_charging,
				}
			)
		)
		if reaction == VenomVineAI.HitReaction.BURROW and _request_burrow(force_hide):
			_spawn_hit_impact_vfx(false)
			return applied
		if reaction == VenomVineAI.HitReaction.COUNTER:
			_pending_counter = true
			counter_triggered = true
			_hits_toward_counter = 0
			_counter_hit_remaining_seconds = 0.0
			_counter_cooldown_remaining_seconds = counter_cooldown_seconds

		if counter_triggered or _pending_counter:
			_flinch_remaining_seconds = 0.0
		else:
			var in_hit_or_attack := (
				is_instance_valid(fsm)
				and is_instance_valid(fsm.current_state)
				and fsm.current_state.name in [&"Hit", &"Attack"]
			)
			if is_awake and not in_hit_or_attack:
				_flinch_remaining_seconds = hit_flinch_seconds
				play_directional_animation(&"hit", true)
		_trigger_hit_recoil()
	elif is_instance_valid(visual):
		visual.rotation = Vector3.ZERO

	_hit_glow_boost = HIT_COUNTER_GLOW_BOOST if counter_triggered else HIT_GLOW_BOOST
	_spawn_hit_impact_vfx(counter_triggered)
	return applied


func set_awake(awake: bool) -> void:
	if is_awake == awake:
		return
	is_awake = awake
	_queue_detection_update()


func _record_melee_hit(damage: DamageContext) -> bool:
	if not damage.is_melee_normal_attack():
		_melee_combo_hits = 0
		_melee_combo_remaining_seconds = 0.0
		return false
	_melee_combo_hits += 1
	_melee_combo_remaining_seconds = melee_combo_window_seconds
	return _melee_combo_hits >= MELEE_COMBO_HIT_LIMIT


func _request_burrow(counter_after_emerge: bool) -> bool:
	if is_instance_valid(fsm) and fsm.current_state is VenomVineBurrow:
		return false
	if not request_state(&"burrow", BURROW_PRIORITY):
		return false
	_counter_after_burrow = counter_after_emerge
	_begin_burrow()
	return true


func _has_active_venom() -> bool:
	for projectile in _active_projectiles:
		if is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
			return true
	for pool in _active_pools:
		if is_instance_valid(pool) and not pool.is_fading():
			return true
	return false


func _begin_burrow() -> void:
	if is_burrowed:
		return
	is_burrowed = true
	if is_instance_valid(_ambient_spores):
		_ambient_spores.emitting = false
		_ambient_spores.visible = false
		_ambient_spores.restart()
	if is_instance_valid(_venom_light):
		_venom_light.light_energy = 0.0
	_sync_glow_vfx()
	_burrow_saved_hurtbox_enabled = hurtbox.enabled
	_burrow_saved_hurtbox_layer = hurtbox.collision_layer
	_burrow_saved_hurtbox_mask = hurtbox.collision_mask
	hurtbox.enabled = false
	hurtbox.collision_layer = 0
	hurtbox.collision_mask = 0
	end_active_attack()
	_stop_contact_damage()
	for projectile in _active_projectiles:
		if is_instance_valid(projectile):
			projectile.cancel()
	_active_projectiles.clear()
	for pool in _active_pools:
		if is_instance_valid(pool):
			pool.begin_fade_out()
	_active_pools.clear()
	_hits_toward_counter = 0
	_counter_hit_remaining_seconds = 0.0
	_pending_counter = false
	_melee_combo_hits = 0
	_melee_combo_remaining_seconds = 0.0
	_flinch_remaining_seconds = 0.0


func _end_burrow() -> void:
	if not is_burrowed:
		return
	is_burrowed = false
	if is_instance_valid(_ambient_spores):
		_ambient_spores.visible = true
	_sync_glow_vfx()
	if not dead:
		hurtbox.collision_layer = _burrow_saved_hurtbox_layer
		hurtbox.collision_mask = _burrow_saved_hurtbox_mask
		hurtbox.enabled = _burrow_saved_hurtbox_enabled
		_burrow_cooldown_remaining = burrow_cooldown_seconds
		if _counter_after_burrow and get_current_zone() == VenomVineAI.Zone.INNER_RING:
			_pending_counter = true
			_counter_cooldown_remaining_seconds = counter_cooldown_seconds
	_counter_after_burrow = false


func _show_burrow_frame(frame_index: int) -> void:
	if not is_instance_valid(visual) or not is_instance_valid(visual.sprite):
		return
	if visual.sprite.texture != BURROW_TEXTURE:
		visual.play_animation(&"RESET")
		if is_instance_valid(visual.animation_player):
			visual.animation_player.stop(true)
		_is_dormant_sheet = false
		visual.sprite.frame = 0
		visual.sprite.texture = BURROW_TEXTURE
		visual.sprite.hframes = 2
		visual.sprite.vframes = 2
	visual.sprite.frame = clampi(frame_index, 0, 3)
	visual.sprite.flip_h = false


func play_directional_animation(action: StringName, restart: bool = false) -> bool:
	if action in [&"idle", &"charge", &"shoot", &"hit", &"death"]:
		set_sprite_sheet_mode(false)
	return super(action, restart)


func set_sprite_sheet_mode(dormant: bool) -> void:
	if not is_instance_valid(visual) or not is_instance_valid(visual.sprite):
		return
	var expected_texture := DORMANT_TEXTURE if dormant else ACTIVE_TEXTURE
	if _is_dormant_sheet == dormant and visual.sprite.texture == expected_texture:
		return
	_is_dormant_sheet = dormant
	if is_instance_valid(visual.animation_player):
		visual.animation_player.stop(true)
	if dormant:
		visual.sprite.frame = 1
		visual.sprite.texture = DORMANT_TEXTURE
		visual.sprite.hframes = 4
		visual.sprite.vframes = 1
		visual.sprite.flip_h = false
	else:
		visual.sprite.frame = 0
		visual.sprite.texture = ACTIVE_TEXTURE
		visual.sprite.hframes = 4
		visual.sprite.vframes = 3


func get_current_zone() -> VenomVineAI.Zone:
	if not has_target() or ai == null:
		return VenomVineAI.Zone.OUT_OF_RANGE
	var effective_outer := (
		outer_detection_radius_meters
		+ (anger_radius_bonus_meters if _anger_detect_remaining_seconds > 0.0 else 0.0)
	)
	return ai.classify_zone(
		_distance_to_target(),
		effective_outer,
		inner_attack_radius_meters,
		detection_hysteresis_meters,
		is_awake
	)


func get_target_velocity() -> Vector3:
	if not has_target():
		return Vector3.ZERO
	if target is CharacterBody3D:
		return (target as CharacterBody3D).velocity
	return _estimated_target_velocity


func add_inner_agitation(delta: float) -> void:
	agitation = minf(1.0, agitation + AGITATION_INNER_GAIN_PER_SECOND * maxf(0.0, delta))


func get_hp_ratio() -> float:
	if not is_instance_valid(hp):
		return 1.0
	return clampf(hp.get_current_hp() / maxf(0.01, hp.get_max_hp()), 0.0, 1.0)


func build_attack_plan() -> Dictionary:
	if not has_target() or ai == null:
		return {"mode": VenomVineAI.AttackMode.NONE, "aim_positions": [] as Array[Vector3]}
	var zone := get_current_zone()
	if zone == VenomVineAI.Zone.OUT_OF_RANGE:
		return {"mode": VenomVineAI.AttackMode.NONE, "aim_positions": [] as Array[Vector3]}

	if can_use_special_attack():
		var special_plan := build_special_attack_plan(_distance_to_target())
		if not special_plan.is_empty():
			return special_plan

	var space := (
		get_world_3d().direct_space_state if is_inside_tree() and get_world_3d() != null else null
	)
	var excluded_rids: Array[RID] = [get_rid()]
	var context := {
		"zone": zone,
		"agitation": agitation,
		"hp_ratio": get_hp_ratio(),
		"origin_pos": global_position,
		"target_pos": target.global_position,
		"target_velocity": get_target_velocity(),
		"ground_y": global_position.y,
		"occupied_spots": PROJECTILE_SCRIPT.collect_active_pool_spots(self),
		"space": space,
		"excluded_rids": excluded_rids,
		"outer_shots": outer_shots_per_volley,
		"outer_cooldown": outer_cooldown_seconds,
		"outer_shot_interval": outer_shot_interval_seconds,
		"inner_shots": inner_shots_per_volley,
		"inner_fan_degrees": inner_fan_degrees,
		"inner_cooldown": inner_cooldown_seconds,
		"inner_shot_interval": inner_shot_interval_seconds,
		"charge_seconds": charge_duration_seconds,
		"recover_seconds": recover_duration_seconds,
		"lead_accuracy": lead_accuracy,
		"max_lead_meters": max_lead_meters,
		"aim_scatter_min": aim_scatter_min_meters,
		"aim_scatter_max": aim_scatter_max_meters,
		"direct_aim_chance": direct_aim_chance,
		"min_shot_distance": min_shot_distance_meters,
		"max_shot_distance": max_shot_distance_meters,
		"pool_radius": pool_radius_meters,
	}
	return ai.select_attack_plan(context)


func has_pending_counter() -> bool:
	return _pending_counter and not dead and hp.is_alive()


func consume_pending_counter() -> bool:
	if not has_pending_counter():
		return false
	_pending_counter = false
	_flinch_remaining_seconds = 0.0
	return true


func is_flinching() -> bool:
	return _flinch_remaining_seconds > 0.0 and not dead


func build_counter_plan() -> Dictionary:
	if ai == null:
		return {"mode": VenomVineAI.AttackMode.NONE, "aim_positions": [] as Array[Vector3]}
	var target_pos := target.global_position if has_target() else last_known_target_position
	if target_pos.is_zero_approx():
		target_pos = global_position + last_facing_direction * 2.2
	var space := (
		get_world_3d().direct_space_state if is_inside_tree() and get_world_3d() != null else null
	)
	var context := {
		"hp_ratio": get_hp_ratio(),
		"origin_pos": global_position,
		"target_pos": target_pos,
		"target_velocity": get_target_velocity(),
		"ground_y": global_position.y,
		"inner_radius": inner_attack_radius_meters,
		"counter_pool_radius": counter_pool_radius_meters,
		"counter_inner_shots": counter_inner_shots,
		"counter_outer_shots": counter_outer_shots,
		"counter_charge_seconds": counter_charge_seconds,
		"max_shot_distance": max_shot_distance_meters,
		"occupied_spots": PROJECTILE_SCRIPT.collect_active_pool_spots(self),
		"space": space,
		"excluded_rids": [get_rid()],
	}
	var plan := ai.build_counter_plan(context)
	var pool_cfg := build_pool_config()
	pool_cfg["pool_radius"] = counter_pool_radius_meters
	pool_cfg["flight_seconds_scale"] = 0.65
	pool_cfg["arc_height_scale"] = 0.55
	plan["pool_config"] = pool_cfg
	return plan


func resolve_attack_damage(multiplier: float = 1.0) -> float:
	if data == null:
		return 0.0
	return maxf(0.0, data.attack_damage * maxf(0.0, multiplier))


## Hook mở rộng cho EliteVenomVine override khi có chiêu đặc biệt.
func can_use_special_attack() -> bool:
	return false


## Hook mở rộng cho EliteVenomVine trả về AttackPlan cho chiêu đặc biệt.
func build_special_attack_plan(_distance_meters: float) -> Dictionary:
	return {}


## Hook mở rộng cho EliteVenomVine thực thi chiêu đặc biệt.
func execute_special_attack(_plan: Dictionary) -> void:
	pass


## Hook mở rộng cho EliteVenomVine cấu hình thêm Bramble Pod Split hoặc Thorny Snare.
func build_pool_config() -> Dictionary:
	return {
		"pool_radius": pool_radius_meters,
		"pool_duration_seconds": pool_duration_seconds,
		"tick_interval_seconds": pool_tick_interval_seconds,
		"tick_damage_hp": resolve_attack_damage(pool_tick_damage_multiplier),
		"snare_slow_ratio": 0.0,
		"split_pod_count": 0,
		"use_thorny_pod": false,
	}


func _get_relocate_telegraph_seconds() -> float:
	return 0.0


func _get_burrow_hidden_duration() -> float:
	return burrow_duration_seconds


func _should_always_relocate() -> bool:
	return false


func _on_vigilant_timeout() -> void:
	ambushed_wake = false
	set_awake(false)
	request_state(&"dormant")


func _consume_relocate_target() -> Variant:
	return null


func _try_custom_hit_reaction(_was_charging: bool, _melee_combo_reached: bool) -> bool:
	return false


func _try_stalk_special_action(_step: float) -> bool:
	return false


func _spawn_relocate_telegraph(
	_old_pos: Vector3, _next_pos: Vector3, _duration_seconds: float
) -> void:
	pass


func _clear_relocate_telegraph() -> void:
	pass


func _on_relocate_emerged() -> bool:
	return false


func _on_burrow_retreat_started() -> void:
	pass


func _update_burrow_retreat_visual(_progress: float) -> void:
	pass


func _on_burrow_emerge_started(_from_relocate: bool) -> void:
	pass


func _update_burrow_emerge_visual(_progress: float, _from_relocate: bool) -> void:
	pass


func _reset_burrow_visual_state() -> void:
	if is_instance_valid(visual):
		visual.visible = true
		visual.position.y = 0.0
		if is_instance_valid(visual.sprite):
			visual.sprite.modulate.a = 1.0


func fire_shot_at(landing_target: Vector3, custom_pool_config: Dictionary = {}) -> void:
	if dead or is_burrowed or data == null:
		return
	var parent := get_parent()
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	var spawn_pos := (
		bullet_spawn.global_position
		if is_instance_valid(bullet_spawn)
		else global_position + Vector3.UP * 1.35
	)
	var flat_dist := (
		Vector2(landing_target.x - spawn_pos.x, landing_target.z - spawn_pos.z).length()
	)
	var config := build_pool_config() if custom_pool_config.is_empty() else custom_pool_config
	var flight_scale := clampf(float(config.get("flight_seconds_scale", 1.0)), 0.45, 2.0)
	var arc_scale := clampf(float(config.get("arc_height_scale", 1.0)), 0.35, 2.0)
	var flight_seconds := maxf(
		0.18,
		clampf(0.28 + flat_dist * 0.045, MIN_FLIGHT_SECONDS, MAX_FLIGHT_SECONDS) * flight_scale
	)
	var proj := PROJECTILE_SCRIPT.new() as VenomPoolProjectile
	proj.setup(
		self,
		team,
		spawn_pos,
		landing_target,
		flight_seconds,
		projectile_arc_height_meters * arc_scale,
		projectile_direct_damage_hp,
		config
	)
	proj.impacted.connect(_on_projectile_impacted)
	_active_projectiles = _active_projectiles.filter(func(p): return is_instance_valid(p))
	_active_projectiles.append(proj)
	parent.add_child(proj)
	_spawn_muzzle_flash()


func set_charge_glow(strength: float, is_counter: bool = false) -> void:
	_charge_glow_strength = clampf(strength, 0.0, 2.0)
	_charge_counter_mix = 1.0 if is_counter else 0.0
	_sync_glow_vfx()


func _uses_purple_acid() -> bool:
	return false


func _spawn_muzzle_flash() -> void:
	var spawn_pos := (
		bullet_spawn.global_position
		if is_instance_valid(bullet_spawn)
		else global_position + Vector3.UP * 1.35
	)
	VFX_SCRIPT.spawn_muzzle_flash(
		get_parent(), spawn_pos, last_facing_direction, _charge_counter_mix, _uses_purple_acid()
	)


func _trigger_hit_recoil() -> void:
	if not is_instance_valid(visual):
		return
	if _hit_recoil_tween != null and _hit_recoil_tween.is_valid():
		_hit_recoil_tween.kill()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var cam_right := cam.global_basis.x if is_instance_valid(cam) else Vector3.RIGHT
	cam_right.y = 0.0
	if cam_right.is_zero_approx():
		cam_right = Vector3.RIGHT
	else:
		cam_right = cam_right.normalized()
	var hit_dir := Vector3(pending_hit_direction.x, 0.0, pending_hit_direction.z)
	var side_dot := hit_dir.normalized().dot(cam_right) if not hit_dir.is_zero_approx() else 0.0
	var tilt_sign := -1.0 if side_dot >= 0.0 else 1.0
	if absf(side_dot) < 0.12:
		tilt_sign = 1.0 if int(Time.get_ticks_msec()) % 2 == 0 else -1.0
	var target_rot := Vector3(0.0, 0.0, tilt_sign * HIT_RECOIL_TILT_RADIANS)
	_hit_recoil_tween = create_tween()
	(
		_hit_recoil_tween
		. tween_property(visual, "rotation", target_rot, 0.06)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_hit_recoil_tween
		. tween_property(visual, "rotation", Vector3.ZERO, 0.22)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


func _spawn_hit_impact_vfx(counter_triggered: bool) -> void:
	VFX_SCRIPT.spawn_hit_impact_vfx(
		get_parent(), global_position, pending_hit_direction, counter_triggered
	)


func _register_spawned_pool(pool: VenomAcidPool) -> void:
	_prune_active_pools()
	if is_instance_valid(pool) and pool not in _active_pools:
		_active_pools.append(pool)
	while _active_pools.size() > max_active_pools:
		var oldest := _active_pools.pop_front() as VenomAcidPool
		if is_instance_valid(oldest) and not oldest.is_fading():
			oldest.begin_fade_out()


func _on_projectile_impacted(_landing_pos: Vector3, pool: VenomAcidPool) -> void:
	_register_spawned_pool(pool)


func _prune_active_pools() -> void:
	var kept: Array[VenomAcidPool] = []
	for pool in _active_pools:
		if is_instance_valid(pool) and not pool.is_fading():
			kept.append(pool)
	_active_pools = kept


func _on_vine_damaged(_applied_hp: float) -> void:
	if dead:
		return
	agitation = minf(1.0, agitation + AGITATION_PER_HIT)
	_anger_detect_remaining_seconds = anger_detect_duration_seconds
	_apply_detection_radius()
	_refresh_target.call_deferred()
	if not has_target() and not pending_hit_direction.is_zero_approx():
		var toward_attacker := -pending_hit_direction
		face_direction(toward_attacker)
		last_known_target_position = (
			global_position + toward_attacker * outer_detection_radius_meters
		)
	if not is_awake:
		ambushed_wake = true


func _update_target_velocity_estimate(step: float) -> void:
	if not has_target():
		_has_tracked_target_pos = false
		_estimated_target_velocity = Vector3.ZERO
		return
	last_known_target_position = target.global_position
	if _has_tracked_target_pos and step > 0.0001:
		var delta_pos := target.global_position - _last_tracked_target_pos
		delta_pos.y = 0.0
		_estimated_target_velocity = delta_pos / step
	_last_tracked_target_pos = target.global_position
	_has_tracked_target_pos = true


func _queue_detection_update() -> void:
	if is_inside_tree() and is_node_ready():
		_apply_detection_radius.call_deferred()


func _apply_detection_radius() -> void:
	if not is_inside_tree():
		return
	var collision := get_node_or_null(^"TargetDetector/CollisionShape3D") as CollisionShape3D
	if collision == null or collision.shape == null:
		return
	if not collision.shape.resource_local_to_scene:
		collision.shape = collision.shape.duplicate()
	var shape := collision.shape as CylinderShape3D
	if shape != null:
		var extra := detection_hysteresis_meters if is_awake else 0.0
		var anger_extra := (
			anger_radius_bonus_meters if _anger_detect_remaining_seconds > 0.0 else 0.0
		)
		shape.radius = outer_detection_radius_meters + extra + anger_extra


func _setup_luminous_vfx() -> void:
	_glow_material = ShaderMaterial.new()
	_glow_material.shader = GLOW_SHADER
	if is_instance_valid(visual) and is_instance_valid(visual.sprite):
		var existing_overlay := visual.sprite.material_overlay
		if existing_overlay != null:
			var tail := existing_overlay
			while tail.next_pass != null:
				tail = tail.next_pass
			tail.next_pass = _glow_material
		else:
			visual.sprite.material_overlay = _glow_material

	var vfx_anchor: Node3D = bullet_spawn if is_instance_valid(bullet_spawn) else self
	var offset := Vector3.ZERO if is_instance_valid(bullet_spawn) else Vector3(0.0, 2.0, 0.25)

	_venom_light = OmniLight3D.new()
	_venom_light.name = "VenomBudLight"
	_venom_light.light_color = NORMAL_GLOW_COLOR
	_venom_light.light_energy = 0.0
	_venom_light.omni_range = 3.2
	_venom_light.shadow_enabled = false
	_venom_light.position = offset
	vfx_anchor.add_child(_venom_light)

	_ambient_spores = ACID_POOL_SCRIPT.create_gpu_particles(
		"AmbientVenomSpores",
		ACID_POOL_SCRIPT.SPORE_TEXTURE,
		AMBIENT_SPORE_COUNT,
		AMBIENT_SPORE_LIFETIME_SECONDS,
		0.48,
		Vector2(0.42, 0.42),
		true,
		true,
		true
	)
	var spore_process := _ambient_spores.process_material as ParticleProcessMaterial
	spore_process.initial_velocity_min = 0.08
	spore_process.initial_velocity_max = 0.35
	spore_process.gravity = Vector3(0.0, 0.14, 0.0)
	spore_process.scale_min = 0.45
	spore_process.scale_max = 1.15
	spore_process.color_ramp = ACID_POOL_SCRIPT.create_fade_ramp_texture(
		Color(0.92, 0.58, 1.0, 0.94) if _uses_purple_acid() else Color(0.84, 1.0, 0.46, 0.94),
		Color(0.56, 0.18, 0.92, 0.0) if _uses_purple_acid() else Color(0.28, 0.94, 0.38, 0.0)
	)
	_ambient_spores.position = offset
	vfx_anchor.add_child(_ambient_spores)
	_sync_glow_vfx()


func _sync_glow_vfx() -> void:
	var active_awake := is_awake and not dead and not is_burrowed
	var effective_charge := 0.0 if is_burrowed else maxf(_charge_glow_strength, _hit_glow_boost)
	var effective_counter := (
		_charge_counter_mix if _charge_glow_strength > 0.01 else (1.0 if _pending_counter else 0.0)
	)
	if is_instance_valid(_ambient_spores):
		_ambient_spores.emitting = active_awake
	if is_instance_valid(_venom_light):
		_venom_light.light_color = NORMAL_GLOW_COLOR.lerp(COUNTER_GLOW_COLOR, effective_counter)
		_venom_light.light_energy = (
			(LIGHT_ENERGY_AWAKE if active_awake else 0.0)
			+ effective_charge * LIGHT_ENERGY_CHARGE_BONUS
		)
	if (
		_glow_material == null
		or not is_instance_valid(visual)
		or not is_instance_valid(visual.sprite)
		or visual.sprite.texture == null
	):
		return
	var sprite := visual.sprite
	var cols := maxi(1, sprite.hframes)
	var rows := maxi(1, sprite.vframes)
	var frame_idx := clampi(sprite.frame, 0, cols * rows - 1)
	var col := frame_idx % cols
	var row := frame_idx / cols
	var uv_size := Vector2(1.0 / float(cols), 1.0 / float(rows))
	var uv_offset := Vector2(float(col) * uv_size.x, float(row) * uv_size.y)
	var tex_size := sprite.texture.get_size()
	var cell_w := tex_size.x * uv_size.x
	var cell_h := maxf(1.0, tex_size.y * uv_size.y)
	_glow_material.set_shader_parameter(&"sprite_texture", sprite.texture)
	_glow_material.set_shader_parameter(&"frame_uv_offset", uv_offset)
	_glow_material.set_shader_parameter(&"frame_uv_size", uv_size)
	_glow_material.set_shader_parameter(&"frame_aspect", cell_w / cell_h)
	_glow_material.set_shader_parameter(
		&"idle_pulse_strength", IDLE_GLOW_AWAKE if active_awake else 0.0
	)
	_glow_material.set_shader_parameter(&"charge_strength", effective_charge)
	_glow_material.set_shader_parameter(&"counter_mix", effective_counter)
