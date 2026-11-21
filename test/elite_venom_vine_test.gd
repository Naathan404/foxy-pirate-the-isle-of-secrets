extends SceneTree
## Kiểm thử Pha A cho EliteVenomVine (damage, snare, split, whip, relocate, tendril).

const ELITE_SCENE := preload("res://gameplay/enemies/venom_vine/elite_venom_vine.tscn")
const POOL_SCRIPT := preload("res://gameplay/enemies/venom_vine/venom_acid_pool.gd")
const SEGMENT_SCRIPT := preload("res://gameplay/enemies/venom_vine/venom_thorn_segment.gd")
const FOREST_VINE_SCENE := preload("res://world/tests/forest_venom_vine_test.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_single_source_damage_and_shader_chain()
	await _test_thorny_snare_and_bramble_pod_split()
	await _test_smart_tunnel_relocate_and_approach()
	await _test_thorn_tendril_below_half_hp()

	if _failures.is_empty():
		print("ALL ELITE VENOM VINE PHASE A CHECKS PASSED")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_single_source_damage_and_shader_chain() -> void:
	var arena := _create_arena()
	var vine := _spawn_fast_elite(arena, Vector3.ZERO)
	await _step_frames(6)

	_check(vine.data != null, "EliteVenomVine must have EnemyData")
	_check(
		is_equal_approx(vine.data.max_hp, 21.0),
		"EliteVenomVine HP must be 21.0, got %.2f" % vine.data.max_hp
	)
	_check(
		is_equal_approx(vine.data.knockback_resistance, 1.0),
		"EliteVenomVine must remain rooted (knockback_resistance = 1.0)"
	)
	_check(vine.data.drop_quantity == 3, "EliteVenomVine must drop 3x item")
	var default_tick_hp := vine.resolve_attack_damage(vine.snare_tick_damage_multiplier)
	_check(
		default_tick_hp <= 0.5,
		"Elite poison tick damage (%.2f) must not exceed regular VenomVine (0.5)" % default_tick_hp
	)

	# Kiểm tra mọi damage đều tính từ data.attack_damage * multiplier.
	var custom_data := vine.data.duplicate(true) as EnemyData
	custom_data.attack_damage = 2.0
	vine.data = custom_data
	var tendril_dmg := vine.resolve_attack_damage(vine.tendril_damage_multiplier)
	var cfg := vine.build_pool_config()
	_check(
		is_equal_approx(tendril_dmg, 2.0 * vine.tendril_damage_multiplier),
		"ThornTendril damage must scale directly from data.attack_damage"
	)
	_check(
		is_equal_approx(
			float(cfg.get("tick_damage_hp", 0.0)), 2.0 * vine.snare_tick_damage_multiplier
		),
		"Pool tick damage must scale directly from data.attack_damage"
	)

	# Kiểm tra hitbox luôn nhỏ hơn visual và không còn state RootWhip.
	_check(
		vine.get_node_or_null(^"States/RootWhip") == null,
		"RootWhip state must be removed cleanly from EliteVenomVine"
	)
	_check(
		vine.initial_state_name == &"Dormant" and vine.fsm.current_state.name == &"Dormant",
		"EliteVenomVine must start Dormant above ground, got %s" % vine.fsm.current_state.name
	)
	_check(not vine.is_burrowed, "EliteVenomVine must NOT start burrowed")
	var burrow_pit := vine.get_node_or_null(^"BurrowPit") as Sprite3D
	_check(
		burrow_pit != null and not burrow_pit.visible,
		"Scene BurrowPit must exist for editor alignment and auto-hide on _ready()"
	)
	_check(
		vine.elite_feedback != null and not vine.elite_feedback.show_ground_telegraph_ring,
		"Forest EliteFeedback must disable ground TorusMesh telegraph ring"
	)
	_check(not _has_torus_mesh(vine), "EliteVenomVine must contain zero TorusMesh ground rings")
	_check(
		vine.tendril_hitbox_radius_meters < vine.tendril_visual_radius_meters,
		"ThornTendril HitBox must be smaller than visual"
	)

	# Kiểm tra shader overlay của EliteFeedback không bị VenomVine đè mất.
	var overlay := vine.visual.sprite.material_overlay
	_check(
		overlay != null and overlay.next_pass != null,
		"EliteVenomVine must keep chained EliteFeedback + VenomVine glow shaders"
	)

	arena.queue_free()
	await _step_frames(3)


func _test_thorny_snare_and_bramble_pod_split() -> void:
	var forest := FOREST_VINE_SCENE.instantiate()
	root.add_child(forest)
	await _step_frames(15)

	var foxy := forest.get_node_or_null("Foxy") as Player
	_check(foxy != null, "Forest scene must include Foxy")
	if foxy == null:
		forest.queue_free()
		return

	var base_speed := foxy._get_move_speed()
	foxy.poison_remaining = 1.0
	var normal_poison_speed := foxy._get_move_speed()
	_check(
		is_equal_approx(normal_poison_speed, base_speed * foxy.poison_move_speed_multiplier),
		"Normal poison must slow Foxy to 0.45x"
	)
	# Vung Elite Thorny Snare (0.72 slow -> 0.28x) phai lam cham hon ro ret so voi doc thuong (0.45x).
	foxy.apply_snare(0.5, 0.28)
	_check(
		(
			is_equal_approx(foxy._get_move_speed(), base_speed * 0.28)
			and foxy._get_move_speed() < normal_poison_speed - 0.1
		),
		(
			"Elite Thorny Snare (%.2f) must slow Foxy noticeably more than normal acid (%.2f)"
			% [foxy._get_move_speed(), normal_poison_speed]
		)
	)
	foxy.poison_remaining = 0.0
	foxy.snare_remaining = 0.0
	foxy._snare_move_speed_multiplier = 1.0

	# Kiểm tra Bramble Pod Split tạo vũng tím shader khác biệt & truyền Snare mạnh khi Foxy dẫm.
	var vine := _spawn_fast_elite(forest, foxy.global_position + Vector3(8.5, 0.0, 0.0))
	vine.set_awake(true)
	vine.is_burrowed = false
	vine.max_active_pools = 8
	vine.fire_shot_at(foxy.global_position + Vector3(3.2, 0.0, 0.0))
	await _step_frames(85)

	var pools := _active_pools_in_tree()
	_check(
		pools.size() >= 3,
		"Bramble Pod Split must produce primary + split pools (got %d)" % pools.size()
	)
	if not pools.is_empty():
		var test_pool := pools[0]
		var spark_quad := (
			test_pool._rising_sparks.draw_pass_1 as QuadMesh
			if is_instance_valid(test_pool._rising_sparks)
			else null
		)
		_check(
			test_pool._puddle_material != null,
			"Elite purple snare pool must apply ELITE_PUDDLE_SHADER to stand apart from normal acid"
		)
		_check(
			spark_quad != null and spark_quad.material is ShaderMaterial,
			"Elite purple snare pool must tint rising light particles purple via ShaderMaterial"
		)
		_check(not _has_torus_mesh(test_pool), "Elite pool must have zero TorusMesh ground ring")
		foxy.global_position = Vector3(
			test_pool.global_position.x, foxy.global_position.y, test_pool.global_position.z
		)
		await _step_frames(8)
		_check(
			foxy.is_snared() and foxy._get_move_speed() < base_speed * 0.35,
			"Standing in Elite purple pool must apply stronger 0.28x slow on real Foxy"
		)
		foxy.request_dash()
		await _step_frames(3)
		_check(
			foxy.fsm.current_state.name == &"Dash",
			"Thorny Snare must not block Foxy Dash, got %s" % foxy.fsm.current_state.name
		)

	forest.queue_free()
	await _step_frames(3)


func _test_smart_tunnel_relocate_and_approach() -> void:
	var forest := FOREST_VINE_SCENE.instantiate()
	root.add_child(forest)
	await _step_frames(15)
	var foxy := forest.get_node_or_null("Foxy") as Player
	_check(foxy != null, "Forest scene must include Foxy")
	if foxy == null:
		forest.queue_free()
		return

	var placed_elite := forest.get_node_or_null("EliteVenomVine") as EliteVenomVine
	_check(placed_elite != null, "ForestVenomVineTest must place an EliteVenomVine instance")
	if placed_elite != null:
		_check(
			(
				placed_elite.initial_state_name == &"Dormant"
				and placed_elite.fsm.current_state.name == &"Dormant"
				and not placed_elite.is_burrowed
			),
			(
				"Placed EliteVenomVine in ForestVenomVineTest must start Dormant above ground (got %s)"
				% placed_elite.fsm.current_state.name
			)
		)
		_check(
			(
				placed_elite.burrow_duration_seconds >= 1.0
				and placed_elite.relocate_telegraph_seconds >= 2.4
				and placed_elite.relocate_max_distance_meters >= 10.0
			),
			"Placed EliteVenomVine must use longer stealth burrow (>=1s hidden, >=2.4s crawl, >=10m range)"
		)
	var arena_center := (
		placed_elite.global_position
		if placed_elite != null
		else foxy.global_position + Vector3(4.0, 0.0, 0.0)
	)
	if placed_elite != null:
		placed_elite.queue_free()

	var origin := arena_center
	var vine := _spawn_fast_elite(forest, origin)
	vine.relocate_telegraph_seconds = 0.25
	vine.relocate_phase_hp_ratio = 0.5
	vine.burrow_cooldown_seconds = 0.2
	await _step_frames(5)

	# 1. Thức dậy từ Dormant (không mở hố) rồi hạ HP <= 50% -> Tunnel Relocate ra chỗ thoáng.
	foxy.global_position = origin + Vector3(-2.4, 0.0, 0.5)
	await _step_frames(22)
	var wake_pit := vine.get_node_or_null(^"BurrowPit") as Sprite3D
	_check(
		(
			vine.fsm.current_state.name == &"Stalk"
			and (wake_pit == null or not wake_pit.visible)
			and forest.find_child("VenomDeparturePit", true, false) == null
		),
		"Waking from Dormant must stay calmly above ground without opening a burrow pit"
	)
	# 1. Ở mức > 75% HP: chui đất để lại dấu chấm chấm chấm chi tiết và KHÔNG có chấm giả.
	vine._request_burrow(false)
	await _step_frames(18)
	var mid_burrow_glow := float(
		vine.elite_feedback._elite_sprite_glow_material.get_shader_parameter("glow_strength")
	)
	_check(
		is_zero_approx(mid_burrow_glow) and not vine._ambient_spores.emitting,
		"While burrowed underground, Elite glow motes and ambient spores must turn off cleanly"
	)
	for _wait_emerge in range(100):
		await physics_frame
		if not vine.is_burrowed and vine.fsm.current_state.name != &"Burrow":
			break
	var high_hp_dots := forest.find_children("TunnelTrailDot*", "", true, false)
	var high_hp_decoys := forest.find_children("TunnelDecoyDot*", "", true, false)
	var moving_mounds := forest.find_children("TunnelMovingMound*", "", true, false)
	_check(
		moving_mounds.is_empty(),
		"Smart Tunnel Relocate must not spawn any sliding TunnelMovingMound on grass"
	)
	_check(
		high_hp_dots.size() >= 4 and high_hp_decoys.is_empty(),
		(
			"Above 75%% HP tunnel trail must show clear earth dots without decoy branches (dots=%d)"
			% high_hp_dots.size()
		)
	)
	var high_hp_pos := vine.global_position
	var first_moved_dist := Vector2(high_hp_pos.x - origin.x, high_hp_pos.z - origin.z).length()
	_check(
		first_moved_dist >= 3.0 and not vine.is_burrowed,
		"Tunnel Relocate must move Elite farther to a new spot (moved=%.2fm)" % first_moved_dist
	)
	_check(
		(
			vine.fsm.current_state.name == &"Attack"
			or (vine.fsm.next_state != null and vine.fsm.next_state.name == &"Attack")
		),
		(
			"Emerging with Player in sight must trigger immediate Emerge Ambush spit (got %s)"
			% vine.fsm.current_state.name
		)
	)

	# Dọn các chấm đợt 1 trước khi đo số chấm ít hơn hẳn ở đợt HP thấp.
	for old_dot in forest.find_children("Tunnel*Dot*", "", true, false):
		old_dot.queue_free()
	await _step_frames(2)

	# 1b. Hạ HP xuống <= 40% -> số chấm thật còn cực ít + nhiều chấm giả để khó đoán hơn nữa!
	vine._burrow_cooldown_remaining = 0.0
	var heavy_hit := _make_player_melee_hit(foxy, 13.5)
	vine.receive_damage(heavy_hit)
	await _step_frames(4)
	_check(
		vine.fsm.current_state.name == &"Burrow",
		"When HP <= 50%%, Elite must enter Burrow, got %s" % vine.fsm.current_state.name
	)
	for _wait_low_emerge in range(100):
		await physics_frame
		if not vine.is_burrowed and vine.fsm.current_state.name != &"Burrow":
			break
	var low_hp_dots := forest.find_children("TunnelTrailDot*", "", true, false)
	var decoy_dots := forest.find_children("TunnelDecoyDot*", "", true, false)
	var tease_mounds := forest.find_children("TunnelDecoyTease*", "", true, false)
	_check(
		(
			low_hp_dots.size() >= 2
			and low_hp_dots.size() <= 4
			and decoy_dots.size() >= 3
			and not tease_mounds.is_empty()
		),
		(
			(
				"At <= 40%% HP, real trail dots must shrink (real=%d) "
				+ "while adding decoy dots (decoy=%d) and decoy tease mounds (tease=%d)"
			)
			% [low_hp_dots.size(), decoy_dots.size(), tease_mounds.size()]
		)
	)
	var first_relocate_pos := vine.global_position
	var moved_dist := (
		Vector2(first_relocate_pos.x - high_hp_pos.x, first_relocate_pos.z - high_hp_pos.z).length()
	)
	_check(
		moved_dist >= 3.0 and not vine.is_burrowed,
		"Low-HP relocate must move Elite farther to another spot (moved=%.2fm)" % moved_dist
	)
	_check(
		vine.visual.position.z > vine._burrow_pit_base_pos.z,
		(
			"2.5D EliteVenomVine Visual (z=%.2f) must stay slightly in front of BurrowPit (z=%.2f)"
			% [vine.visual.position.z, vine._burrow_pit_base_pos.z]
		)
	)
	_check(
		not _has_torus_mesh(vine),
		"EliteVenomVine must contain zero TorusMesh ground telegraph rings"
	)
	var vine_a := forest.get_node_or_null("VenomVineA") as VenomVine
	if vine_a != null:
		_check(
			not vine_a.is_burrowed and vine_a.initial_state_name == &"Dormant",
			"Regular VenomVineA must also start Dormant above ground without hiding forever"
		)
		_check(
			not _has_torus_mesh(vine_a),
			"VenomVineA must contain zero TorusMesh ground telegraph rings"
		)
	var space := vine.get_world_3d().direct_space_state
	var open_1 := VenomVineRelocateHelper.count_open_directions(
		space, first_relocate_pos, first_relocate_pos.y, [vine.get_rid()]
	)
	_check(open_1 >= 6, "Relocate spot must avoid tight corners (open_dirs=%d/8)" % open_1)

	# 2. Chui xuống lần 2 ngay sau đó -> bắt buộc vẫn phải đi sang chỗ khác trước khi trồi lên!
	vine._request_burrow(false)
	await _step_frames(52)
	var second_pos := vine.global_position
	var second_moved_dist := (
		Vector2(second_pos.x - first_relocate_pos.x, second_pos.z - first_relocate_pos.z).length()
	)
	_check(
		second_moved_dist >= 1.5 and not vine.is_burrowed,
		"Every consecutive burrow must relocate & emerge (moved2=%.2fm)" % second_moved_dist
	)

	# 3. Đưa Foxy áp sát ngay cạnh -> Elite chủ động chui rút RA XA Player về vùng thoáng.
	vine._burrow_cooldown_remaining = 0.0
	foxy.global_position = vine.global_position + Vector3(1.5, 0.0, 0.4)
	var before_evade_dist := VenomVineRelocateHelper.flat_distance(
		vine.global_position, foxy.global_position
	)
	var entered_evade_burrow := false
	var emerged_after_evade := false
	for _frame in range(260):
		await physics_frame
		if vine.fsm.current_state.name == &"Burrow":
			entered_evade_burrow = true
		elif entered_evade_burrow and not vine.is_burrowed:
			emerged_after_evade = true
			break
	var after_evade_dist := VenomVineRelocateHelper.flat_distance(
		vine.global_position, foxy.global_position
	)
	var open_3 := VenomVineRelocateHelper.count_open_directions(
		space, vine.global_position, vine.global_position.y, [vine.get_rid()]
	)
	_check(
		entered_evade_burrow and emerged_after_evade,
		"Close Foxy pressure must trigger defensive keep-away Tunnel Relocate"
	)
	_check(
		after_evade_dist >= before_evade_dist + 1.2 and after_evade_dist >= 3.3,
		(
			(
				"Smart Tunnel Relocate must move AWAY from Player to avoid instant hit/spit "
				+ "(before=%.2fm, after=%.2fm)"
			)
			% [before_evade_dist, after_evade_dist]
		)
	)
	_check(
		open_3 >= 6, "Keep-away relocate spot must stay out of corners (open_dirs=%d/8)" % open_3
	)

	# 4. Khi mất dấu OUT_OF_RANGE, cây vẫn phải trồi lên về Dormant chứ không trốn dưới đất.
	foxy.global_position = Vector3(-40.0, 0.0, -40.0)
	vine._request_burrow(false)
	await _step_frames(62)
	_check(
		not vine.is_burrowed and vine.fsm.current_state.name == &"Dormant",
		(
			"Burrowing while OUT_OF_RANGE must still emerge above ground into Dormant (got %s)"
			% vine.fsm.current_state.name
		)
	)
	foxy.global_position = Vector3(-0.5, 0.0, 0.5)

	# 5. Đánh tụt <= 50% HP ngay lúc còn Dormant vẫn phải chui đất đổi chỗ, không trồi tại chỗ.
	vine.queue_free()
	await _step_frames(3)
	var dormant_hit_vine := _spawn_fast_elite(forest, arena_center)
	dormant_hit_vine.relocate_telegraph_seconds = 0.2
	await _step_frames(5)
	var pre_hit_pos := dormant_hit_vine.global_position
	dormant_hit_vine.receive_damage(_make_player_melee_hit(foxy, 11.5))
	await _step_frames(46)
	var post_hit_move := (
		Vector2(
			dormant_hit_vine.global_position.x - pre_hit_pos.x,
			dormant_hit_vine.global_position.z - pre_hit_pos.z
		)
		. length()
	)
	_check(
		post_hit_move >= 1.2 and not dormant_hit_vine.is_burrowed,
		"Heavy hit while Dormant must relocate & emerge at a new spot (moved=%.2fm)" % post_hit_move
	)
	dormant_hit_vine.queue_free()

	forest.queue_free()
	await _step_frames(3)


func _test_thorn_tendril_below_half_hp() -> void:
	var forest := FOREST_VINE_SCENE.instantiate()
	root.add_child(forest)
	await _step_frames(15)
	var foxy := forest.get_node_or_null("Foxy") as Player
	_check(foxy != null, "Forest scene must include Foxy")
	if foxy == null:
		forest.queue_free()
		return

	var placed := forest.get_node_or_null("EliteVenomVine") as EliteVenomVine
	if placed != null:
		var seg_anim_total := (
			placed.tendril_segment_telegraph_seconds
			+ placed.tendril_segment_active_seconds
			+ placed.tendril_segment_retract_seconds
		)
		_check(
			seg_anim_total >= 1.2 and seg_anim_total <= 2.2,
			"Default lightning root animation must span 1-2s (got %.2fs)" % seg_anim_total
		)
		placed.queue_free()

	var origin := foxy.global_position + Vector3(5.0, 0.0, 0.0)
	var vine := _spawn_fast_elite(forest, origin)
	vine.tendril_windup_seconds = 0.16
	vine.tendril_segment_interval_seconds = 0.05
	vine.tendril_segment_telegraph_seconds = 0.22
	vine.tendril_segment_active_seconds = 0.28
	vine.tendril_segment_retract_seconds = 0.16
	vine.tendril_cooldown_seconds = 4.0
	await _step_frames(22)

	# Đưa HP về 40% qua HealthComponent và giả lập đã xong phase relocate để kiểm tra ThornTendril.
	vine._half_hp_relocate_done = true
	vine.hp.take_damage(vine.data.max_hp * 0.6)
	vine.attack_cooldown_remaining = 0.0
	vine._tendril_cooldown_remaining = 0.0
	vine.request_state(&"stalk", 80)
	var pre_hp := foxy.hp.current_hp
	foxy.global_position = vine.global_position + Vector3(2.8, 0.0, 0.0)
	await _step_frames(24)

	var early_segments := _collect_segments(forest)
	if not early_segments.is_empty():
		var target_seg := early_segments[mini(2, early_segments.size() - 1)]
		foxy.global_position = Vector3(
			target_seg.global_position.x, foxy.global_position.y, target_seg.global_position.z
		)
	await _step_frames(34)
	var segments := _collect_segments(forest)
	_check(
		segments.size() >= 6,
		(
			"Lightning ThornTendril must spawn longer jagged chain + fork (segments=%d)"
			% segments.size()
		)
	)
	var max_perp_deviation := _max_line_deviation(vine.global_position, segments)
	_check(
		max_perp_deviation >= 0.45,
		(
			(
				"Lightning ThornTendril path must zig-zag unpredictably rather than straight line "
				+ "(dev=%.2fm)"
			)
			% max_perp_deviation
		)
	)
	_check(
		foxy.hp.current_hp < pre_hp,
		"Erupting lightning ThornTendril segment must hit Foxy standing on its zig-zag node"
	)
	for seg in segments:
		_check(
			seg.get_hitbox_radius() < seg.get_visual_radius(),
			"Every ThornTendril segment hitbox must stay smaller than visual"
		)
		_check(not _has_torus_mesh(seg), "Forest ThornSegment must not spawn ground TorusMesh ring")

	forest.queue_free()
	await _step_frames(3)


func _max_line_deviation(origin_pos: Vector3, segments: Array[VenomThornSegment]) -> float:
	if segments.size() < 3:
		return 0.0
	var last_seg := segments[mini(segments.size() - 1, 8)]
	var axis := Vector2(
		last_seg.global_position.x - origin_pos.x, last_seg.global_position.z - origin_pos.z
	)
	if axis.length() <= 0.05:
		return 0.0
	var dir := axis.normalized()
	var max_dev := 0.0
	for seg in segments:
		var rel := Vector2(
			seg.global_position.x - origin_pos.x, seg.global_position.z - origin_pos.z
		)
		var perp := absf(dir.x * rel.y - dir.y * rel.x)
		if perp > max_dev:
			max_dev = perp
	return max_dev


func _has_torus_mesh(node: Node) -> bool:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh is TorusMesh:
		return true
	for child in node.get_children():
		if _has_torus_mesh(child):
			return true
	return false


func _make_player_melee_hit(attacker: Node, amount_hp: float) -> DamageContext:
	var ctx := DamageContext.new()
	ctx.source = attacker
	ctx.source_team = CombatTeams.PLAYER
	ctx.attack_id = 1
	ctx.base_amount_hp = amount_hp
	ctx.amount_hp = amount_hp
	ctx.tag = &"normal"
	ctx.stagger_damage = 10.0
	return ctx


func _spawn_fast_elite(parent: Node, pos: Vector3) -> EliteVenomVine:
	var vine := ELITE_SCENE.instantiate() as EliteVenomVine
	vine.position = pos
	vine.ambush_delay_min_seconds = 0.02
	vine.ambush_delay_max_seconds = 0.02
	vine.burrow_transition_seconds = 0.08
	vine.burrow_duration_seconds = 0.12
	vine.wake_duration_seconds = 0.08
	vine.wake_attack_delay_seconds = 0.06
	vine.charge_duration_seconds = 0.15
	vine.recover_duration_seconds = 0.08
	parent.add_child(vine)
	vine.global_position = pos
	return vine


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


func _active_pools_in_tree() -> Array[VenomAcidPool]:
	var result: Array[VenomAcidPool] = []
	for node in get_nodes_in_group(POOL_SCRIPT.POOL_GROUP):
		var pool := node as VenomAcidPool
		if pool != null and is_instance_valid(pool) and not pool.is_fading():
			result.append(pool)
	return result


func _collect_segments(parent_node: Node) -> Array[VenomThornSegment]:
	var out: Array[VenomThornSegment] = []
	for child in parent_node.get_children():
		if child is VenomThornSegment:
			out.append(child as VenomThornSegment)
	return out


func _step_frames(count: int) -> void:
	for _i in range(count):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
