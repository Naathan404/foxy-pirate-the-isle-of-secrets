extends SceneTree
## Plays a split-island room for real and prints PASS/FAIL. Exit code 1 if anything fails.
##
## Reads "split_checks" from the room's layout JSON:
## - "wades":     [[x, z], action, metres]  walking from (x, z) must get at least that far, and a
##                ShallowWaterArea must slow Foxy on the way;
## - "blocked":   [[x, z], action, metres]  walking towards a real gap must stop within that far;
## - "grapples":  [[x, z], [dx, dz], metres] Tide Grapple from (x, z) facing (dx, dz) must carry
##                Foxy at least that far, onto ground.
## - "defeated_bosses": [encounter_id] marked defeated before the room loads (a boss arena checked
##                after the fight, e.g. room_08's broken bridge).
## Actions are the project's input actions (left, right, up, down).
##
## godot --headless --path . --script <this> -- res://.../room_XX.tscn <layout.json>

const Q := CharmConstants.SocketId.Q
const SETTLE_SECONDS := 1.5
const PLACE_SECONDS := 0.4
const WALK_SECONDS := 2.6
const GRAPPLE_SECONDS := 1.6
## Tide Grapple's cooldown is 5 s.
const COOLDOWN_SECONDS := 5.2
const RANGE_UNITS := 7.0
const SPAWN_HEIGHT := 0.6
const GROUND_MIN_Y := -1.0

var _failures := 0
var _player: Player


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var checks: Dictionary = (
		JSON.parse_string(FileAccess.get_file_as_string(args[1]))["split_checks"]
	)
	var game_manager := root.get_node("GameManager")
	for encounter_id: String in checks.get("defeated_bosses", []):
		game_manager.boss_encounters[StringName(encounter_id)] = {
			"defeated": true, "opened": true, "items": {}, "position": Vector3.ZERO
		}
	change_scene_to_file(args[0])
	await create_timer(SETTLE_SECONDS).timeout
	_player = current_scene.get_node("Foxy") as Player
	_player.stamina.set_regeneration_enabled(false)
	_check(_player.charm_socket_manager.debug_equip_charm(&"tide_grapple", Q), "equip Tide Grapple")
	for wade: Array in checks.get("wades", []):
		var slowed: Array[bool] = [false]
		var moved := await _walk(wade[0], wade[1], slowed)
		_check(moved >= float(wade[2]), "wade %s from %s: %.1f m" % [wade[1], wade[0], moved])
		_check(slowed[0], "wade %s from %s is slowed by shallow water" % [wade[1], wade[0]])
	for blocked: Array in checks.get("blocked", []):
		var moved := await _walk(blocked[0], blocked[1], [false])
		_check(
			moved <= float(blocked[2]) and not _player.dead,
			"gap blocks walking %s from %s: %.1f m" % [blocked[1], blocked[0], moved]
		)
	for grapple: Array in checks.get("grapples", []):
		await _grapple(grapple[0], grapple[1], float(grapple[2]))
	print("%d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)


func _place(at: Array) -> void:
	_player.global_position = Vector3(at[0], SPAWN_HEIGHT, at[1])
	_player.velocity = Vector3.ZERO
	await create_timer(PLACE_SECONDS).timeout


func _walk(start: Array, action: String, slowed: Array) -> float:
	await _place(start)
	var from := _player.global_position
	Input.action_press(action)
	var end := Time.get_ticks_msec() + int(WALK_SECONDS * 1000)
	while Time.get_ticks_msec() < end:
		await physics_frame
		slowed[0] = slowed[0] or _player.environment_move_speed_multiplier < 1.0
	Input.action_release(action)
	await create_timer(PLACE_SECONDS).timeout
	return Vector2(from.x, from.z).distance_to(
		Vector2(_player.global_position.x, _player.global_position.z)
	)


func _grapple(start: Array, facing_xz: Array, metres: float) -> void:
	await _place(start)
	var facing := Vector3(facing_xz[0], 0.0, facing_xz[1]).normalized()
	var from := _player.global_position
	_player.stamina.set_current_sp(_player.stamina.get_max_sp())
	_player.last_facing_direction = facing
	var context := CharmActivationContext.new()
	context.actor = _player
	context.socket_id = Q
	context.has_target = true
	context.target_position = from + facing * RANGE_UNITS
	context.direction = facing
	var launched := _player.charm_registry.input_pressed(Q, context)
	await create_timer(GRAPPLE_SECONDS).timeout
	var travelled := (_player.global_position - from).dot(facing)
	_check(
		(
			launched
			and travelled >= metres
			and not _player.dead
			and _player.global_position.y > GROUND_MIN_Y
		),
		"grapple from %s towards %s: %.1f m" % [start, facing_xz, travelled]
	)
	await create_timer(COOLDOWN_SECONDS).timeout


func _check(condition: bool, label: String) -> void:
	print(("PASS  " if condition else "FAIL  ") + label)
	if not condition:
		_failures += 1
