class_name RaidEnemySpawner
extends FlatTideEnemySpawner
## Exact wave composition; blocked positions are retried rather than losing enemies.

signal wave_spawn_finished

@export_range(0, 100, 1) var elite_count: int = 0
@export_range(0.1, 2.0, 0.1, "suffix:s") var retry_seconds := 0.3

var _required_spawns: Array[Dictionary] = []
var _wave_zones: Array[FlatTideZone] = []
var _spawned_positions: Array[Vector3] = []
var _retry_remaining := 0.0


func _begin_wave() -> void:
	_required_spawns.clear()
	_wave_zones.clear()
	_spawned_positions.clear()
	_retry_remaining = 0.0
	for zone in controller.zones:
		if is_instance_valid(zone) and zone._fill > 0.0:
			_wave_zones.append(zone)
	var normal_pool: Array[PackedScene] = []
	var elite_pool: Array[PackedScene] = []
	for entry in enemies:
		if entry == null:
			continue
		if entry.normal_scene != null:
			normal_pool.append(entry.normal_scene)
		if entry.elite_scene != null:
			elite_pool.append(entry.elite_scene)
	if (
		_wave_zones.is_empty()
		or normal_pool.is_empty()
		or elite_count > enemies_per_tide
		or (elite_count > 0 and elite_pool.is_empty())
	):
		push_error("RaidEnemySpawner: invalid zones, enemy pool or elite count.")
		return
	for index in enemies_per_tide:
		var elite := index < elite_count
		var pool := elite_pool if elite else normal_pool
		_required_spawns.append(
			{"scene": pool[_random.randi_range(0, pool.size() - 1)], "elite": elite}
		)
	_required_spawns.shuffle()


func _on_coverage_changed(_coverage: float) -> void:
	if _required_spawns.is_empty():
		return
	if controller.state not in [FlatTideController.State.FALLING, FlatTideController.State.LOW]:
		return
	_retry_remaining -= get_physics_process_delta_time()
	if _retry_remaining > 0.0:
		return
	_retry_remaining = retry_seconds
	for index in range(_required_spawns.size() - 1, -1, -1):
		var entry := _required_spawns[index]
		for attempt in attempts_per_enemy:
			var point = _find_dry_position()
			if not point is Vector3 or not _spawn(point, entry.scene, entry.elite):
				continue
			_spawned_positions.append(point)
			_required_spawns.remove_at(index)
			break
	if _required_spawns.is_empty():
		wave_spawn_finished.emit()


func _find_dry_position() -> Variant:
	var zone := _wave_zones[_random.randi_range(0, _wave_zones.size() - 1)]
	var local := Vector3(
		_random.randf_range(-zone.size.x * 0.5, zone.size.x * 0.5),
		0.0,
		_random.randf_range(-zone.size.y * 0.5, zone.size.y * 0.5)
	)
	var hit := _raycast_ground(zone.to_global(local))
	if hit.is_empty() or hit.collider != spawn_ground or hit.normal.y < MINIMUM_GROUND_NORMAL_Y:
		return null
	var point: Vector3 = hit.position
	if controller.is_point_flooded(point) or not _away_from_player(point):
		return null
	if not _has_edge_clearance(point, spawn_ground):
		return null
	for other in _spawned_positions:
		if Vector2(point.x - other.x, point.z - other.z).length() < minimum_spacing:
			return null
	return point
