class_name FlatTideEnemySpawner
extends Node3D
## Chọn vị trí khi nước bắt đầu rút, tạo enemy ngay khi từng vị trí khô.

signal enemy_spawned(enemy: EnemyBase, is_elite: bool)

## Controller cung cấp các vùng nước và chu kỳ triều.
@export var controller: FlatTideController
## Danh sách loại enemy; mỗi phần tử gồm scene thường và scene elite tương ứng.
@export var enemies: Array[FlatTideEnemyEntry] = []
## Số enemy tối đa được chọn cho mỗi lần nước rút.
@export_range(0, 100, 1) var enemies_per_tide: int = 1
## Xác suất có đợt spawn trong mỗi lần nước rút, tính theo phần trăm.
@export_range(0.0, 100.0, 0.1, "suffix:%") var wave_chance: float = 100.0
## Xác suất mỗi enemy được chọn là elite, tính theo phần trăm.
@export_range(0.0, 100.0, 0.1, "suffix:%") var elite_chance: float = 10.0
## Khoảng cách ngang tối thiểu giữa các vị trí spawn trong cùng đợt.
@export_range(0.0, 20.0, 0.1, "suffix:m") var minimum_spacing: float = 3.0
## Khoảng cách ngang tối thiểu đến Foxy khi chọn và tạo enemy.
@export_range(0.0, 20.0, 0.1, "suffix:m") var minimum_player_distance: float = 2.0
## Số lần thử tìm vị trí cho mỗi enemy; tăng nếu vùng có nhiều vật cản.
@export_range(1, 500, 1) var attempts_per_enemy: int = 40
## Các lớp va chạm được xem là địa hình.
@export_flags_3d_physics var ground_collision_mask: int = 1
## Khoảng kiểm tra nền ở phía trên và phía dưới đáy vùng nước.
@export_range(0.1, 20.0, 0.1, "suffix:m") var ground_search_distance: float = 2.0
## Khoảng nâng nhỏ để collider của enemy không giao với nền khi spawn.
@export_range(0.01, 0.5, 0.01, "suffix:m") var ground_clearance: float = 0.05

var _random := RandomNumberGenerator.new()
var _pending: Array[Dictionary] = []


func _ready() -> void:
	if not is_instance_valid(controller):
		push_warning("FlatTideEnemySpawner: hãy gán controller.")
		return
	controller.state_changed.connect(_on_state_changed)
	controller.coverage_changed.connect(_on_coverage_changed)


func _on_state_changed(state: FlatTideController.State) -> void:
	if state == FlatTideController.State.FALLING:
		_begin_wave()
	elif state != FlatTideController.State.LOW:
		_pending.clear()


func _begin_wave() -> void:
	_pending.clear()
	if _random.randf() * 100.0 >= wave_chance:
		return
	var available: Array[FlatTideEnemyEntry] = []
	for entry in enemies:
		if entry != null and entry.normal_scene != null and entry.normal_scene.can_instantiate():
			available.append(entry)
	if available.is_empty():
		return
	var zones: Array[FlatTideZone] = []
	var total_area := 0.0
	for zone in controller.zones:
		if is_instance_valid(zone) and zone._fill > 0.0:
			zones.append(zone)
			total_area += zone.size.x * zone.size.y
	if zones.is_empty():
		return
	for attempt in range(enemies_per_tide * attempts_per_enemy):
		if _pending.size() >= enemies_per_tide:
			break
		var pick := _random.randf() * total_area
		var zone: FlatTideZone = zones.back()
		for candidate in zones:
			pick -= candidate.size.x * candidate.size.y
			if pick <= 0.0:
				zone = candidate
				break
		var local := Vector3(
			_random.randf_range(-zone.size.x * 0.5, zone.size.x * 0.5), 0.0,
			_random.randf_range(-zone.size.y * 0.5, zone.size.y * 0.5)
		)
		var point := zone.to_global(local)
		if not zone.contains_flooded_point(point) or not _is_separated(point):
			continue
		var ground = _find_ground(point, zone)
		if not ground is Vector3 or not _away_from_player(ground):
			continue
		var selected: FlatTideEnemyEntry = available[_random.randi_range(0, available.size() - 1)]
		var is_elite := (
			selected.elite_scene != null
			and selected.elite_scene.can_instantiate()
			and _random.randf() * 100.0 < elite_chance
		)
		var scene := selected.elite_scene if is_elite else selected.normal_scene
		_pending.append({"position": ground, "elite": is_elite, "scene": scene})


func _on_coverage_changed(_coverage: float) -> void:
	if controller.state not in [FlatTideController.State.FALLING, FlatTideController.State.LOW]:
		return
	for index in range(_pending.size() - 1, -1, -1):
		var entry := _pending[index]
		var point: Vector3 = entry.position
		if controller.is_point_flooded(point):
			continue
		_pending.remove_at(index)
		_spawn(point, entry.scene, entry.elite)


func _find_ground(point: Vector3, zone: FlatTideZone) -> Variant:
	var ray := PhysicsRayQueryParameters3D.create(
		point + Vector3.UP * ground_search_distance,
		point + Vector3.DOWN * ground_search_distance, ground_collision_mask
	)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or not hit.collider is StaticBody3D or hit.normal.y < 0.7:
		return null
	var ground: Vector3 = hit.position
	if not zone.contains_flooded_point(ground):
		return null
	return ground


func _is_separated(point: Vector3) -> bool:
	for entry in _pending:
		var other: Vector3 = entry.position
		if Vector2(point.x - other.x, point.z - other.z).length() < minimum_spacing:
			return false
	return true


func _away_from_player(point: Vector3) -> bool:
	if not is_instance_valid(controller.player):
		return true
	var player_position := controller.player.global_position
	return Vector2(point.x - player_position.x, point.z - player_position.z).length() >= minimum_player_distance


func _spawn(point: Vector3, scene: PackedScene, is_elite: bool) -> void:
	if not _away_from_player(point):
		return
	var spawn_position := point + Vector3.UP * ground_clearance
	if scene == null or not scene.can_instantiate():
		return
	var instance := scene.instantiate()
	var enemy := instance as EnemyBase
	if enemy == null:
		instance.free()
		push_warning("FlatTideEnemySpawner: scene enemy phải có root là EnemyBase.")
		return
	for child in enemy.get_children():
		var collider := child as CollisionShape3D
		if collider == null or collider.disabled or collider.shape == null:
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = collider.shape
		query.transform = Transform3D(enemy.basis, spawn_position) * collider.transform
		query.collision_mask = ground_collision_mask | CombatLayers.PLAYER_BODY | CombatLayers.ENEMY_BODY
		if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			enemy.free()
			return
	enemy.position = to_local(spawn_position)
	enemy.destroy_on_death = true
	add_child(enemy)
	enemy_spawned.emit(enemy, is_elite)
