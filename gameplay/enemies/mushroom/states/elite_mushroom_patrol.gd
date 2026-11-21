class_name EliteMushroomPatrol
extends MushroomPatrol
## Hành vi tuần tra & chiến đấu của EliteMushroom: giữ nguyên toàn bộ chiêu thức cũ
## và kết hợp gọi chiêu thổi luồng khói bào tử liên tục khi Player ở tầm trung-xa.


func _try_start_elite_attack(
	mushroom: MushroomEnemy, _delta: float, target_offset: Vector3
) -> bool:
	var elite := mushroom as EliteMushroom
	if elite == null:
		return false
	if _try_start_stream_attack(elite, target_offset):
		return true
	# Extension point: thêm chiêu thứ 2 cho EliteMushroom tại đây.
	return false


func _try_start_stream_attack(elite: EliteMushroom, target_offset: Vector3) -> bool:
	if elite.stream_cooldown_remaining > 0.0:
		return false
	if elite.is_evading() or elite.is_approach_leaping():
		return false
	var distance := target_offset.length()
	if distance < elite.stream_min_distance_meters or distance > elite.stream_max_distance_meters:
		return false
	var dir := target_offset.normalized()
	elite.face_direction(dir)
	elite._refresh_direction_checks()
	if elite.is_front_blocked():
		return false
	return request_state(&"sporestream")
