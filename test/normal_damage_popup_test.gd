extends SceneTree

const STARFISH: PackedScene = preload("res://gameplay/enemies/starfish/starfish.tscn")

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var enemy := STARFISH.instantiate() as EnemyBase
	world.add_child(enemy)
	enemy.set_physics_process(false)
	var hit := DamageContext.new()
	hit.source_team = CombatTeams.PLAYER
	hit.amount_hp = 0.88
	var applied := enemy.receive_damage(hit)
	var normal := world.get_node_or_null("NormalDamagePopup") as Label3D
	_check(normal != null, "Ordinary hit spawns damage number")
	if normal == null:
		world.free()
		quit(1)
		return
	_check(is_equal_approx(float(normal.text), applied), "Normal damage preserves fractions")
	_check(normal.modulate.g > 0.8 and normal.modulate.b > 0.7, "Normal number is cream white")
	_check(
		world.get_node_or_null("CriticalDamagePopup") == null,
		"Normal hit does not spawn a critical number"
	)
	var count := world.get_child_count()
	hit.amount_hp = 0.0
	enemy.receive_damage(hit)
	hit.amount_hp = 1.0
	hit.source_team = CombatTeams.ENEMY
	enemy.receive_damage(hit)
	_check(world.get_child_count() == count, "Zero and rejected damage do not spawn numbers")
	hit.source_team = CombatTeams.PLAYER
	hit.is_critical = true
	hit.amount_hp = 100.0
	var remaining := enemy.hp.get_current_hp()
	applied = enemy.receive_damage(hit)
	var critical := world.get_node_or_null("CriticalDamagePopup") as Label3D
	_check(critical != null and critical.modulate.g < 0.2, "Critical hit retains red styling")
	_check(
		is_equal_approx(float(critical.text), remaining), "Lethal number shows actual HP removed"
	)
	_check(normal.font_size < critical.font_size, "Normal number is smaller than critical")
	_check(
		float(normal.get("lifetime")) < float(critical.get("lifetime")),
		"Normal number fades sooner"
	)
	enemy.free()
	_check(
		is_instance_valid(normal) and is_instance_valid(critical),
		"Both numbers survive enemy removal"
	)
	await create_timer(float(normal.get("lifetime")) + 0.1).timeout
	_check(not is_instance_valid(normal), "Normal number cleans up after animation")
	_check(is_instance_valid(critical), "Critical number remains readable longer")
	world.free()
	var lethal_world := Node3D.new()
	root.add_child(lethal_world)
	enemy = STARFISH.instantiate() as EnemyBase
	lethal_world.add_child(enemy)
	enemy.set_physics_process(false)
	hit.is_critical = false
	remaining = enemy.hp.get_current_hp()
	enemy.receive_damage(hit)
	normal = lethal_world.get_node_or_null("NormalDamagePopup") as Label3D
	_check(
		normal != null and is_equal_approx(float(normal.text), remaining),
		"Ordinary killing blow also has a number"
	)
	lethal_world.free()
	if _failures == 0:
		print(
			"Normal damage popups: actual fractional damage, rejection, critical distinction, "
			+ "lethal hits and cleanup passed"
		)
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
