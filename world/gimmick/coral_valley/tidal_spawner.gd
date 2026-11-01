class_name TidalSpawner
extends Node3D
## One random reinforcement budget per ebb. Survivors count toward max_alive.
## Place this in the level, alongside TideController, never under an enemy.

signal enemy_spawned(enemy: EnemyBase, is_elite: bool)
signal wave_started(spawn_budget: int, elite_selected: bool)

const TIDAL_ENEMY_SCRIPT = preload("res://world/gimmick/coral_valley/tidal_enemy.gd")
const Placement = preload("res://world/gimmick/coral_valley/tidal_placement.gd")

@export var tide_controller: TideController
@export var enabled: bool = true
## Empty uses the Marker3D children of SpawnPoints in the reusable scene.
@export var spawn_points: Array[Marker3D] = []

@export_group("Enemy Pools")
@export var normal_enemies: Array[PackedScene] = []
@export var elite_enemies: Array[PackedScene] = []
## Rolled once per wave, not once per enemy. Replaces one normal spawn.
@export_range(0.0, 1.0, 0.01) var elite_chance: float = 0.33

@export_group("Population")
@export_range(0, 50, 1) var min_spawns_per_wave: int = 1
@export_range(0, 50, 1) var max_spawns_per_wave: int = 3
@export_range(0, 100, 1) var max_alive: int = 6

@export_group("Placement")
@export_range(0.0, 50.0, 0.1, "suffix:m") var min_player_distance: float = 5.0
@export_range(0.0, 10.0, 0.1, "suffix:m") var min_enemy_distance: float = 1.5
@export_range(0.0, 5.0, 0.01, "suffix:m") var submerge_depth: float = 0.15

@export_group("Seabed")
@export_flags_3d_physics var ground_collision_mask: int = CombatLayers.WORLD
@export_range(0.1, 50.0, 0.1, "suffix:m") var ground_ray_above: float = 8.0
@export_range(1.0, 500.0, 1.0, "suffix:m") var ground_ray_below: float = 128.0
@export_range(0.0, 0.2, 0.01, "suffix:m") var ground_clearance: float = 0.03

@export_group("Appearance")
@export_range(0.0, 3.0, 0.05, "suffix:s") var emerge_duration: float = 0.7
@export_range(0.0, 3.0, 0.05, "suffix:m") var emerge_depth: float = 0.8
@export_range(0.0, 3.0, 0.05, "suffix:s") var sink_duration: float = 0.45

@export_group("Survivor Recovery")
@export_range(0.0, 10.0, 0.1, "suffix:m") var recovery_radius: float = 4.0
@export_range(0.1, 2.0, 0.05, "suffix:s") var recovery_interval: float = 0.35
@export_range(0.0, 10.0, 0.1, "suffix:m") var reveal_player_distance: float = 1.5

var _random := RandomNumberGenerator.new()
var _living: Array[EnemyBase] = []
var _pending_points: Array[Marker3D] = []
var _ground_positions: Dictionary = {}
var _elite_pending: bool = false
var _wave_open: bool = false
var _start_pending: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = -110
	_random.randomize()
	_initialize.call_deferred()


func _initialize() -> void:
	if not is_instance_valid(tide_controller):
		push_warning("TidalSpawner: assign the level's TideController.")
		set_physics_process(false)
		return
	if spawn_points.is_empty():
		var container := get_node_or_null("SpawnPoints")
		if container != null:
			for child: Node in container.get_children():
				if child is Marker3D:
					spawn_points.append(child)
	tide_controller.state_changed.connect(_on_tide_state_changed)
	# Handles controllers which started before this node was ready, including LOW.
	_on_tide_state_changed(tide_controller.state)


func _on_tide_state_changed(state: TideController.State) -> void:
	match state:
		TideController.State.FALLING:
			_wave_open = true
			_start_pending = true
		TideController.State.LOW:
			# FALLING -> LOW belongs to the same wave.
			if not _wave_open:
				_wave_open = true
				_start_pending = true
		_:
			_wave_open = false
			_start_pending = false
			_pending_points.clear()
			_ground_positions.clear()
			_elite_pending = false


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(tide_controller) or not is_instance_valid(tide_controller.water):
		return
	if not enabled:
		# Enabling again mid-wave must not refill enemies killed in that wave.
		_start_pending = false
		_pending_points.clear()
		return
	if _start_pending:
		_start_pending = false
		_begin_wave()
	if not _wave_open or _pending_points.is_empty():
		return
	for index in range(_pending_points.size() - 1, -1, -1):
		var point := _pending_points[index]
		if not is_instance_valid(point):
			_pending_points.remove_at(index)
			continue
		# Reveal lower points later during FALLING; do not wait for LOW as a group.
		var spawn_position: Vector3 = _ground_positions[point]
		# Terrain/props may have changed while this point was under water.
		var refreshed = _find_seabed(point.global_position)
		if not refreshed is Vector3:
			_pending_points.remove_at(index)
			continue
		spawn_position = refreshed
		if tide_controller.get_depth_at(spawn_position) > submerge_depth:
			continue
		_pending_points.remove_at(index)
		# Each selected point is attempted once; blocked points lose their spawn.
		if get_alive_count() >= max_alive or not _is_safe_position(spawn_position):
			continue
		var is_elite := _elite_pending
		if _spawn_enemy(point, spawn_position, is_elite):
			_elite_pending = false


func get_alive_count() -> int:
	for index in range(_living.size() - 1, -1, -1):
		var enemy := _living[index]
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.dead:
			_living.remove_at(index)
	return _living.size()


func _begin_wave() -> void:
	_pending_points.clear()
	_ground_positions.clear()
	_elite_pending = false
	var capacity := maxi(0, max_alive - get_alive_count())
	if capacity == 0 or normal_enemies.is_empty():
		return
	var minimum := maxi(0, mini(min_spawns_per_wave, max_spawns_per_wave))
	var maximum := maxi(minimum, maxi(min_spawns_per_wave, max_spawns_per_wave))
	var budget := mini(capacity, _random.randi_range(minimum, maximum))
	var candidates: Array[Marker3D] = []
	for point: Marker3D in spawn_points:
		if not is_instance_valid(point) or candidates.has(point):
			continue
		var ground = _find_seabed(point.global_position)
		if ground is Vector3 and _is_safe_position(ground):
			candidates.append(point)
			_ground_positions[point] = ground
	# Fisher-Yates uses the same RNG as count/type/Elite selection.
	for index in range(candidates.size() - 1, 0, -1):
		var other := _random.randi_range(0, index)
		var point := candidates[index]
		candidates[index] = candidates[other]
		candidates[other] = point
	for index in range(mini(budget, candidates.size())):
		_pending_points.append(candidates[index])
	budget = _pending_points.size()
	if budget > 0 and not elite_enemies.is_empty():
		_elite_pending = _random.randf() < elite_chance
	wave_started.emit(budget, _elite_pending)


func _is_safe_position(position: Vector3) -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"player"):
		var player := node as Node3D
		if is_instance_valid(player) and _horizontal_distance(position, player.global_position) < min_player_distance:
			return false
	for enemy: EnemyBase in _living:
		if _horizontal_distance(position, enemy.global_position) < min_enemy_distance:
			return false
	return true


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _find_seabed(marker_position: Vector3) -> Variant:
	return Placement.find_floor(self, marker_position, ground_collision_mask,
		ground_ray_above, ground_ray_below, ground_clearance)


func _spawn_enemy(point: Marker3D, spawn_position: Vector3, is_elite: bool) -> bool:
	var pool := elite_enemies if is_elite else normal_enemies
	var scene := pool[_random.randi_range(0, pool.size() - 1)]
	if scene == null or not scene.can_instantiate():
		push_warning("TidalSpawner: enemy pools must contain valid PackedScenes.")
		return false
	var instance := scene.instantiate()
	var enemy := instance as EnemyBase
	if enemy == null:
		push_warning("TidalSpawner: enemy scene root must extend EnemyBase.")
		instance.free()
		return false
	# Configure before add_child so _ready sees the right position and controller.
	var spawn_transform := point.global_transform
	spawn_transform.origin = spawn_position
	enemy.transform = global_transform.affine_inverse() * spawn_transform
	if not Placement.can_stand(self, enemy, spawn_position, ground_collision_mask,
			ground_clearance, min_player_distance):
		enemy.free()
		return false
	enemy.destroy_on_death = true
	var tidal: TidalEnemy = null
	for child: Node in enemy.get_children():
		if child is TidalEnemy:
			tidal = child
			break
	if tidal == null:
		tidal = TIDAL_ENEMY_SCRIPT.new()
		tidal.name = &"TidalEnemy"
		enemy.add_child(tidal)
	tidal.tide_controller = tide_controller
	tidal.submerge_depth = submerge_depth
	tidal.emerge_duration = emerge_duration
	tidal.emerge_depth = emerge_depth
	tidal.sink_duration = sink_duration
	tidal.ground_collision_mask = ground_collision_mask
	tidal.ground_clearance = ground_clearance
	tidal.recovery_points = spawn_points.duplicate()
	tidal.recovery_radius = recovery_radius
	tidal.recovery_interval = recovery_interval
	tidal.reveal_player_distance = reveal_player_distance
	tidal.animate_initial_spawn = true
	add_child(enemy)
	# Parent _ready has completed: hide/start the reveal before the first render.
	tidal._initialize()
	_living.append(enemy)
	enemy_spawned.emit(enemy, is_elite)
	return true
