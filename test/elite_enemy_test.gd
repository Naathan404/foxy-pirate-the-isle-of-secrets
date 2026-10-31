extends SceneTree

const ELITE_SCENES := {
	&"EliteCrab": preload("res://gameplay/enemies/crab/elite_crab.tscn"),
	&"EliteStarfish": preload("res://gameplay/enemies/starfish/elite_starfish.tscn"),
	&"EliteBarrel": preload("res://gameplay/enemies/barrel/elite_barrel.tscn"),
}
const ELITE_MOVE_SPEEDS := {
	&"EliteCrab": 1.8,
	&"EliteStarfish": 1.5,
	&"EliteBarrel": 0.0,
}
const NORMAL_ENEMY_DATA := {
	&"EliteCrab": preload("res://data/enemies/crab_data.tres"),
	&"EliteStarfish": preload("res://data/enemies/starfish_data.tres"),
	&"EliteBarrel": preload("res://data/enemies/barrel_data.tres"),
}
const ELITE_DROP_MULTIPLIER := 3
const STARFISH_ANIMATIONS: AnimationLibrary = preload(
	"res://gameplay/enemies/starfish/starfish_anims.tres"
)
const STARFISH_HORIZONTAL_FLIPS := {
	&"attack_left": true,
	&"attack_right": false,
	&"charge_left": true,
	&"charge_right": false,
	&"death_left": true,
	&"death_right": false,
	&"hit_left": true,
	&"hit_right": false,
	&"idle_left": true,
	&"idle_right": false,
	&"run_left": true,
	&"run_right": false,
}

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_elite_crab_uses_cardinal_charge()
	_check_starfish_animation_directions()
	for scene_name: StringName in ELITE_SCENES:
		await _check_elite(scene_name, ELITE_SCENES[scene_name])
	await _check_barrel_projectile_cleanup()
	if not _failures.is_empty():
		for failure: String in _failures:
			push_error(failure)
		quit(1)
		return
	print("Elite enemy scenarios passed")
	quit(0)


func _check_starfish_animation_directions() -> void:
	for animation_name: StringName in STARFISH_HORIZONTAL_FLIPS:
		var animation := STARFISH_ANIMATIONS.get_animation(animation_name)
		var track_index := animation.find_track(NodePath("Sprite3D:flip_h"), Animation.TYPE_VALUE)
		_check(track_index >= 0, "Starfish: %s is missing flip_h in the .tres" % animation_name)
		if track_index < 0:
			continue
		_check(
			(
				bool(animation.track_get_key_value(track_index, 0))
				== bool(STARFISH_HORIZONTAL_FLIPS[animation_name])
			),
			"Starfish: %s has an incorrect horizontal flip in the .tres" % animation_name
		)


func _check_elite_crab_uses_cardinal_charge() -> void:
	var southeast_route := EliteCrabCharge.get_cardinal_route(Vector3.ZERO, Vector3(4.0, 0.0, 1.0))
	_check(
		southeast_route == [Vector3.BACK, Vector3.RIGHT],
		"EliteCrab: diagonal target must charge vertically then turn right"
	)
	var northwest_route := EliteCrabCharge.get_cardinal_route(
		Vector3.ZERO, Vector3(-4.0, 0.0, -1.0)
	)
	_check(
		northwest_route == [Vector3.FORWARD, Vector3.LEFT],
		"EliteCrab: vertical leg and horizontal turn must preserve both signs"
	)
	var horizontal_route := EliteCrabCharge.get_cardinal_route(Vector3.ZERO, Vector3(4.0, 0.0, 0.0))
	_check(
		horizontal_route == [Vector3.RIGHT],
		"EliteCrab: an aligned target must still use one cardinal axis"
	)
	var vertical_route := EliteCrabCharge.get_cardinal_route(Vector3.ZERO, Vector3(0.0, 0.0, -4.0))
	_check(
		vertical_route == [Vector3.FORWARD], "EliteCrab: a vertical target must preserve its Z sign"
	)


func _check_elite(scene_name: StringName, scene: PackedScene) -> void:
	var enemy := scene.instantiate() as EnemyBase
	root.add_child(enemy)
	await process_frame
	var label := String(scene_name)
	_check(enemy.data.max_hp == 12, label + ": expected 12 max HP")
	_check(enemy.data.attack_damage == 2, label + ": expected 2 attack damage")
	_check(
		is_equal_approx(enemy.data.move_speed, ELITE_MOVE_SPEEDS[scene_name]),
		label + ": expected movement speed scaled for its larger body"
	)
	_check(
		is_equal_approx(enemy.data.knockback_resistance, 0.5), label + ": expected 50% resistance"
	)
	var normal_data := NORMAL_ENEMY_DATA[scene_name] as EnemyData
	_check(enemy.data.drop_item == normal_data.drop_item, label + ": expected its normal loot item")
	_check(
		enemy.data.drop_quantity == normal_data.drop_quantity * ELITE_DROP_MULTIPLIER,
		label + ": expected triple normal loot quantity"
	)
	_check(
		enemy.get_node_or_null("EliteFeedback") is EliteFeedback, label + ": missing elite feedback"
	)
	var feedback := enemy.get_node_or_null("EliteFeedback") as EliteFeedback
	var elite_glow_material := enemy.visual.sprite.material_overlay as ShaderMaterial
	_check(elite_glow_material != null, label + ": missing sprite-bound elite glow overlay")
	var expected_frame_uv_size := Vector2(
		1.0 / maxi(1, enemy.visual.sprite.hframes), 1.0 / maxi(1, enemy.visual.sprite.vframes)
	)
	_check(
		(
			elite_glow_material != null
			and (
				(elite_glow_material.get_shader_parameter("frame_uv_size") as Vector2)
				. is_equal_approx(expected_frame_uv_size)
			)
		),
		label + ": elite glow overlay must track the billboard's atlas frame size"
	)
	_check(
		(
			feedback.get_node_or_null("EliteStarGlow") == null
			and feedback.get_node_or_null("EliteMarker") == null
		),
		label + ": elite identity must not add a positioned marker node"
	)
	_check(
		feedback.get_node_or_null("EliteMovementSmoke") is GPUParticles3D,
		label + ": missing white movement smoke"
	)
	_check(
		feedback.get_node_or_null("EliteMovementPuff0") is GPUParticles3D,
		label + ": missing Foxy-style movement dust puffs"
	)
	_check(
		feedback.get_node_or_null("EliteAura") == null, label + ": ground aura ring must not exist"
	)
	var telegraph_ring := feedback.get_node_or_null("EliteAttackTelegraphRing") as MeshInstance3D
	_check(telegraph_ring != null, label + ": missing attack-only ground telegraph ring")
	_check(
		telegraph_ring != null and not telegraph_ring.visible,
		label + ": telegraph ring must be hidden outside an attack wind-up"
	)
	_check(
		feedback.get_node_or_null("EliteBurst") == null,
		label + ": charge, impact, and death burst particles must not exist"
	)
	_check(
		enemy.visual.get_node_or_null("EliteTelegraphSprite") == null,
		label + ": telegraph must not create a second billboard"
	)
	var base_modulate := enemy.visual.sprite.modulate
	var base_scale := enemy.visual.sprite.scale
	feedback.begin_telegraph()
	await process_frame
	_check(
		telegraph_ring != null and telegraph_ring.visible,
		label + ": telegraph ring must appear during the wind-up"
	)
	_check(
		not enemy.visual.sprite.modulate.is_equal_approx(base_modulate),
		label + ": telegraph must pulse the original sprite brightness"
	)
	feedback.end_telegraph()
	_check(
		telegraph_ring != null and not telegraph_ring.visible,
		label + ": telegraph ring must disappear before the attack starts"
	)
	_check(
		(
			enemy.visual.sprite.modulate.is_equal_approx(base_modulate)
			and enemy.visual.sprite.scale.is_equal_approx(base_scale)
		),
		label + ": telegraph must restore the original sprite presentation"
	)
	_check(
		enemy.visual.scale.is_equal_approx(Vector3.ONE * 1.5), label + ": expected 1.5 visual scale"
	)
	_check(enemy.show_debug_health, label + ": expected debug HP to be enabled")
	if scene_name == &"EliteStarfish":
		_check(
			enemy.visual.sprite.scale.x > 0.0,
			"EliteStarfish: sprite transform must not invert .tres directions"
		)
		_check_starfish_runtime_horizontal_flip(enemy)
		var patrol := enemy.get_node_or_null("States/Patrol") as EnemyPatrol
		_check(
			patrol != null and patrol.use_random_axis_changes,
			"EliteStarfish: expected random cardinal patrol axes"
		)
	_check(enemy.hp.current_hp == 12, label + ": HealthComponent did not use elite HP")
	var target := Node3D.new()
	target.position = Vector3(0.0, 0.0, 3.0)
	root.add_child(target)
	enemy.set_target(target)
	var special_state := _get_special_state_name(scene_name)
	_check(enemy.request_state(special_state), label + ": could not request special state")
	for _frame in 3:
		await physics_frame
	_check(
		enemy.fsm.current_state == enemy.fsm.states.get(String(special_state).to_lower()),
		label + ": did not enter special state"
	)
	if scene_name == &"EliteStarfish":
		_check_elite_starfish_attack_animation_stages(enemy)
	enemy.take_damage(enemy.hp.current_hp)
	for _frame in 3:
		await physics_frame
	_check(enemy.dead, label + ": lethal damage did not mark enemy dead")
	_check(
		(
			elite_glow_material != null
			and is_zero_approx(float(elite_glow_material.get_shader_parameter("glow_strength")))
		),
		label + ": sprite-bound elite glow must stop when the enemy dies"
	)
	if is_instance_valid(target):
		target.queue_free()
	if is_instance_valid(enemy):
		enemy.queue_free()
	await process_frame


func _check_starfish_runtime_horizontal_flip(enemy: EnemyBase) -> void:
	var sprite := enemy.visual.sprite
	var animation_player := enemy.visual.animation_player
	enemy.face_direction(Vector3.LEFT)
	enemy.play_directional_animation(&"idle", true)
	animation_player.advance(0.0)
	# EnemyVisual continually resolves directional clips, as it does in-game.
	enemy.visual._process(0.0)
	_check(sprite.flip_h, "EliteStarfish: left clip flip_h must survive directional refresh")
	enemy.face_direction(Vector3.RIGHT)
	enemy.play_directional_animation(&"idle", true)
	animation_player.advance(0.0)
	enemy.visual._process(0.0)
	_check(not sprite.flip_h, "EliteStarfish: right clip must reset flip_h")


func _check_elite_starfish_attack_animation_stages(enemy: EnemyBase) -> void:
	var attack := enemy.get_node_or_null("States/Attack") as EliteStarfishAttack
	var animation_player := enemy.visual.animation_player
	_check(
		String(animation_player.assigned_animation).begins_with("idle_"),
		"EliteStarfish: dash cycle must begin with the normal Starfish idle preparation"
	)
	attack._update(attack.preparation_duration)
	_check(
		String(animation_player.assigned_animation).begins_with("charge_"),
		"EliteStarfish: idle preparation must transition to Starfish charge"
	)
	attack._update(attack.telegraph_duration)
	_check(
		String(animation_player.assigned_animation).begins_with("attack_"),
		"EliteStarfish: charge must transition to Starfish attack dash"
	)
	_check(
		attack.timer > attack.dash_duration,
		"EliteStarfish: distant locked target must extend the fixed dash timeout"
	)


func _check_barrel_projectile_cleanup() -> void:
	var barrel_scene := ELITE_SCENES[&"EliteBarrel"] as PackedScene
	var barrel := barrel_scene.instantiate() as Barrel
	root.add_child(barrel)
	await process_frame
	barrel.fire_fan_volley(5, 50.0)
	await process_frame
	_check(barrel._projectiles.size() == 5, "EliteBarrel: fan volley did not create five bullets")
	barrel.take_damage(barrel.hp.current_hp)
	await process_frame
	_check(barrel._projectiles.is_empty(), "EliteBarrel: bullets survived barrel death")
	if is_instance_valid(barrel):
		barrel.queue_free()
	await process_frame


func _get_special_state_name(scene_name: StringName) -> StringName:
	match scene_name:
		&"EliteCrab":
			return &"charge"
		&"EliteStarfish":
			return &"attack"
		_:
			return &"scattershot"


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
