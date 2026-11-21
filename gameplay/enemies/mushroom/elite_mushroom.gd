class_name EliteMushroom
extends MushroomEnemy
## EliteMushroom kế thừa toàn bộ hành vi Nấm thường và bổ sung chiêu thổi luồng khói +
## hạt bào tử quạt rộng uốn lượn theo gió, tạo bãi độc gần đồng thời đọng bãi độc xa.

const STREAM_SCRIPT := preload("res://gameplay/enemies/mushroom/mushroom_spore_stream.gd")

@export_group("Elite Spore Stream")
## Cự ly tối thiểu (m) để tung luồng thổi bào tử tầm trung-xa (cự ly gần dùng chiêu cũ).
@export_range(1.5, 12.0, 0.1, "suffix:m") var stream_min_distance_meters: float = 2.8
## Cự ly tối đa (m) để kích hoạt luồng thổi bào tử.
@export_range(3.0, 20.0, 0.1, "suffix:m") var stream_max_distance_meters: float = 8.8
## Vận tốc đẩy tối thiểu ở gốc khi phóng luồng khói bào tử (m/s).
@export_range(4.0, 24.0, 0.2, "suffix:m/s") var stream_jet_speed_min: float = 11.8
## Vận tốc đẩy tối đa ở gốc khi phóng luồng khói bào tử (m/s).
@export_range(5.0, 28.0, 0.2, "suffix:m/s") var stream_jet_speed_max: float = 14.4
## Góc quạt mở tổng (độ) tại vòi phun.
@export_range(18.0, 100.0, 2.0, "suffix:deg") var stream_fan_degrees: float = 52.0
## Độ lệch hướng gió ngẫu nhiên tối đa (độ) để luồng thổi không nhắm cứng vào Player.
@export_range(0.0, 45.0, 1.0, "suffix:deg") var stream_aim_jitter_degrees: float = 14.0
## Thời gian hồi (s) giữa các lần thổi luồng bào tử.
@export_range(1.0, 20.0, 0.1, "suffix:s") var stream_cooldown_seconds: float = 4.6
## Thời gian gồng báo hiệu (s) trước khi xả luồng khói bào tử.
@export_range(0.3, 3.0, 0.05, "suffix:s") var stream_windup_seconds: float = 0.95
## Khoảng thời gian khóa hướng gió ở cuối pha gồng (s) để Player né công bằng.
@export_range(0.1, 1.5, 0.05, "suffix:s") var stream_aim_lock_seconds: float = 0.35
## Thời gian nấm thổi luồng khói bào tử liên tục (s).
@export_range(0.4, 4.0, 0.05, "suffix:s") var stream_duration_seconds: float = 1.65
## Thời gian sống của hạt/khói kể từ lúc rời gốc (quyết định độ đọng sau khi dừng bay).
@export_range(1.5, 8.0, 0.1, "suffix:s") var stream_particle_lifetime_seconds: float = 3.8
## Thời gian khựng hồi phục (s) sau khi ngừng thổi luồng.
@export_range(0.1, 2.0, 0.05, "suffix:s") var stream_recovery_seconds: float = 0.45
## Bán kính collider gây sát thương khi khói mới tách miệng phun (m).
@export_range(0.2, 2.5, 0.05, "suffix:m") var stream_start_radius_meters: float = 0.35
## Bán kính collider gây sát thương tối đa ở lõi vùng khói đọng (nhỏ hơn vùng hiển thị) (m).
@export_range(0.4, 3.5, 0.05, "suffix:m") var stream_end_radius_meters: float = 1.05
## Chu kỳ gây sát thương độc (s/lần) khi chạm vùng khói đang bay hoặc đang đọng.
@export_range(0.15, 2.0, 0.05, "suffix:s") var stream_tick_interval_seconds: float = 0.45
## Lượng máu trừ mỗi nhịp độc (HP/tick).
@export_range(0.1, 10.0, 0.1) var stream_tick_damage_hp: float = 1.0
## Bán kính collider sát thương của phần bào tử rỉ gần gốc (m); bằng 0 để tắt.
@export_range(0.0, 2.5, 0.05, "suffix:m") var stream_near_cloud_radius: float = 0.85

var stream_cooldown_remaining: float = 0.0
var _stream_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_stream_rng.randomize()
	super()


func _physics_process(delta: float) -> void:
	stream_cooldown_remaining = maxf(0.0, stream_cooldown_remaining - maxf(0.0, delta))
	super(delta)


func can_start_defensive_hop() -> bool:
	return not is_elite_skill_active()


func can_trigger_defensive_counter() -> bool:
	return not is_elite_skill_active()


func is_elite_skill_active() -> bool:
	if not is_instance_valid(fsm):
		return false
	for state: FsmState in [fsm.current_state, fsm.next_state]:
		if is_instance_valid(state) and state.name == &"SporeStream":
			return true
	return false


func get_elite_feedback() -> EliteFeedback:
	return get_node_or_null("EliteFeedback") as EliteFeedback


func get_stream_windup_seconds() -> float:
	var pressure := get_hp_pressure()
	var speedup := 1.0 - pressure * clampf(low_hp_charge_speedup_max, 0.0, 0.35)
	return maxf(0.55, stream_windup_seconds * speedup)


func reset_stream_cooldown() -> void:
	var pressure := get_hp_pressure()
	var reduction := 1.0 - pressure * clampf(low_hp_cooldown_reduction_max * 0.75, 0.0, 0.35)
	stream_cooldown_remaining = maxf(2.2, stream_cooldown_seconds * reduction)


func apply_stream_aim_jitter(aim_direction: Vector3) -> Vector3:
	var base := Vector3(aim_direction.x, 0.0, aim_direction.z)
	if base.is_zero_approx():
		return Vector3.BACK
	var jitter_rad := deg_to_rad(stream_aim_jitter_degrees)
	var offset_rad := _stream_rng.randf_range(-jitter_rad, jitter_rad)
	return base.normalized().rotated(Vector3.UP, offset_rad)


func start_spore_stream(aim_direction: Vector3) -> MushroomSporeStream:
	if dead or not is_inside_tree():
		return null
	var parent := get_parent()
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return null
	var base_dir := Vector3(aim_direction.x, 0.0, aim_direction.z)
	if base_dir.is_zero_approx():
		base_dir = last_facing_direction
	base_dir.y = 0.0
	base_dir = base_dir.normalized() if not base_dir.is_zero_approx() else Vector3.BACK

	# Low origin near lower cap/base so the wide stream emerges naturally without a sharp floating tip.
	var spawn_origin := global_position + base_dir * 0.28 + Vector3.UP * 0.48
	var stream := STREAM_SCRIPT.new() as MushroomSporeStream
	(
		stream
		. setup(
			{
				"owner": self,
				"origin": spawn_origin,
				"direction": base_dir,
				"jet_speed_min": stream_jet_speed_min,
				"jet_speed_max": stream_jet_speed_max,
				"particle_lifetime": stream_particle_lifetime_seconds,
				"duration_seconds": stream_duration_seconds,
				"start_radius": stream_start_radius_meters,
				"end_radius": stream_end_radius_meters,
				"fan_degrees": stream_fan_degrees,
				"tick_interval": stream_tick_interval_seconds,
				"tick_damage": stream_tick_damage_hp,
				"near_cloud_radius": stream_near_cloud_radius,
				"ground_y": global_position.y,
			}
		)
	)
	if parent is Node3D:
		stream.position = (parent as Node3D).to_local(spawn_origin)
	else:
		stream.position = spawn_origin
	parent.add_child(stream)
	stream.global_position = spawn_origin
	reset_stream_cooldown()
	return stream
