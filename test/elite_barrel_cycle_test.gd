extends SceneTree

const ELITE_SCENE := preload("res://gameplay/enemies/barrel/elite_barrel.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var barrel := ELITE_SCENE.instantiate() as EliteBarrel
	root.add_child(barrel)
	barrel.set_physics_process(false)
	barrel.normal_attacks_before_special = 3
	for _attack in 3:
		barrel.complete_normal_attack()
	_check(barrel.special_ready(), "Configured three-attack threshold must be respected")
	barrel.complete_special_attack()
	barrel.normal_attacks_before_special = 5
	barrel.trigger_mode = Barrel.TriggerMode.AUTO
	barrel.auto_aim_at_player = false
	barrel.normal_volley_count = 2
	barrel.normal_bullets_per_volley = 3
	barrel.normal_volley_interval = 0.02
	barrel.special_volley_count = 3
	barrel.special_bullets_per_volley = 8
	barrel.special_volley_interval = 0.02
	var attack := barrel.get_node("States/Scattershot") as EliteBarrelScattershot
	attack.telegraph_duration = 0.05
	attack.release_duration = 0.05
	attack.cooldown = 0.0
	var base_scale := barrel.visual.scale
	var base_color := barrel.visual.sprite.modulate

	for _step in 100:
		barrel.fsm._update(0.05)
		if not attack._special_attack and attack._shots_fired == 1:
			break
	_check(barrel._projectiles.size() == 3, "First normal volley must fire three bullets")
	barrel.trigger_mode = Barrel.TriggerMode.DETECT_PLAYER
	barrel.fsm._update(0.05)
	barrel.fsm._update(0.05)
	_check(barrel.normal_attacks_completed == 0, "Interrupted normal attack must not count")
	barrel._clear_projectiles()
	barrel.trigger_mode = Barrel.TriggerMode.AUTO

	for _step in 300:
		barrel.fsm._update(0.05)
		if barrel.special_ready():
			break
	_check(barrel.normal_attacks_completed == 5, "Five normal attacks must prepare special")
	_check(barrel._projectiles.size() == 30, "Each normal attack must fire two three-bullet fans")
	_check(barrel._charged_feedback_active, "Warning must begin after the fifth normal attack")
	barrel._process(0.02)
	_check(barrel.visual.scale.x > base_scale.x, "Charged Elite must grow")
	_check(barrel.visual.sprite.modulate.g < base_color.g, "Charged Elite must turn red")
	barrel._clear_projectiles()

	# Losing the target during a partial special must keep the charge for a retry.
	for _step in 100:
		barrel.fsm._update(0.05)
		if attack._special_attack and attack._shots_fired == 1:
			break
	_check(barrel._projectiles.size() == 8, "First special volley must fire eight bullets")
	_check(barrel.special_ready(), "Partial special must not consume the charge")
	barrel.trigger_mode = Barrel.TriggerMode.DETECT_PLAYER
	barrel.fsm._update(0.05)
	barrel.fsm._update(0.05)
	_check(barrel.special_ready(), "Interrupted special must retain charge")
	barrel._clear_projectiles()
	barrel.trigger_mode = Barrel.TriggerMode.AUTO

	for _step in 200:
		barrel.fsm._update(0.05)
		if not barrel.special_ready():
			break
	_check(not barrel.special_ready(), "Completed special must consume the charge")
	_check(barrel.normal_attacks_completed == 0, "Completed special must reset the cycle")
	_check(barrel._projectiles.size() == 24, "Special must fire three eight-bullet volleys")
	_check(not barrel._charged_feedback_active, "Warning must stop after special")
	_check(barrel.visual.scale.is_equal_approx(base_scale), "Special must restore visual scale")
	_check(barrel.visual.sprite.modulate.is_equal_approx(base_color), "Special must restore color")
	if barrel._projectiles.size() == 24:
		for index in range(8):
			var bullet := barrel._projectiles[index]
			var expected := Vector3.FORWARD.rotated(Vector3.UP, TAU * float(index) / 8.0)
			_check(bullet._direction.distance_to(expected) < 0.001, "Radial angles must be unique")
			var offset := bullet.global_position - barrel.global_position
			offset.y = 0.0
			_check(
				offset.distance_to(expected * barrel.special_spawn_radius) < 0.001,
				"Radial bullets must spawn around the body"
			)
	barrel._clear_projectiles()
	barrel.queue_free()
	await process_frame
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("Elite Barrel cycle scenarios passed")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
