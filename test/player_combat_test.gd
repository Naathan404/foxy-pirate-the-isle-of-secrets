extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var player := _create_player()
	_expect(player.hp.current_hp == player.data.max_hp, "Player initializes health")
	_expect(player.hurtbox.actor == player, "HurtBox targets its player")
	_expect(player.hurtbox.team == player.team, "HurtBox inherits the player's team")
	_expect(player.hurtbox.take_damage(null) == 0, "Null damage is ignored")
	_expect(player.take_damage(0) == 0, "Zero damage is ignored")
	_expect(player.take_damage(-1) == 0, "Negative damage is ignored")

	var damage := DamageContext.new()
	damage.source = player
	damage.source_team = player.team + 1
	_expect(player.hurtbox.take_damage(damage) == 0, "Self damage is ignored")
	var enemy := Node3D.new()
	root.add_child(enemy)
	damage.source = enemy
	damage.source_team = player.team
	_expect(player.hurtbox.take_damage(damage) == 0, "Friendly damage is ignored")
	_expect(player.receive_damage(damage) == 0, "Direct context also rejects friendly damage")
	var defense := player.weapon_controller as DamageModifier
	defense.block_damage = true
	damage.source_team = player.team + 1
	damage.attack_id = 7
	damage.tag = &"heavy"
	_expect(player.hurtbox.take_damage(damage) == 0, "Defense can block incoming damage")
	_expect(defense.received_damage == damage, "HurtBox preserves the full damage context")
	_expect(player.hp.current_hp == 8, "Blocked damage does not reduce health")
	defense.block_damage = false

	var enemy_hitbox := HitBox.new()
	enemy_hitbox.actor = enemy
	enemy_hitbox.team = player.team + 1
	_add_shape(enemy_hitbox)
	enemy.add_child(enemy_hitbox)
	var second_hurtbox := HurtBox.new()
	second_hurtbox.actor = player
	second_hurtbox.team = player.team
	_add_shape(second_hurtbox)
	player.add_child(second_hurtbox)
	_expect(enemy_hitbox.begin_attack(2), "Enemy attack starts")
	await _physics_steps()
	_expect(player.hp.current_hp == 6, "Multiple hurtboxes apply one hit per attack")
	_expect(player.fsm.next_state.name == &"Hit", "Damage requests the Hit state")
	await _physics_steps()
	_expect(player.hp.current_hp == 6, "Sustained overlap does not repeat damage")
	enemy_hitbox.end_attack()
	await _physics_steps()
	_expect(player.hp.current_hp == 6, "Inactive hitbox causes no damage")
	_expect(enemy_hitbox.begin_attack(2), "Next attack starts during existing overlap")
	await _physics_steps()
	_expect(player.hp.current_hp == 4, "New attack can hit the same target again")
	enemy_hitbox.end_attack()

	defense.cancelled = false
	player.cancel_attack()
	_expect(defense.cancelled, "Cancel delegates to weapon controller")
	defense.cancelled = false
	damage.source_team = player.team + 1
	damage.amount_hp = 100
	_expect(player.hurtbox.take_damage(damage) == 4, "Lethal damage returns remaining health")
	_expect(player.dead, "Lethal hit kills player")
	_expect(player.fsm.next_state.name == &"Death", "Lethal hit requests Death")
	_expect(not player.hurtbox.enabled, "Death disables HurtBox")
	_expect(defense.cancelled, "Death cancels weapon controller")
	_expect(player.hurtbox.take_damage(damage) == 0, "Dead player receives no further damage")

	player.free()
	enemy.free()
	print("Player combat tests: ", _failures, " failures")
	quit(0 if _failures == 0 else 1)


func _create_player() -> Player:
	var player := Player.new()
	player.data = PlayerData.new()
	player.hp = HealthComponent.new()
	player.add_child(player.hp)
	player.stamina = StaminaComponent.new()
	player.add_child(player.stamina)
	player.weapon_controller = DamageModifier.new()
	player.add_child(player.weapon_controller)
	player.hurtbox = HurtBox.new()
	_add_shape(player.hurtbox)
	player.add_child(player.hurtbox)
	var visual := PlayerVisual.new()
	visual.name = &"Visual"
	player.add_child(visual)
	var fsm := Fsm.new()
	fsm.name = &"FSM"
	player.add_child(fsm)
	var states := Node.new()
	states.name = &"States"
	for state_name in [&"Idle", &"Hit", &"Death"]:
		var state := FsmState.new()
		state.name = state_name
		state.is_terminal = state_name == &"Death"
		states.add_child(state)
	player.add_child(states)
	root.add_child(player)
	player.set_physics_process(false)
	return player


func _add_shape(area: Area3D) -> void:
	var collision := CollisionShape3D.new()
	collision.shape = SphereShape3D.new()
	area.add_child(collision)


func _physics_steps() -> void:
	for _step in range(4):
		await physics_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


class DamageModifier:
	extends WeaponController

	var received_damage: DamageContext
	var block_damage: bool = false
	var cancelled: bool = false

	func modify_incoming_damage(amount: int, damage: DamageContext) -> int:
		received_damage = damage
		if block_damage:
			return maxi(0, amount - 1)
		return amount

	func cancel() -> void:
		cancelled = true
		super.cancel()
