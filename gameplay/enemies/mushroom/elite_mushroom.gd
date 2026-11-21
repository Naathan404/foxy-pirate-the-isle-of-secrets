class_name EliteMushroom
extends MushroomEnemy
## EliteMushroom kế thừa toàn bộ hành vi Nấm thường, sở hữu hai hình thái Không Chân <-> Có Chân
## cùng di chuyển bọc sườn/giữ cự ly, (1) SporeStream và (2) GreatSpore khi sắp bị tiêu diệt.

enum Stance { FOOTLESS, LEGGED }

const STREAM_SCRIPT := preload("res://gameplay/enemies/mushroom/mushroom_spore_stream.gd")
const GREAT_SPORE_SCRIPT := preload("res://gameplay/enemies/mushroom/mushroom_great_spore.gd")
const LEGGED_MOVE_TEXTURE := preload("res://assets/sprites/enemies/mushroom/mushroom_move_4dir.png")
const LEGGED_SPORE_TEXTURE := preload(
	"res://assets/sprites/enemies/mushroom/mushroom_spore_4dir.png"
)
const EGG_GROUP := &"mushroom_eggs"
const STRIDE_DUST_INTERVAL := 0.26

@export_group("Elite Stance & Movement")
## Hệ số tốc độ chạy khi ở hình thái Có Chân (nhân với move_speed).
@export_range(0.6, 3.0, 0.05) var legged_chase_speed_scale: float = 1.65
## Thời gian hiệu ứng mọc / thu chân khi chuyển hình thái (s).
@export_range(0.15, 1.2, 0.02, "suffix:s") var morph_duration_seconds: float = 0.42
## Thời gian tối thiểu giữa hai lần chuyển hình thái (s) để chuyển động ổn định.
@export_range(1.5, 12.0, 0.25, "suffix:s") var stance_switch_cooldown_seconds: float = 3.5
## Thời gian tối đa giữ trạng thái chạy Có Chân trước khi thu chân về nhịp nhảy nặng (s).
@export_range(2.0, 15.0, 0.25, "suffix:s") var legged_stance_max_seconds: float = 5.8
## Thời gian tối đa giữ trạng thái Không Chân lúc đang đuổi trước khi mọc chân chạy lại (s).
@export_range(1.5, 12.0, 0.25, "suffix:s") var footless_stance_max_seconds: float = 3.8
## Cự ly mục tiêu (m) tự kích hoạt mọc chân để tăng tốc áp sát/bọc sườn.
@export_range(2.0, 10.0, 0.1, "suffix:m") var legged_chase_trigger_distance: float = 4.0

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
## Tỉ lệ góc quạt gây sát thương ở lõi so với góc quạt hiển thị (nhỏ hơn 1 để rìa khói an toàn).
@export_range(0.1, 1.0, 0.02) var stream_damage_core_fan_ratio: float = 0.32
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
@export_range(0.15, 2.5, 0.05, "suffix:m") var stream_start_radius_meters: float = 0.2
## Bán kính collider gây sát thương tối đa ở lõi vùng khói đọng (nhỏ hơn rõ rệt vùng hiển thị) (m).
@export_range(0.25, 3.5, 0.05, "suffix:m") var stream_end_radius_meters: float = 0.55
## Chu kỳ gây sát thương độc (s/lần) khi chạm lõi vùng khói đang bay hoặc đang đọng.
@export_range(0.15, 2.0, 0.05, "suffix:s") var stream_tick_interval_seconds: float = 0.75
## Hệ số nhân với EnemyData.attack_damage cho mỗi nhịp độc của luồng thổi.
@export_range(0.0, 5.0, 0.05) var stream_tick_damage_multiplier: float = 1.0
## Bán kính collider sát thương của phần bào tử rỉ gần gốc (m); bằng 0 để tắt.
@export_range(0.0, 2.5, 0.05, "suffix:m") var stream_near_cloud_radius: float = 0.45

@export_group("Elite Great Spore")
## Số lần tối đa tung chiêu Đại Bào Tử trong một trận (1-2 lần khi sắp bị tiêu diệt).
@export_range(0, 4, 1) var great_spore_max_uses: int = 2
## Ngưỡng tỉ lệ HP (0.0 - 1.0) mở khóa lần tung Đại Bào Tử đầu tiên.
@export_range(0.1, 0.9, 0.05) var great_spore_first_hp_ratio: float = 0.45
## Ngưỡng tỉ lệ HP (0.0 - 1.0) mở khóa lần tung Đại Bào Tử thứ hai lúc cận tử.
@export_range(0.05, 0.8, 0.05) var great_spore_second_hp_ratio: float = 0.22
## Thời gian hồi tối thiểu giữa hai lần tung Đại Bào Tử (s).
@export_range(1.5, 20.0, 0.25, "suffix:s") var great_spore_cooldown_seconds: float = 6.0
## Thời gian gồng báo hiệu (s) trước khi phóng các Đại Bào Tử lên không.
@export_range(0.3, 3.0, 0.05, "suffix:s") var great_spore_windup_seconds: float = 0.95
## Thời gian giữ dáng phun bung sau khi phóng Đại Bào Tử lên không (s).
@export_range(0.15, 2.0, 0.05, "suffix:s") var great_spore_release_seconds: float = 0.65
## Thời gian hồi phục sau khi phóng Đại Bào Tử (s).
@export_range(0.1, 2.0, 0.05, "suffix:s") var great_spore_recovery_seconds: float = 0.45
## Số lượng Đại Bào Tử phóng ra mỗi lượt (5 cụm tỏa tự do khắp sân).
@export_range(1, 10, 1) var great_spore_count_per_cast: int = 5
## Số Trứng Nấm tạo ra trong mỗi lượt phóng (ví dụ 3/5 cụm, tự giảm nếu chạm trần đàn nấm con).
@export_range(0, 10, 1) var great_spore_eggs_per_cast: int = 3
## Tổng số Trứng Nấm + Mushroom con sống cùng lúc tối đa do Elite này sinh ra.
@export_range(0, 12, 1) var great_spore_max_active_minions: int = 6
## Thời gian bay lơ lửng tối thiểu trên không (s) trước khi đáp xuống đất.
@export_range(0.8, 10.0, 0.1, "suffix:s") var great_spore_hover_min_seconds: float = 2.8
## Thời gian bay lơ lửng tối đa trên không (s) trước khi đáp xuống đất.
@export_range(1.0, 12.0, 0.1, "suffix:s") var great_spore_hover_max_seconds: float = 4.2
## Độ cao bay lơ lửng trên không của Đại Bào Tử (m).
@export_range(1.6, 12.0, 0.1, "suffix:m") var great_spore_hover_altitude_meters: float = 5.6
## Thời gian lượn đáp xuống mặt đất (s).
@export_range(0.25, 2.0, 0.05, "suffix:s") var great_spore_land_duration_seconds: float = 0.78
## Khoảng cách tối thiểu (m) từ gốc Elite tới điểm đáp để bào tử bay xa khắp map.
@export_range(1.5, 14.0, 0.25, "suffix:m") var great_spore_min_distance_meters: float = 6.4
## Bán kính phân bố điểm đáp rộng trên toàn sân (m).
@export_range(3.0, 26.0, 0.25, "suffix:m") var great_spore_spread_radius_meters: float = 15.5
## Thời gian ủ mầm trước khi Trứng Nấm nở thành Mushroom bình thường (s).
@export_range(2.0, 15.0, 0.25, "suffix:s") var great_spore_egg_hatch_seconds: float = 5.5

var stream_cooldown_remaining: float = 0.0
var great_spore_cooldown_remaining: float = 0.0
var great_spore_uses_done: int = 0
var _stance: Stance = Stance.FOOTLESS
var _morph_target_stance: Stance = Stance.FOOTLESS
var _morph_remaining: float = 0.0
var _morph_duration: float = 0.42
var _morph_swapped: bool = false
var _stance_cooldown_remaining: float = 0.0
var _stance_elapsed: float = 0.0
var _base_visual_scale: Vector3 = Vector3.ONE
var _stride_dust_remaining: float = 0.0
var _stream_rng := RandomNumberGenerator.new()
var _spawned_minions: Array[Node] = []


func _ready() -> void:
	_stream_rng.randomize()
	super()
	if is_instance_valid(visual):
		_base_visual_scale = visual.scale


func _physics_process(delta: float) -> void:
	var step := maxf(0.0, delta)
	stream_cooldown_remaining = maxf(0.0, stream_cooldown_remaining - step)
	great_spore_cooldown_remaining = maxf(0.0, great_spore_cooldown_remaining - step)
	_stance_cooldown_remaining = maxf(0.0, _stance_cooldown_remaining - step)
	_stance_elapsed += step
	_stride_dust_remaining = maxf(0.0, _stride_dust_remaining - step)
	if _morph_remaining > 0.0:
		if _is_in_hit_state() or dead:
			_stance = _morph_target_stance
			_morph_remaining = 0.0
			_stance_elapsed = 0.0
			if is_instance_valid(visual):
				visual.scale = _base_visual_scale
		else:
			_update_morph(step)
	super(delta)
	if dead and is_instance_valid(visual):
		visual.scale = _base_visual_scale


func get_stance() -> Stance:
	return _stance


func is_legged() -> bool:
	return _stance == Stance.LEGGED


func is_morphing() -> bool:
	return _morph_remaining > 0.0


func get_stance_elapsed() -> float:
	return _stance_elapsed


func can_switch_stance() -> bool:
	if dead or _morph_remaining > 0.0 or _stance_cooldown_remaining > 0.0:
		return false
	if is_evading() or is_approach_leaping() or is_elite_skill_active():
		return false
	return true


func request_stance(target_stance: Stance, instant: bool = false) -> bool:
	if _stance == target_stance:
		return false
	if instant:
		_stance = target_stance
		_morph_remaining = 0.0
		_stance_elapsed = 0.0
		_stance_cooldown_remaining = stance_switch_cooldown_seconds
		if is_instance_valid(visual):
			visual.scale = _base_visual_scale
		return true
	if not can_switch_stance():
		return false
	_morph_target_stance = target_stance
	_morph_duration = maxf(0.15, morph_duration_seconds)
	_morph_remaining = _morph_duration
	_morph_swapped = false
	_stance_cooldown_remaining = stance_switch_cooldown_seconds
	stop_movement()
	play_directional_animation(&"morph", true)
	return true


func notify_legged_stride(is_moving: bool) -> void:
	if not is_moving or _stance != Stance.LEGGED or _morph_remaining > 0.0:
		return
	if _stride_dust_remaining <= 0.0:
		_stride_dust_remaining = STRIDE_DUST_INTERVAL
		_emit_hop_landing_vfx()


func can_start_defensive_hop() -> bool:
	return not is_elite_skill_active() and not is_morphing()


func can_trigger_defensive_counter() -> bool:
	return not is_elite_skill_active() and not is_morphing()


func is_elite_skill_active() -> bool:
	if not is_instance_valid(fsm):
		return false
	for state: FsmState in [fsm.current_state, fsm.next_state]:
		if is_instance_valid(state) and state.name in [&"SporeStream", &"GreatSpore"]:
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

	# Low origin near lower cap/base so the wide stream emerges naturally without a sharp tip.
	var spawn_origin := global_position + base_dir * 0.28 + Vector3.UP * 0.44
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
				"damage_core_fan_ratio": stream_damage_core_fan_ratio,
				"tick_interval": stream_tick_interval_seconds,
				"tick_damage": _resolve_stream_tick_damage(),
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


func can_trigger_great_spore() -> bool:
	if dead or not is_inside_tree() or not is_instance_valid(hp):
		return false
	if great_spore_uses_done >= great_spore_max_uses or great_spore_cooldown_remaining > 0.0:
		return false
	if not has_target():
		return false
	var max_hp := hp.get_max_hp()
	if max_hp <= 0.0:
		return false
	var hp_ratio := hp.current_hp / max_hp
	var required_ratio := (
		great_spore_first_hp_ratio if great_spore_uses_done == 0 else great_spore_second_hp_ratio
	)
	return hp_ratio <= required_ratio


func get_active_minion_count() -> int:
	var idx := _spawned_minions.size() - 1
	while idx >= 0:
		var node := _spawned_minions[idx]
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			_spawned_minions.remove_at(idx)
		elif node is EnemyBase and (node as EnemyBase).dead:
			_spawned_minions.remove_at(idx)
		idx -= 1
	return _spawned_minions.size()


func can_spawn_more_minions() -> bool:
	var pending_eggs := _count_pending_egg_spores()
	return get_active_minion_count() + pending_eggs < great_spore_max_active_minions


func register_spawned_minion(minion: Node) -> void:
	if not is_instance_valid(minion):
		return
	if not _spawned_minions.has(minion):
		_spawned_minions.append(minion)


func launch_great_spores() -> Array[MushroomGreatSpore]:
	var launched: Array[MushroomGreatSpore] = []
	if dead or not is_inside_tree():
		return launched
	var parent := get_parent()
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return launched

	var count := maxi(1, great_spore_count_per_cast)
	var spots := _resolve_great_spore_spots(count)
	var outcomes := _assign_great_spore_outcomes(spots.size())
	var spawn_origin := global_position + Vector3.UP * 1.65
	var hover_min := minf(great_spore_hover_min_seconds, great_spore_hover_max_seconds)
	var hover_max := maxf(great_spore_hover_min_seconds, great_spore_hover_max_seconds)
	_spawn_great_spore_eruption_vfx(parent, spawn_origin)

	for i in range(spots.size()):
		var spore := GREAT_SPORE_SCRIPT.new() as MushroomGreatSpore
		if spore == null:
			continue
		var hover_time := _stream_rng.randf_range(hover_min, hover_max) + float(i) * 0.14
		(
			spore
			. setup(
				{
					"owner": self,
					"outcome": outcomes[i],
					"start_pos": spawn_origin,
					"landing_pos": spots[i],
					"hover_altitude": great_spore_hover_altitude_meters,
					"hover_seconds": hover_time,
					"land_seconds": great_spore_land_duration_seconds,
					"launch_delay": float(i) * 0.055,
					"cloud_radius": cloud_radius,
					"cloud_duration": cloud_duration_seconds,
					"cloud_ramp": spore_ramp_seconds,
					"poison_interval": poison_interval_seconds,
					"poison_damage": _resolve_poison_damage(),
					"egg_hatch_seconds": great_spore_egg_hatch_seconds,
				}
			)
		)
		if parent is Node3D:
			spore.position = (parent as Node3D).to_local(spawn_origin)
		else:
			spore.position = spawn_origin
		parent.add_child(spore)
		spore.global_position = spawn_origin
		launched.append(spore)

	great_spore_uses_done += 1
	great_spore_cooldown_remaining = great_spore_cooldown_seconds
	return launched


func _get_evade_direction_candidates(away: Vector3) -> Array[Vector3]:
	var edge_danger := not _is_hop_safe(away, evade_distance * 1.15)
	var to_home := Vector3(
		home_position.x - global_position.x, 0.0, home_position.z - global_position.z
	)
	to_home.y = 0.0
	var pushed_out := to_home.length() > movement_radius * 0.65 and away.dot(to_home) < -0.2
	if not edge_danger and not pushed_out:
		return super(away)

	# When backed near a cliff or room corner, escape tangentially/inward instead of trapping self.
	var inward := to_home.normalized() if not to_home.is_zero_approx() else -away
	var side_a := Vector3(-away.z, 0.0, away.x).normalized()
	if side_a.dot(inward) < 0.0:
		side_a = -side_a
	var side_b := -side_a
	return [
		(side_a * 0.68 + inward * 0.72).normalized(),
		side_a,
		(side_a * 0.65 - away * 0.75).normalized(),
		inward,
		(side_b * 0.68 + inward * 0.72).normalized(),
		side_b,
		-away,
		away,
	]


func _can_use_hop_locomotion() -> bool:
	return _stance == Stance.FOOTLESS and not is_morphing()


func _get_texture_for_action(action: StringName) -> Texture2D:
	if _stance == Stance.LEGGED:
		if action in [&"spore_windup", &"spore_release", &"great_spore_release"]:
			return LEGGED_SPORE_TEXTURE
		return LEGGED_MOVE_TEXTURE
	if action in [&"spore_windup", &"great_spore_release"]:
		return CHARGE_TEXTURE
	return NORMAL_TEXTURE


func _resolve_animation_action(action: StringName) -> StringName:
	if _stance != Stance.LEGGED:
		return action
	match action:
		&"walk":
			return &"legged_walk"
		&"idle":
			return &"legged_idle"
		&"spore_windup":
			return &"legged_spore_windup"
		&"spore_release":
			return &"legged_spore_release"
		&"great_spore_release":
			return &"legged_great_spore_release"
		&"hit", &"death":
			return &"morph"
		_:
			return action


func _update_morph(step: float) -> void:
	_morph_remaining = maxf(0.0, _morph_remaining - step)
	var progress := 1.0 - _morph_remaining / maxf(0.05, _morph_duration)
	if progress < 0.45:
		var crouch := progress / 0.45
		if is_instance_valid(visual):
			visual.scale = (
				_base_visual_scale * Vector3(lerpf(1.0, 1.18, crouch), lerpf(1.0, 0.7, crouch), 1.0)
			)
	else:
		if not _morph_swapped:
			_morph_swapped = true
			_stance = _morph_target_stance
			_stance_elapsed = 0.0
			_reset_hop_visuals()
			_emit_hop_landing_vfx()
			play_directional_animation(&"morph", true)
		var pop := clampf((progress - 0.45) / 0.55, 0.0, 1.0)
		if is_instance_valid(visual):
			var spring := sin(pop * PI) * 0.16
			visual.scale = _base_visual_scale * Vector3(1.0 - spring * 0.6, 1.0 + spring, 1.0)
	if _morph_remaining <= 0.0 and is_instance_valid(visual):
		visual.scale = _base_visual_scale
		play_directional_animation(&"idle")


func _apply_cast_visual_scale(multiplier: Vector3) -> void:
	if is_instance_valid(visual):
		visual.scale = _base_visual_scale * multiplier


func _spawn_great_spore_eruption_vfx(parent: Node, origin: Vector3) -> void:
	var fountain := CPUParticles3D.new()
	fountain.name = "GreatSporeCastFountain"
	fountain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fountain.amount = 42
	fountain.lifetime = 0.78
	fountain.one_shot = true
	fountain.explosiveness = 0.82
	fountain.emitting = false
	fountain.local_coords = false
	fountain.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	fountain.emission_ring_axis = Vector3.UP
	fountain.emission_ring_radius = 0.65
	fountain.emission_ring_inner_radius = 0.2
	fountain.direction = Vector3.UP
	fountain.spread = 52.0
	fountain.initial_velocity_min = 4.6
	fountain.initial_velocity_max = 8.4
	fountain.gravity = Vector3(0.0, -3.2, 0.0)
	fountain.scale_amount_min = 0.35
	fountain.scale_amount_max = 0.85
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.28, 0.62, 1.0])
	grad.colors = PackedColorArray(
		[
			Color(0.84, 1.0, 0.56, 0.98),
			Color(0.86, 0.52, 1.0, 0.9),
			Color(0.76, 0.44, 1.0, 0.45),
			Color(0.4, 0.2, 0.65, 0.0),
		]
	)
	fountain.color_ramp = grad
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.albedo_texture = GREAT_SPORE_SCRIPT.SPARK_MOTE_TEXTURE
	var quad := QuadMesh.new()
	quad.size = Vector2(0.45, 0.45)
	quad.material = mat
	fountain.mesh = quad
	parent.add_child(fountain)
	fountain.global_position = origin
	fountain.emitting = true
	var cleanup := fountain.create_tween()
	cleanup.tween_interval(1.0)
	cleanup.tween_callback(fountain.queue_free)


func _resolve_stream_tick_damage() -> float:
	var base_damage := data.attack_damage if data != null else 0.5
	return maxf(0.0, base_damage * maxf(0.0, stream_tick_damage_multiplier))


func _count_pending_egg_spores() -> int:
	if not is_inside_tree():
		return 0
	var count := 0
	for node in get_tree().get_nodes_in_group(GREAT_SPORE_SCRIPT.GREAT_SPORE_GROUP):
		var spore := node as MushroomGreatSpore
		if spore != null and is_instance_valid(spore) and not spore.is_finished():
			if spore.get_outcome() == MushroomGreatSpore.OutcomeKind.MUSHROOM_EGG:
				count += 1
	return count


func _assign_great_spore_outcomes(count: int) -> Array[int]:
	var outcomes: Array[int] = []
	var available_slots := maxi(
		0, great_spore_max_active_minions - get_active_minion_count() - _count_pending_egg_spores()
	)
	var egg_quota := mini(count, mini(maxi(0, great_spore_eggs_per_cast), available_slots))
	for i in range(count):
		if i < egg_quota:
			outcomes.append(MushroomGreatSpore.OutcomeKind.MUSHROOM_EGG)
		else:
			outcomes.append(MushroomGreatSpore.OutcomeKind.SPORE_CLOUD)
	for i in range(outcomes.size() - 1, 0, -1):
		var swap_idx := _stream_rng.randi_range(0, i)
		var tmp := outcomes[i]
		outcomes[i] = outcomes[swap_idx]
		outcomes[swap_idx] = tmp
	return outcomes


func _resolve_great_spore_spots(count: int) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	var center := home_position
	if has_target():
		var target_xz := Vector3(
			target.global_position.x, global_position.y, target.global_position.z
		)
		center = global_position.lerp(target_xz, 0.6)
	var base_angle := _stream_rng.randf_range(0.0, TAU)
	var space := get_world_3d().direct_space_state if is_inside_tree() else null

	for i in range(count):
		var chosen := _pick_single_landing_spot(center, i, count, base_angle, spots, space)
		spots.append(chosen)
	return spots


func _pick_single_landing_spot(
	center: Vector3,
	slot_index: int,
	total_count: int,
	base_angle: float,
	chosen_spots: Array[Vector3],
	space: PhysicsDirectSpaceState3D
) -> Vector3:
	var sector := TAU / float(maxi(1, total_count))
	var start_angle := base_angle + float(slot_index) * sector
	var min_spread := minf(
		maxf(3.0, great_spore_min_distance_meters), great_spore_spread_radius_meters
	)
	var max_roam := maxf(movement_radius * 1.45, great_spore_spread_radius_meters * 1.1)
	var angle_offsets := [0.0, 0.35, -0.35, 0.72, -0.72, 1.15, -1.15, 1.75, -1.75, 2.4, -2.4]
	for radial_scale: float in [1.0, 0.88, 0.74, 0.58, 0.42]:
		for angle_offset: float in angle_offsets:
			var angle := start_angle + angle_offset
			var dist := (
				_stream_rng.randf_range(min_spread, great_spore_spread_radius_meters) * radial_scale
			)
			var cand := center + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
			var home_delta := Vector3(cand.x - home_position.x, 0.0, cand.z - home_position.z)
			if home_delta.length() > max_roam:
				cand = home_position + home_delta.normalized() * (max_roam * 0.94)
			var dist_from_elite := (
				Vector2(cand.x - global_position.x, cand.z - global_position.z).length()
			)
			if dist_from_elite < great_spore_min_distance_meters * 0.75 and radial_scale > 0.65:
				continue
			var floor_pos := _sample_landing_floor(cand, space)
			if floor_pos.is_empty():
				continue
			var ground_pos := floor_pos["position"] as Vector3
			if _is_spot_crowded(ground_pos, chosen_spots):
				continue
			return ground_pos
	for safe_step: float in [5.5, 4.0, 2.8]:
		for k in range(12):
			var ang := base_angle + float(slot_index + k) * (TAU / 12.0)
			var cand := global_position + Vector3(cos(ang) * safe_step, 0.0, sin(ang) * safe_step)
			var floor_pos := _sample_landing_floor(cand, space)
			if floor_pos.is_empty():
				continue
			var ground_pos := floor_pos["position"] as Vector3
			if not _is_spot_crowded(ground_pos, chosen_spots):
				return ground_pos
	var fallback := _sample_landing_floor(global_position, space)
	if not fallback.is_empty():
		return fallback["position"] as Vector3
	return global_position


func _sample_landing_floor(at_pos: Vector3, space: PhysicsDirectSpaceState3D) -> Dictionary:
	if space == null:
		return {"position": Vector3(at_pos.x, global_position.y, at_pos.z)}
	var ray_from := Vector3(at_pos.x, global_position.y + 3.2, at_pos.z)
	var ray_to := Vector3(at_pos.x, global_position.y - 3.5, at_pos.z)
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to, CombatLayers.WORLD)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return {}
	# Spores fly over obstacles at hover altitude; only reject spots inside a tall roof/wall shaft.
	var ground_pos := hit["position"] as Vector3
	var ceiling_ray := PhysicsRayQueryParameters3D.create(
		ground_pos + Vector3.UP * 0.35, ground_pos + Vector3.UP * 2.4, CombatLayers.WORLD
	)
	ceiling_ray.exclude = [get_rid()]
	if not space.intersect_ray(ceiling_ray).is_empty():
		return {}
	return hit


func _is_spot_crowded(candidate: Vector3, chosen_spots: Array[Vector3]) -> bool:
	for existing: Vector3 in chosen_spots:
		if Vector2(candidate.x - existing.x, candidate.z - existing.z).length() < 3.0:
			return true
	if is_inside_tree():
		for node in get_tree().get_nodes_in_group(EGG_GROUP):
			var egg := node as Node3D
			if egg != null and is_instance_valid(egg):
				var egg_dist := (
					Vector2(
						candidate.x - egg.global_position.x, candidate.z - egg.global_position.z
					)
					. length()
				)
				if egg_dist < 1.8:
					return true
	return false
