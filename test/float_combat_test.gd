extends SceneTree

const ENEMIES: Dictionary = {
	"starfish": [2.6, 3, 2],
	"crab": [3.2, 4, 3],
	"barrel": [4.0, 4, 4],
	"war_lord_turtle": [16.0, 16, 13],
}

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_health()
	var world := Node3D.new()
	root.add_child(world)
	_test_enemy_balance(world)
	_test_hitbox(world)
	await _test_player_and_charms(world)
	root.get_node("HitstopController").cancel()
	root.get_node("ScreenShakeController").cancel()
	root.get_node("AudioManager").stop_all_sfx()
	world.free()
	await create_timer(0.1).timeout
	if _failures == 0:
		print("Float HP, healing, hit payloads, charms, HUD and enemy balance passed")
	quit(0 if _failures == 0 else 1)


func _test_health() -> void:
	var health := HealthComponent.new()
	_check(health.init(2.6), "Fractional maximum initializes")
	var deaths: Array[int] = [0]
	var signals: Array[float] = []
	health.died.connect(func(): deaths[0] += 1)
	health.damaged.connect(func(amount: float): signals.append(amount))
	_near(health.take_damage(1.3), 1.3, "First fractional hit")
	_near(health.get_current_hp(), 1.3, "Fractional HP is retained")
	_near(health.take_damage(1.3), 1.3, "Second fractional hit")
	_check(not health.is_alive() and deaths[0] == 1, "Decimal lethal hit dies once")
	_near(health.get_current_hp(), 0.0, "Lethal hit clamps to zero")
	_near(health.take_damage(1.0), 0.0, "Dead target cannot take more damage")
	_near(health.heal(0.5), 0.0, "Healing cannot revive a dead target")
	_near(signals[0], 1.3, "Damage signal preserves fractions")
	health.free()
	health = HealthComponent.new()
	health.init(8.0)
	_near(health.take_damage(1.3), 1.3, "Small damage does not round")
	_near(health.heal(0.35), 0.35, "Small heal does not round")
	_near(health.get_current_hp(), 7.05, "Damage and healing accumulate precisely")
	health.set_max_hp_modifier(&"fractional_bonus", 0.25)
	_near(health.get_max_hp(), 8.25, "Maximum HP bonus supports fractions")
	_near(health.heal(100.0), 1.2, "Overheal reports only the applied fraction")
	health.remove_max_hp_modifier(&"fractional_bonus")
	_near(health.get_current_hp(), 8.0, "Removing modifier clamps current HP")
	_near(health.take_damage(NAN), 0.0, "NaN damage is rejected")
	_near(health.heal(INF), 0.0, "Infinite healing is rejected")
	_near(health.take_damage(-0.25), 0.0, "Negative damage is rejected")
	health.free()
	health = HealthComponent.new()
	health.init(0.3)
	for index in 3:
		health.take_damage(0.1)
	_check(
		not health.is_alive() and health.current_hp == 0.0,
		"Repeated decimal hits leave no living residue"
	)
	health.free()
	health = HealthComponent.new()
	health.init(100000.0)
	health.take_damage(99999.5)
	_check(health.is_alive(), "Large HP values do not widen the lethal tolerance")
	_near(health.current_hp, 0.5, "A real half-HP remainder stays alive")
	health.free()
	health = HealthComponent.new()
	health.init(1e-9)
	health.take_damage(0.88e-9)
	_check(health.is_alive(), "Tiny positive HP is not treated as zero")
	health.free()


func _enemy(world: Node3D, enemy_name: String) -> EnemyBase:
	var scene := load("res://gameplay/enemies/%s/%s.tscn" % [enemy_name, enemy_name]) as PackedScene
	var enemy := scene.instantiate() as EnemyBase
	enemy.data = enemy.data.duplicate(true)
	enemy.data.drop_chance = 0.0
	world.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy


func _test_enemy_balance(world: Node3D) -> void:
	for enemy_name: String in ENEMIES:
		var expected: Array = ENEMIES[enemy_name]
		for heavy_edge: bool in [false, true]:
			var enemy := _enemy(world, enemy_name)
			_near(enemy.hp.get_max_hp(), expected[0], enemy_name + " authored maximum HP")
			var hits := 0
			while enemy.hp.is_alive() and hits < 30:
				enemy.take_damage(1.3 if heavy_edge else 1.0)
				hits += 1
			_check(enemy.dead, enemy_name + " enters Death when float HP reaches zero")
			_check(hits == expected[2 if heavy_edge else 1], enemy_name + " damage breakpoint")
			enemy.free()


func _test_hitbox(world: Node3D) -> void:
	var enemy := _enemy(world, "starfish")
	var source := Node3D.new()
	world.add_child(source)
	var hitbox := HitBox.new()
	hitbox.actor = source
	hitbox.team = CombatTeams.PLAYER
	source.add_child(hitbox)
	var amounts: Array[float] = []
	hitbox.damage_applied.connect(
		func(_damage: DamageContext, _target: Node, applied: float): amounts.append(applied)
	)
	for index in 3:
		_check(hitbox.begin_attack(0.88, index), "Fractional hitbox begins")
		hitbox._on_area_entered(enemy.hurtbox)
		hitbox._on_area_entered(enemy.hurtbox)
	_near(amounts[0], 0.88, "HurtBox returns a fraction without integer conversion")
	_near(amounts[2], 0.84, "Lethal payload is capped to remaining fractional HP")
	_check(amounts.size() == 3, "Float damage retains hit deduplication")
	_check(enemy.dead, "Real hitbox can kill a fractional-health enemy")
	enemy.free()
	source.free()


func _test_player_and_charms(world: Node3D) -> void:
	var player := load("res://gameplay/player/foxy.tscn").instantiate() as Player
	player.data = player.data.duplicate()
	player.data.max_hp = 8.0
	player.get_node("WeaponController").default_forge = null
	world.add_child(player)
	player.set_physics_process(false)
	await process_frame
	_near(player.take_damage(0.88), 0.88, "Player damage preserves fractions")
	root.get_node("HitstopController").cancel()
	_near(player.hp.current_hp, 7.12, "Player HP preserves fractions")
	var hud := player.get_node("PlayerHUD")
	_near(hud.health_arc.fill_effect._target, 7.12, "HP fill target preserves fractions")
	_check(hud.health_arc.capacity._stat_text.contains("7.12"), "HUD displays fractional HP")
	_near(hud.portrait._health_ratio, 7.12 / 8.0, "Portrait uses the true HP ratio")
	var potion := HealingPotion.new()
	potion.item_id = &"float_test_potion"
	potion.heal_amount = 0.25
	player.potion.inventory.add_item(potion, 1)
	_check(player.potion.equip_potion(potion), "Fractional potion equips")
	_check(player.potion.use_equipped_potion(), "Fractional potion can be consumed")
	_near(player.hp.current_hp, 7.37, "Potion healing is not truncated to zero")
	_check(player.potion.inventory.count_item(potion.item_id) == 0, "Potion consumes one item")
	var source := _enemy(world, "barrel")
	var bullet := (
		load("res://gameplay/enemies/barrel/barrel_bullet.tscn").instantiate() as BarrelBullet
	)
	bullet.launch(source, CombatTeams.ENEMY, Vector3.RIGHT, 0.0, 0.35)
	world.add_child(bullet)
	bullet.hitbox._on_area_entered(player.hurtbox)
	_near(player.hp.current_hp, 7.02, "Enemy projectile preserves fractional damage to Player")
	root.get_node("HitstopController").cancel()
	_test_passive_charms(player)
	_test_active_charms(player)


func _test_passive_charms(player: Player) -> void:
	var definition := (
		load("res://gameplay/charms/charm_data/double_strike.tres").duplicate(true) as CharmData
	)
	definition.proc_chance = 1.0
	var double_strike := DoubleStrikeEffect.new()
	player.add_child(double_strike)
	_check(double_strike.setup(player, definition, CharmRuntime.new()), "Double Strike sets up")
	var damage := DamageContext.new()
	damage.source = player
	damage.amount_hp = 0.88
	damage.base_amount_hp = 0.88
	_near(damage.create_hit_copy().base_amount_hp, 0.88, "Hit copies preserve base fractions")
	_near(
		double_strike.modify_outgoing_damage(0.88, damage),
		1.76,
		"Double Strike multiplies fractional damage"
	)
	definition = load("res://gameplay/charms/charm_data/life_steal.tres").duplicate(true)
	definition.proc_chance = 1.0
	definition.effect_params[&"heal_hp"] = 0.125
	var life_steal := LifeStealEffect.new()
	player.add_child(life_steal)
	_check(life_steal.setup(player, definition, CharmRuntime.new()), "Life Steal sets up")
	var before := player.hp.current_hp
	life_steal.on_damage_dealt(damage, null, 0.88)
	_near(player.hp.current_hp - before, 0.125, "Life Steal healing supports fractional metadata")


func _test_active_charms(player: Player) -> void:
	player.weapon_controller.equipped.definition = (
		player.weapon_controller.equipped.definition.duplicate(true)
	)
	player.weapon_controller.equipped.definition.normal_attack.damage_hp = 0.65
	var activation := CharmActivationContext.new()
	activation.actor = player
	activation.socket_id = CharmConstants.SocketId.Q
	activation.direction = Vector3.BACK
	var arrow := ArrowRainEffect.new()
	player.add_child(arrow)
	var definition := load("res://gameplay/charms/charm_data/arrow_rain.tres") as CharmData
	_check(arrow.setup(player, definition, CharmRuntime.new()), "Arrow Rain sets up")
	var amounts: Array[float] = []
	arrow.projectile_launched.connect(
		func(_index: int, _count: int, _direction: Vector3, amount: float): amounts.append(amount)
	)
	_check(arrow.activate(activation), "Arrow Rain with low base damage activates")
	_near(amounts[0], 0.2275, "Arrow Rain has no one-HP damage floor")
	arrow.cancel_active()
	var cleave := CrescentCleaveEffect.new()
	player.add_child(cleave)
	definition = load("res://gameplay/charms/charm_data/crescent_cleave.tres")
	_check(cleave.setup(player, definition, CharmRuntime.new()), "Cleave sets up")
	_near(cleave._build_context(activation).damage_hp, 1.3, "Cleave does not round damage")
	var tide := TideGrappleEffect.new()
	player.add_child(tide)
	definition = load("res://gameplay/charms/charm_data/tide_grapple.tres")
	_check(tide.setup(player, definition, CharmRuntime.new()), "Tide Grapple sets up")
	_near(tide._build_context(activation).damage_hp, 1.625, "Tide Grapple does not round damage")


func _near(actual: float, expected: float, message: String) -> void:
	_check(
		is_equal_approx(actual, expected), "%s: expected %s, got %s" % [message, expected, actual]
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
