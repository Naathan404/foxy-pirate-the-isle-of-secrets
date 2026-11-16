extends SceneTree

const BOSS_SCENE := preload("res://gameplay/bosses/blubberbeard/blubberbeard.tscn")
const HAZARD_SCRIPT := preload("res://gameplay/bosses/blubberbeard/boss_hazard.gd")
var failures: Array[String] = []


class DummyTarget:
	extends Node3D
	var damage_received := 0.0

	func receive_damage(damage: DamageContext) -> float:
		damage_received += damage.amount_hp
		return damage.amount_hp


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena := Node3D.new()
	root.add_child(arena)
	current_scene = arena
	var target := DummyTarget.new()
	target.add_to_group("player")
	target.position = Vector3(5, 0, 0)
	arena.add_child(target)
	var hurtbox := HurtBox.new()
	hurtbox.actor = target
	hurtbox.team = CombatTeams.PLAYER
	hurtbox.collision_layer = CombatLayers.PLAYER_HURTBOX
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.5
	collider.shape = shape
	hurtbox.add_child(collider)
	target.add_child(hurtbox)
	var boss := BOSS_SCENE.instantiate() as BossBase
	arena.add_child(boss)
	var behavior := boss.behavior as BlubberbeardBehavior
	boss.set_physics_process(false)
	boss._physics_process(0.01)
	_check(
		boss.fighting and boss.get_node("BossHealthUI").visible,
		"Fight and health bar did not start"
	)
	var maximum_hp := boss.boss_data.max_hp
	_check(boss.hp.current_hp == maximum_hp, "Incorrect starting HP")
	var player_data := load("res://data/foxy/foxy_data.tres") as PlayerData
	for phase_data: BossPhaseData in boss.boss_data.phases:
		for move: BossSkillData in phase_data.skills:
			_check(move.damage < player_data.max_hp, "A boss attack would one-shot Foxy")
	behavior.next_skill = 1
	behavior._choose_skill()
	var direction := behavior.charge_direction
	target.position = Vector3(0, 0, 5)
	behavior._execute_skill()
	_check(
		(
			behavior.state == BlubberbeardBehavior.State.CHARGE
			and behavior.charge_direction == direction
		),
		"Charge did not lock its direction"
	)
	behavior.fight_tick(0.05)
	var initial_speed := behavior.charge_speed
	behavior.fight_tick(0.05)
	_check(
		(
			initial_speed > 0.0
			and initial_speed < behavior.skill.speed
			and behavior.charge_speed > initial_speed
		),
		"Charge should accelerate smoothly toward its configured speed"
	)
	behavior.timer = 0.0
	behavior.fight_tick(0.01)
	var speed_before_recovery := behavior.charge_speed
	behavior.fight_tick(0.05)
	_check(
		(
			behavior.state == BlubberbeardBehavior.State.RECOVERY
			and behavior.charge_speed < speed_before_recovery
		),
		"Charge should decelerate during recovery"
	)
	behavior.charge_hitbox.end_attack()
	var barrel := HAZARD_SCRIPT.new()
	barrel.source = boss
	barrel.damage = 12.0
	barrel.radius = 1.0
	barrel.remaining = 0.05
	arena.add_child(barrel)
	barrel.global_position = target.global_position
	await create_timer(0.3).timeout
	_check(
		target.damage_received == 12.0, "Barrel explosion did not damage the hurtbox exactly once"
	)
	boss.take_damage(maximum_hp * 0.5)
	_check(
		boss.phase_index == 1 and boss.hp.current_hp == maximum_hp * 0.5,
		"Phase 2 did not retain shared HP at 50%"
	)
	var phase := boss.boss_data.phases[1]
	_check(phase.skills.size() == 3, "Phase 2 should contain three skills")
	behavior.skill = phase.skills[2] as BlubberbeardSkillData
	behavior._execute_skill()
	var hazards: Array[Node] = []
	for child in arena.get_children():
		if child.get_script() == HAZARD_SCRIPT:
			hazards.append(child)
	_check(hazards.size() == 8, "Spiky Inflation did not spawn eight spikes")
	if hazards.size() == 8:
		_check(
			hazards[0].direction.dot(hazards[1].direction) < 0.8,
			"Spike directions are not separated"
		)
	behavior.next_skill = 1
	behavior._choose_skill()
	_check(is_instance_valid(behavior.charge_warning), "Charge warning did not appear")
	var death_position := boss.global_position
	boss.take_damage(maximum_hp * 0.5)
	boss.take_damage(10.0)
	_check(
		behavior.charge_warning == null and not behavior.charge_hitbox.is_active(),
		"Death did not cancel the charge warning and hitbox"
	)
	await physics_frame
	await process_frame
	var live_hazards := 0
	for child in arena.get_children():
		if child.get_script() == HAZARD_SCRIPT and not child.is_queued_for_deletion():
			live_hazards += 1
	_check(live_hazards == 0, "Boss hazards remained active after death")
	var chests := arena.find_children("BossRewardChest", "", false, false)
	_check(chests.size() == 1, "Death must spawn exactly one chest")
	if chests.size() == 1:
		var chest := chests[0] as BossRewardChest
		_check(
			chest.global_position == death_position and chest.rewards.size() == 3,
			"Chest position or rewards are incorrect"
		)
		var damage := DamageContext.new()
		damage.source_team = CombatTeams.PLAYER
		damage.amount_hp = 100.0
		chest.receive_damage(damage)
		var count := 0
		for child in arena.get_children():
			if child is ItemPickup:
				count += 1
		_check(count == 3, "Opening the chest did not spawn all three item pickups")
	behavior.sound.stop()
	root.get_node("AudioManager").stop_all_sfx()
	arena.queue_free()
	await process_frame
	if failures.is_empty():
		print("Blubberbeard boss integration test passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
