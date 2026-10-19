extends SceneTree

const ATTACK_STATE = preload("res://gameplay/player/states/player_attack.gd")

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(20.0, 1.0, 20.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	var player := _create_player()
	var controller := player.attack_controller as WeaponController
	_expect(controller.equipped != null, "Setup equips default weapon")
	_expect(controller.team == player.team, "Controller inherits player team")
	_expect(player.can_equip_weapon(), "Idle permits equip")
	_expect(not player.can_start_weapon_attack(), "Airborne player cannot attack")
	for _step in range(12):
		await physics_frame
		player.velocity = Vector3.DOWN
		player.move_and_slide()
	_expect(player.is_on_floor(), "Fixture reaches the floor")
	_expect(player.can_start_weapon_attack(), "Grounded idle permits attack")
	var context := player.build_attack_context()
	_expect(context.actor == player and context.team == player.team, "Context has actor and team")
	_expect(context.origin.is_equal_approx(player.global_position), "Context has world origin")
	_expect(context.direction.is_equal_approx(Vector3.BACK), "Context preserves facing")
	_expect(not context.has_target, "No camera leaves target unset")
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0.0, 10.0, 10.0)
	camera.look_at(player.global_position)
	player.camera = camera
	player.pending_attack_action = &"secondary"
	context = player.build_attack_context()
	_expect(context.action == &"secondary", "Context preserves requested action")
	_expect(context.has_target, "Camera provides cursor target")
	_expect(
		is_equal_approx(context.target_position.y, player.global_position.y),
		"Cursor target lies on the player's XZ plane"
	)
	player.pending_attack_action = &"normal"
	var idle := player.fsm.next_state
	for state_name in ["dash", "hit", "fall", "death"]:
		player.fsm.next_state = player.fsm.states[state_name]
		_expect(not player.can_start_weapon_attack(), "Pending " + state_name + " blocks attack")
		_expect(
			player.can_equip_weapon() == (state_name == "fall"),
			"Equip gate respects pending " + state_name
		)
		_expect(
			not controller.try_attack(player.build_attack_context()),
			"Controller respects player's " + state_name + " gate"
		)
	player.fsm.next_state = idle
	var attack := player.fsm.states["attack"] as FsmState
	player.fsm._update(0.0)
	player.fsm.change_state(attack)
	player.fsm._update(0.0)
	_expect(controller.busy, "Attack state accepts controller with attack_finished signal")
	_expect(
		not controller.try_attack(player.build_attack_context()), "Busy rejects overlapping attack"
	)
	_expect(not player.can_equip_weapon(), "Cannot equip during attack")
	_expect(player.can_start_weapon_attack(), "Attack state can call controller")
	_expect(
		is_equal_approx(player.visual.animation_player.speed_scale, 2.5),
		"Attack state fits animation to controller duration"
	)
	controller._physics_process(0.4)
	_expect(not controller.busy, "Controller finishes attack")
	player.fsm._update(0.0)
	player.fsm._update(0.0)
	_expect(player.fsm.current_state.name == &"Idle", "Finished attack returns to locomotion")
	_expect(
		is_equal_approx(player.visual.animation_player.speed_scale, 1.0),
		"Leaving attack restores animation speed"
	)
	player.fsm.change_state(attack)
	player.fsm._update(0.0)
	_expect(controller.busy, "Next attack starts")
	player.notify_hit()
	_expect(not controller.busy, "Hit reaction cancels controller")
	_expect(not player.can_start_weapon_attack(), "Pending Hit blocks attack")
	_expect(not player.can_equip_weapon(), "Pending Hit blocks equip")
	player.fsm._update(0.0)
	_expect(player.fsm.current_state.name == &"Hit", "Interruption enters Hit")
	_expect(
		is_equal_approx(player.visual.animation_player.speed_scale, 1.0),
		"Interruption restores animation speed"
	)
	player.die()
	_expect(not player.can_start_weapon_attack(), "Death blocks attack")
	_expect(not player.can_equip_weapon(), "Death blocks equip")
	player.free()
	camera.free()
	floor_body.free()
	await process_frame
	print("Player weapon integration tests: ", _failures, " failures")
	quit(0 if _failures == 0 else 1)


func _create_player() -> Player:
	var player := Player.new()
	player.data = PlayerData.new()
	player.team = 9
	player.position.y = 0.55
	player.hp = HealthComponent.new()
	player.add_child(player.hp)
	player.stamina = StaminaComponent.new()
	player.add_child(player.stamina)
	var body_shape := CollisionShape3D.new()
	body_shape.shape = BoxShape3D.new()
	player.add_child(body_shape)
	var fsm := Fsm.new()
	fsm.name = &"FSM"
	player.add_child(fsm)
	var states := Node.new()
	states.name = &"States"
	for state_name in [&"Idle", &"Hit", &"Fall", &"Dash", &"Death"]:
		var state := FsmState.new()
		state.name = state_name
		state.is_terminal = state_name == &"Death"
		states.add_child(state)
	var attack_state := ATTACK_STATE.new()
	attack_state.name = &"Attack"
	states.add_child(attack_state)
	player.add_child(states)
	player.add_child(_create_visual())
	var controller := WeaponController.new()
	controller.default_weapon = _create_weapon()
	player.attack_controller = controller
	player.add_child(controller)
	root.add_child(player)
	player.set_physics_process(false)
	controller.set_physics_process(false)
	return player


func _create_visual() -> PlayerVisual:
	var visual := PlayerVisual.new()
	visual.name = &"Visual"
	visual.sprite = Sprite3D.new()
	visual.sprite.name = &"Sprite3D"
	visual.add_child(visual.sprite)
	visual.animation_player = AnimationPlayer.new()
	visual.add_child(visual.animation_player)
	var library := AnimationLibrary.new()
	for suffix in ["down", "up", "side"]:
		var animation := Animation.new()
		animation.length = 1.0
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath("Sprite3D:modulate"))
		animation.track_insert_key(track, 0.0, Color.WHITE)
		library.add_animation("attack_dagger_" + suffix, animation)
	visual.animation_player.add_animation_library(&"", library)
	return visual


func _create_weapon() -> WeaponData:
	var execution := WeaponAttack.new()
	var scene := PackedScene.new()
	scene.pack(execution)
	execution.free()
	var weapon := WeaponData.new()
	weapon.normal_attack = AttackData.new()
	weapon.normal_attack.attack_scene = scene
	weapon.normal_attack.windup_seconds = 0.1
	weapon.normal_attack.active_seconds = 0.2
	weapon.normal_attack.recovery_seconds = 0.1
	return weapon


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
