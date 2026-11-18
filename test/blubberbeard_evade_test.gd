extends SceneTree

const BOSS_SCENE := preload("res://gameplay/bosses/blubberbeard/blubberbeard.tscn")
const HAZARD_SCRIPT := preload("res://gameplay/bosses/blubberbeard/boss_hazard.gd")

var failures: Array[String] = []


class MockPlayerTarget:
	extends Node3D
	var total_damage: float = 0.0

	func receive_damage(damage: DamageContext) -> float:
		total_damage += damage.amount_hp
		return damage.amount_hp


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena := Node3D.new()
	root.add_child(arena)
	current_scene = arena

	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = CombatLayers.WORLD
	var floor_collider := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(100.0, 1.0, 100.0)
	floor_collider.shape = floor_shape
	floor_body.add_child(floor_collider)
	floor_body.position.y = -0.5
	arena.add_child(floor_body)

	var player := MockPlayerTarget.new()
	player.position = Vector3(2.8, 0.0, 0.0)
	player.add_to_group("player")
	arena.add_child(player)
	var hurtbox := HurtBox.new()
	hurtbox.actor = player
	hurtbox.team = CombatTeams.PLAYER
	hurtbox.collision_layer = CombatLayers.PLAYER_HURTBOX
	var h_col := CollisionShape3D.new()
	var h_shape := SphereShape3D.new()
	h_shape.radius = 0.6
	h_col.shape = h_shape
	hurtbox.add_child(h_col)
	player.add_child(hurtbox)

	var boss := BOSS_SCENE.instantiate() as BlubberbeardBoss
	arena.add_child(boss)
	boss.hits_before_counter = 2
	boss.counter_cooldown = 4.0
	boss.super_armor_during_attacks = true
	boss.start_fight(player)
	boss.timer = 10.0
	for _i in 5:
		await physics_frame

	var damage := DamageContext.new()
	damage.source = player
	damage.source_team = CombatTeams.PLAYER
	damage.amount_hp = 0.2

	# 1. First two hits trigger normal hurt animation without starting Spiky Counter.
	for _hit in 2:
		_check(
			is_equal_approx(boss.receive_damage(damage), 0.2),
			"Vulnerable hit did not deal expected damage"
		)
		_check(
			boss.state != BlubberbeardBoss.State.COUNTER_SHOCK,
			"Spiky Counter triggered before configured hit count"
		)
		_check(boss.visual.texture == boss.visual.HIT_DEATH_SHEET, "Hurt recoil sprite not active")
	_check(boss._hits_since_counter == 2, "Counter hit count was not tracked")

	# 2. Threshold hit triggers shock recoil followed by Spiky Burst counter AoE & spikes.
	_check(
		is_equal_approx(boss.receive_damage(damage), 0.2), "Counter threshold hit must deal damage"
	)
	_check(
		boss.state == BlubberbeardBoss.State.COUNTER_SHOCK,
		"Threshold hit did not trigger COUNTER_SHOCK state"
	)
	_check(boss._hits_since_counter == 0, "Counter did not reset hit count")

	var entered_spiky_hold := false
	for _tick in 140:
		await physics_frame
		if boss.state == BlubberbeardBoss.State.SPIKY_HOLD:
			entered_spiky_hold = true
		if boss.state == BlubberbeardBoss.State.RECOVERY and entered_spiky_hold:
			break
	var spike_count := 0
	for child in arena.get_children():
		if child.get_script() == HAZARD_SCRIPT and bool(child.get("spike")):
			spike_count += 1
	_check(player.total_damage >= 2.0, "Spiky Counter burst did not punish nearby player")
	_check(entered_spiky_hold, "Spiky Counter did not enter prolonged SPIKY_HOLD state")
	_check(spike_count == 0, "Spiky Counter should not spawn flying projectile spikes")

	# 3. Cooldown prevents consecutive instant counters; counts hits safely until cooldown expires.
	boss.timer = 10.0
	boss.state = BlubberbeardBoss.State.WAIT
	for _hit in 3:
		boss.receive_damage(damage)
	_check(
		boss.state != BlubberbeardBoss.State.COUNTER_SHOCK,
		"Counter cooldown allowed immediate second Spiky Counter"
	)

	# 4. Super Armor blocks counter/interruption during active WINDUP & WHIRLWIND states.
	boss._counter_cooldown_left = 0.0
	boss._hits_since_counter = boss.hits_before_counter
	boss.forced_skill_index = 1
	boss._choose_skill()
	var windup_skill := boss.skill
	_check(
		boss.state == BlubberbeardBoss.State.WINDUP,
		"Boss did not enter WINDUP before super armor test"
	)
	_check(
		is_equal_approx(boss.receive_damage(damage), 0.2),
		"Super armor blocked damage instead of taking HP cleanly"
	)
	_check(
		boss.state == BlubberbeardBoss.State.WINDUP and boss.skill == windup_skill,
		"Super armor failed: hit during WINDUP interrupted boss attack"
	)

	# Entering RECOVERY exposes vulnerable window again: next hit fires counter!
	boss._enter_recovery()
	boss.receive_damage(damage)
	_check(
		boss.state == BlubberbeardBoss.State.COUNTER_SHOCK,
		"Spiky Counter did not fire when hit in vulnerable RECOVERY after super armor"
	)

	boss.sound.stop()
	root.get_node("AudioManager").stop_all_sfx()
	arena.queue_free()
	await process_frame
	if failures.is_empty():
		print("Blubberbeard counter & super-armor test passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
