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
const HOP_FREQUENCY := 0.9
const HOP_HEIGHT := 0.16
const HOP_MIN_SPEED_FACTOR := 0.35
const CHARGE_TINT := Color(1.0, 1.0, 0.55, 1.0)
const CHARGE_PULSE_COUNT := 4.0
const HOP_VELOCITY_THRESHOLD := 0.08
const EVADE_CHECK_UP := 1.2
const EVADE_CHECK_DOWN := 2.4
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
@export_range(0.0, 5.0, 0.05, "suffix:s") var observe_seconds: float = 0.8
## Thời gian (s) đi tới vị trí thấy Player lần cuối sau khi Player thoát khỏi vùng nhận diện.
@export_range(0.5, 15.0, 0.1, "suffix:s") var search_seconds: float = 3.0

@export_group("Movement & Patrol")
## Bán kính tuần tra tối đa tính từ vị trí spawn ban đầu (m); vượt quá sẽ quay đầu về.
@export_range(1.0, 40.0, 0.5, "suffix:m") var movement_radius: float = 12.0
## Hệ số tốc độ khi đuổi theo (nhân với move_speed trong mushroom_data.tres).
## Giữ bằng wander để vòng nhận diện chỉ điều hướng, không làm nấm chạy nhanh.
@export_range(0.05, 5.0, 0.05) var chase_speed_scale: float = 0.55
## Hệ số tốc độ khi đi lang thang quanh gốc (nhân với move_speed trong mushroom_data.tres).
@export_range(0.05, 5.0, 0.05) var wander_speed_scale: float = 0.55
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
@export_range(0.2, 20.0, 0.1, "suffix:s") var spore_cooldown_seconds: float = 4.0
## Chu kỳ (s) tung xúc xắc phun độc ngẫu nhiên khi đang tiến tới Player trong vùng nhận diện.
@export_range(0.2, 20.0, 0.1, "suffix:s") var chase_spore_interval_seconds: float = 2.0
## Xác suất (0.0 - 1.0) phun độc ngẫu nhiên mỗi chu kỳ khi đang đuổi trong vùng nhận diện.
@export_range(0.0, 1.0, 0.05) var chase_spore_chance: float = 0.3
## Bán kính gây sát thương của đám mây độc (m). Nên nhỏ hơn evade_distance để Player kịp né.
@export_range(0.4, 10.0, 0.1, "suffix:m") var cloud_radius: float = 2.6
## Hệ số (0.1 - 1.0) nhân với cloud_radius: nấm đứng trong vùng này sẽ không phun chồng độc mới.
@export_range(0.1, 1.0, 0.05) var cloud_overlap_block_factor: float = 0.85
## Thời gian tồn tại (s) của mỗi đám mây độc trước khi mờ dần và biến mất.
@export_range(0.2, 20.0, 0.1, "suffix:s") var cloud_duration_seconds: float = 3.5
## Thời gian (s) để bụi độc và sương mặt đất đậm dần lên mức tối đa khi vừa bung ra.
@export_range(0.05, 3.0, 0.05, "suffix:s") var spore_ramp_seconds: float = 0.8
## Chu kỳ gây sát thương độc (s/lần) lên Player đứng trong vùng mây độc.
@export_range(0.1, 5.0, 0.05, "suffix:s") var poison_interval_seconds: float = 1.0
## Lượng máu trừ mỗi nhịp độc (HP/tick).
@export_range(0.1, 100.0, 0.1) var poison_damage: float = 0.5
## Số lượng đám mây độc tối đa tồn tại cùng lúc của con nấm này; vượt quá sẽ tắt đám cũ nhất.
@export_range(1, 10, 1) var max_active_clouds: int = 3

@export_group("Spore Visual & Particles")
## Hệ số mở rộng vùng hiển thị khói/bụi độc so với collider gây sát thương thật.
## Mặc định 1.15 để rìa ngoài khói trông rõ và rộng hơn nhẹ so với vùng trúng độc.
@export_range(0.5, 2.0, 0.05) var visual_spread_scale: float = 1.15
## Số lượng hạt bụi độc (FloatingSpores) phát ra trong mỗi đám mây độc.
@export_range(10, 1000, 10) var spore_particle_count: int = 240
## Số lượng cụm khói mờ (PoisonMist) 3D trong mỗi đám mây độc.
@export_range(1, 100, 1) var mist_particle_count: int = 18
## Thời gian tồn tại (s) của mỗi hạt bụi độc.
@export_range(0.2, 10.0, 0.1, "suffix:s") var spore_particle_lifetime: float = 2.0
## Thời gian tồn tại (s) của mỗi cụm khói mờ.
@export_range(0.2, 10.0, 0.1, "suffix:s") var mist_particle_lifetime: float = 2.2
## Độ đậm tối đa (0.0 - 1.0) của lớp sương mờ tự nhiên dưới mặt đất tại tâm đám độc.
@export_range(0.0, 1.0, 0.02) var ground_mist_opacity: float = 0.26
## Hệ số phóng to mặt phẳng sương dưới đất theo cloud_radius (span = cloud_radius * scale).
@export_range(0.5, 5.0, 0.05) var ground_mist_scale: float = 2.45

@export_group("Defensive Knockback")
## Quãng đường bật lùi tối đa (m) khi dính đòn nhẹ; mặc định > cloud_radius để không trúng độc ngay.
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

var home_position: Vector3
var attack_cooldown_remaining: float = 0.0
var ai: MushroomAI
var _hop_time: float = 0.0
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
var _active_clouds: Array[MushroomSporeCloud] = []


func _ready() -> void:
	home_position = global_position
	ai = AI_CLASS.new()
	var detector_shape := $TargetDetector/CollisionShape3D as CollisionShape3D
	detector_shape.shape = detector_shape.shape.duplicate()
	(detector_shape.shape as CylinderShape3D).radius = detection_radius
	super()


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
	if _evade_pending and not dead and not _is_in_hit_state():
		_start_defensive_hop()
	attack_cooldown_remaining = maxf(0.0, attack_cooldown_remaining - step)
	super(delta)
	if dead:
		_evade_remaining = 0.0
		_evade_pending = false
		_pending_knockback_charge = false
		return
	if _evade_remaining > 0.0:
		if _is_in_hit_state():
			_evade_remaining = 0.0
			return
		_update_defensive_hop(step)
		return
	if is_instance_valid(visual):
		if Vector2(velocity.x, velocity.z).length() > HOP_VELOCITY_THRESHOLD:
			_hop_time += step * HOP_FREQUENCY * TAU
			visual.position.y = absf(sin(_hop_time)) * HOP_HEIGHT
		else:
			_hop_time = 0.0
			visual.position.y = 0.0


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
	return false


func get_active_spore_clouds() -> Array[Node]:
	if not is_inside_tree():
		return []
	return get_tree().get_nodes_in_group(SPORE_CLOUD.POISON_CLOUD_GROUP)


func move_in_direction(direction: Vector3, delta: float, speed_scale: float = 1.0) -> void:
	if not direction.is_zero_approx():
		var hop_factor := lerpf(HOP_MIN_SPEED_FACTOR, 1.0, absf(sin(_hop_time)))
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


func release_cloud() -> bool:
	var spawned := _spawn_cloud_at(global_position)
	if spawned:
		attack_cooldown_remaining = spore_cooldown_seconds
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


func _spawn_cloud_at(world_position: Vector3) -> bool:
	if is_point_in_poison_cloud(world_position):
		return false
	var parent := get_parent()
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return false
	var cloud := SPORE_CLOUD.new() as MushroomSporeCloud
	cloud.setup(
		self,
		cloud_radius,
		cloud_duration_seconds,
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
	parent.add_child(cloud)
	cloud.global_position = world_position
	cloud.activate_poison()
	_register_spore_cloud(cloud)
	return true


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
	for fraction: float in [0.5, 1.0]:
		var point := global_position + direction * distance * fraction
		var query := PhysicsRayQueryParameters3D.create(
			point + Vector3.UP * EVADE_CHECK_UP,
			point + Vector3.DOWN * EVADE_CHECK_DOWN,
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
	if is_instance_valid(visual):
		visual.position.y = sin(progress * PI) * evade_hop_height
	if _evade_remaining <= 0.0 and is_instance_valid(visual):
		visual.position.y = 0.0
