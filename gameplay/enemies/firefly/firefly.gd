class_name FireflyEnemy
extends EnemyBase
## Đom đóm bay vùng Misty Swamp: nghỉ dưới đất, bay lên bất tử khi thấy Player,
## phát nổ thả chất độc khi Player áp sát rồi rơi kiệt sức để Foxy tiêu diệt.

enum GroundReactionKind {
	SWIFT_ESCAPE,
	POLLEN_VENT_ESCAPE,
	GALE_PULSE_ESCAPE,
}

const AI_CLASS := preload("res://gameplay/enemies/firefly/firefly_ai.gd")
const VFX_CLASS := preload("res://gameplay/enemies/firefly/firefly_vfx.gd")
const POLLEN_FIELD_SCRIPT := preload("res://gameplay/enemies/firefly/firefly_pollen_field.gd")
const EMBER_MOTE_SCRIPT := preload("res://gameplay/enemies/firefly/firefly_ember_mote.gd")
const GROUND_TEXTURE := preload("res://assets/sprites/enemies/firefly/firefly_ground_sheet.png")
const AIR_TEXTURE := preload("res://assets/sprites/enemies/firefly/firefly_air_sheet.png")

const COUNTER_STATE_PRIORITY := 65
const REACTION_PUSH_SPEED := 4.8
const GROUND_OFFSET_Y := 188.0
const AIR_OFFSET_Y := 42.0
const BOB_FREQUENCY_RADIANS := 4.8
const SHADOW_BASE_SCALE := 1.05
const SHADOW_MIN_SCALE := 0.48
const SHADOW_GROUND_OFFSET_Y := 0.03
const REST_GLOW_STRENGTH := 0.48
const HOVER_GLOW_STRENGTH := 0.85
const CHARGE_GLOW_STRENGTH := 1.7
const EXHAUSTED_GLOW_STRENGTH := 0.36
const REST_LIGHT_ENERGY := 0.55
const HOVER_LIGHT_ENERGY := 1.05
const CHARGE_LIGHT_ENERGY := 2.2
const EXHAUSTED_LIGHT_ENERGY := 0.44
const REST_LIGHT_COLOR := Color(1.0, 0.82, 0.28)
const HOVER_LIGHT_COLOR := Color(0.84, 1.0, 0.24)
const CHARGE_LIGHT_COLOR := Color(1.0, 0.56, 0.16)
const EXHAUSTED_LIGHT_COLOR := Color(1.0, 0.74, 0.24)
const DROPLET_FLIGHT_SECONDS := 0.36
const DROPLET_ARC_HEIGHT_METERS := 1.15
const BLAST_KNOCKBACK_SPEED := 7.5

@export_group("Flight Altitude & Timing")
## Độ cao bay ổn định trên không (m) — bay cao rõ rệt hẳn lên trên đầu Foxy.
@export_range(2.0, 9.0, 0.1, "suffix:m") var hover_altitude_meters: float = 4.6
## Độ cao lúc gồng chuẩn bị nổ (m) — hơi hạ nhẹ nhưng vẫn cao hơn đỉnh đầu Foxy.
@export_range(1.5, 8.0, 0.1, "suffix:m") var charge_altitude_meters: float = 3.6
## Ngưỡng độ cao (m) tính đang bay (chỉ chạm hẳn đất <= mức này HurtBox mới mở).
@export_range(0.1, 1.5, 0.05, "suffix:m") var airborne_hurt_threshold_meters: float = 0.25
## Thời gian cất cánh vỗ cánh bay lên từ mặt đất lên độ cao ổn định (s).
@export_range(0.3, 3.5, 0.05, "suffix:s") var takeoff_duration_seconds: float = 1.15
## Thời gian hạ cánh nhẹ nhàng về nghỉ khi hết giờ bay hoặc mất dấu quay về tổ (s).
@export_range(0.3, 4.0, 0.05, "suffix:s") var gentle_land_duration_seconds: float = 1.55
## Thời gian rơi có sức cản không khí xuống đất sau khi nổ cạn lực (con bọ nhẹ rơi chậm dần).
@export_range(0.25, 3.0, 0.05, "suffix:s") var fall_to_ground_seconds: float = 1.35
## Thời gian nghỉ nhẹ dưới đất sau khi hạ cánh hết giờ bay (s).
@export_range(0.4, 6.0, 0.1, "suffix:s") var gentle_rest_seconds: float = 1.05
## Thời gian bay tự do tối thiểu sau khi giật mình cất cánh (kể cả Player bỏ đi ngay) (s).
@export_range(0.5, 10.0, 0.25, "suffix:s") var min_free_flight_seconds: float = 4.0
## Thời gian bay lượn tối đa trước khi mệt phải hạ cánh nghỉ nhẹ (s).
@export_range(2.0, 20.0, 0.5, "suffix:s") var max_hover_seconds: float = 8.5
## Biên độ nhịp dập dềnh cánh côn trùng khi đang bay trên không (m).
@export_range(0.0, 0.8, 0.02, "suffix:m") var hover_bob_amplitude_meters: float = 0.36

@export_group("Detection & Aggro")
## Bán kính nhận diện ngoài (m): vào vòng này Đom đóm thức dậy và bay lên.
@export_range(1.5, 25.0, 0.1, "suffix:m") var outer_detection_radius_meters: float = 7.5:
	set(value):
		outer_detection_radius_meters = maxf(1.5, value)
		_queue_detection_update()
## Bán kính vùng tấn công (m): vào sâu vòng này Đom đóm dừng bay, gồng nổ tại chỗ.
@export_range(0.8, 12.0, 0.1, "suffix:m") var inner_attack_radius_meters: float = 2.75
## Cự ly giật mình bay lên tức thì (m), bỏ qua trễ lúc nghỉ trên đất.
@export_range(0.5, 10.0, 0.1, "suffix:m") var instant_takeoff_distance_meters: float = 4.2
## Độ mở trễ (m) khi đã bay để tránh rớt/cất cánh liên tục ở mép vòng.
@export_range(0.0, 6.0, 0.1, "suffix:m") var detection_hysteresis_meters: float = 1.2:
	set(value):
		detection_hysteresis_meters = maxf(0.0, value)
		_queue_detection_update()
@export_range(0.0, 2.0, 0.05, "suffix:s") var startle_delay_seconds: float = 0.22
@export_range(0.2, 6.0, 0.1, "suffix:s") var search_seconds: float = 1.2

@export_group("Hover Orbit & Glitter Dust")
@export_range(0.2, 3.0, 0.05) var hover_speed_scale: float = 1.0
@export_range(0.0, 2.5, 0.05) var weave_amplitude: float = 1.35
@export_range(0.5, 8.0, 0.1) var weave_frequency: float = 2.8
@export_range(0.4, 6.0, 0.1, "suffix:s") var glitter_drop_interval_seconds: float = 1.65
@export_range(0.2, 2.0, 0.05, "suffix:m") var glitter_pool_radius_meters: float = 0.58
@export_range(0.4, 5.0, 0.1, "suffix:s") var glitter_pool_duration_seconds: float = 1.5
@export_range(0.05, 5.0, 0.05) var glitter_damage_hp: float = 0.35

@export_group("Bio-Detonation & Poison Drop")
@export_range(1.0, 3.0, 0.05, "suffix:s") var charge_duration_seconds: float = 1.25
## Xác suất Đom đóm đủ sức nảy lên bay tiếp thêm nhịp nữa thay vì rớt ngay sau 1 lần nổ.
@export_range(0.0, 1.0, 0.05) var multi_burst_chance: float = 0.65
## Độ cao bật nảy thêm theo phản lực Newton khi túi khí nổ hướng xuống đất (m).
@export_range(0.3, 3.0, 0.05, "suffix:m") var blast_recoil_pop_height_meters: float = 1.35
@export_range(0.2, 1.2, 0.02, "suffix:s") var detonate_recoil_seconds: float = 0.52
## Thời gian lượn hồi nhịp trên không trước khi được phép gồng nổ tiếp nếu chưa rớt (s).
@export_range(0.5, 4.0, 0.1, "suffix:s") var post_burst_hover_cooldown_seconds: float = 1.6
@export_range(0.8, 6.0, 0.1, "suffix:m") var blast_radius_meters: float = 2.35
@export_range(0.5, 5.0, 0.05, "suffix:m") var main_pool_radius_meters: float = 1.35
@export_range(0.5, 15.0, 0.1, "suffix:s") var main_pool_duration_seconds: float = 4.6
@export_range(0.1, 4.0, 0.05, "suffix:s") var pool_tick_interval_seconds: float = 0.85
@export_range(0.1, 20.0, 0.1) var pool_tick_damage_hp: float = 0.6
@export_range(0, 6, 1) var secondary_droplet_count: int = 2
@export_range(0.4, 3.0, 0.05, "suffix:m") var secondary_pool_radius_meters: float = 0.78
@export_range(0.5, 10.0, 0.1, "suffix:s") var secondary_pool_duration_seconds: float = 3.4
@export_range(1, 12, 1) var max_active_pools: int = 5

@export_group("Exhausted Drop")
@export_range(0.8, 8.0, 0.1, "suffix:s") var exhausted_duration_seconds: float = 2.15
## Tổng sát thương nhận trong 1 lần rơi kiệt sức trước khi Đom đóm kích hoạt thoát thân.
@export_range(1.5, 10.0, 0.25) var max_damage_per_exhausted_window: float = 3.8
@export_range(0.3, 4.0, 0.05, "suffix:m") var landing_clearance_meters: float = 0.55

@export_group("Ground Escape Reactions")
## Số đòn tối đa chịu khi đang kiệt sức dưới đất trước khi kích hoạt phản ứng thoát thân.
@export_range(1, 5, 1) var hits_before_counter: int = 2
## Nếu dính đòn rất mạnh khi đang kiệt sức (>= ngưỡng này), giật mình thoát thân ngay sau 1 hit.
@export_range(0.5, 10.0, 0.1) var heavy_hit_reaction_threshold_hp: float = 2.5
@export_range(0.08, 1.0, 0.02, "suffix:s") var swift_escape_windup_seconds: float = 0.18
@export_range(0.15, 1.2, 0.02, "suffix:s") var vent_escape_windup_seconds: float = 0.34
@export_range(0.15, 1.5, 0.05, "suffix:s") var counter_windup_seconds: float = 0.5
@export_range(1.0, 5.0, 0.1, "suffix:m") var counter_blast_radius_meters: float = 2.1
## Sát thương sóng đẩy thoát thân (mặc định 0.0 — chỉ đẩy tạo khoảng trống, tránh ức chế).
@export_range(0.0, 5.0, 0.05) var counter_damage_hp: float = 0.0
@export_range(0.4, 3.0, 0.05, "suffix:m") var counter_pool_radius_meters: float = 0.85
@export_range(0.5, 8.0, 0.1, "suffix:s") var counter_pool_duration_seconds: float = 2.6
@export_range(0.0, 2.0, 0.05, "suffix:s") var vent_pool_arm_delay_seconds: float = 0.55
@export_range(0.1, 5.0, 0.05, "suffix:s") var counter_cooldown_seconds: float = 0.4

var ai: FireflyAI
var home_position: Vector3 = Vector3.ZERO
var altitude_meters: float = 0.0
var is_airborne_alert: bool = false
var defensive_takeoff_pending: bool = false
var remaining_burst_charges: int = 0
var post_burst_attack_cooldown_seconds: float = 0.0
var free_flight_remaining_seconds: float = 0.0
var pending_blast_center: Vector3 = Vector3.ZERO
var pending_landing_spot: Vector3 = Vector3.ZERO
var pending_gentle_land_to_rest: bool = false
var exhausted_remaining_seconds: float = 0.0
var exhausted_window_damage_taken: float = 0.0
var orbit_sign: float = 1.0
var current_reaction_kind: int = GroundReactionKind.SWIFT_ESCAPE
var pending_reaction_windup_seconds: float = 0.18

var _is_ground_sheet: bool = true
var _hover_clock_seconds: float = 0.0
var _active_fields: Array[FireflyPollenField] = []
var _glow_material: ShaderMaterial
var _lantern_light: OmniLight3D
var _ambient_motes: GPUParticles3D
var _air_charge_ring: Sprite3D
var _ground_shadow: Sprite3D
var _glow_mode: int = 0  # 0: rest, 1: hover, 2: charge, 3: exhausted
var _charge_glow_boost: float = 0.0
var _charge_tremor_active: bool = false
var _was_charge_tremor_active: bool = false
var _charge_progress: float = 0.0
var _ground_hit_count: int = 0
var _counter_windup_active: bool = false
var _counter_cooldown_remaining: float = 0.0
var _last_reaction_kind: int = -1


func _ready() -> void:
	ai = AI_CLASS.new()
	home_position = global_position
	orbit_sign = 1.0 if randf() >= 0.5 else -1.0
	_apply_detection_radius()
	super()
	_set_sprite_sheet_mode(true)
	_ground_shadow = VFX_CLASS.create_ground_shadow(self, SHADOW_GROUND_OFFSET_Y)
	_setup_lantern_vfx()
	var vfx_anchor: Node3D = visual if is_instance_valid(visual) else self
	_air_charge_ring = VFX_CLASS.create_air_charge_ring(vfx_anchor)
	set_altitude_meters(0.0)
	damaged.connect(_on_firefly_damaged)


func _process(delta: float) -> void:
	_hover_clock_seconds += maxf(0.0, delta)
	if is_airborne():
		_apply_altitude_transforms()
	_sync_air_charge_telegraph()
	_sync_lantern_vfx()


func _physics_process(delta: float) -> void:
	var step := maxf(0.0, delta)
	if _counter_cooldown_remaining > 0.0:
		_counter_cooldown_remaining = maxf(0.0, _counter_cooldown_remaining - step)
	if post_burst_attack_cooldown_seconds > 0.0:
		post_burst_attack_cooldown_seconds = maxf(0.0, post_burst_attack_cooldown_seconds - step)
	super(delta)


func receive_damage(damage: DamageContext) -> float:
	if is_airborne():
		orbit_sign *= -1.0
		return 0.0
	if dead:
		return super(damage)
	var was_exposed := exhausted_remaining_seconds > 0.0
	var applied := super(damage)
	if applied > 0.0 and not dead and not is_airborne() and not _counter_windup_active:
		if was_exposed:
			exhausted_window_damage_taken += applied
			_ground_hit_count += 1
			if (
				(
					exhausted_window_damage_taken >= max_damage_per_exhausted_window
					or _ground_hit_count >= hits_before_counter
					or applied >= heavy_hit_reaction_threshold_hp
				)
				and _counter_cooldown_remaining <= 0.0
			):
				_start_ground_escape_reaction()
		elif _counter_cooldown_remaining <= 0.0:
			_start_ground_escape_reaction()
	return applied


func request_state(state_name: StringName, priority: int = 0) -> bool:
	if _counter_windup_active and state_name == &"hit":
		return false
	return super(state_name, priority)


func reset_ground_hit_counter() -> void:
	_ground_hit_count = 0
	_counter_windup_active = false


func is_airborne() -> bool:
	return altitude_meters > airborne_hurt_threshold_meters and not dead


func set_altitude_meters(next_altitude: float) -> void:
	altitude_meters = maxf(0.0, next_altitude)
	_apply_altitude_transforms()
	_sync_airborne_combat_state()


func set_glow_mode(mode: int, charge_progress: float = 0.0) -> void:
	_glow_mode = clampi(mode, 0, 3)
	_charge_glow_boost = clampf(charge_progress, 0.0, 1.0)
	_sync_lantern_vfx()


func set_airborne_alert(alert: bool) -> void:
	if is_airborne_alert == alert:
		return
	is_airborne_alert = alert
	_queue_detection_update()


func play_firefly_animation(
	action: StringName, directional: bool = false, restart: bool = false
) -> bool:
	if action in [&"rest_idle", &"rest_alert", &"exhausted", &"hit", &"death"]:
		_set_sprite_sheet_mode(true)
	else:
		_set_sprite_sheet_mode(false)
	if directional:
		return play_directional_animation(action, restart)
	if not is_instance_valid(visual):
		return false
	return visual.play_animation(action, restart)


func play_directional_animation(action: StringName, restart: bool = false) -> bool:
	if action in [&"rest_idle", &"rest_alert", &"exhausted", &"hit", &"death"]:
		_set_sprite_sheet_mode(true)
		if is_instance_valid(visual):
			return visual.play_animation(action, restart)
		return false
	_set_sprite_sheet_mode(false)
	return super(action, restart)


func get_current_zone() -> FireflyAI.Zone:
	if not has_target() or ai == null:
		return FireflyAI.Zone.OUT_OF_RANGE
	return ai.classify_zone(
		_distance_to_target(),
		outer_detection_radius_meters,
		inner_attack_radius_meters,
		detection_hysteresis_meters,
		is_airborne_alert
	)


func compute_self_blast_center() -> Vector3:
	if ai == null:
		return Vector3(global_position.x, home_position.y, global_position.z)
	var space := (
		get_world_3d().direct_space_state if is_inside_tree() and get_world_3d() != null else null
	)
	return ai.snap_point_to_ground(global_position, home_position.y, space, [get_rid()])


func set_air_charge_telegraph(active: bool, progress: float) -> void:
	_charge_tremor_active = active and not dead
	_charge_progress = clampf(progress, 0.0, 1.0)
	_sync_air_charge_telegraph()


func spawn_glitter_mote() -> void:
	if dead or not is_inside_tree():
		return
	var parent := get_parent()
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	var spot := Vector3(global_position.x, home_position.y, global_position.z)
	var space := get_world_3d().direct_space_state if get_world_3d() != null else null
	if space != null and ai != null:
		spot = ai.resolve_ground_spot(
			global_position,
			spot,
			home_position.y,
			glitter_pool_radius_meters,
			[],
			space,
			[get_rid()],
			0.1,
			1.5
		)
	var start_pos := global_position + Vector3.UP * maxf(0.5, altitude_meters * 0.88)
	var mote := EMBER_MOTE_SCRIPT.new() as FireflyEmberMote
	mote.setup(
		self,
		team,
		start_pos,
		spot,
		0.44,
		0.22,
		glitter_pool_radius_meters,
		glitter_pool_duration_seconds,
		0.6,
		glitter_damage_hp
	)
	mote.landed.connect(_on_field_landed)
	parent.add_child(mote)


func execute_detonate_drop(blast_center: Vector3) -> void:
	set_air_charge_telegraph(false, 0.0)
	if data != null:
		_apply_radial_shockwave(
			blast_center, blast_radius_meters, data.attack_damage, &"blast", BLAST_KNOCKBACK_SPEED
		)
	VFX_CLASS.spawn_blast_vfx(get_parent(), blast_center, blast_radius_meters)
	_spawn_pollen_field_at(
		blast_center, main_pool_radius_meters, main_pool_duration_seconds, pool_tick_damage_hp
	)
	_spawn_secondary_ember_motes(blast_center)
	on_detonate_burst(blast_center)


## Thực thi pha kết thúc phản ứng thoát thân dưới đất (chỉ bay, xì phấn hoặc đẩy gió).
func execute_counter_burst() -> void:
	_counter_windup_active = false
	_ground_hit_count = 0
	_counter_cooldown_remaining = counter_cooldown_seconds
	set_air_charge_telegraph(false, 0.0)
	var center := compute_self_blast_center()
	var parent := get_parent()

	match current_reaction_kind:
		GroundReactionKind.SWIFT_ESCAPE:
			VFX_CLASS.spawn_swift_escape_vfx(parent, center)
		GroundReactionKind.POLLEN_VENT_ESCAPE:
			VFX_CLASS.spawn_pollen_vent_vfx(parent, center, counter_pool_radius_meters)
			_spawn_pollen_field_at(
				center,
				counter_pool_radius_meters,
				counter_pool_duration_seconds,
				pool_tick_damage_hp * 0.65,
				vent_pool_arm_delay_seconds
			)
		GroundReactionKind.GALE_PULSE_ESCAPE:
			_apply_radial_shockwave(
				center,
				counter_blast_radius_meters,
				counter_damage_hp,
				&"counter_blast",
				REACTION_PUSH_SPEED
			)
			VFX_CLASS.spawn_gale_pulse_vfx(parent, center, counter_blast_radius_meters)
	on_counter_burst()


## Trả về số phát nổ trong một lượt bay (1-2 phát ngẫu nhiên trước khi cạn lực rơi).
func get_burst_charges_per_flight() -> int:
	return 2 if randf() < multi_burst_chance else 1


## Hook mở rộng cho EliteFirefly quyết định có lướt thả tiếp ngòi nổ không.
func can_continue_bombing_run() -> bool:
	return remaining_burst_charges > 0


## Hook mở rộng cho EliteFirefly thêm hiệu ứng phụ khi phát nổ (vd: Solar Flashbang).
func on_detonate_burst(_blast_center: Vector3) -> void:
	pass


## Hook mở rộng cho EliteFirefly thêm hiệu ứng khi bung đòn phản công dưới đất.
func on_counter_burst() -> void:
	pass


## Hook mở rộng cho EliteFirefly chọn điểm đáp ngay bên cạnh vụ nổ (hoặc lùi nhẹ về phía an toàn).
func select_exhausted_landing_spot(blast_center: Vector3) -> Vector3:
	var recoil_dir := -last_facing_direction
	var avoid_pos := target.global_position if has_target() else Vector3.ZERO
	if has_target():
		var away := Vector3(blast_center.x - avoid_pos.x, 0.0, blast_center.z - avoid_pos.z)
		if not away.is_zero_approx():
			recoil_dir = away.normalized()
	if ai == null:
		return blast_center + recoil_dir * (main_pool_radius_meters + landing_clearance_meters)
	var space := (
		get_world_3d().direct_space_state if is_inside_tree() and get_world_3d() != null else null
	)
	var occupied := EMBER_MOTE_SCRIPT.collect_active_field_spots(self)
	occupied.append({"pos": blast_center, "radius": main_pool_radius_meters})
	return (
		ai
		. select_landing_spot(
			{
				"origin_pos": global_position,
				"blast_center": blast_center,
				"preferred_dir": recoil_dir,
				"has_avoid_pos": has_target(),
				"avoid_pos": avoid_pos,
				"ground_y": home_position.y,
				"pool_radius": main_pool_radius_meters,
				"landing_clearance": landing_clearance_meters,
				"occupied_spots": occupied,
				"space": space,
				"excluded_rids": [get_rid()],
			}
		)
	)


func _apply_radial_shockwave(
	center: Vector3,
	radius_meters: float,
	damage_hp: float,
	hit_tag: StringName,
	knockback_speed: float
) -> void:
	if not is_inside_tree() or get_world_3d() == null:
		return
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius_meters
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, center + Vector3.UP * 0.65)
	query.collision_mask = CombatLayers.PLAYER_HURTBOX
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var hit_actors: Dictionary = {}
	for result in space.intersect_shape(query, 16):
		var hurtbox_node := result.collider as HurtBox
		if hurtbox_node == null or not is_instance_valid(hurtbox_node.actor):
			continue
		var actor_id := hurtbox_node.actor.get_instance_id()
		if hit_actors.has(actor_id):
			continue
		hit_actors[actor_id] = true
		if damage_hp > 0.0:
			var damage := DamageContext.new()
			damage.source = self
			damage.source_team = team
			damage.base_amount_hp = damage_hp
			damage.amount_hp = damage_hp
			damage.tag = hit_tag
			damage.origin = center
			damage.knockback_multiplier = 1.15
			hurtbox_node.take_damage(damage)
		if knockback_speed > 0.0 and hurtbox_node.actor.has_method("_apply_external_push"):
			var actor_node := hurtbox_node.actor as Node3D
			var push_dir := actor_node.global_position - center
			push_dir.y = 0.0
			push_dir = push_dir.normalized() if not push_dir.is_zero_approx() else Vector3.BACK
			hurtbox_node.actor.call("_apply_external_push", push_dir * knockback_speed)


func _start_ground_escape_reaction() -> void:
	var reaction := _pick_next_ground_reaction(exhausted_remaining_seconds > 0.0)
	_last_reaction_kind = reaction
	current_reaction_kind = reaction
	match reaction:
		GroundReactionKind.SWIFT_ESCAPE:
			pending_reaction_windup_seconds = swift_escape_windup_seconds
		GroundReactionKind.POLLEN_VENT_ESCAPE:
			pending_reaction_windup_seconds = vent_escape_windup_seconds
		GroundReactionKind.GALE_PULSE_ESCAPE:
			pending_reaction_windup_seconds = counter_windup_seconds
	_counter_windup_active = true
	_ground_hit_count = 0
	request_state(&"counterflash", COUNTER_STATE_PRIORITY)


func _pick_next_ground_reaction(from_exhausted: bool) -> int:
	var candidates: Array[Dictionary] = [
		{"kind": GroundReactionKind.SWIFT_ESCAPE, "weight": 0.45 if from_exhausted else 0.65},
		{"kind": GroundReactionKind.POLLEN_VENT_ESCAPE, "weight": 0.35 if from_exhausted else 0.35},
	]
	if from_exhausted:
		candidates.append({"kind": GroundReactionKind.GALE_PULSE_ESCAPE, "weight": 0.2})

	var total_weight := 0.0
	for entry in candidates:
		if int(entry["kind"]) == _last_reaction_kind:
			continue
		total_weight += float(entry["weight"])
	var roll := randf() * maxf(0.001, total_weight)
	var accum := 0.0
	for entry in candidates:
		if int(entry["kind"]) == _last_reaction_kind:
			continue
		accum += float(entry["weight"])
		if roll <= accum:
			return int(entry["kind"])
	return GroundReactionKind.SWIFT_ESCAPE


func _spawn_pollen_field_at(
	world_pos: Vector3,
	radius_meters: float,
	duration_seconds: float,
	tick_damage_hp: float,
	arm_delay_seconds: float = 0.0
) -> void:
	var parent := get_parent()
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	var field := POLLEN_FIELD_SCRIPT.new() as FireflyPollenField
	field.setup(
		self,
		team,
		radius_meters,
		duration_seconds,
		pool_tick_interval_seconds,
		tick_damage_hp,
		arm_delay_seconds
	)
	parent.add_child(field)
	field.global_position = world_pos
	_register_field(field)


func _spawn_secondary_ember_motes(blast_center: Vector3) -> void:
	if secondary_droplet_count <= 0 or ai == null:
		return
	var parent := get_parent()
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	var space := (
		get_world_3d().direct_space_state if is_inside_tree() and get_world_3d() != null else null
	)
	var occupied := EMBER_MOTE_SCRIPT.collect_active_field_spots(self)
	var spots := ai.select_droplet_spots(
		blast_center,
		home_position.y,
		main_pool_radius_meters,
		secondary_droplet_count,
		secondary_pool_radius_meters,
		occupied,
		space,
		[get_rid()]
	)
	var start_pos := blast_center + Vector3.UP * maxf(0.9, charge_altitude_meters * 0.75)
	for spot in spots:
		var mote := EMBER_MOTE_SCRIPT.new() as FireflyEmberMote
		mote.setup(
			self,
			team,
			start_pos,
			spot,
			DROPLET_FLIGHT_SECONDS,
			DROPLET_ARC_HEIGHT_METERS,
			secondary_pool_radius_meters,
			secondary_pool_duration_seconds,
			pool_tick_interval_seconds,
			pool_tick_damage_hp * 0.75
		)
		mote.landed.connect(_on_field_landed)
		parent.add_child(mote)


func _sync_air_charge_telegraph() -> void:
	if is_instance_valid(visual):
		if _charge_tremor_active:
			_was_charge_tremor_active = true
			var swell := lerpf(1.0, 1.38, _charge_progress)
			var pulse := 1.0 + sin(_hover_clock_seconds * 26.0) * 0.06 * _charge_progress
			visual.scale = Vector3.ONE * swell * pulse
			if is_instance_valid(visual.sprite):
				var shake_amp := 0.085 * _charge_progress
				visual.sprite.position = Vector3(
					sin(_hover_clock_seconds * 52.0) * shake_amp,
					cos(_hover_clock_seconds * 47.0) * shake_amp * 0.65,
					0.0
				)
		elif _was_charge_tremor_active:
			_was_charge_tremor_active = false
			visual.scale = Vector3.ONE
			if is_instance_valid(visual.sprite):
				visual.sprite.position = Vector3.ZERO
	if is_instance_valid(_air_charge_ring):
		_air_charge_ring.visible = _charge_tremor_active
		if _charge_tremor_active:
			var ring_scale := lerpf(1.45, 0.72, _charge_progress)
			var blink := 0.65 + 0.35 * sin(_hover_clock_seconds * 22.0)
			_air_charge_ring.scale = Vector3.ONE * ring_scale
			_air_charge_ring.modulate = Color(1.0, lerpf(0.85, 0.42, _charge_progress), 0.16, blink)


func _on_field_landed(_landing_pos: Vector3, field: FireflyPollenField) -> void:
	_register_field(field)


func _register_field(field: FireflyPollenField) -> void:
	_prune_active_fields()
	if is_instance_valid(field):
		_active_fields.append(field)
	while _active_fields.size() > max_active_pools:
		var oldest := _active_fields.pop_front() as FireflyPollenField
		if is_instance_valid(oldest) and not oldest.is_fading():
			oldest.begin_fade_out()


func _prune_active_fields() -> void:
	var kept: Array[FireflyPollenField] = []
	for field in _active_fields:
		if is_instance_valid(field) and not field.is_fading():
			kept.append(field)
	_active_fields = kept


func _apply_altitude_transforms() -> void:
	var wave_a := sin(_hover_clock_seconds * 3.8)
	var wave_b := sin(_hover_clock_seconds * 7.1 + 0.9) * 0.45
	var bob := (wave_a + wave_b) * hover_bob_amplitude_meters * 0.72
	var effective_y := altitude_meters + (bob if is_airborne() else 0.0)
	if is_instance_valid(visual):
		visual.position.y = effective_y
		if is_instance_valid(visual.sprite):
			visual.sprite.render_priority = 4 if is_airborne() else 0
	if is_instance_valid(hurtbox):
		hurtbox.position.y = effective_y
	if is_instance_valid(debug_health_label):
		debug_health_label.position.y = effective_y + 1.25
	if is_instance_valid(_ground_shadow):
		var ratio := clampf(altitude_meters / maxf(0.1, hover_altitude_meters), 0.0, 1.0)
		var shadow_scale := lerpf(SHADOW_BASE_SCALE, SHADOW_MIN_SCALE, ratio)
		_ground_shadow.scale = Vector3.ONE * shadow_scale
		_ground_shadow.modulate = Color(0.04, 0.06, 0.02, lerpf(0.56, 0.32, ratio))


func _sync_airborne_combat_state() -> void:
	if dead:
		return
	var airborne := is_airborne()
	if is_instance_valid(hurtbox):
		hurtbox.enabled = not airborne
		hurtbox.monitorable = not airborne
		hurtbox.monitoring = not airborne
	if airborne:
		collision_layer = 0
		collision_mask = CombatLayers.WORLD
	else:
		collision_layer = CombatLayers.ENEMY_BODY
		collision_mask = CombatLayers.ENEMY_BODY_MASK


func _set_sprite_sheet_mode(grounded: bool) -> void:
	if not is_instance_valid(visual) or not is_instance_valid(visual.sprite):
		return
	if _is_ground_sheet == grounded and visual.sprite.texture != null:
		return
	_is_ground_sheet = grounded
	if is_instance_valid(visual.animation_player):
		visual.animation_player.stop()
	if grounded:
		visual.sprite.frame = 0
		visual.sprite.texture = GROUND_TEXTURE
		visual.sprite.hframes = 4
		visual.sprite.vframes = 1
		visual.sprite.offset = Vector2(0.0, GROUND_OFFSET_Y)
		visual.sprite.flip_h = false
		if (
			is_instance_valid(visual.animation_player)
			and visual.animation_player.has_animation(&"rest_idle")
		):
			visual.animation_player.assigned_animation = &"rest_idle"
	else:
		visual.sprite.frame = 0
		visual.sprite.texture = AIR_TEXTURE
		visual.sprite.hframes = 4
		visual.sprite.vframes = 3
		visual.sprite.offset = Vector2(0.0, AIR_OFFSET_Y)
		if (
			is_instance_valid(visual.animation_player)
			and visual.animation_player.has_animation(&"hover_down")
		):
			visual.animation_player.assigned_animation = &"hover_down"


func _setup_lantern_vfx() -> void:
	var vfx_anchor: Node3D = visual if is_instance_valid(visual) else self
	var sprite := visual.sprite if is_instance_valid(visual) else null
	var rig := VFX_CLASS.setup_lantern_rig(vfx_anchor, sprite, REST_LIGHT_COLOR, REST_LIGHT_ENERGY)
	_glow_material = rig.glow_material
	_lantern_light = rig.lantern_light
	_ambient_motes = rig.ambient_motes
	_sync_lantern_vfx()


func _sync_lantern_vfx() -> void:
	var alive := not dead
	var strength := 0.0
	var active_mix := 0.0
	var charge_mix := 0.0
	var light_energy := 0.0
	var light_color := REST_LIGHT_COLOR

	if alive:
		match _glow_mode:
			0:
				strength = REST_GLOW_STRENGTH
				light_energy = REST_LIGHT_ENERGY
				light_color = REST_LIGHT_COLOR
			1:
				strength = HOVER_GLOW_STRENGTH
				active_mix = 1.0
				light_energy = HOVER_LIGHT_ENERGY
				light_color = HOVER_LIGHT_COLOR
			2:
				strength = lerpf(HOVER_GLOW_STRENGTH, CHARGE_GLOW_STRENGTH, _charge_glow_boost)
				active_mix = 1.0
				charge_mix = _charge_glow_boost
				light_energy = lerpf(HOVER_LIGHT_ENERGY, CHARGE_LIGHT_ENERGY, _charge_glow_boost)
				light_color = HOVER_LIGHT_COLOR.lerp(CHARGE_LIGHT_COLOR, _charge_glow_boost)
			3:
				strength = EXHAUSTED_GLOW_STRENGTH
				light_energy = EXHAUSTED_LIGHT_ENERGY
				light_color = EXHAUSTED_LIGHT_COLOR

	if is_instance_valid(_ambient_motes):
		_ambient_motes.emitting = alive
		_ambient_motes.amount_ratio = 0.35 if _glow_mode == 3 else 1.0
	if is_instance_valid(_lantern_light):
		_lantern_light.light_color = light_color
		_lantern_light.light_energy = light_energy

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
	_glow_material.set_shader_parameter(&"glow_strength", strength)
	_glow_material.set_shader_parameter(&"active_mix", active_mix)
	_glow_material.set_shader_parameter(&"charge_mix", charge_mix)


func _on_firefly_damaged(_applied_hp: float) -> void:
	if dead:
		return
	if not is_airborne() and exhausted_remaining_seconds <= 0.0 and not _counter_windup_active:
		defensive_takeoff_pending = true
	if not has_target() and not pending_hit_direction.is_zero_approx():
		face_direction(-pending_hit_direction)


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
		var extra := detection_hysteresis_meters if is_airborne_alert else 0.0
		shape.radius = outer_detection_radius_meters + extra
