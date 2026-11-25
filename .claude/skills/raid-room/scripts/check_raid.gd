extends SceneTree
## Plays a raid room headlessly and checks the contract in docs/systems/raid_room.md.
## Usage (one line): godot --headless --path .
##     --script .claude/skills/raid-room/scripts/check_raid.gd -- res://path/room.tscn
## Exit code 1 on any failure. Foxy is kept at full HP; enemies are killed by the script once
## they have fully emerged. Prints where each enemy rose, relative to Foxy and to the island.

const TIME_SCALE := 4.0
const STEP_TIMEOUT_MSEC := 60000
const ARRIVAL_SETTLE_FRAMES := 60

var _failures := 0
var _room: BaseRoom
var _player: Player
var _manager: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Pass the room scene after --")
		quit(2)
		return
	Engine.time_scale = TIME_SCALE
	_manager = root.get_node("GameManager")
	_manager.story_flags.clear()
	_room = (load(args[0]) as PackedScene).instantiate() as BaseRoom
	if not _check(_room != null, "scene root is a BaseRoom"):
		quit(1)
		return
	# Like a real arrival: the tree stays paused while Foxy is moved to a door.
	paused = true
	root.add_child(_room)
	await process_frame
	_player = _manager.player

	var lockdowns := _room.find_children("*", "RaidLockdown", true, false)
	if not _check(lockdowns.size() == 1, "exactly one RaidLockdown"):
		quit(1)
		return
	var lockdown := lockdowns[0] as RaidLockdown
	_check_config(lockdown)
	await _check_arrivals(lockdown)

	var stage_index := 0
	for stage in lockdown.stages:
		stage_index += 1
		await _play_stage(lockdown, stage, stage_index)
	await _frames(30)
	if lockdown.reward_chest_scene != null:
		_check(
			not _room.find_children("*", "TreasureChest", true, false).is_empty(),
			"reward chest spawned after every stage is cleared"
		)
	print("Raid check failures: %d" % _failures)
	quit(1 if _failures > 0 else 0)


func _check_config(lockdown: RaidLockdown) -> void:
	_check(lockdown.room == _room, "lockdown.room is the room root")
	_check(not lockdown.stages.is_empty(), "lockdown has stages")
	var any_locking := false
	var ids: Dictionary[StringName, bool] = {}
	for stage in lockdown.stages:
		any_locking = any_locking or stage.locks_room
		_check(not ids.has(stage.stage_id), "%s: unique stage_id" % stage.name)
		ids[stage.stage_id] = true
		_check(stage.spawner != null, "%s: spawner assigned" % stage.name)
		_check(stage.activation_area != null, "%s: activation area assigned" % stage.name)
		if stage.spawner != null:
			_check(
				is_instance_valid(stage.spawner.spawn_ground),
				"%s: spawner has a spawn_ground" % stage.name
			)
			_check(
				stage.spawner.spawn_effect_scene != null,
				"%s: spawner has the ground burst effect" % stage.name
			)
		var complete := not stage.waves.is_empty()
		for wave in stage.waves:
			complete = complete and wave != null and not wave.spawns.is_empty()
			if wave != null:
				for spec in wave.spawns:
					complete = complete and spec != null and spec.scene != null
		_check(complete, "%s: every wave has spawns with enemy scenes" % stage.name)
	if any_locking:
		_check(not lockdown.gates.is_empty(), "a locking raid has at least one gate")


## Foxy appears at each door; no stage may start before Foxy walks in.
func _check_arrivals(lockdown: RaidLockdown) -> void:
	var triggers := _room.find_children("*", "SceneChangeTrigger", true, false)
	for node in triggers:
		var trigger := node as SceneChangeTrigger
		if not trigger.enabled:
			continue
		paused = true
		_player.global_position = trigger.get_exit_position()
		_player.velocity = Vector3.ZERO
		await process_frame
		paused = false
		await _frames(ARRIVAL_SETTLE_FRAMES)
		var started := false
		for stage in lockdown.stages:
			started = started or stage._active
		_check(not started, "no stage starts on arrival at %s" % trigger.get_parent().name)
	paused = false


func _play_stage(lockdown: RaidLockdown, stage: RaidStage, number: int) -> void:
	print("== Stage %d: %s (locks_room=%s)" % [number, stage.name, stage.locks_room])
	var spawner := stage.spawner
	spawner.enemy_spawned.connect(_on_enemy_spawned.bind(spawner))
	stage.wave_started.connect(func(wave: int) -> void: print("  -- wave %d" % wave))
	var stand := _activation_point(stage)
	var started := [false]
	stage.started.connect(func() -> void: started[0] = true, CONNECT_ONE_SHOT)
	_player.global_position = stand
	await _wait_for(func() -> bool: return started[0], "%s starts when Foxy walks in" % stage.name)
	await _frames(5)
	if stage.locks_room:
		_check(_room._exits_locked, "%s: exits locked during the fight" % stage.name)
		for gate in lockdown.gates:
			_check(gate.visible, "%s: gate %s raised" % [stage.name, gate.name])

	var deadline := Time.get_ticks_msec() + STEP_TIMEOUT_MSEC
	while not stage.is_cleared() and Time.get_ticks_msec() < deadline:
		await physics_frame
		_player.global_position = stand
		_player.hp.set_current_hp(_player.hp.get_max_hp())
		for child in spawner.get_children():
			var enemy := child as EnemyBase
			if (
				enemy != null
				and not enemy.dead
				and enemy.process_mode != Node.PROCESS_MODE_DISABLED
			):
				enemy.die()
	_check(stage.is_cleared(), "%s cleared" % stage.name)
	await _frames(60)
	if stage.locks_room:
		_check(not _room._exits_locked, "%s: exits open after the fight" % stage.name)
		for gate in lockdown.gates:
			_check(not gate.visible, "%s: gate %s lowered" % [stage.name, gate.name])


func _activation_point(stage: RaidStage) -> Vector3:
	for child in stage.activation_area.get_children():
		var shape := child as CollisionShape3D
		if shape != null:
			return shape.global_position
	return stage.activation_area.global_position


func _on_enemy_spawned(enemy: EnemyBase, is_elite: bool, spawner: Node3D) -> void:
	var from_player := enemy.global_position - _player.global_position
	var from_center := enemy.global_position - spawner.global_position
	print(
		(
			"    %-28s elite=%-5s foxy(%5.1f, %5.1f) centre(%5.1f, %5.1f)"
			% [
				enemy.scene_file_path.get_file(),
				is_elite,
				from_player.x,
				from_player.z,
				from_center.x,
				from_center.z,
			]
		)
	)


func _wait_for(condition: Callable, label: String) -> void:
	var deadline := Time.get_ticks_msec() + STEP_TIMEOUT_MSEC
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await physics_frame
	_check(condition.call(), label)


func _frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func _check(condition: bool, label: String) -> bool:
	print("%s %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures += 1
	return condition
