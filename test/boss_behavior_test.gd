extends SceneTree


class DifferentBehavior:
	extends BossBehavior
	var started := 0
	var ticks := 0
	var phases: Array[int] = []
	var ended := 0

	func fight_started() -> void:
		started += 1

	func fight_tick(_delta: float) -> void:
		ticks += 1
		boss.velocity = Vector3(0, 0, -3)

	func phase_entered(index: int) -> void:
		phases.append(index)

	func fight_ended() -> void:
		ended += 1


class DifferentSkill:
	extends BossSkillData
	var summon_count := 4


class GrappleSource:
	extends Node3D
	var stop_distance := 0.0

	func apply_charm_grapple_pull(_target: Vector3, distance: float, _speed: float) -> bool:
		stop_distance = distance
		return true


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena := Node3D.new()
	root.add_child(arena)
	current_scene = arena
	var target := Node3D.new()
	target.add_to_group("player")
	target.position = Vector3(100, 0, 0)
	arena.add_child(target)
	var boss := BossBase.new()
	var data := BossData.new()
	data.max_hp = 100.0
	var first := BossPhaseData.new()
	var second := BossPhaseData.new()
	second.hp_threshold = 0.5
	var summon := DifferentSkill.new()
	first.skills.append(summon)
	data.phases.assign([first, second])
	boss.boss_data = data
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	boss.add_child(health)
	var hurtbox := HurtBox.new()
	hurtbox.name = "HurtBox"
	boss.add_child(hurtbox)
	var behavior := DifferentBehavior.new()
	boss.add_child(behavior)
	boss.behavior = behavior
	arena.add_child(boss)
	boss.set_physics_process(false)
	var ranged_hit := DamageContext.new()
	ranged_hit.source = target
	ranged_hit.source_team = CombatTeams.PLAYER
	ranged_hit.amount_hp = 1.0
	boss.receive_damage(ranged_hit)
	var activated_by_damage := boss.fighting and boss.target == target
	boss._physics_process(0.1)
	boss._physics_process(0.1)
	var source := GrappleSource.new()
	arena.add_child(source)
	boss.grapple_stop_distance = 3.0
	var grapple_result := boss.apply_charm_grapple(source, 1.0, 10.0, 2.0)
	boss.take_damage(49.0)
	boss.take_damage(50.0)
	boss.take_damage(50.0)
	var ok := (
		behavior.boss == boss
		and activated_by_damage
		and behavior.started == 1
		and behavior.ticks == 2
		and behavior.phases == [1]
		and behavior.ended == 1
		and boss.is_defeated()
		and summon.summon_count == 4
		and grapple_result == &"actor_pulled_boss"
		and source.stop_distance == 3.0
		and bool(boss.collision_mask & CombatLayers.PLAYER_BOUNDARY)
	)
	arena.queue_free()
	await process_frame
	if ok:
		print("Boss behavior extension test passed")
		quit(0)
	else:
		push_error("Independent boss behavior or lifecycle failed")
		quit(1)
