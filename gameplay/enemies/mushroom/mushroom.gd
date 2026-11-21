class_name MushroomEnemy
extends EnemyBase
## Sedentary footless spore mushroom: creeps slowly like a plant, sprays spores
## at random times in detection range or immediately in attack range, avoids
## stacking poison when already inside a cloud, and may release poison on knockback.

const AI_CLASS := preload("res://gameplay/enemies/mushroom/mushroom_ai.gd")
const SPORE_CLOUD := preload("res://gameplay/enemies/mushroom/mushroom_spore_cloud.gd")
const NORMAL_TEXTURE := preload("res://assets/sprites/enemies/mushroom/mushroom_footless_4dir.png")
const CHARGE_TEXTURE := preload("res://assets/sprites/enemies/mushroom/mushroom_charge_4dir.png")

const CHARGE_ANIMATION_SECONDS := 1.6
const HOP_TAKEOFF_PHASE := 0.18
const HOP_LAND_PHASE := 0.84
const HOP_GROUND_SPEED_FACTOR := 0.38
const HOP_AIR_SPEED_BOOST := 1.55
const HOP_SHADOW_RADIUS := 0.46
const HOP_SHADOW_OFFSET_METERS := 0.025
const HOP_STEP_DUST_AMOUNT := 10
const HOP_STEP_DUST_LIFETIME := 0.42
const CHARGE_TINT := Color(1.0, 1.0, 0.55, 1.0)
const CHARGE_PULSE_COUNT := 4.0
const HOP_CHECK_UP_METERS := 1.2
const HOP_CHECK_DOWN_METERS := 2.4
const HOP_GROUND_SAMPLE_FRACTIONS := [0.25, 0.5, 0.75, 1.0]
const EVADE_DIRECTION_ANGLES := [
	0.0,
	PI / 4.0,
	-PI / 4.0,
	PI / 2.0,
	-PI / 2.0,
	3.0 * PI / 4.0,
	-3.0 * PI / 4.0,
	PI,
]
const EVADE_DISTANCE_FACTORS := [1.0, 0.75, 0.5]

@export_group("Detection & Ambush")
## Bán kính nhận diện (m). Nấm chỉ phát hiện, đuổi theo và phun độc khi Player ở trong vòng này.
@export_range(0.5, 30.0, 0.1, "suffix:m") var detection_radius: float = 6.0
## Cự ly thức tỉnh ngay (m): Player vào gần hơn mức này là nấm tỉnh liền, bỏ qua trễ giả vờ.
@export_range(0.5, 15.0, 0.1, "suffix:m") var ambush_wake_distance: float = 4.2
## Thời gian tối thiểu (s) giả vờ đứng im ngụy trang khi Player mới bước vào rìa vùng nhận diện.
@export_range(0.0, 5.0, 0.05, "suffix:s") var ambush_delay_min_seconds: float = 0.35
## Thời gian tối đa (s) giả vờ đứng im ngụy trang khi Player mới bước vào rìa vùng nhận diện.
@export_range(0.0, 5.0, 0.05, "suffix:s") var ambush_delay_max_seconds: float = 0.65
## Thời gian nhìn/cảnh giác Player (s) sau khi tỉnh dậy trước khi bắt đầu tiến lại gần.
@export_range(0.0, 5.0, 0.05, "suffix:s") var observe_seconds: float = 0.55
## Thời gian (s) đi tới vị trí thấy Player lần cuối sau khi Player thoát khỏi vùng nhận diện.
@export_range(0.5, 15.0, 0.1, "suffix:s") var search_seconds: float = 3.0

@export_group("Movement & Patrol")
## Bán kính tuần tra tối đa tính từ vị trí spawn ban đầu (m); vượt quá sẽ quay đầu về.
@export_range(1.0, 40.0, 0.5, "suffix:m") var movement_radius: float = 12.0
## Hệ số tốc độ khi đuổi theo (nhân với move_speed trong mushroom_data.tres).
## Giữ bằng wander để vòng nhận diện chỉ điều hướng, không làm nấm chạy nhanh.
@export_range(0.05, 5.0, 0.05) var chase_speed_scale: float = 0.75
## Hệ số tốc độ khi đi lang thang quanh gốc (nhân với move_speed trong mushroom_data.tres).
@export_range(0.05, 5.0, 0.05) var wander_speed_scale: float = 0.7
## Độ cao mỗi bước nhảy khi đi/đuổi (m) để nhịp nhảy tách bạch rõ khỏi mặt đất.
@export_range(0.1, 1.2, 0.02, "suffix:m") var hop_height: float = 0.44
## Chu kỳ 1 bước nhảy hoàn chỉnh (s), tự co tốc độ animation walk_* (0.68s) theo nhịp này.
@export_range(0.25, 1.5, 0.02, "suffix:s") var hop_cycle_seconds: float = 0.62
## Khoảng cách tối thiểu (m) để cân nhắc nhảy xa áp sát Player.
@export_range(1.0, 10.0, 0.1, "suffix:m") var approach_leap_trigger_distance: float = 4.5
## Quãng đường tối đa (m) của cú nhảy áp sát.
@export_range(1.0, 8.0, 0.1, "suffix:m") var approach_leap_distance_meters: float = 3.2
## Thời gian (s) của cú nhảy áp sát.
@export_range(0.2, 1.5, 0.05, "suffix:s") var approach_leap_duration_seconds: float = 0.55
## Độ cao cung nhảy (m) khi áp sát.
@export_range(0.2, 2.0, 0.05, "suffix:m") var approach_leap_height: float = 1.0
## Thời gian hồi (s) giữa các cú nhảy áp sát.
@export_range(0.5, 10.0, 0.1, "suffix:s") var approach_leap_cooldown_seconds: float = 2.8
## Xác suất nấm chọn nhảy xa khi Player ở đủ xa.
@export_range(0.0, 1.0, 0.05) var approach_leap_chance: float = 0.6
## Thời gian tối thiểu (s) mỗi lượt đi lang thang ngẫu nhiên khi chưa thấy Player.
@export_range(0.2, 10.0, 0.1, "suffix:s") var wander_min_seconds: float = 1.2
## Thời gian tối đa (s) mỗi lượt đi lang thang ngẫu nhiên khi chưa thấy Player.
@export_range(0.2, 10.0, 0.1, "suffix:s") var wander_max_seconds: float = 2.8
## Thời gian tối thiểu (s) đứng im ngụy trang giữa các lượt đi lang thang.
@export_range(0.2, 15.0, 0.1, "suffix:s") var disguise_min_seconds: float = 2.0
## Thời gian tối đa (s) đứng im ngụy trang giữa các lượt đi lang thang.
@export_range(0.2, 15.0, 0.1, "suffix:s") var disguise_max_seconds: float = 4.5

@export_group("Charge & Poison Attack")
## Thời gian gồng Charge báo hiệu trước khi phun độc (s).
## Mặc định 1.6s (trong khoảng 1-2s, khớp animation 1.6s) để Player kịp quan sát và né.
@export_range(0.5, 4.0, 0.05, "suffix:s") var charge_duration_seconds: float = 1.6
## Thời gian khựng lại sau khi phun xong đám mây độc (s) trước khi di chuyển tiếp.
@export_range(0.05, 3.0, 0.05, "suffix:s") var recovery_seconds: float = 0.5
## Cự ly gần (m): Player bước vào tầm này là nấm bắt buộc gồng Charge phun độc khi hết hồi chiêu.
@export_range(0.2, 10.0, 0.1, "suffix:m") var attack_range: float = 2.5
## Thời gian hồi chiêu phun độc (s) áp dụng sau mỗi lần tạo mây độc thành công.
@export_range(0.2, 20.0, 0.1, "suffix:s") var spore_cooldown_seconds: float = 3.1
## Chu kỳ (s) tung xúc xắc phun độc ngẫu nhiên khi đang tiến tới Player trong vùng nhận diện.
@export_range(0.2, 20.0, 0.1, "suffix:s") var chase_spore_interval_seconds: float = 1.7
## Xác suất (0.0 - 1.0) phun độc ngẫu nhiên mỗi chu kỳ khi đang đuổi trong vùng nhận diện.
@export_range(0.0, 1.0, 0.05) var chase_spore_chance: float = 0.4
## Bán kính gây sát thương của đám mây độc (m). Nên nhỏ hơn evade_distance để Player kịp né.
@export_range(0.4, 10.0, 0.1, "suffix:m") var cloud_radius: float = 2.6
## Hệ số (0.1 - 1.0) nhân với cloud_radius: nấm đứng trong vùng này sẽ không phun chồng độc mới.
@export_range(0.1, 1.0, 0.05) var cloud_overlap_block_factor: float = 0.85
## Thời gian tồn tại (s) của mỗi đám mây độc trước khi mờ dần và biến mất.
@export_range(0.2, 20.0, 0.1, "suffix:s") var cloud_duration_seconds: float = 3.5
## Thời gian (s) để bụi độc và sương mặt đất đậm dần lên mức tối đa khi vừa bung ra.
@export_range(0.05, 3.0, 0.05, "suffix:s") var spore_ramp_seconds: float = 0.8
## Chu kỳ gây sát thương độc (s/lần) lên Player đứng trong vùng mây độc.
@export_range(0.1, 5.0, 0.05, "suffix:s") var poison_interval_seconds: float = 0.85
## Lượng máu trừ mỗi nhịp độc (HP/tick).
@export_range(0.1, 100.0, 0.1) var poison_damage: float = 1.0
## Số lượng đám mây độc tối đa tồn tại cùng lúc của con nấm này; vượt quá sẽ tắt đám cũ nhất.
@export_range(1, 10, 1) var max_active_clouds: int = 3

@export_group("Spore Visual & Particles")
## Hệ số mở rộng vùng hiển thị khói/bụi độc so với collider gây sát thương thật.
## Mặc định 1.15 để rìa ngoài khói trông rõ và rộng hơn nhẹ so với vùng trúng độc.
@export_range(0.5, 2.0, 0.05) var visual_spread_scale: float = 1.15
## Số lượng hạt bụi độc (FloatingSpores) phát ra trong mỗi đám mây độc.
@export_range(10, 1000, 10) var spore_particle_count: int = 240
## Số lượng cụm khói mờ (PoisonMist) 3D trong mỗi đám mây độc.
@export_range(1, 100, 1) var mist_particle_count: int = 64
## Thời gian tồn tại (s) của mỗi hạt bụi độc.
@export_range(0.2, 10.0, 0.1, "suffix:s") var spore_particle_lifetime: float = 2.0
## Thời gian tồn tại (s) của mỗi cụm khói mờ.
@export_range(0.2, 10.0, 0.1, "suffix:s") var mist_particle_lifetime: float = 2.2
## Độ đậm tối đa (0.0 - 1.0) của lớp sương mờ tự nhiên dưới mặt đất tại tâm đám độc.
@export_range(0.0, 1.0, 0.02) var ground_mist_opacity: float = 0.26
## Hệ số phóng to mặt phẳng sương dưới đất theo cloud_radius (span = cloud_radius * scale).
@export_range(0.5, 5.0, 0.05) var ground_mist_scale: float = 2.45

@export_group("Defensive Knockback")
## Quãng đường bật lùi tối đa (m) khi dính đòn nhẹ để giữ nhịp giao tranh gần.
@export_range(0.2, 12.0, 0.1, "suffix:m") var evade_distance: float = 3.2
## Thời gian thực hiện cú nhảy bật lùi (s).
@export_range(0.1, 2.0, 0.05, "suffix:s") var evade_duration_seconds: float = 0.45
## Thời gian hồi (s) giữa hai lần nhảy bật lùi defensive hop.
@export_range(0.1, 10.0, 0.1, "suffix:s") var evade_cooldown_seconds: float = 2.5
## Độ cao vòng cung (m) nhấc sprite lên khi thực hiện cú nhảy bật lùi.
@export_range(0.0, 2.0, 0.05, "suffix:m") var evade_hop_height: float = 0.4
## Xác suất (0.0 - 1.0) sau khi đáp đất knockback sẽ vào pha Charge phun độc.
@export_range(0.0, 1.0, 0.05) var knockback_spore_chance: float = 0.85
## Tỉ lệ cộng thêm (0.0 - 1.0) vào xác suất phản công nếu nấm bị đánh ngắt lúc đang gồng Charge.
@export_range(0.0, 1.0, 0.05) var interrupted_charge_counter_bonus: float = 0.25
## Thời gian hồi (s) cho phép kích hoạt phản công Charge phun độc sau knockback.
@export_range(0.1, 10.0, 0.1, "suffix:s") var knockback_spore_cooldown_seconds: float = 0.8
## Thời gian gồng Charge (s) khi phản công sau knockback (ngắn hơn gồng thường).
@export_range(0.1, 4.0, 0.05, "suffix:s") var knockback_charge_duration_seconds: float = 0.7

@export_group("Low-HP Escalation")
## Tỉ lệ giảm hồi chiêu tối đa khi máu nấm gần cạn (giữ cân bằng, không spam quá mức).
@export_range(0.0, 0.6, 0.05) var low_hp_cooldown_reduction_max: float = 0.42
## Tỉ lệ rút ngắn thời gian gồng Charge tối đa khi máu nấm gần cạn.
@export_range(0.0, 0.4, 0.05) var low_hp_charge_speedup_max: float = 0.25
## Xác suất cộng thêm tối đa cho đòn phun ngẫu nhiên lúc đuổi khi máu gần cạn.
@export_range(0.0, 0.5, 0.05) var low_hp_chase_chance_bonus: float = 0.32

var home_position: Vector3
var attack_cooldown_remaining: float = 0.0
var ai: MushroomAI
var _hop_phase: float = 0.0
var _was_moving_hop: bool = false
var _move_requested_this_step: bool = false
var _last_walk_anim: String = ""
var _shadow_mesh: MeshInstance3D
var _shadow_material: StandardMaterial3D
var _step_spores: CPUParticles3D
var _charge_base_modulate: Color = Color.WHITE
var _charge_feedback_active: bool = false
var _evade_pending: bool = false
var _evade_away: Vector3 = Vector3.ZERO
var _evade_direction: Vector3 = Vector3.ZERO
var _evade_remaining: float = 0.0
var _evade_speed: float = 0.0
var _evade_cooldown_remaining: float = 0.0
var _knockback_spore_cooldown_remaining: float = 0.0
var _pending_knockback_charge: bool = false
var _approach_leap_direction: Vector3 = Vector3.ZERO
var _approach_leap_remaining: float = 0.0
var _approach_leap_speed: float = 0.0
var _active_clouds: Array[MushroomSporeCloud] = []


func _ready() -> void:
	home_position = global_position
	ai = AI_CLASS.new()
	var detector_shape := $TargetDetector/CollisionShape3D as CollisionShape3D
	detector_shape.shape = detector_shape.shape.duplicate()
	(detector_shape.shape as CylinderShape3D).radius = detection_radius
	super()
	_build_hop_visuals()


func _physics_process(delta: float) -> void:
	var hitstop := get_node_or_null("/root/HitstopController")
	if (
		hitstop != null
		and hitstop.has_method("is_frozen")
		and bool(hitstop.call("is_frozen", self))
	):
		return
	var step := maxf(delta, 0.0)
	_evade_cooldown_remaining = maxf(0.0, _evade_cooldown_remaining - step)
	_knockback_spore_cooldown_remaining = maxf(0.0, _knockback_spore_cooldown_remaining - step)
	if _evade_pending and not dead and not _is_in_hit_state() and can_start_defensive_hop():
		_start_defensive_hop()
	attack_cooldown_remaining = maxf(0.0, attack_cooldown_remaining - step)
	super(delta)
	if dead:
		_evade_remaining = 0.0
		_approach_leap_remaining = 0.0
		_approach_leap_direction = Vector3.ZERO
		_evade_pending = false
		_pending_knockback_charge = false
		_reset_hop_visuals()
		return
	if _evade_remaining > 0.0:
		if _is_in_hit_state():
			_evade_remaining = 0.0
			_reset_hop_visuals()
			return
		_update_defensive_hop(step)
		return
	if _approach_leap_remaining > 0.0:
		if _is_in_hit_state():
			cancel_approach_leap()
		else:
			_update_approach_leap(step)
		return
	_update_walk_hop(step)


func receive_damage(damage: DamageContext) -> float:
	var was_charging := _charge_feedback_active
	var applied := super(damage)
	if (
		applied <= 0.0
		or dead
		or not hp.is_alive()
		or damage == null
		or damage.source_team != CombatTeams.PLAYER
	):
		return applied
	var in_detection := _is_attacker_in_detection(damage.source)
	if not can_trigger_defensive_counter():
		return applied
	var will_hit := _is_in_hit_state()
	var should_roll := (
		in_detection
		and _knockback_spore_cooldown_remaining <= 0.0
		and ai != null
		and ai.roll_knockback_spore(
			knockback_spore_chance,
			was_charging,
			is_inside_poison_cloud(),
			interrupted_charge_counter_bonus
		)
	)
	if not will_hit and _evade_cooldown_remaining <= 0.0:
		_evade_away = pending_hit_direction
		_evade_pending = true
		_evade_cooldown_remaining = evade_cooldown_seconds
		if should_roll:
			_pending_knockback_charge = true
			_knockback_spore_cooldown_remaining = knockback_spore_cooldown_seconds
	elif will_hit and should_roll:
		_pending_knockback_charge = true
		_knockback_spore_cooldown_remaining = knockback_spore_cooldown_seconds
	return applied


func consume_knockback_charge() -> bool:
	if not _pending_knockback_charge:
		return false
	_pending_knockback_charge = false
	return not dead and hp.is_alive()


func is_evading() -> bool:
	return _evade_remaining > 0.0


func can_start_defensive_hop() -> bool:
	return true


func can_trigger_defensive_counter() -> bool:
	return true


func start_approach_leap(direction: Vector3, distance_meters: float) -> bool:
	if dead or is_evading() or _approach_leap_remaining > 0.0:
		return false
	var horizontal_direction := Vector3(direction.x, 0.0, direction.z).normalized()
	var leap_distance := minf(distance_meters, approach_leap_distance_meters)
	if horizontal_direction.is_zero_approx() or leap_distance <= 0.0:
		return false
	var landing_position := global_position + horizontal_direction * leap_distance
	var from_home := landing_position - home_position
	from_home.y = 0.0
	if from_home.length() > movement_radius:
		return false
	if not _is_hop_safe(horizontal_direction, leap_distance):
		return false
	_approach_leap_direction = horizontal_direction
	_approach_leap_speed = leap_distance / maxf(0.05, approach_leap_duration_seconds)
	_approach_leap_remaining = approach_leap_duration_seconds
	velocity.x = 0.0
	velocity.z = 0.0
	face_direction(horizontal_direction)
	play_directional_animation(&"walk", true)
	return true


func is_approach_leaping() -> bool:
	return _approach_leap_remaining > 0.0


func cancel_approach_leap() -> void:
	if not is_approach_leaping():
		return
	_approach_leap_remaining = 0.0
	_approach_leap_direction = Vector3.ZERO
	_approach_leap_speed = 0.0
	_reset_hop_visuals()


func is_inside_poison_cloud() -> bool:
	return is_point_in_poison_cloud(global_position)


func is_point_in_poison_cloud(world_position: Vector3) -> bool:
	for node in get_active_spore_clouds():
		var cloud := node as MushroomSporeCloud
		if cloud == null or not is_instance_valid(cloud) or cloud.is_fading():
			continue
		var offset := Vector2(
			world_position.x - cloud.global_position.x, world_position.z - cloud.global_position.z
		)
		if offset.length() <= cloud.get_radius() * cloud_overlap_block_factor:
			return true
	if is_inside_tree():
		for stream_node in get_tree().get_nodes_in_group(&"mushroom_spore_stream"):
			if stream_node != null and stream_node.has_method("covers_point"):
				if bool(
					stream_node.call("covers_point", world_position, cloud_overlap_block_factor)
				):
					return true
	return false


func get_active_spore_clouds() -> Array[Node]:
	if not is_inside_tree():
		return []
	return get_tree().get_nodes_in_group(SPORE_CLOUD.POISON_CLOUD_GROUP)


func move_in_direction(direction: Vector3, delta: float, speed_scale: float = 1.0) -> void:
	if not direction.is_zero_approx():
		_move_requested_this_step = true
		var air_factor := 0.0
		if _hop_phase >= HOP_TAKEOFF_PHASE and _hop_phase < HOP_LAND_PHASE:
			var air_t := (_hop_phase - HOP_TAKEOFF_PHASE) / (HOP_LAND_PHASE - HOP_TAKEOFF_PHASE)
			air_factor = sin(air_t * PI)
		var hop_factor := lerpf(HOP_GROUND_SPEED_FACTOR, HOP_AIR_SPEED_BOOST, air_factor)
		speed_scale *= hop_factor
	super(direction, delta, speed_scale)


func play_directional_animation(action: StringName, restart: bool = false) -> bool:
	if is_instance_valid(visual) and is_instance_valid(visual.sprite):
		visual.sprite.texture = CHARGE_TEXTURE if action == &"spore_windup" else NORMAL_TEXTURE
	return super(action, restart)


func begin_charge_animation(duration_seconds: float = -1.0) -> void:
	var target_duration := duration_seconds if duration_seconds > 0.0 else charge_duration_seconds
	if is_instance_valid(visual) and is_instance_valid(visual.sprite):
		if not _charge_feedback_active:
			_charge_base_modulate = visual.sprite.modulate
		_charge_feedback_active = true
		var scale_denom := maxf(0.1, target_duration)
		visual.animation_player.speed_scale = CHARGE_ANIMATION_SECONDS / scale_denom
	play_directional_animation(&"spore_windup", true)


func get_hp_pressure() -> float:
	if ai == null or not is_instance_valid(hp):
		return 0.0
	return ai.compute_hp_pressure(hp.get_current_hp(), hp.get_max_hp())


func get_attack_cadence() -> Dictionary:
	if ai == null:
		return {
			"cooldown": spore_cooldown_seconds,
			"charge": charge_duration_seconds,
			"chase_interval": chase_spore_interval_seconds,
			"chase_chance": chase_spore_chance,
		}
	return ai.compute_attack_cadence(
		spore_cooldown_seconds,
		charge_duration_seconds,
		chase_spore_interval_seconds,
		chase_spore_chance,
		get_hp_pressure(),
		low_hp_cooldown_reduction_max,
		low_hp_charge_speedup_max,
		low_hp_chase_chance_bonus
	)


func release_cloud() -> bool:
	var spawned := _spawn_cloud_at(global_position)
	if spawned:
		attack_cooldown_remaining = float(
			get_attack_cadence().get("cooldown", spore_cooldown_seconds)
		)
	return spawned


func update_charge_feedback(progress: float) -> void:
	if not is_instance_valid(visual) or not is_instance_valid(visual.sprite):
		return
	var pulse := 0.5 + 0.5 * sin(progress * TAU * CHARGE_PULSE_COUNT)
	visual.sprite.modulate = _charge_base_modulate.lerp(CHARGE_TINT, progress * pulse)


func cancel_spore_charge() -> void:
	if _charge_feedback_active and is_instance_valid(visual) and is_instance_valid(visual.sprite):
		visual.sprite.modulate = _charge_base_modulate
	_charge_feedback_active = false
	if is_instance_valid(visual) and is_instance_valid(visual.animation_player):
		visual.animation_player.speed_scale = 1.0


func spawn_spore_cloud_at(
	world_position: Vector3, radius_override: float = -1.0, duration_override: float = -1.0
) -> bool:
	var target_radius := radius_override if radius_override > 0.0 else cloud_radius
	var target_duration := duration_override if duration_override > 0.0 else cloud_duration_seconds
	if is_point_in_poison_cloud(world_position):
		return false
	var parent := get_parent()
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return false
	var cloud := SPORE_CLOUD.new() as MushroomSporeCloud
	cloud.setup(
		self,
		target_radius,
		target_duration,
		spore_ramp_seconds,
		poison_interval_seconds,
		poison_damage
	)
	cloud.configure_visuals(
		spore_particle_count,
		mist_particle_count,
		spore_particle_lifetime,
		mist_particle_lifetime,
		ground_mist_opacity,
		ground_mist_scale,
		visual_spread_scale
	)
	if parent is Node3D:
		cloud.position = (parent as Node3D).to_local(world_position)
	else:
		cloud.position = world_position
	parent.add_child(cloud)
	cloud.global_position = world_position
	cloud.activate_poison()
	_register_spore_cloud(cloud)
	return true


func _spawn_cloud_at(world_position: Vector3) -> bool:
	return spawn_spore_cloud_at(world_position)


func _register_spore_cloud(cloud: MushroomSporeCloud) -> void:
	var pruned: Array[MushroomSporeCloud] = []
	for existing in _active_clouds:
		if is_instance_valid(existing) and not existing.is_fading():
			pruned.append(existing)
	pruned.append(cloud)
	while pruned.size() > max_active_clouds:
		var oldest := pruned.pop_front() as MushroomSporeCloud
		if is_instance_valid(oldest):
			oldest.finish()
	_active_clouds = pruned


func _is_in_hit_state() -> bool:
	for state: FsmState in [fsm.current_state, fsm.next_state]:
		if is_instance_valid(state) and state.name == &"Hit":
			return true
	return false


func _is_attacker_in_detection(attacker: Node) -> bool:
	if is_instance_valid(attacker) and attacker is Node3D:
		var node := attacker as Node3D
		var offset := Vector3(
			node.global_position.x - global_position.x,
			0.0,
			node.global_position.z - global_position.z
		)
		return offset.length_squared() <= detection_radius * detection_radius
	return _is_target_detected_now()


func _is_target_detected_now() -> bool:
	if not has_target():
		return false
	var offset := Vector3(
		target.global_position.x - global_position.x,
		0.0,
		target.global_position.z - global_position.z
	)
	return offset.length_squared() <= detection_radius * detection_radius


func _start_defensive_hop() -> void:
	_evade_pending = false
	cancel_approach_leap()
	var away := Vector3(_evade_away.x, 0.0, _evade_away.z).normalized()
	if has_target():
		var from_target := global_position - target.global_position
		from_target.y = 0.0
		if not from_target.is_zero_approx():
			away = from_target.normalized()
	if away.is_zero_approx():
		away = -last_facing_direction
	for distance_factor: float in EVADE_DISTANCE_FACTORS:
		var distance := evade_distance * distance_factor
		for angle: float in EVADE_DIRECTION_ANGLES:
			var direction := away.rotated(Vector3.UP, angle)
			if _is_hop_safe(direction, distance):
				_evade_direction = direction
				_evade_speed = distance / evade_duration_seconds
				_evade_remaining = evade_duration_seconds
				return


func _is_hop_safe(direction: Vector3, distance: float) -> bool:
	if test_move(global_transform, direction * distance):
		return false
	var space := get_world_3d().direct_space_state
	for fraction: float in HOP_GROUND_SAMPLE_FRACTIONS:
		var point := global_position + direction * distance * fraction
		var query := PhysicsRayQueryParameters3D.create(
			point + Vector3.UP * HOP_CHECK_UP_METERS,
			point + Vector3.DOWN * HOP_CHECK_DOWN_METERS,
			CombatLayers.WORLD
		)
		query.exclude = [get_rid()]
		if space.intersect_ray(query).is_empty():
			return false
	return true


func _update_defensive_hop(delta: float) -> void:
	var step := minf(maxf(delta, 0.0), _evade_remaining)
	var collision := move_and_collide(_evade_direction * _evade_speed * step)
	_evade_remaining = maxf(0.0, _evade_remaining - step)
	if collision != null:
		_evade_remaining = 0.0
	var progress := 1.0 - _evade_remaining / evade_duration_seconds
	var height := sin(progress * PI) * evade_hop_height
	if is_instance_valid(visual):
		visual.position.y = height
	_update_shadow_for_height(height)
	if _evade_remaining <= 0.0:
		if is_instance_valid(visual):
			visual.position.y = 0.0
		_update_shadow_for_height(0.0)
		_emit_hop_landing_vfx()


func _update_approach_leap(delta: float) -> void:
	var step := minf(maxf(delta, 0.0), _approach_leap_remaining)
	var collision := move_and_collide(_approach_leap_direction * _approach_leap_speed * step)
	_approach_leap_remaining = maxf(0.0, _approach_leap_remaining - step)
	if collision != null:
		_approach_leap_remaining = 0.0
	var progress := 1.0 - _approach_leap_remaining / approach_leap_duration_seconds
	var height := sin(progress * PI) * approach_leap_height
	if is_instance_valid(visual):
		visual.position.y = height
	_update_shadow_for_height(height)
	if _approach_leap_remaining <= 0.0:
		_approach_leap_direction = Vector3.ZERO
		_approach_leap_speed = 0.0
		_reset_hop_visuals()
		_emit_hop_landing_vfx()


func _build_hop_visuals() -> void:
	_shadow_material = StandardMaterial3D.new()
	_shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow_material.albedo_color = Color(0.04, 0.03, 0.06, 0.36)
	_shadow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var shadow_radius := HOP_SHADOW_RADIUS * _get_shadow_scale_factor()
	var cyl := CylinderMesh.new()
	cyl.top_radius = shadow_radius
	cyl.bottom_radius = shadow_radius
	cyl.height = 0.015
	cyl.material = _shadow_material
	_shadow_mesh = MeshInstance3D.new()
	_shadow_mesh.name = "MushroomShadow"
	_shadow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow_mesh.mesh = cyl
	_shadow_mesh.position = Vector3(0.0, HOP_SHADOW_OFFSET_METERS, 0.0)
	add_child(_shadow_mesh)

	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.82, 0.68, 1.0, 0.85), Color(0.42, 0.22, 0.72, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.albedo_texture = SPORE_CLOUD.SPORE_TEXTURE
	var quad := QuadMesh.new()
	quad.size = Vector2(0.32, 0.32)
	quad.material = mat

	_step_spores = CPUParticles3D.new()
	_step_spores.name = "HopLandingSpores"
	_step_spores.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_step_spores.amount = HOP_STEP_DUST_AMOUNT
	_step_spores.lifetime = HOP_STEP_DUST_LIFETIME
	_step_spores.one_shot = true
	_step_spores.explosiveness = 1.0
	_step_spores.emitting = false
	_step_spores.local_coords = false
	_step_spores.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_step_spores.emission_ring_axis = Vector3.UP
	_step_spores.emission_ring_height = 0.04
	_step_spores.emission_ring_radius = 0.28
	_step_spores.emission_ring_inner_radius = 0.1
	_step_spores.direction = Vector3.UP
	_step_spores.spread = 72.0
	_step_spores.initial_velocity_min = 0.45
	_step_spores.initial_velocity_max = 1.15
	_step_spores.gravity = Vector3(0.0, -1.2, 0.0)
	_step_spores.scale_amount_min = 0.45
	_step_spores.scale_amount_max = 0.95
	_step_spores.color_ramp = grad
	_step_spores.mesh = quad
	_step_spores.position = Vector3(0.0, 0.08, 0.0)
	add_child(_step_spores)


func _update_walk_hop(step: float) -> void:
	var is_moving := _move_requested_this_step
	_move_requested_this_step = false
	if not is_instance_valid(visual):
		return
	if not is_moving:
		if _was_moving_hop and visual.position.y > 0.04:
			_emit_hop_landing_vfx()
		_was_moving_hop = false
		_hop_phase = 0.0
		_last_walk_anim = ""
		if not _charge_feedback_active and is_instance_valid(visual.animation_player):
			visual.animation_player.speed_scale = 1.0
		visual.position.y = move_toward(visual.position.y, 0.0, step * 3.8)
		_update_shadow_for_height(visual.position.y)
		return

	var prev_phase := _hop_phase
	var rate := 1.0 / maxf(0.1, hop_cycle_seconds)
	_hop_phase = fposmod(_hop_phase + step * rate, 1.0)
	_was_moving_hop = true

	if prev_phase < HOP_LAND_PHASE and (_hop_phase >= HOP_LAND_PHASE or _hop_phase < prev_phase):
		_emit_hop_landing_vfx()

	var height := 0.0
	if _hop_phase >= HOP_TAKEOFF_PHASE and _hop_phase < HOP_LAND_PHASE:
		var air_t := (_hop_phase - HOP_TAKEOFF_PHASE) / (HOP_LAND_PHASE - HOP_TAKEOFF_PHASE)
		height = sin(air_t * PI) * hop_height

	visual.position.y = height
	_update_shadow_for_height(height)
	_sync_walk_animation_to_hop()


func _sync_walk_animation_to_hop() -> void:
	if not is_instance_valid(visual) or not is_instance_valid(visual.animation_player):
		return
	var anim_player := visual.animation_player
	var anim_name := String(anim_player.current_animation)
	if not anim_name.begins_with("walk_"):
		_last_walk_anim = ""
		return
	var clip_len := maxf(0.1, anim_player.current_animation_length)
	anim_player.speed_scale = clip_len / maxf(0.1, hop_cycle_seconds)
	var target_pos := _hop_phase * clip_len
	var drift := absf(anim_player.current_animation_position - target_pos)
	if _last_walk_anim != anim_name or (drift > 0.09 and drift < clip_len - 0.09):
		anim_player.seek(target_pos, true)
	_last_walk_anim = anim_name


func _update_shadow_for_height(height_meters: float) -> void:
	if is_instance_valid(_shadow_mesh):
		var max_h := maxf(maxf(hop_height, evade_hop_height), approach_leap_height)
		var ratio := clampf(height_meters / maxf(0.1, max_h), 0.0, 1.0)
		var shadow_scale := lerpf(1.0, 0.52, ratio)
		_shadow_mesh.scale = Vector3(shadow_scale, 1.0, shadow_scale)
		if _shadow_material != null:
			_shadow_material.albedo_color.a = lerpf(0.36, 0.16, ratio)


func _emit_hop_landing_vfx() -> void:
	if is_instance_valid(_step_spores):
		_step_spores.restart()
		_step_spores.emitting = true


func _get_shadow_scale_factor() -> float:
	if is_instance_valid(visual):
		return maxf(0.5, visual.scale.x)
	return 1.0


func _reset_hop_visuals() -> void:
	_was_moving_hop = false
	_move_requested_this_step = false
	_hop_phase = 0.0
	_last_walk_anim = ""
	if is_instance_valid(visual):
		visual.position.y = 0.0
		if not _charge_feedback_active and is_instance_valid(visual.animation_player):
			visual.animation_player.speed_scale = 1.0
	_update_shadow_for_height(0.0)
