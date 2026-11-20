class_name VenomVine
extends EnemyBase
## Cây dây leo bắn axit cố định cho vùng Forest: ngụy trang theo cự ly, AI đón đầu & tránh chồng.

const AI_CLASS := preload("res://gameplay/enemies/venom_vine/venom_vine_ai.gd")
const PROJECTILE_SCRIPT := preload("res://gameplay/enemies/venom_vine/venom_pool_projectile.gd")
const ACID_POOL_SCRIPT := preload("res://gameplay/enemies/venom_vine/venom_acid_pool.gd")
const DORMANT_TEXTURE := preload("res://assets/sprites/enemies/venom_vine/venom_vine_dormant.png")
const ACTIVE_TEXTURE := preload(
	"res://assets/sprites/enemies/venom_vine/venom_vine_active_sheet.png"
)

const AGITATION_DECAY_PER_SECOND := 0.12
const AGITATION_PER_HIT := 0.35
const AGITATION_INNER_GAIN_PER_SECOND := 0.15
const MIN_FLIGHT_SECONDS := 0.32
const MAX_FLIGHT_SECONDS := 0.85

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
@export_range(0.0, 5.0, 0.05, "suffix:s") var wake_attack_delay_seconds: float = 0.55
@export_range(0.2, 15.0, 0.1, "suffix:s") var vigilant_duration_seconds: float = 3.5
@export_range(0.1, 2.0, 0.05, "suffix:s") var retract_duration_seconds: float = 0.35
## Độ mở rộng bán kính nhận diện tạm thời (m) khi bị đánh tầm xa.
@export_range(0.0, 15.0, 0.5, "suffix:m") var anger_radius_bonus_meters: float = 2.5
@export_range(0.5, 20.0, 0.5, "suffix:s") var anger_detect_duration_seconds: float = 6.0

@export_group("Outer Ring Attack")
@export_range(1, 5, 1) var outer_shots_per_volley: int = 1
@export_range(0.5, 10.0, 0.1, "suffix:s") var outer_cooldown_seconds: float = 3.2
@export_range(0.05, 2.0, 0.05, "suffix:s") var outer_shot_interval_seconds: float = 0.28

@export_group("Inner Ring Attack")
@export_range(2, 10, 1) var inner_shots_per_volley: int = 3
@export_range(10.0, 180.0, 2.0, "suffix:deg") var inner_fan_degrees: float = 64.0
@export_range(0.5, 10.0, 0.1, "suffix:s") var inner_cooldown_seconds: float = 1.75
@export_range(0.05, 2.0, 0.05, "suffix:s") var inner_shot_interval_seconds: float = 0.16

@export_group("Charge & Prediction")
@export_range(0.2, 3.0, 0.05, "suffix:s") var charge_duration_seconds: float = 0.75
@export_range(0.1, 3.0, 0.05, "suffix:s") var recover_duration_seconds: float = 0.45
@export_range(0.0, 1.2, 0.05) var lead_accuracy: float = 0.75
@export_range(0.0, 6.0, 0.1, "suffix:m") var max_lead_meters: float = 2.0
## Khoảng lệch tối thiểu/tối đa quanh Player (m) để bắn vùng lân cận thay vì bắn trực diện.
@export_range(0.3, 5.0, 0.05, "suffix:m") var aim_scatter_min_meters: float = 1.15
@export_range(0.5, 6.0, 0.05, "suffix:m") var aim_scatter_max_meters: float = 2.15
## Giới hạn khoảng cách rơi đạn tính từ gốc cây (m).
@export_range(0.5, 10.0, 0.1, "suffix:m") var min_shot_distance_meters: float = 1.6
@export_range(1.0, 20.0, 0.1, "suffix:m") var max_shot_distance_meters: float = 6.2

@export_group("Acid Projectile & Pool")
@export_range(0.5, 6.0, 0.1, "suffix:m") var projectile_arc_height_meters: float = 2.4
@export_range(0.4, 5.0, 0.05, "suffix:m") var pool_radius_meters: float = 1.05
@export_range(0.5, 15.0, 0.1, "suffix:s") var pool_duration_seconds: float = 4.2
@export_range(0.1, 4.0, 0.05, "suffix:s") var pool_tick_interval_seconds: float = 0.85
@export_range(0.1, 20.0, 0.1) var pool_tick_damage_hp: float = 0.5
@export_range(1, 12, 1) var max_active_pools: int = 4

@export_group("Hit Reaction & Counter")
## Số đòn trúng từ Player để kích hoạt phản công (đánh trúng lúc đang gồng tính gấp đôi).
@export_range(1, 10, 1) var hits_before_counter: int = 2
@export_range(0.5, 15.0, 0.1, "suffix:s") var counter_cooldown_seconds: float = 3.0
@export_range(0.15, 2.0, 0.05, "suffix:s") var counter_charge_seconds: float = 0.35
@export_range(1, 8, 1) var counter_inner_shots: int = 3
@export_range(1, 6, 1) var counter_outer_shots: int = 2
@export_range(0.4, 3.0, 0.05, "suffix:m") var counter_pool_radius_meters: float = 0.9
@export_range(0.05, 1.0, 0.01, "suffix:s") var hit_flinch_seconds: float = 0.22

var ai: VenomVineAI
var is_awake: bool = false
var ambushed_wake: bool = false
var agitation: float = 0.0
var attack_cooldown_remaining: float = 0.0
var last_known_target_position: Vector3 = Vector3.ZERO
var _active_pools: Array[VenomAcidPool] = []
var _last_tracked_target_pos: Vector3 = Vector3.ZERO
var _has_tracked_target_pos: bool = false
var _estimated_target_velocity: Vector3 = Vector3.ZERO
var _is_dormant_sheet: bool = true
var _anger_detect_remaining_seconds: float = 0.0
var _hits_toward_counter: int = 0
var _counter_cooldown_remaining_seconds: float = 0.0
var _pending_counter: bool = false
var _flinch_remaining_seconds: float = 0.0

@onready var bullet_spawn: Marker3D = $Direction/BulletSpawn


func _ready() -> void:
	ai = AI_CLASS.new()
	_apply_detection_radius()
	super()
	set_sprite_sheet_mode(true)
	damaged.connect(_on_vine_damaged)


func _physics_process(delta: float) -> void:
	var step := maxf(0.0, delta)
	attack_cooldown_remaining = maxf(0.0, attack_cooldown_remaining - step)
	_counter_cooldown_remaining_seconds = maxf(0.0, _counter_cooldown_remaining_seconds - step)
	_flinch_remaining_seconds = maxf(0.0, _flinch_remaining_seconds - step)
	agitation = maxf(0.0, agitation - AGITATION_DECAY_PER_SECOND * step)
	if _anger_detect_remaining_seconds > 0.0:
		_anger_detect_remaining_seconds = maxf(0.0, _anger_detect_remaining_seconds - step)
		if _anger_detect_remaining_seconds <= 0.0:
			_queue_detection_update()
	_update_target_velocity_estimate(step)
	super(delta)


func receive_damage(damage: DamageContext) -> float:
	var attack_state := (
		fsm.current_state as VenomVineAttack
		if is_instance_valid(fsm) and fsm.current_state is VenomVineAttack
		else null
	)
	var was_charging := attack_state != null and attack_state.is_charging()
	var applied := super(damage)
	if (
		applied <= 0.0
		or dead
		or not hp.is_alive()
		or damage == null
		or damage.source_team != CombatTeams.PLAYER
	):
		return applied

	_hits_toward_counter += 2 if was_charging else 1
	if (
		not _pending_counter
		and _counter_cooldown_remaining_seconds <= 0.0
		and _hits_toward_counter >= maxi(1, hits_before_counter)
	):
		_pending_counter = true
		_hits_toward_counter = 0
		_counter_cooldown_remaining_seconds = counter_cooldown_seconds

	var in_hit_or_attack := (
		is_instance_valid(fsm)
		and is_instance_valid(fsm.current_state)
		and fsm.current_state.name in [&"Hit", &"Attack"]
	)
	if is_awake and not in_hit_or_attack:
		_flinch_remaining_seconds = hit_flinch_seconds
		play_directional_animation(&"hit", true)
	return applied


func set_awake(awake: bool) -> void:
	if is_awake == awake:
		return
	is_awake = awake
	_queue_detection_update()


func play_directional_animation(action: StringName, restart: bool = false) -> bool:
	if action in [&"idle", &"charge", &"shoot", &"hit", &"death"]:
		set_sprite_sheet_mode(false)
	return super(action, restart)


func set_sprite_sheet_mode(dormant: bool) -> void:
	if not is_instance_valid(visual) or not is_instance_valid(visual.sprite):
		return
	if _is_dormant_sheet == dormant and visual.sprite.texture != null:
		return
	_is_dormant_sheet = dormant
	if is_instance_valid(visual.animation_player):
		visual.animation_player.stop()
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
	plan["pool_config"] = pool_cfg
	return plan


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
		"tick_damage_hp": pool_tick_damage_hp,
		"snare_slow_ratio": 0.0,
		"split_pod_count": 0,
		"use_thorny_pod": false,
	}


func fire_shot_at(landing_target: Vector3, custom_pool_config: Dictionary = {}) -> void:
	if dead or data == null:
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
	var flight_seconds := clampf(0.28 + flat_dist * 0.045, MIN_FLIGHT_SECONDS, MAX_FLIGHT_SECONDS)
	var config := build_pool_config() if custom_pool_config.is_empty() else custom_pool_config
	var proj := PROJECTILE_SCRIPT.new() as VenomPoolProjectile
	proj.setup(
		self,
		team,
		spawn_pos,
		landing_target,
		flight_seconds,
		projectile_arc_height_meters,
		data.attack_damage,
		config
	)
	proj.impacted.connect(_on_projectile_impacted)
	parent.add_child(proj)


func _on_projectile_impacted(_landing_pos: Vector3, pool: VenomAcidPool) -> void:
	_prune_active_pools()
	if is_instance_valid(pool):
		_active_pools.append(pool)
	while _active_pools.size() > max_active_pools:
		var oldest := _active_pools.pop_front() as VenomAcidPool
		if is_instance_valid(oldest) and not oldest.is_fading():
			oldest.begin_fade_out()


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
