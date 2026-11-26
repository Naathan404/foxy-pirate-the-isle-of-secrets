class_name RaidGroundSpawner
extends FlatTideEnemySpawner
## Plays a scripted `RaidWave` on one island: the ground rumbles, then each planned spawn
## point cracks and its enemy climbs out of the ground. A planned point that is off the island
## or taken is moved to the nearest free ground towards the island centre, so the wave keeps
## its shape. Reuses the tide spawner's ground checks, but needs no tide controller.

## Emitted once every enemy of the current wave has appeared.
signal wave_spawn_finished

const PULL_STEP_METERS := 1.5
const SEARCH_RING_RADII_METERS: Array[float] = [1.5, 3.0]
const SEARCH_RING_POINT_COUNT := 8
const RUMBLE_PULSE_SECONDS := 0.25
const EMERGE_SHAKE_SECONDS := 0.2
const EMERGE_SQUASH_SCALE := Vector3(1.25, 0.55, 1.25)
## A point whose crack closed unused is avoided by this much for the rest of the wave.
const BLOCKED_POINT_RADIUS_METERS := 1.5

## Width (x) and depth (z) of the area searched when a planned point has no free ground near.
@export var spawn_extents_meters: Vector2 = Vector2(22.0, 26.0)
@export_range(0.1, 3.0, 0.05, "suffix:s") var telegraph_seconds: float = 1.0
@export_range(0.1, 4.0, 0.05, "suffix:s") var elite_telegraph_seconds: float = 1.6
@export_range(0.1, 2.0, 0.1, "suffix:s") var retry_seconds: float = 0.3
## How long an open crack waits for a body standing on it to move before it closes and the
## enemy picks another point.
@export_range(0.0, 10.0, 0.1, "suffix:s") var blocked_hold_seconds: float = 2.0

@export_group("Emerge")
## How far below its resting height the enemy sprite starts.
@export_range(0.0, 3.0, 0.05, "suffix:m") var emerge_depth_meters: float = 1.2
@export_range(0.05, 2.0, 0.05, "suffix:s") var emerge_seconds: float = 0.45
@export_range(0.05, 2.0, 0.05, "suffix:s") var elite_emerge_seconds: float = 0.75

@export_group("Shake")
@export_range(0.0, 10.0, 0.5, "suffix:px") var rumble_shake_pixels: float = 1.5
@export_range(0.0, 14.0, 0.5, "suffix:px") var emerge_shake_pixels: float = 3.0
@export_range(0.0, 14.0, 0.5, "suffix:px") var elite_emerge_shake_pixels: float = 8.0
@export_group("")

var _unspawned_count: int = 0
## Points where a crack closed because something kept standing on it (a prop, a body), so the
## next try picks another spot instead of waiting there forever.
var _blocked_points: Array[Vector3] = []
## Set while placing an enemy at an already telegraphed point, where only overlap matters.
var _ignore_player_distance: bool = false


# The tide spawner wires itself to a FlatTideController here; this one has none.
func _ready() -> void:
	enemy_spawned.connect(_play_emerge)


## Starts `wave`. Returns false when the wave cannot be played.
func spawn_wave(wave: RaidWave) -> bool:
	if wave == null or wave.spawns.is_empty() or not is_instance_valid(spawn_ground):
		push_error("RaidGroundSpawner: needs a wave with spawns and a spawn ground.")
		return false
	for spec in wave.spawns:
		if spec == null or spec.scene == null:
			push_error("RaidGroundSpawner: every spawn of a wave needs an enemy scene.")
			return false
	_unspawned_count = wave.spawns.size()
	_blocked_points.clear()
	_run_wave(wave)
	return true


func _run_wave(wave: RaidWave) -> void:
	var rumbled_seconds := 0.0
	while rumbled_seconds < wave.lead_in_seconds:
		_shake(rumble_shake_pixels, RUMBLE_PULSE_SECONDS)
		if not await _wait(RUMBLE_PULSE_SECONDS):
			return
		rumbled_seconds += RUMBLE_PULSE_SECONDS
	for spec in wave.spawns:
		_spawn_planned(spec)


func _spawn_planned(spec: RaidSpawnSpec) -> void:
	if spec.delay_seconds > 0.0 and not await _wait(spec.delay_seconds):
		return
	var crack_seconds := elite_telegraph_seconds if spec.is_elite else telegraph_seconds
	while true:
		var point: Variant = _resolve_point(spec)
		if not point is Vector3:
			if not await _wait(retry_seconds):
				return
			continue
		var reserved := {"position": point}
		_pending.append(reserved)
		var effect := _play_telegraph(point, spec.is_elite, crack_seconds)
		if not await _wait(crack_seconds):
			return
		var spawned := await _emerge_when_clear(point, spec)
		if not is_inside_tree():
			return
		_pending.erase(reserved)
		if effect != null:
			if spawned:
				effect.erupt()
			else:
				effect.close()
		if spawned:
			break
		_blocked_points.append(point)
	_unspawned_count -= 1
	if _unspawned_count == 0:
		wave_spawn_finished.emit()


## Brings the enemy out at the cracked point. Foxy may stand close to a crack (it was the
## warning); only a body right on the spot blocks it, and the crack then stays open until
## the spot is free or `blocked_hold_seconds` pass.
func _emerge_when_clear(point: Vector3, spec: RaidSpawnSpec) -> bool:
	var held_seconds := 0.0
	while true:
		_ignore_player_distance = true
		var spawned := _spawn(point, spec.scene, spec.is_elite)
		_ignore_player_distance = false
		if spawned:
			return true
		if held_seconds >= blocked_hold_seconds or not await _wait(retry_seconds):
			return false
		held_seconds += retry_seconds
	return false


## Waits on a tween bound to this node, so the wait pauses with the game and simply never
## resumes if the room is freed. Returns false when the room has left the tree meanwhile.
func _wait(seconds: float) -> bool:
	if not is_inside_tree():
		return false
	await create_tween().tween_interval(seconds).finished
	return is_inside_tree()


func _resolve_point(spec: RaidSpawnSpec) -> Variant:
	var center := global_position
	var anchor := center
	if spec.anchor == RaidSpawnSpec.Anchor.PLAYER:
		var player := get_node("/root/GameManager").player as Player
		if is_instance_valid(player) and player.is_inside_tree():
			anchor = player.global_position
	var planned := anchor + Vector3(spec.offset_meters.x, 0.0, spec.offset_meters.y)
	planned.y = center.y

	# Walk back towards the island centre, which keeps the intended side and spacing.
	var to_center := center - planned
	var pull_steps := ceili(to_center.length() / PULL_STEP_METERS)
	for step in pull_steps + 1:
		var candidate := planned + to_center * (float(step) / maxf(pull_steps, 1))
		var point: Variant = _usable_point(candidate)
		if point is Vector3:
			return point
		for radius in SEARCH_RING_RADII_METERS:
			for index in SEARCH_RING_POINT_COUNT:
				var angle := TAU * index / SEARCH_RING_POINT_COUNT
				point = _usable_point(candidate + Vector3(cos(angle), 0.0, sin(angle)) * radius)
				if point is Vector3:
					return point
	return _find_random_point()


func _usable_point(candidate: Vector3) -> Variant:
	var hit := _raycast_ground(candidate)
	if hit.is_empty() or hit.collider != spawn_ground or hit.normal.y < MINIMUM_GROUND_NORMAL_Y:
		return null
	var point: Vector3 = hit.position
	if (
		_away_from_player(point)
		and _is_separated(point)
		and not _is_near_blocked(point)
		and _has_edge_clearance(point, spawn_ground)
	):
		return point
	return null


func _is_near_blocked(point: Vector3) -> bool:
	for blocked in _blocked_points:
		if Vector2(point.x - blocked.x, point.z - blocked.z).length() < BLOCKED_POINT_RADIUS_METERS:
			return true
	return false


func _find_random_point() -> Variant:
	for attempt in attempts_per_enemy:
		var local := Vector3(
			_random.randf_range(-spawn_extents_meters.x * 0.5, spawn_extents_meters.x * 0.5),
			0.0,
			_random.randf_range(-spawn_extents_meters.y * 0.5, spawn_extents_meters.y * 0.5)
		)
		var point: Variant = _usable_point(to_global(local))
		if point is Vector3:
			return point
	return null


# The telegraph already played at the spawn point, so the tide splash is not repeated.
func _spawn_effect(_point: Vector3, _is_elite: bool) -> void:
	pass


func _away_from_player(point: Vector3) -> bool:
	var player := get_node("/root/GameManager").player as Player
	if _ignore_player_distance or not is_instance_valid(player) or not player.is_inside_tree():
		return true
	var player_position := player.global_position
	return (
		Vector2(point.x - player_position.x, point.z - player_position.z).length()
		>= minimum_player_distance
	)


func _play_telegraph(point: Vector3, is_elite: bool, crack_seconds: float) -> GroundBurstEffect:
	if spawn_effect_scene == null:
		return null
	var instance := spawn_effect_scene.instantiate()
	var effect := instance as GroundBurstEffect
	if effect == null:
		instance.free()
		push_warning("RaidGroundSpawner: spawn effect root must be a GroundBurstEffect.")
		return null
	add_child(effect)
	effect.global_position = point
	effect.play(is_elite, crack_seconds)
	return effect


## The enemy climbs out of the ground with its AI and hurtbox off, so nothing can act on or
## hit it until it is fully up.
func _play_emerge(enemy: EnemyBase, is_elite: bool) -> void:
	_shake(elite_emerge_shake_pixels if is_elite else emerge_shake_pixels, EMERGE_SHAKE_SECONDS)
	var visual := enemy.visual as Node3D
	if not is_instance_valid(visual):
		return
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	# Keep the idle animation playing while the body itself is frozen.
	visual.process_mode = Node.PROCESS_MODE_PAUSABLE
	enemy.hurtbox.enabled = false
	var rest_position := visual.position
	var rest_scale := visual.scale
	visual.position = rest_position + Vector3.DOWN * emerge_depth_meters
	visual.scale = rest_scale * EMERGE_SQUASH_SCALE

	var rise_seconds := elite_emerge_seconds if is_elite else emerge_seconds
	var tween := visual.create_tween().set_parallel()
	var rise := tween.tween_property(visual, "position", rest_position, rise_seconds)
	rise.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var unsquash := tween.tween_property(visual, "scale", rest_scale, rise_seconds)
	unsquash.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(_finish_emerge.bind(enemy))


func _finish_emerge(enemy: EnemyBase) -> void:
	enemy.visual.process_mode = Node.PROCESS_MODE_INHERIT
	enemy.process_mode = Node.PROCESS_MODE_INHERIT
	enemy.hurtbox.enabled = true


func _shake(pixels: float, duration_seconds: float) -> void:
	get_node("/root/ScreenShakeController").request(pixels, duration_seconds)
