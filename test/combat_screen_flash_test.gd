extends SceneTree

const BOW: WeaponData = preload("res://data/weapon/weapon_bow.tres")

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var player := load("res://gameplay/player/foxy.tscn").instantiate() as Player
	world.add_child(player)
	player.set_physics_process(false)
	var flash = player.get_node("Effects/CombatScreenFlash")
	# Use deterministic feedback tuning, independently of the scene's Inspector overrides.
	flash.intensity_scale = 1.0
	flash.maximum_opacity = 0.16
	flash.minimum_interval = 0.25
	flash.bow_color = Color(0.55, 0.85, 1.0)
	flash.bow_opacity = 0.07
	flash.bow_seconds = 0.10
	flash.elite_color = Color(1.0, 0.78, 0.35)
	flash.elite_opacity = 0.10
	flash.elite_seconds = 0.14
	flash.boss_opacity = 0.16
	flash.boss_seconds = 0.28
	var weapons := player.weapon_controller
	_check(not flash.overlay.visible, "Overlay starts hidden")
	_check(flash.overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Overlay cannot block input")
	var context := AttackContext.new()
	context.actor = player
	context.weapon = WeaponInstance.new()
	context.weapon.definition = BOW
	context.projectile_count = 5
	context.charge_progress = 0.99
	weapons.charge_released.emit(context)
	_check(not flash.overlay.visible, "Partial charge does not flash")
	context.charge_progress = 1.0
	weapons.charge_released.emit(context)
	_check(
		flash.overlay.visible and is_equal_approx(flash.overlay.color.a, 0.07),
		"Full bow release flashes softly"
	)
	_check(flash.overlay.color.b > flash.overlay.color.r, "Bow flash is blue")
	context.weapon.definition = load("res://data/weapon/weapon_dagger.tres")
	flash.overlay.hide()
	weapons.charge_released.emit(context)
	_check(not flash.overlay.visible, "Other weapons do not trigger bow flash")
	_kill(world, player, "res://gameplay/enemies/starfish/starfish.tscn")
	_check(not flash.overlay.visible, "Normal enemy kill does not flash")
	_kill(world, player, "res://gameplay/enemies/starfish/elite_starfish.tscn")
	_check(
		flash.overlay.visible and is_equal_approx(flash.overlay.color.a, 0.10),
		"Elite kill replaces weaker bow flash"
	)
	_check(flash.overlay.color.r > flash.overlay.color.b, "Defeat flash is gold")
	var started: int = flash._last_flash_ms
	context.weapon.definition = BOW
	weapons.charge_released.emit(context)
	_check(flash._last_flash_ms == started, "Repeated events respect the rate limit")
	_kill(world, player, "res://gameplay/enemies/starfish/starfish.tscn", true)
	_check(
		is_equal_approx(flash.overlay.color.a, 0.16), "Boss kill immediately replaces elite flash"
	)
	_check(flash.overlay.color.a <= flash.maximum_opacity, "Flashes do not stack opacity")
	await create_timer(0.35).timeout
	_check(not flash.overlay.visible, "Flash fades and hides")
	# Headless frame delta may advance faster than the wall-clock rate limiter.
	flash._last_flash_ms -= 1000
	_kill(world, player, "res://gameplay/enemies/war_lord_turtle/war_lord_turtle.tscn")
	_check(
		is_equal_approx(flash.overlay.color.a, 0.16),
		"Existing turtle scene triggers boss flash without group changes"
	)
	await create_timer(0.35).timeout
	flash.intensity_scale = 0.0
	_kill(world, player, "res://gameplay/enemies/starfish/starfish.tscn", true)
	_check(not flash.overlay.visible, "Zero intensity disables flashes")
	flash.intensity_scale = 1.0
	flash.bow_opacity = 0.7
	flash._last_flash_ms -= 1000
	weapons.charge_released.emit(context)
	_check(
		is_equal_approx(flash.overlay.color.a, 0.16), "Stronger scene tuning respects opacity cap"
	)
	world.free()
	if _failures == 0:
		print(
			"Combat screen flash wiring, eligibility, priority, opacity cap, fade and disable passed"
		)
	quit(0 if _failures == 0 else 1)


func _kill(world: Node3D, player: Player, scene_path: String, boss: bool = false) -> void:
	var enemy := load(scene_path).instantiate() as EnemyBase
	world.add_child(enemy)
	enemy.set_physics_process(false)
	if boss:
		enemy.add_to_group("boss")
	var damage := DamageContext.new()
	damage.source = player
	damage.source_team = CombatTeams.PLAYER
	damage.amount_hp = 10000.0
	var applied := enemy.receive_damage(damage)
	player.weapon_controller._on_damage_applied(
		damage, enemy, applied, player.weapon_controller.equipped
	)
	enemy.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
