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
	var boss := BOSS_SCENE.instantiate() as BlubberbeardBoss
	arena.add_child(boss)
	var behavior := boss
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
	behavior.forced_skill_index = 1
	behavior._choose_skill()
	_check(
		(
			behavior.skill.kind == BlubberbeardSkillData.Kind.SKY_DIVE
			and behavior.state == BlubberbeardBoss.State.WINDUP
		),
		"Parabolic leap windup did not start"
	)
	behavior.fight_tick(behavior.skill.windup + 0.05)
	_check(
		behavior.state == BlubberbeardBoss.State.SKYDIVE_LEAP,
		"Parabolic leap did not launch boss into SKYDIVE_LEAP"
	)
	var locked_pos := behavior._skydive.target_position
	behavior.fight_tick(behavior.skill.skydive_leap_duration * 0.45)
	_check(
		behavior.visual.airborne_height > 2.5 and behavior._skydive.target_position == locked_pos,
		"Parabolic leap did not arc high toward locked target destination"
	)
	target.position = Vector3(20, 0, 20)
	await physics_frame
	for _tick in 25:
		if behavior.state == BlubberbeardBoss.State.RECOVERY:
			break
		behavior.fight_tick(0.05)
	_check(
		(
			behavior.state == BlubberbeardBoss.State.RECOVERY
			and is_zero_approx(behavior.visual.airborne_height)
			and (
				(
					Vector2(
						boss.global_position.x - locked_pos.x, boss.global_position.z - locked_pos.z
					)
					. length()
				)
				< 0.8
			)
		),
		"Parabolic leap did not land straight onto locked target coordinates"
	)
	behavior.visual.begin_recovery(BlubberbeardSkillData.Kind.SKY_DIVE)
	behavior.visual._process(0.5)
	_check(
		behavior.visual.pose == BlubberbeardVisual.Pose.IDLE,
		"Sky Dive recovery animation should return to idle or movement"
	)
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
	_check(phase.skills.size() == 5, "Phase 2 should contain five skills")
	target.damage_received = 0.0
	target.position = boss.global_position + Vector3(2.2, 0.0, 0.0)
	await physics_frame
	behavior.skill = phase.skills[2] as BlubberbeardSkillData
	behavior._execute_skill()
	var projectile_spikes := 0
	for child in arena.get_children():
		if child.get_script() == HAZARD_SCRIPT and bool(child.get("spike")):
			projectile_spikes += 1
	_check(
		projectile_spikes == 0, "Spiky Inflation should no longer shoot flying spike projectiles"
	)
	_check(
		behavior.state == BlubberbeardBoss.State.SPIKY_HOLD and behavior.timer >= 1.0,
		"Spiky Inflation did not hold enlarged spiked puffer state cleanly"
	)
	_check(
		(
			behavior.visual.clip == BlubberbeardVisual.Clip.INFLATE_BURST
			and behavior.visual.pose == BlubberbeardVisual.Pose.ACTIVE
		),
		"Spiky Inflation hold did not activate enlarged spiky visual"
	)
	_check(
		target.damage_received >= behavior.skill.damage,
		"Spiky Inflation close burst did not hit nearby target"
	)
	behavior.fight_tick(0.6)
	_check(
		behavior.state == BlubberbeardBoss.State.SPIKY_HOLD,
		"Spiky Inflation exited hold state too quickly"
	)
	behavior.fight_tick(behavior.skill.spiky_hold_duration)
	_check(
		behavior.state == BlubberbeardBoss.State.RECOVERY,
		"Spiky Inflation did not transition cleanly into recovery after holding"
	)
	behavior.forced_skill_index = 3
	behavior._choose_skill()
	behavior._execute_skill()
	var death_position := boss.global_position
	boss.take_damage(maximum_hp * 0.5)
	boss.take_damage(10.0)
	_check(
		not behavior._whirlwind_rig.hitbox.is_active(), "Death did not cancel the whirlwind hitbox"
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
