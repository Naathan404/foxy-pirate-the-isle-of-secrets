extends SceneTree
## Integration and balance trials with the production Foxy, HUD, enemy hurtboxes and physics.

const ARENA := preload("res://world/tests/enemy_test.tscn")
const CRAB := preload("res://gameplay/enemies/crab/crab.tscn")
const Q := CharmConstants.SocketId.Q
const E := CharmConstants.SocketId.E
const RIGHT := Vector3.RIGHT
const DUMMY_HP := 100.0

var arena: Node3D
var player: Player
var crab: EnemyBase
var registry: CharmRegistry
var manager: CharmSocketManager
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	arena = ARENA.instantiate()
	arena.get_node("BounceObstacle").free()
	for child in arena.get_children():
		if child is EnemyBase:
			child.free()
	root.add_child(arena)
	current_scene = arena
	player = arena.get_node("Foxy")
	manager = player.charm_socket_manager
	registry = player.charm_registry
	player.global_position = Vector3.ZERO
	player.stamina.set_regeneration_enabled(false)
	crab = CRAB.instantiate()
	crab.data = crab.data.duplicate()
	crab.data.max_hp = DUMMY_HP
	arena.add_child(crab)
	crab.set_physics_process(false)
	crab.contact_hitbox.end_attack()
	crab.global_position = RIGHT * 3.0
	await _frames(10)
	_check(
		registry.get_registered_ids().size() == 24 and registry.validate_catalog().is_empty(),
		"24 valid catalog entries"
	)
	await _casts()
	await _whirlpool_trials()
	await _mobility()
	await _arrow_trials()
	await _new_actives()
	await _passives()
	await _acquisition()
	await _wall_and_recall()
	await _staff_regression()
	await _boss_and_cleanup()
	print("Charm arena failures: ", failures)
	arena.queue_free()
	await _frames(3)
	quit(1 if failures > 0 else 0)


func _casts() -> void:
	_equip(&"crescent_cleave")
	_check(_cast(Q, RIGHT), "cleave accepted")
	var before := player.global_position
	Input.action_press(&"right")
	await _frames(3)
	_check(
		player.is_charm_casting() and before.distance_to(player.global_position) < 0.05,
		"cleave holds movement"
	)
	await _frames(24)
	Input.action_release(&"right")
	_check(
		not player.is_charm_casting() and before.distance_to(player.global_position) > 0.1,
		"held movement resumes"
	)
	player.global_position = Vector3.ZERO
	_equip(&"dead_mans_salute")
	_check(_cast(Q, RIGHT), "charge accepted")
	await _frames(8)
	var paid := player.stamina.get_current_sp()
	registry.input_released(Q, _context(Q, RIGHT))
	_check(not player.is_charm_casting() and paid < 1000.0, "release unroots and drains SP")
	_equip(&"abyssal_whirlpool")
	var hp := crab.hp.current_hp
	_check(_cast(Q, crab.global_position), "whirlpool accepted")
	await _frames(35)
	_check(player.is_charm_casting(), "whirlpool holds through sustain")
	await _frames(85)
	_check(
		not player.is_charm_casting() and crab.hp.current_hp < hp,
		"whirlpool detonates and releases"
	)
	print("Whirlpool damage ", hp - crab.hp.current_hp)
	_equip(&"dead_mans_anchor", E)
	var border := player.find_child("RecallBorder", true, false) as Node2D
	var rim := border.get_node("Rim") as Line2D
	var glow := border.get_node("Glow") as Line2D
	var perimeter := _line_length(rim)
	var mark := player.global_position
	_check(_cast(E, RIGHT), "anchor placed")
	player.global_position += Vector3.FORWARD * 2
	await _frames(3)
	var label := player.find_child("RecallHint", true, false) as Label
	_check(label.visible and label.text == "[E]  RECALL", "E recast visible in HUD")
	var marker := arena.get_node("DeadMansAnchorMarker") as Sprite3D
	_check(is_instance_valid(marker) and marker.global_position.y > mark.y, "anchor drops at cast")
	var slot := player.find_child("E_socket", true, false)
	_check(
		(
			border.visible
			and _line_length(rim) > perimeter * 0.95
			and not slot.get_node("Cooldown").visible
			and not slot.get_node("CooldownLabel").visible
		),
		"only border signals recast in slot"
	)
	await _frames(147)
	_check(
		(
			border.visible
			and not rim.closed
			and not glow.closed
			and absf(_line_length(rim) / perimeter - 0.5) < 0.02
			and rim.points == glow.points
			and is_equal_approx(marker.global_position.y, mark.y)
		),
		"half the rim and glow remain halfway through the recall window"
	)
	_checkpoint("anchor")
	var sp := player.stamina.current_sp
	_check(
		_cast(E, RIGHT) and player.global_position.distance_to(mark) < 0.1, "recall returns to mark"
	)
	_check(is_equal_approx(sp, player.stamina.current_sp), "recall is free")
	await _frames(2)
	_check(
		not border.visible and slot.get_node("Cooldown").visible,
		"recall replaces rim with cooldown"
	)
	manager.debug_unequip_charm(E)


func _crab_at(site: Vector3) -> EnemyBase:
	var target := CRAB.instantiate() as EnemyBase
	target.data = crab.data
	arena.add_child(target)
	target.set_physics_process(false)
	target.contact_hitbox.end_attack()
	target.global_position = site
	return target


func _line_length(line: Line2D) -> float:
	var length := 0.0
	for i in range(1, line.get_point_count()):
		length += line.get_point_position(i - 1).distance_to(line.get_point_position(i))
	return length


func _whirlpool_trials() -> void:
	_equip(&"abyssal_whirlpool")
	var site := RIGHT * 3.0
	var group := [crab, _crab_at(site + Vector3.BACK), _crab_at(site + Vector3.FORWARD)]
	var runtime := registry.get_equipped(Q)
	var original := runtime.definition
	for cost: float in [400.0, 300.0]:
		var trial := original.duplicate() as CharmData
		trial.resource_cost = cost
		runtime.definition = trial
		runtime.effect.definition = trial
		runtime.reset_cooldown()
		player.stamina.set_current_sp(1000.0)
		for index in group.size():
			var target := group[index] as EnemyBase
			target.global_position = site + Vector3.BACK * (index - 1)
			target.hp.set_current_hp(DUMMY_HP)
		await _frames(2)
		_check(_cast(Q, site), "whirlpool trial accepted")
		await _frames(110)
		var total := 0.0
		for target: EnemyBase in group:
			total += DUMMY_HP - target.hp.current_hp
		print("Whirlpool cost ", cost, " damage on three crabs ", total)
		_check(
			is_equal_approx(total, 7.5) and player.stamina.current_sp == 1000.0 - cost,
			"whirlpool three contacts, one cost"
		)
	runtime.definition = original
	runtime.effect.definition = original
	group[1].queue_free()
	group[2].queue_free()
	await _frames(2)


func _mobility() -> void:
	player.global_position = Vector3.ZERO
	crab.global_position = RIGHT * 2
	var farther := _crab_at(RIGHT * 3.8)
	var farther_hp := farther.hp.current_hp
	await _frames(2)
	_equip(&"shadow_lunge")
	var hp := crab.hp.current_hp
	var start := player.global_position
	_check(
		_cast(Q, RIGHT * 5) and player.global_position.is_equal_approx(start),
		"lunge does not teleport on press"
	)
	await _frames(30)
	_check(
		player.global_position.x < crab.global_position.x and crab.hp.current_hp < hp,
		"lunge stops on first crab"
	)
	_check(farther.hp.current_hp == farther_hp, "lunge leaves the second crab untouched")
	farther.queue_free()
	player.global_position = Vector3.ZERO
	crab.global_position = RIGHT * 6.2
	registry.get_equipped(Q).reset_cooldown()
	_check(_cast(Q, RIGHT * 5), "second lunge accepted")
	await _frames(3)
	_check(
		player.take_damage(1.0) > 0.0 and not player.is_charm_casting(),
		"incoming hit interrupts lunge"
	)
	await _frames(65)
	player.global_position = Vector3.ZERO
	player.set_horizontal_velocity(Vector3.ZERO)
	crab.global_position = RIGHT * 6.2
	_equip(&"tide_grapple")
	hp = crab.hp.current_hp
	_check(_cast(Q, RIGHT * 7), "long grapple launched")
	await _frames(65)
	print(
		"Grapple 6.2 units damage ",
		hp - crab.hp.current_hp,
		" crab position ",
		crab.global_position
	)
	_check(
		crab.hp.current_hp < hp and crab.global_position.x < 3,
		"grapple reaches 6.2 units and reels crab"
	)
	_equip(&"buckshot_salvo")
	crab.global_position = RIGHT * 7.2
	hp = crab.hp.current_hp
	_check(_cast(Q, RIGHT * 8), "long salvo launched")
	var start_site := player.global_position
	Input.action_press(&"down")
	await _frames(5)
	_check(
		player.is_charm_casting() and start_site.distance_to(player.global_position) < 0.05,
		"buckshot roots through windup"
	)
	_check(
		player.visual.charm_cast_animator.is_playing_charm(&"buckshot_salvo"),
		"buckshot cast visible"
	)
	await _frames(24)
	Input.action_release(&"down")
	_check(
		not player.is_charm_casting() and start_site.distance_to(player.global_position) > 0.1,
		"buckshot releases at muzzle flash"
	)
	await _frames(40)
	_check(crab.hp.current_hp < hp, "pellet reaches 7.2 units")


func _arrow_trials() -> void:
	_equip(&"arrow_rain")
	player.global_position = Vector3.ZERO
	crab.global_position = RIGHT * 3.0
	var runtime := registry.get_equipped(Q)
	var original := runtime.definition
	for multiplier: float in [1.5, 1.0]:
		var trial := original.duplicate(true) as CharmData
		trial.effect_params["damage_percent"] = multiplier
		runtime.definition = trial
		runtime.effect.definition = trial
		runtime.reset_cooldown()
		crab.hp.set_current_hp(DUMMY_HP)
		_check(_cast(Q, crab.global_position), "arrow volley accepted")
		await _frames(112)
		print("Arrow per arrow ", multiplier, " damage on crab ", DUMMY_HP - crab.hp.current_hp)
		_check(not player.is_charm_casting(), "arrow unlocks after last launch")
	runtime.definition = original
	runtime.effect.definition = original


func _new_actives() -> void:
	player.global_position = Vector3.ZERO
	crab.global_position = RIGHT * 3.0
	_equip(&"glacial_spikes")
	var hp := crab.hp.current_hp
	player.last_facing_direction = RIGHT
	var behind := _crab_at(Vector3.LEFT * 2)
	var behind_hp := behind.hp.current_hp
	_check(_cast(Q, behind.global_position), "glacial casts toward facing even with cursor behind")
	var frost := registry.get_equipped(Q).effect
	_check(
		(
			frost.get("_marks").size() == 6
			and player.visual.charm_cast_animator.is_playing_charm(&"glacial_spikes")
		),
		"six sites and frost windup"
	)
	for expected_remaining: int in [5, 3, 0]:
		var ticks := 0
		while frost.get("_marks").size() > expected_remaining and ticks < 45:
			await _frames(1)
			ticks += 1
		_check(frost.get("_marks").size() == expected_remaining, "successive ice rows 1-2-3")
	_checkpoint("glacial")
	await _frames(18)
	_check(
		(
			is_equal_approx(behind.hp.current_hp, behind_hp)
			and is_equal_approx(hp - crab.hp.current_hp, 1.5)
		),
		"only the forward fan hits, once per target"
	)
	behind.queue_free()
	_check(
		crab.hp.current_hp < hp and not player.is_charm_casting(), "forward spikes hit and release"
	)
	print("Glacial damage ", hp - crab.hp.current_hp)
	_equip(&"meteor_strike")
	var runtime := registry.get_equipped(Q)
	var original := runtime.definition
	for cost in [150.0, 250.0, 500.0]:
		var candidate := original.duplicate() as CharmData
		candidate.resource_cost = cost
		runtime.definition = candidate
		runtime.effect.definition = candidate
		player.stamina.set_current_sp(1000.0)
		crab.hp.set_current_hp(DUMMY_HP)
		runtime.reset_cooldown()
		_check(_cast(Q, crab.global_position), "meteor accepted")
		_check(
			(
				player.visual.charm_cast_animator.is_playing_charm(&"meteor_strike")
				and player.is_charm_casting()
			),
			"meteor windup matches gameplay"
		)
		_check(is_equal_approx(player.stamina.current_sp, 1000.0 - cost), "one meteor charge")
		await _frames(65)
		_checkpoint("meteor")
		await _frames(260)
		print("Meteor cost ", cost, " damage on 100 HP ", DUMMY_HP - crab.hp.current_hp)
		_check(
			crab.hp.current_hp < DUMMY_HP - 4.0 and not player.is_charm_casting(),
			"meteor impact and burn"
		)
	runtime.definition = original
	runtime.effect.definition = original
	_equip(&"devil_contract")
	player.stamina.set_current_sp(299.0)
	_check(
		not _cast(Q, RIGHT) and player.stamina.current_sp == 299.0,
		"contract rejects below threshold"
	)
	player.stamina.set_current_sp(780.0)
	_check(_cast(Q, RIGHT) and player.stamina.current_sp == 0.0, "contract spends all 780 SP")
	_check(player.stamina.restore(10.0) == 0.0, "contract blocks external recovery")
	_check(
		(
			player.visual.charm_cast_animator.is_playing_charm(&"devil_contract")
			and player.is_charm_casting()
		),
		"pact has a windup"
	)
	await _frames(25)
	_check(
		not player.is_charm_casting() and player.has_node("DevilContractParticles"),
		"buff particles follow Foxy after sealing"
	)
	var stats: Dictionary[StringName, float] = {}
	registry.modify_stats(stats)
	_check(
		is_equal_approx(stats.get(&"move_speed_multiplier", 0.0), 1.3),
		"contract movement multiplier"
	)
	_check(
		(
			is_equal_approx(registry.modify_attack_damage(2.0, AttackContext.new()), 2.6)
			and is_equal_approx(stats[&"charm_damage_multiplier"], 1.3)
		),
		"contract weapon and charm multipliers"
	)
	await _frames(10)
	_checkpoint("contract")
	manager.debug_unequip_charm(Q)
	_check(player.stamina.restore(10.0) == 10.0, "contract cleanup restores SP recovery")
	await _frames(2)
	_check(not player.has_node("DevilContractParticles"), "unequip removes embers")
	_equip(&"devil_contract")
	_check(_cast(Q, RIGHT), "second pact starts")
	await _frames(24)
	_check(player.has_node("DevilContractParticles"), "second pact creates its emitter")
	await _frames(611)
	_check(
		not player.has_node("DevilContractParticles") and player.stamina.restore(10.0) == 10.0,
		"pact expiry clears particles and SP lock"
	)
	_check(
		registry.modify_attack_damage(2.0, AttackContext.new()) == 2.0, "pact expiry clears bonus"
	)


func _passives() -> void:
	player.global_position = Vector3.ZERO
	crab.global_position = RIGHT * 3
	crab.hp.set_current_hp(DUMMY_HP)
	var normal := DamageContext.new()
	normal.source = player
	normal.tag = &"normal"
	_equip(&"crimson_band")
	registry.dispatch_event(&"damage_dealt", [normal, crab, 1.0])
	await _frames(33)
	registry.dispatch_event(&"damage_dealt", [normal, crab, 1.0])
	await _frames(163)
	_check(
		is_equal_approx(crab.hp.current_hp, DUMMY_HP - 1.5), "crimson refresh preserves tick phase"
	)
	# The stationary target has no AI tick to expire its earlier Glacial stun.
	crab.set("_charm_stun_remaining", 0.0)
	_equip(&"skull_cracker")
	for hit in 4:
		registry.dispatch_event(&"damage_dealt", [normal, crab, 1.0])
	_check(
		is_equal_approx(crab.get("_charm_stun_remaining"), 0.6),
		"four confirmed hits stun one target"
	)
	_equip(&"death_bloom")
	var hp := player.hp.current_hp
	var victim := Node3D.new()
	arena.add_child(victim)
	victim.global_position = RIGHT
	crab.global_position = RIGHT * 1.7
	registry.dispatch_event(&"target_defeated", [victim, normal])
	var enemy_hp := crab.hp.current_hp
	await _frames(40)
	_check(
		player.hp.current_hp == hp - 1.0 and crab.hp.current_hp == enemy_hp - 1.0,
		"death bloom harms Foxy and crab"
	)
	victim.queue_free()
	await _frames(65)
	_equip(&"shadow_renment")
	_equip(&"momentum_strike", E)
	player.global_position = Vector3.ZERO
	player.last_facing_direction = Vector3.FORWARD
	crab.global_position = RIGHT * 1.5
	enemy_hp = crab.hp.current_hp
	player.request_dash()
	await _frames(48)
	_check(crab.hp.current_hp < enemy_hp, "real dash leaves delayed shadow blast")
	var attack := AttackContext.new()
	attack.action = &"normal"
	attack.damage_hp = 2.0
	player.weapon_controller.attack_released.emit(attack)
	_check(attack.damage_hp == 3.0, "dash empowers first normal release")
	player.weapon_controller.attack_released.emit(attack)
	_check(attack.damage_hp == 3.0, "momentum consumed exactly once")
	_equip(&"fortune_leaf")
	var stats: Dictionary[StringName, float] = {}
	registry.modify_stats(stats)
	var multiplier: float = stats.get(&"item_drop_multiplier", 1.0)
	_check(is_equal_approx(0.2 * multiplier, 0.22), "fortune changes 20% to 22%")
	_check(not CharmAcquisitionService.is_item_drop(0.21, 0.20, 1.0), "base roll misses")
	_check(
		CharmAcquisitionService.is_item_drop(0.21, 0.20, multiplier), "same roll with Fortune drops"
	)
	_check(
		not CharmAcquisitionService.is_item_drop(0.221, 0.20, multiplier),
		"outside bonus still misses"
	)
	_check(not CharmAcquisitionService.is_item_drop(0.0, 0.0, multiplier), "zero chance stays zero")
	_check(
		CharmAcquisitionService.is_item_drop(1.0, 1.0, multiplier),
		"guaranteed drops stay guaranteed"
	)


func _acquisition() -> void:
	var merchant := MerchantTransactionService.new(
		preload("res://data/merchants/silas_catalog.tres")
	)
	var wallet := GoldWallet.new()
	for id: StringName in [&"crimson_band", &"skull_cracker", &"momentum_strike", &"fortune_leaf"]:
		var before := wallet.get_balance()
		var result := merchant.purchase(id, null, wallet, null, 1, registry)
		_check(
			result == MerchantTransactionService.Result.SUCCESS and registry.is_owned(id),
			"Silas unlocks %s" % id
		)
		var price := 200 if id == &"fortune_leaf" else 100
		_check(wallet.get_balance() == before - price, "sheet merchant price")
		result = merchant.purchase(id, null, wallet, null, 1, registry)
		_check(
			(
				result == MerchantTransactionService.Result.ALREADY_OWNED
				and wallet.get_balance() == before - price
			),
			"duplicate purchase is free"
		)
	var acquisition := CharmAcquisitionService.new()
	for id: StringName in [&"glacial_spikes", &"meteor_strike", &"devil_contract"]:
		_check(acquisition.grant_fixed_boss_reward(registry, id), "fixed reward grants %s" % id)
	_check(crab.charm_loot.size() == 4, "real enemy has four eligible charm definitions")
	_check(
		(
			not crab.data.elite_charm_drops
			and preload("res://data/enemies/elite_crab_data.tres").elite_charm_drops
		),
		"elite-only loot uses enemy data"
	)


func _wall_and_recall() -> void:
	var wall := StaticBody3D.new()
	wall.collision_layer = CombatLayers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.08, 2.0, 3.0)
	shape.shape = box
	wall.add_child(shape)
	arena.add_child(wall)
	wall.global_position = Vector3(2, 1, 0)
	crab.global_position = Vector3.RIGHT * 4.0
	player.global_position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await _frames(3)
	_equip(&"shadow_lunge")
	var hp := crab.hp.current_hp
	_check(_cast(Q, RIGHT * 5), "lunge launches toward thin wall")
	await _frames(22)
	_check(
		player.global_position.x < 2 and crab.hp.current_hp == hp,
		"thin wall stops lunge before crab"
	)
	var hint := player.find_child("RecallHint", true, false) as Label
	for slot: int in [Q, E, CharmConstants.SocketId.SPACE]:
		var key := str({Q: "Q", E: "E", CharmConstants.SocketId.SPACE: "SPACE"}[slot])
		player.global_position = Vector3.ZERO
		_equip(&"dead_mans_anchor", slot)
		_check(_cast(slot, RIGHT), "arm recall in " + key)
		player.global_position = RIGHT * 3.2
		await _frames(3)
		_check(hint.visible and key in hint.text, "resolved recall binding " + key)
		var border := player.find_child("RecallBorder", true, false) as Node2D
		var rim := border.get_node("Rim") as Line2D
		_check(
			border.visible and rim.get_point_count() == 5, "new recall starts with all four edges"
		)
		_check(not _cast(slot, RIGHT), "wall blocks recall")
		var effect := registry.get_equipped(slot).effect as DeadMansAnchorEffect
		_check(
			(
				effect.get_recast_remaining() > 0
				and registry.get_equipped(slot).cooldown_remaining == 0.0
			),
			"blocked recall stays armed"
		)
		manager.debug_unequip_charm(slot)
		await _frames(2)
		_check(not hint.visible, "unequip clears recall HUD")
	wall.queue_free()
	player.global_position = Vector3.ZERO
	await _frames(3)


func _staff_regression() -> void:
	var controller := player.weapon_controller
	var previous := controller.equipped
	var staff := WeaponInstance.new()
	staff.definition = preload("res://data/weapon/weapon_meteor_staff.tres")
	_check(controller.equip(staff), "equip Meteor Staff")
	var counts: Array[int] = [0, 0]
	var observe := func(node: Node) -> void:
		if node.scene_file_path == "res://gameplay/weapons/meteor_impact.tscn":
			counts[0] += 1
			node.connect("landed", func(_at: Vector3, _hit: bool) -> void: counts[1] += 1)
	arena.child_entered_tree.connect(observe)
	for action: StringName in [&"normal", &"secondary"]:
		var request := player.build_attack_context()
		request.action = action
		request.has_target = true
		request.target_position = player.global_position + RIGHT * 3.0
		player.chaos.gain(player.data.max_chaos)
		player.stamina.set_current_sp(player.stamina.get_max_sp())
		counts.assign([0, 0])
		_check(controller.try_attack(request), "staff launches %s" % action)
		await _frames(235)
		var expected := counts[0] == 1 if action == &"normal" else counts[0] >= 4 and counts[0] <= 6
		_check(expected and counts[0] == counts[1], "all staff meteors land %s" % action)
		print("Staff ", action, " launched/landed ", counts)
	arena.child_entered_tree.disconnect(observe)
	if previous != null:
		_check(controller.equip(previous), "restore initial weapon")


func _boss_and_cleanup() -> void:
	var boss := (
		preload("res://gameplay/bosses/blubberbeard/blubberbeard.tscn").instantiate() as BossBase
	)
	arena.add_child(boss)
	boss.global_position = Vector3.BACK * 4.0
	boss.set_physics_process(false)
	player.global_position = Vector3.ZERO
	var before := boss.hp.current_hp
	var site := boss.global_position
	_equip(&"abyssal_whirlpool")
	_check(_cast(Q, site), "boss whirlpool cast")
	await _frames(110)
	_check(
		boss.hp.current_hp < before and boss.global_position.is_equal_approx(site),
		"boss takes detonation without being pulled"
	)
	boss.queue_free()
	_equip(&"glacial_spikes")
	_check(_cast(Q, RIGHT), "glacial windup started")
	manager.debug_unequip_charm(Q)
	_check(not player.is_charm_casting(), "unequip during windup releases control")
	_equip(&"dead_mans_salute")
	player.stamina.set_current_sp(5.0)
	_check(_cast(Q, RIGHT), "charge starts with 5 SP")
	await _frames(14)
	_check(
		not player.is_charm_casting() and player.stamina.current_sp == 0.0, "empty SP auto-releases"
	)
	_equip(&"dead_mans_anchor")
	_check(_cast(Q, RIGHT), "anchor armed before pause")
	var anchor := registry.get_equipped(Q).effect as DeadMansAnchorEffect
	var remaining := anchor.get_recast_remaining()
	registry.input_cancelled()
	_check(anchor.get_recast_remaining() == remaining, "opening a modal preserves the armed anchor")
	paused = true
	await create_timer(0.12, true, false, true).timeout
	_check(
		is_equal_approx(remaining, anchor.get_recast_remaining()), "pause preserves recall window"
	)
	paused = false
	await _frames(285)
	var rim := player.find_child("RecallBorder", true, false).get_node("Rim") as Line2D
	_check(
		rim.is_visible_in_tree() and rim.get_point_count() == 2, "last fraction of the final edge"
	)
	await _frames(30)
	_check(
		anchor.get_recast_remaining() == 0.0 and registry.get_equipped(Q).cooldown_remaining > 0.0,
		"anchor expires into cooldown"
	)
	var q_slot := player.find_child("Q_socket", true, false)
	_check(
		(
			q_slot.get_node("Cooldown").visible
			and not player.find_child("RecallBorder", true, false).visible
		),
		"expiry replaces border with cooldown"
	)
	_equip(&"abyssal_whirlpool")
	_check(_cast(Q, RIGHT), "channel before death")
	player.take_damage(player.hp.get_max_hp())
	await _frames(2)
	_check(player.dead and not player.is_charm_casting(), "death clears active cast")


func _context(socket_id: int, target: Vector3) -> CharmActivationContext:
	var context := CharmActivationContext.new()
	context.actor = player
	context.socket_id = socket_id
	context.has_target = true
	context.target_position = target
	context.direction = player.global_position.direction_to(target)
	return context


func _cast(socket_id: int, target: Vector3) -> bool:
	return registry.input_pressed(socket_id, _context(socket_id, target))


func _equip(id: StringName, socket_id: int = Q) -> void:
	player.stamina.set_current_sp(player.stamina.get_max_sp())
	_check(manager.debug_equip_charm(id, socket_id), "equip %s" % id)


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _checkpoint(_label: String) -> void:
	pass


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("Charm arena: " + label)
