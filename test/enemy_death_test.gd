extends SceneTree

const ENEMY_SCENES := [
	preload("res://gameplay/enemies/starfish/starfish.tscn"),
	preload("res://gameplay/enemies/barrel/barrel.tscn"),
	preload("res://gameplay/enemies/crab/elite_crab.tscn"),
	preload("res://gameplay/enemies/starfish/elite_starfish.tscn"),
	preload("res://gameplay/enemies/barrel/elite_barrel.tscn"),
]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for scene: PackedScene in ENEMY_SCENES:
		for scenario: String in ["idle", "hit", "recovery"]:
			await _check_death(scene, scenario)
		await _check_cleanup(scene)
	if not _failures.is_empty():
		for failure: String in _failures:
			push_error(failure)
		quit(1)
		return
	print("Enemy death scenarios passed")
	quit(0)


func _check_death(scene: PackedScene, scenario: String) -> void:
	var enemy := scene.instantiate() as EnemyBase
	enemy.destroy_on_death = false
	root.add_child(enemy)
	await process_frame
	var label := "%s / %s" % [enemy.name, scenario]
	var hit_state := enemy.fsm.states.get("hit") as FsmState
	var death_state := enemy.fsm.states.get("death") as FsmState

	if scenario != "idle":
		enemy.take_damage(1)
		for frame in 60:
			if enemy.fsm.current_state == hit_state:
				break
			await physics_frame
		_check(enemy.fsm.current_state == hit_state, label + ": did not enter Hit")
		if scenario == "recovery":
			for frame in 60:
				if hit_state.get("_is_recovering"):
					break
				await physics_frame
			_check(bool(hit_state.get("_is_recovering")), label + ": did not enter recovery")

	var start_position := enemy.global_position
	enemy.take_damage(enemy.hp.current_hp)
	_check(enemy.dead and enemy.hp.current_hp == 0, label + ": lethal damage did not mark dead")
	if is_instance_valid(enemy.target_detector):
		enemy.target_detector.monitoring = false
		enemy._refresh_target()
	_check(enemy.fsm.next_state == death_state, label + ": Death was not requested")
	for frame in 60:
		if enemy.fsm.current_state == death_state:
			break
		await physics_frame
	_check(enemy.fsm.current_state == death_state, label + ": did not enter Death")
	_check(
		String(enemy.visual.animation_player.assigned_animation).begins_with("hit"),
		label + ": fatal reaction did not play hit animation"
	)
	_check(not enemy.request_state(&"idle"), label + ": Death is not terminal")
	for frame in 30:
		await physics_frame
	var displacement := enemy.global_position - start_position
	displacement.y = 0.0
	_check(not displacement.is_zero_approx(), label + ": fatal recoil did not move enemy")
	_check(
		String(enemy.visual.animation_player.assigned_animation).begins_with("death"),
		label + ": did not play death animation"
	)
	enemy.queue_free()
	await process_frame


func _check_cleanup(scene: PackedScene) -> void:
	var enemy := scene.instantiate() as EnemyBase
	root.add_child(enemy)
	await process_frame
	var label := String(enemy.name)
	enemy.take_damage(enemy.hp.current_hp)
	for frame in 120:
		if not is_instance_valid(enemy):
			break
		await physics_frame
	_check(not is_instance_valid(enemy), label + ": death animation did not clean up enemy")
	if is_instance_valid(enemy):
		enemy.queue_free()
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
