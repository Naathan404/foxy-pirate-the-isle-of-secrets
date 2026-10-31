extends SceneTree

var _failures: int = 0
var _started: Array[int] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var actor := CombatDummy.new()
	world.add_child(actor)
	var controller := WeaponController.new()
	actor.add_child(controller)
	controller.default_weapon = load("res://data/weapon/weapon_dagger.tres").duplicate(true)
	_check(controller.setup(actor), "Dagger equips through the existing framework")
	var attack := controller.equipped.definition.normal_attack
	# Pin fixture damage so production balance changes do not alter this regression check.
	attack.combo_steps[2].damage_multiplier = 2.0
	for step in attack.combo_steps:
		step.hitstop_seconds = 0.0
	var targets: Array[CombatDummy] = []
	for index in 8:
		var target := CombatDummy.new()
		target.position = Vector3(sin(index * TAU / 8.0), 0.0, -cos(index * TAU / 8.0)) * 1.25
		world.add_child(target)
		var hurtbox := HurtBox.new()
		hurtbox.actor = target
		hurtbox.team = CombatTeams.ENEMY
		hurtbox.collision_layer = CombatLayers.ENEMY_HURTBOX
		var collider := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.12
		collider.shape = shape
		collider.position.y = 0.7
		hurtbox.add_child(collider)
		target.add_child(hurtbox)
		target.hurtbox = hurtbox
		targets.append(target)
	await _frames(2)
	controller.attack_started.connect(
		func(context: AttackContext): _started.append(context.combo_index)
	)
	for direction in 8:
		controller.cancel()
		for target in targets:
			target.hits = 0
		var request := _request(targets[direction].position.normalized())
		_check(controller.try_attack(request), "Swing starts in direction %d" % direction)
		var execution := controller._execution as DaggerAttack
		_check(not execution.hitbox.is_active(), "Windup cannot damage")
		execution.hitbox._on_area_entered(targets[direction].hurtbox)
		_check(targets[direction].hits == 0, "Overlap in anticipation causes no damage")
		controller._physics_process(attack.combo_steps[0].windup_seconds)
		for frame in 12:
			controller._physics_process(0.01)
		_check(targets[direction].hits == 1, "Forward target hit once in direction %d" % direction)
		_check(targets[(direction + 1) % 8].hits == 1, "Arc supports multiple targets per swing")
		_check(targets[(direction + 4) % 8].hits == 0, "Swing cannot hit behind actor")
		for target in targets:
			_check(target.hits <= 1, "Subsamples/overlaps deduplicate per target")
		_check(not execution.hitbox.is_active(), "Recovery closes damage window")
		var before := targets[direction].hits
		execution.hitbox._on_area_entered(targets[direction].hurtbox)
		_check(targets[direction].hits == before, "Recovery overlap causes no damage")
		_check(not controller.can_dash_cancel(), "Early recovery remains committed")
		controller._physics_process(0.04)
		_check(controller.can_dash_cancel(), "Late recovery allows dash")
	controller.cancel()
	_started.clear()
	_check(controller.try_attack(_request()), "Combo starts")
	for press in 10:
		controller.queue_attack(_request())
	controller._physics_process(controller.get_attack_duration())
	_check(_started == [0, 1], "Spam queues exactly one follow-up without skipping")
	_check(controller._context.combo_step.swing_start_degrees > 0.0, "Second swing reverses arc")
	controller.queue_attack(_request())
	controller._physics_process(controller.get_attack_duration())
	_check(_started == [0, 1, 2], "Second input chains to finisher")
	_check(controller._context.damage_hp == 2, "Finisher multiplies authored base damage once")
	controller._physics_process(controller.get_attack_duration())
	_check(not controller.busy, "Chain finishes without a permanent attack lock")
	_check(controller.try_attack(_request()), "Fresh attack after finisher")
	_check(controller._context.combo_index == 0, "Finisher loops back to first swing")
	controller.cancel()
	_check(controller.try_attack(_request()), "Reset fixture starts")
	controller._physics_process(controller.get_attack_duration())
	controller._physics_process(attack.combo_reset_seconds + 0.01)
	_check(controller.try_attack(_request()), "Attack after timeout starts")
	_check(controller._context.combo_index == 0, "Expired continuation window resets combo")
	controller.cancel()
	_check(controller.try_attack(_request()), "Buffer expiry fixture starts")
	controller.queue_attack(_request())
	controller._buffer_remaining = 0.001
	controller._physics_process(controller.get_attack_duration())
	_check(not controller.busy, "Expired input buffer does not trigger an unwanted attack")
	# Local hitstop must not change global timing, and cancel must restore animation speed.
	var player := load("res://gameplay/player/foxy.tscn").instantiate() as Player
	# Pin the fixture independently of the forge selected for manual testing.
	player.get_node("WeaponController").default_forge = null
	player.position = Vector3(10, 0.7, 0)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(40, 1, 40)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	world.add_child(player)
	await _frames(12)
	var hitstop := root.get_node("HitstopController")
	var speed := player.visual.animation_player.speed_scale
	hitstop.request_local(player, actor, 0.04)
	_check(Engine.time_scale == 1.0, "Melee hitstop leaves UI/global time untouched")
	_check(hitstop.is_frozen(player), "Melee hitstop freezes source")
	_check(player.visual.animation_player.speed_scale == 0.0, "Hitstop freezes animation")
	hitstop.cancel()
	_check(player.visual.animation_player.speed_scale == speed, "Cancel restores animation timing")
	hitstop.request_local(player, actor, 0.025)
	var restore_deadline := Time.get_ticks_msec() + 250
	while hitstop.is_frozen(player) and Time.get_ticks_msec() < restore_deadline:
		await process_frame
	_check(not hitstop.is_frozen(player), "Real-time deadline restores local hitstop automatically")
	_check(
		player.visual.animation_player.speed_scale == speed, "Timed restore returns animation speed"
	)
	var enemy := load("res://gameplay/enemies/starfish/starfish.tscn").instantiate() as EnemyBase
	enemy.data = enemy.data.duplicate()
	enemy.data.max_hp = 20
	enemy.position = player.position + Vector3.FORWARD * 1.25
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy._stop_contact_damage()
	await _frames(2)
	var chaos_before: float = player.chaos.current
	var hp_before := enemy.hp.current_hp
	player.last_facing_direction = Vector3.FORWARD
	player.request_attack()
	for frame in 25:
		await _frames(1)
		if enemy.hp.current_hp < hp_before:
			break
	_check(enemy.hp.current_hp == hp_before - 1, "Real enemy receives melee damage")
	_check(
		player.chaos.current == chaos_before + player.data.chaos_per_hit,
		"Confirmed melee keeps existing Chaos gain rule"
	)
	_check(Engine.time_scale == 1.0, "Real melee hit does not slow global/UI time")
	_check(hitstop.is_frozen(player), "Confirmed melee hit requests local player hitstop")
	var phase_remaining := player.weapon_controller._remaining
	player.weapon_controller._physics_process(0.01)
	_check(
		player.weapon_controller._remaining == phase_remaining,
		"Hitstop holds the actual attack phase clock"
	)
	var shake := root.get_node("ScreenShakeController")
	_check(shake._camera == player.camera, "Melee shake binds the gameplay camera")
	var world_offset: Vector2 = (
		Vector2(player.camera.h_offset, player.camera.v_offset) - shake._base_offset
	)
	var pixels: float = world_offset.length() / shake._world_units_per_pixel()
	_check(
		pixels > 1.0 and pixels <= shake.maximum_pixels + 0.01,
		"Confirmed hit immediately produces visible, bounded pixel displacement"
	)
	enemy.fsm._update(0.0)
	_check(enemy.velocity.z < 0.0, "Enemy recoil follows locked XZ swing direction")
	enemy.data.knockback_resistance = 1.0
	var resistant_hit := DamageContext.new()
	resistant_hit.source = player
	resistant_hit.source_team = CombatTeams.PLAYER
	resistant_hit.weapon_category = WeaponData.WeaponCategory.MELEE
	resistant_hit.direction = Vector3.FORWARD
	resistant_hit.knockback_multiplier = 1.1
	enemy.receive_damage(resistant_hit)
	_check(enemy.velocity.is_zero_approx(), "Knockback immunity is respected")
	await _frames(35)
	_check(not player.weapon_controller.busy, "Real hitstop leaves attack able to finish")
	enemy.free()
	_started.clear()
	player.weapon_controller.attack_started.connect(
		func(context: AttackContext): _started.append(context.combo_index)
	)
	player.request_attack()
	await _frames(3)
	_check(player.fsm.current_state.name == &"Attack", "Player enters actual Attack state")
	player.request_attack()
	await _frames(40)
	_check(_started == [0, 1], "Player input reaches one-slot combo buffer")
	await _frames(20)
	player.request_attack()
	await _frames(3)
	for frame in 30:
		if player.weapon_controller.can_dash_cancel():
			break
		await _frames(1)
	player.request_dash()
	await _frames(3)
	_check(player.fsm.current_state.name == &"Dash", "Dash cancels late recovery")
	_check(not player.weapon_controller.busy, "Dash closes current hitbox")
	player.request_attack()
	await _frames(2)
	_check(player.fsm.current_state.name == &"Dash", "Attack cannot interrupt dash")
	await _frames(16)
	_check(player.fsm.current_state.name == &"Attack", "Attack buffers until dash completes")
	player.take_damage(1)
	hitstop.cancel()
	await _frames(2)
	_check(not player.weapon_controller.busy, "Incoming hit cancels combo")
	_check(player.weapon_controller._combo_index == 0, "Interruption resets combo")
	hitstop.cancel()
	root.get_node("ScreenShakeController").cancel()
	root.get_node("AudioManager").stop_all_sfx()
	world.free()
	# Give the audio mixer a real-time cycle to release stopped one-shot playback.
	var audio_deadline := Time.get_ticks_msec() + 80
	while Time.get_ticks_msec() < audio_deadline:
		await process_frame
	if _failures == 0:
		print("Dagger combo, eight-direction sweep, deduplication, buffer, dash and hitstop passed")
	quit(0 if _failures == 0 else 1)


func _request(direction: Vector3 = Vector3.FORWARD) -> AttackContext:
	var request := AttackContext.new()
	request.direction = direction
	return request


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


class CombatDummy:
	extends Node3D
	var charm_socket_manager: CharmSocketManager
	var hurtbox: HurtBox
	var hits: int = 0

	func receive_damage(damage: DamageContext) -> float:
		hits += 1
		return damage.amount_hp
