extends SceneTree

const ELITE_SKELETON := preload(
	"res://gameplay/enemies/coral_skeleton/elite_coral_skeleton.tscn"
)
const MORTAR_SCRIPT := preload(
	"res://gameplay/enemies/coral_skeleton/coral_poison_mortar.gd"
)
const POISON_CLOUD_SCRIPT := preload(
	"res://gameplay/enemies/coral_skeleton/coral_poison_cloud.gd"
)

class Target extends Node3D:
	var hits := 0
	var last_damage: DamageContext

	func receive_damage(damage: DamageContext) -> float:
		hits += 1
		last_damage = damage
		return damage.amount_hp

var arena: Node3D
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	arena = Node3D.new()
	root.add_child(arena)
	current_scene = arena

	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = CombatLayers.WORLD
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(40, 0.5, 40)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	floor_body.position = Vector3(0, -0.25, 0)
	arena.add_child(floor_body)

	var elite := ELITE_SKELETON.instantiate() as EliteCoralSkeleton
	elite.fire_delay = 0.05
	elite.burst_cooldown = 0.05
	elite.shoot_recovery_time = 0.05
	elite.normal_attacks_before_special = 2
	elite.mortar_flight_duration = 0.2
	elite.mortar_arc_height = 3.0
	elite.poison_cloud_duration = 1.5
	elite.poison_tick_interval = 0.25
	elite.poison_tick_damage = 0.5
	elite.guard_roam_pause_time = 0.05
	elite.guard_roam_segment_time = 0.3
	arena.add_child(elite)

	# 1. Does not sleep and roams freely around home when idle in Guard.
	await create_timer(0.45).timeout
	_check(elite.is_awake, "Elite Coral Skeleton should remain awake")
	_check(
		elite.fsm.current_state.name == &"Guard",
		"Elite did not remain in Guard without sleeping"
	)
	_check(
		elite.global_position.distance_to(elite.home_position) > 0.05,
		"Elite did not roam freely while guarding"
	)

	# 2. Target in range -> x normal bursts (pitched down to hit Foxy height) ->
	# turns angry red -> fires multi-directional high mortars -> poison clouds.
	var target := Target.new()
	target.position = Vector3(3.8, 0.0, 0.0)
	arena.add_child(target)
	var hurtbox := HurtBox.new()
	hurtbox.name = "HurtBox"
	hurtbox.actor = target
	hurtbox.team = CombatTeams.PLAYER
	hurtbox.collision_layer = CombatLayers.PLAYER_HURTBOX
	hurtbox.collision_mask = 0
	var hb_col := CollisionShape3D.new()
	hb_col.name = "CollisionShape3D"
	hb_col.position = Vector3(0.0, 1.25, 0.0)
	var hb_shape := BoxShape3D.new()
	hb_shape.size = Vector3(1.27, 1.97, 1.0)
	hb_col.shape = hb_shape
	hurtbox.add_child(hb_col)
	target.add_child(hurtbox)
	elite.set_target(target)
	elite.randomize_shot_mode = false
	elite.shot_mode = CoralSkeleton.ShotMode.FAN

	for _i in 16:
		await create_timer(0.05).timeout
		if elite.is_special_attack_ready():
			break
	_check(elite.is_special_attack_ready(), "Elite did not enter enraged special ready state")
	_check(
		elite._charged_feedback_active,
		"Elite did not activate red enraged feedback before special attack"
	)

	var mortars: Array[Node] = []
	for _i in 16:
		await create_timer(0.05).timeout
		mortars = _nodes_with_script(MORTAR_SCRIPT)
		if mortars.size() > 0:
			break
	_check(target.hits > 0, "Pitched normal shots from high Elite muzzle did not hit target HurtBox")
	_check(
		mortars.size() == elite.mortar_shot_count and mortars.size() > 1,
		"Elite did not launch multi-directional poison mortars"
	)
	var min_dot := 1.0
	if mortars.size() >= 2:
		var dir0: Vector3 = mortars[0].get("_target") - elite.global_position
		dir0.y = 0.0
		dir0 = dir0.normalized()
		for idx in range(1, mortars.size()):
			var dir_i: Vector3 = mortars[idx].get("_target") - elite.global_position
			dir_i.y = 0.0
			if not dir_i.is_zero_approx():
				min_dot = minf(min_dot, dir0.dot(dir_i.normalized()))
	_check(min_dot < 0.0, "Charged poison mortars did not spread across multiple directions")
	_check(
		not elite._charged_feedback_active,
		"Elite did not clear red enraged feedback after special attack"
	)

	elite.set_target(null)
	await create_timer(0.4).timeout
	_check(
		_count_nodes_with_script(POISON_CLOUD_SCRIPT) == elite.mortar_shot_count,
		"Multi-directional mortars did not spawn poison clouds upon landing"
	)

	var hits_before := target.hits
	await create_timer(0.35).timeout
	_check(target.hits > hits_before, "Poison cloud did not damage player inside hazard")

	# 3. 3 lives with decreasing max HP: revives twice into skull/bones, dies on 3rd life.
	var revive_state := elite.get_node_or_null(^"States/Revive") as EliteCoralRevive
	if revive_state != null:
		revive_state.curl_duration = 0.08
		revive_state.dormant_duration = 0.30
		revive_state.reassemble_duration = 0.08
	var life1_max := elite.hp.get_max_hp()
	_check(elite.current_life == 1, "Elite should start on life 1")

	var lethal_hit := DamageContext.new()
	lethal_hit.amount_hp = life1_max
	lethal_hit.source_team = CombatTeams.PLAYER
	elite.receive_damage(lethal_hit)
	await create_timer(0.15).timeout
	_check(
		elite.fsm.current_state.name == &"Revive",
		"Elite did not enter Revive bone-curl state at end of life 1"
	)
	_check(elite.reviving, "Elite did not mark reviving active on life 1")
	var hp_while_curled := elite.hp.current_hp
	var ignored := DamageContext.new()
	ignored.amount_hp = 5.0
	ignored.source_team = CombatTeams.PLAYER
	var applied_while_curled := elite.receive_damage(ignored)
	_check(applied_while_curled == 0.0, "Elite took damage while curled into skull and bones")
	_check(
		is_equal_approx(elite.hp.current_hp, hp_while_curled),
		"Elite HP changed while invulnerable in Revive"
	)

	await create_timer(0.4).timeout
	_check(not elite.reviving, "Elite stayed stuck in reviving state after life 1")
	var life2_max := elite.hp.get_max_hp()
	_check(elite.current_life == 2, "Elite did not advance to life 2")
	_check(
		life2_max < life1_max and is_equal_approx(elite.hp.current_hp, life2_max),
		"Elite life 2 max HP did not decrease or restore cleanly"
	)
	_check(
		elite.fsm.current_state.name == &"Guard",
		"Elite did not return to normal behavior after revive 1"
	)

	# Life 2 -> Revive 2 -> Life 3
	var lethal_hit_2 := DamageContext.new()
	lethal_hit_2.amount_hp = life2_max
	lethal_hit_2.source_team = CombatTeams.PLAYER
	elite.receive_damage(lethal_hit_2)
	await create_timer(0.15).timeout
	_check(
		elite.fsm.current_state.name == &"Revive",
		"Elite did not enter Revive bone-curl state at end of life 2"
	)
	await create_timer(0.4).timeout
	var life3_max := elite.hp.get_max_hp()
	_check(elite.current_life == 3, "Elite did not advance to life 3")
	_check(
		life3_max < life2_max and is_equal_approx(elite.hp.current_hp, life3_max),
		"Elite life 3 max HP did not decrease further or restore cleanly"
	)

	# Life 3 lethal drop must kill normally without reviving again.
	var lethal_hit_3 := DamageContext.new()
	lethal_hit_3.amount_hp = 100.0
	lethal_hit_3.source_team = CombatTeams.PLAYER
	elite.receive_damage(lethal_hit_3)
	_check(elite.dead, "Elite did not die normally on final 3rd life")

	arena.queue_free()
	await process_frame
	if failures.is_empty():
		print("Elite Coral Skeleton tests passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _nodes_with_script(target_script: Script) -> Array[Node]:
	var found: Array[Node] = []
	for child in arena.get_children():
		if child.get_script() == target_script:
			found.append(child)
	return found


func _count_nodes_with_script(target_script: Script) -> int:
	return _nodes_with_script(target_script).size()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
