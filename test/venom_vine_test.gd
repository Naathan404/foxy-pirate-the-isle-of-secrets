extends SceneTree
## Kiểm thử toàn diện cho VenomVine, VenomVineAI, VenomPoolProjectile, VenomAcidPool và ForestTest.

const VINE_SCENE := preload("res://gameplay/enemies/venom_vine/venom_vine.tscn")
const FOREST_TEST_SCENE := preload("res://world/tests/forest_test.tscn")
const AI_CLASS := preload("res://gameplay/enemies/venom_vine/venom_vine_ai.gd")
const POOL_SCRIPT := preload("res://gameplay/enemies/venom_vine/venom_acid_pool.gd")
const PROJECTILE_SCRIPT := preload("res://gameplay/enemies/venom_vine/venom_pool_projectile.gd")


class DummyPlayer:
	extends CharacterBody3D
	var poison_ticks: int = 0
	var direct_hits: int = 0
	var total_damage_hp: float = 0.0

	func _init() -> void:
		add_to_group("player")
		collision_layer = CombatLayers.PLAYER_BODY
		collision_mask = CombatLayers.WORLD

	func receive_damage(damage: DamageContext) -> float:
		total_damage_hp += damage.amount_hp
		if damage.tag == &"poison":
			poison_ticks += 1
		else:
			direct_hits += 1
		return damage.amount_hp


var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_ai_intelligence()
	await _test_state_machine_and_zones()
	await _test_sniper_anger_stagger_and_death_pools()
	await _test_forest_test_real_foxy_integration()

	if _failures.is_empty():
		print("VenomVine full suite passed (AI, FSM, Hazard, ForestTest + Real Foxy)")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_ai_intelligence() -> void:
	var ai := AI_CLASS.new() as VenomVineAI
	_check(
		ai.classify_zone(10.0, 8.5, 4.5, 1.5, false) == VenomVineAI.Zone.OUT_OF_RANGE,
		"Outside outer radius must be OUT_OF_RANGE when dormant"
	)
	_check(
		ai.classify_zone(9.2, 8.5, 4.5, 1.5, true) == VenomVineAI.Zone.OUTER_RING,
		"Hysteresis must keep target in OUTER_RING when already engaged"
	)
	_check(
		ai.classify_zone(4.2, 8.5, 4.5, 1.5, true) == VenomVineAI.Zone.INNER_RING,
		"Close range must classify as INNER_RING"
	)

	var lead := ai.compute_lead_position(
		Vector3.ZERO, Vector3(6.0, 0.0, 0.0), Vector3(0.0, 0.0, 4.0), 0.5, 3.0, 1.0
	)
	_check(lead.z > 1.5, "Lead prediction must aim ahead of target velocity, got %s" % lead)

	# Nếu Player đang đứng trong vũng axit sẵn có, AI phải dịch góc bắn sang đường thoát.
	var occupied: Array[Dictionary] = [{"pos": Vector3(6.0, 0.0, 0.0), "radius": 1.6}]
	var outer_plan := (
		ai
		. select_attack_plan(
			{
				"zone": VenomVineAI.Zone.OUTER_RING,
				"agitation": 0.0,
				"origin_pos": Vector3.ZERO,
				"target_pos": Vector3(6.0, 0.0, 0.0),
				"target_velocity": Vector3.ZERO,
				"occupied_spots": occupied,
				"ground_y": 0.0,
				"pool_radius": 1.6,
				"outer_shots": 1,
			}
		)
	)
	var outer_aims: Array = outer_plan.get("aim_positions", [])
	_check(outer_aims.size() == 1, "Outer ring plan must produce 1 shot")
	if not outer_aims.is_empty():
		var spot := outer_aims[0] as Vector3
		var dist_from_old := Vector2(spot.x - 6.0, spot.z).length()
		_check(
			dist_from_old >= 2.0,
			"Outer plan must avoid stacking on existing pool, got dist=%s" % dist_from_old
		)

	# Trong vùng cận, 3 phát quạt phải tách nhau ra chứ không dồn vào một chỗ.
	var inner_plan := (
		ai
		. select_attack_plan(
			{
				"zone": VenomVineAI.Zone.INNER_RING,
				"agitation": 0.5,
				"origin_pos": Vector3.ZERO,
				"target_pos": Vector3(3.2, 0.0, 0.0),
				"target_velocity": Vector3.ZERO,
				"occupied_spots": [],
				"ground_y": 0.0,
				"pool_radius": 1.4,
				"inner_shots": 3,
				"inner_fan_degrees": 72.0,
			}
		)
	)
	var inner_aims: Array = inner_plan.get("aim_positions", [])
	_check(inner_aims.size() == 3, "Inner ring plan must produce 3 fan shots")
	if inner_aims.size() == 3:
		var sep01 := (inner_aims[0] as Vector3).distance_to(inner_aims[1] as Vector3)
		var sep02 := (inner_aims[0] as Vector3).distance_to(inner_aims[2] as Vector3)
		_check(
			sep01 >= 2.0 and sep02 >= 2.0,
			"Inner fan shots must stay separated (sep01=%.2f, sep02=%.2f)" % [sep01, sep02]
		)


func _test_state_machine_and_zones() -> void:
	var arena := _create_arena()
	var vine := _spawn_fast_vine(arena)
	var player := _spawn_dummy_player(arena, Vector3(14.0, 0.0, 0.0))
	await _step_frames(10)
	_check(vine.fsm.current_state.name == &"Dormant", "Vine must start Dormant outside range")
	_check(not vine.is_awake, "Dormant vine must have is_awake == false")

	# Bước vào rìa vùng ngoài -> tỉnh dậy, bắn 1 phát.
	player.position = Vector3(7.0, 0.0, 0.0)
	player.velocity = Vector3(0.0, 0.0, 2.5)
	await _step_frames(85)
	_check(vine.is_awake, "Vine must wake in outer ring")
	var outer_count := _active_pools_in_tree().size()
	_check(outer_count == 1, "Outer ring must fire 1 shot initially, got %d" % outer_count)

	# Bước vào vùng cận -> bắn chùm quạt 3 phát.
	player.position = Vector3(3.0, 0.0, 0.0)
	player.velocity = Vector3.ZERO
	await _step_frames(120)
	var inner_count := _active_pools_in_tree().size()
	_check(
		inner_count >= 3, "Inner ring must fire multi-shot fan volley, got %d pools" % inner_count
	)

	# Rời khỏi vùng nhận diện -> Vigilant -> quay lại Dormant.
	player.position = Vector3(20.0, 0.0, 0.0)
	await _step_frames(15)
	_check(
		vine.fsm.current_state.name == &"Vigilant",
		"Vine must enter Vigilant after losing target, got %s" % vine.fsm.current_state.name
	)
	await _step_frames(65)
	_check(
		vine.fsm.current_state.name == &"Dormant" and not vine.is_awake,
		"Vine must retract to Dormant after vigilant_duration"
	)

	arena.queue_free()
	await _step_frames(3)


func _test_sniper_anger_stagger_and_death_pools() -> void:
	var arena := _create_arena()
	var vine := _spawn_fast_vine(arena)
	vine.max_active_pools = 2
	vine.pool_duration_seconds = 0.8
	# Đứng ở 11m (ngoài vùng nhận diện thường 8.5m, nhưng nằm trong vùng mở rộng 8.5 + 4.0 = 12.5m).
	var player := _spawn_dummy_player(arena, Vector3(11.0, 0.0, 0.0))
	await _step_frames(10)
	_check(vine.fsm.current_state.name == &"Dormant", "Vine must stay Dormant at 11m before hit")

	# Bắn tỉa từ 11m gây sát thương + stagger đủ vào EnemyHit.
	var sniper_hit := DamageContext.new()
	sniper_hit.source = player
	sniper_hit.source_team = CombatTeams.PLAYER
	sniper_hit.base_amount_hp = 1.5
	sniper_hit.amount_hp = 1.5
	sniper_hit.stagger_damage = 60.0
	sniper_hit.knockback_multiplier = 3.0
	vine.receive_damage(sniper_hit)
	await _step_frames(5)
	_check(vine.global_position.distance_to(Vector3.ZERO) < 0.05, "Rooted vine must not knock back")
	await _step_frames(45)
	_check(
		vine.is_awake and vine.has_target(),
		"Sniper hit from 11m must expand detection and lock onto sniper"
	)

	# Test max_active_pools cap: sinh 3 vũng thì vũng cũ nhất phải bị ép fade.
	vine.fire_shot_at(Vector3(3.0, 0.0, 0.0))
	vine.fire_shot_at(Vector3(3.0, 0.0, 3.0))
	vine.fire_shot_at(Vector3(3.0, 0.0, -3.0))
	await _step_frames(55)
	var non_fading := _active_pools_in_tree()
	_check(
		non_fading.size() <= vine.max_active_pools,
		(
			"Active pools must not exceed max_active_pools=%d (got %d)"
			% [vine.max_active_pools, non_fading.size()]
		)
	)

	# Giết cây -> vũng axit còn lại vẫn sống độc lập rồi tự tan biến.
	var lethal := DamageContext.new()
	lethal.source = player
	lethal.source_team = CombatTeams.PLAYER
	lethal.base_amount_hp = 99.0
	lethal.amount_hp = 99.0
	vine.receive_damage(lethal)
	await _step_frames(5)
	_check(vine.dead, "Vine must die after lethal damage")
	_check(_active_pools_in_tree().size() >= 1, "Acid pools must persist after VenomVine dies")
	await _step_frames(100)
	_check(
		_active_pools_in_tree().is_empty(), "Acid pools must fade out and clean up after duration"
	)

	arena.queue_free()
	await _step_frames(3)


func _test_forest_test_real_foxy_integration() -> void:
	var forest := FOREST_TEST_SCENE.instantiate()
	root.add_child(forest)
	await _step_frames(20)

	var foxy := forest.get_node_or_null("Foxy") as Player
	var vine_a := forest.get_node_or_null("VenomVineA") as VenomVine
	var vine_b := forest.get_node_or_null("VenomVineB") as VenomVine
	_check(foxy != null, "ForestTest must have Foxy")
	_check(vine_a != null and vine_b != null, "ForestTest must have VenomVineA and VenomVineB")
	if foxy == null or vine_a == null or vine_b == null:
		forest.queue_free()
		return

	# Khi Foxy đứng ở spawn (0, y, 0), cả 2 cây phải giữ Dormant.
	_check(
		not vine_a.is_awake and not vine_b.is_awake,
		"Both VenomVines in ForestTest must start Dormant at player spawn"
	)

	# Đưa Foxy vào vùng cận của VenomVineA -> tỉnh dậy, bắn lên BaseGround thật và làm Foxy nhiễm độc.
	var start_hp := foxy.hp.current_hp
	foxy.global_position = vine_a.global_position + Vector3(3.2, 0.2, 0.0)
	var saw_poison := false
	for _i in range(210):
		await physics_frame
		if foxy.is_poisoned() or foxy.hp.current_hp < start_hp:
			saw_poison = true
			break

	_check(vine_a.is_awake, "VenomVineA must wake when real Foxy approaches")
	_check(
		saw_poison,
		(
			"VenomVineA acid attack must hit real Foxy in ForestTest (hp %.2f -> %.2f)"
			% [start_hp, foxy.hp.current_hp]
		)
	)

	forest.queue_free()
	await _step_frames(3)


func _create_arena() -> Node3D:
	var arena := Node3D.new()
	root.add_child(arena)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = CombatLayers.WORLD
	floor_body.collision_mask = 0
	var floor_col := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(60.0, 1.0, 60.0)
	floor_col.shape = floor_box
	floor_col.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_col)
	arena.add_child(floor_body)
	return arena


func _spawn_fast_vine(arena: Node3D) -> VenomVine:
	var vine := VINE_SCENE.instantiate() as VenomVine
	vine.ambush_delay_min_seconds = 0.05
	vine.ambush_delay_max_seconds = 0.05
	vine.wake_duration_seconds = 0.1
	vine.wake_attack_delay_seconds = 0.08
	vine.charge_duration_seconds = 0.2
	vine.recover_duration_seconds = 0.1
	vine.outer_cooldown_seconds = 0.8
	vine.inner_cooldown_seconds = 0.5
	vine.vigilant_duration_seconds = 0.25
	vine.retract_duration_seconds = 0.12
	vine.pool_duration_seconds = 3.2
	arena.add_child(vine)
	return vine


func _spawn_dummy_player(arena: Node3D, pos: Vector3) -> DummyPlayer:
	var player := DummyPlayer.new()
	var p_col := CollisionShape3D.new()
	var p_cap := CapsuleShape3D.new()
	p_cap.radius = 0.4
	p_cap.height = 1.6
	p_col.shape = p_cap
	p_col.position = Vector3(0.0, 0.8, 0.0)
	player.add_child(p_col)

	var hurtbox := HurtBox.new()
	hurtbox.actor = player
	hurtbox.team = CombatTeams.PLAYER
	hurtbox.collision_layer = CombatLayers.PLAYER_HURTBOX
	hurtbox.collision_mask = 0
	var h_col := CollisionShape3D.new()
	var h_sph := SphereShape3D.new()
	h_sph.radius = 0.6
	h_col.shape = h_sph
	h_col.position = Vector3(0.0, 0.8, 0.0)
	hurtbox.add_child(h_col)
	player.add_child(hurtbox)

	player.position = pos
	arena.add_child(player)
	return player


func _active_pools_in_tree() -> Array[VenomAcidPool]:
	var result: Array[VenomAcidPool] = []
	for node in get_nodes_in_group(POOL_SCRIPT.POOL_GROUP):
		var pool := node as VenomAcidPool
		if pool != null and is_instance_valid(pool) and not pool.is_fading():
			result.append(pool)
	return result


func _step_frames(count: int) -> void:
	for _i in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
