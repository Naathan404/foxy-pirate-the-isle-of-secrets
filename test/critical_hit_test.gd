extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var attack := AttackContext.new()
	attack.damage_hp = 2.0
	attack.critical_rate = 1.0
	attack.critical_damage_multiplier = 1.5
	var template := attack.create_damage_context()
	var hit := template.create_hit_copy()
	hit.resolve_critical()
	_check(
		hit.is_critical and is_equal_approx(hit.amount_hp, 3.0),
		"Guaranteed critical multiplies damage"
	)
	hit.resolve_critical()
	_check(is_equal_approx(hit.amount_hp, 3.0), "Repeated preparation does not multiply twice")
	_check(is_equal_approx(template.amount_hp, 2.0), "Hit leaves attack template unchanged")
	var second := hit.create_hit_copy()
	second.critical_rate = 0.0
	second.resolve_critical()
	_check(
		not second.is_critical and is_equal_approx(second.amount_hp, 2.0),
		"Hit copy resets critical result"
	)
	var world := Node3D.new()
	root.add_child(world)
	var enemy := load("res://gameplay/enemies/starfish/starfish.tscn").instantiate() as EnemyBase
	world.add_child(enemy)
	enemy.set_physics_process(false)
	var remaining := enemy.hp.get_current_hp()
	hit = template.create_hit_copy(enemy)
	hit.source_team = CombatTeams.PLAYER
	hit.base_amount_hp = 100.0
	hit.amount_hp = 100.0
	hit.resolve_critical()
	var applied := enemy.receive_damage(hit)
	_check(is_equal_approx(applied, remaining), "Lethal critical reports actual remaining HP")
	var popup := world.get_node_or_null("CriticalDamagePopup") as Label3D
	_check(popup != null, "Critical damage spawns a number")
	if popup != null:
		_check(popup.modulate.r > popup.modulate.g, "Critical number is red")
		_check(
			is_equal_approx(float(popup.text), snappedf(applied, 0.01)),
			"Popup displays actual damage"
		)
	enemy.free()
	_check(is_instance_valid(popup), "Number survives enemy removal")
	await create_timer(float(popup.get("lifetime")) + 0.15).timeout
	_check(not is_instance_valid(popup), "Number frees after animation")
	world.free()
	if _failures == 0:
		print("Critical roll, idempotence, hit isolation and lethal popup lifecycle passed")
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
