extends SceneTree

const BOSS_SCENE := preload("res://gameplay/bosses/blubberbeard/blubberbeard.tscn")
const HAZARD_SCRIPT := preload("res://gameplay/bosses/blubberbeard/boss_hazard.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena := Node3D.new()
	root.add_child(arena)
	current_scene = arena

	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = CombatLayers.WORLD
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(40, 0.5, 40)
	floor_col.shape = floor_shape
	floor_body.add_child(floor_col)
	floor_body.position = Vector3(0, -0.25, 0)
	arena.add_child(floor_body)

	var player := Node3D.new()
	player.add_to_group("player")
	player.position = Vector3(12, 0, 0)
	arena.add_child(player)

	var boss := BOSS_SCENE.instantiate() as BlubberbeardBoss
	arena.add_child(boss)
	boss.set_physics_process(false)
	var behavior := boss
	var visual := behavior.visual
	boss.start_fight(player)

	# 1. 4-directional Idle & Move animations.
	_check(
		visual.texture == visual.IDLE_4DIR_SHEET and visual.hframes == 4 and visual.vframes == 3,
		"Idle visual should use 4x3 idle_4dir sheet"
	)
	behavior.timer = 1.0
	behavior.fight_tick(0.05)
	_check(
		visual.moving and visual.clip == BlubberbeardVisual.Clip.MOVE,
		"Boss did not enter Move clip when target is beyond preferred_distance"
	)
	var walk_dust := arena.get_node_or_null("BossMoveDustPuff") as Sprite3D
	_check(
		walk_dust != null and walk_dust.texture.resource_path.ends_with("boss_move_dust.png"),
		"Boss walking did not spawn textured BossMoveDustPuff"
	)
	_check(behavior.dust.emitting, "Boss walking did not enable continuous ChargeDust emitter")
	_check(
		visual.texture == visual.MOVE_4DIR_SHEET and visual.frame >= 4 and visual.frame <= 7,
		"Right-facing move did not select Side row (row 1)"
	)
	visual.face_direction(Vector3.FORWARD)
	_check(
		visual.frame >= 8 and visual.frame <= 11 and not visual.flip_h,
		"Up/Back move did not select Up row (row 2)"
	)
	visual.face_direction(Vector3.BACK)
	_check(
		visual.frame >= 0 and visual.frame <= 3 and not visual.flip_h,
		"Down/Front move did not select Down row (row 0)"
	)
	visual.face_direction(Vector3.LEFT)
	_check(
		visual.frame >= 4 and visual.frame <= 7 and visual.flip_h,
		"Left-facing move did not select Side row with flip_h"
	)

	# 2. Barrel barrage: escalating 1 -> 2 -> 3 waves + barrel hand-release sync + ash scorch.
	var barrel_skill := boss.boss_data.phases[0].skills[0] as BlubberbeardSkillData
	var prev_escalating := barrel_skill.barrel_escalating_burst
	var prev_fmin := barrel_skill.barrel_final_burst_min
	var prev_fmax := barrel_skill.barrel_final_burst_max
	var prev_dur := barrel_skill.barrel_throw_duration
	var prev_gmin := barrel_skill.barrel_throw_gap_min
	var prev_gmax := barrel_skill.barrel_throw_gap_max
	barrel_skill.barrel_escalating_burst = true
	barrel_skill.barrel_final_burst_min = 3
	barrel_skill.barrel_final_burst_max = 3
	barrel_skill.barrel_throw_duration = 0.40
	barrel_skill.barrel_throw_gap_min = 0.12
	barrel_skill.barrel_throw_gap_max = 0.22
	player.position = Vector3(5, 0, 0)
	behavior.forced_skill_index = 0
	behavior._choose_skill()
	var hazard: Node3D = (
		behavior._barrel_pending_hazards[0]
		if not behavior._barrel_pending_hazards.is_empty()
		else null
	)
	_check(is_instance_valid(hazard), "Barrel windup did not allocate wave 1 barrel hazard")
	var warning_disc := hazard.warning.get_child(0) as MeshInstance3D
	_check(hazard.warning.visible, "Barrel landing warning was not visible")
	_check(
		is_equal_approx((warning_disc.mesh as CylinderMesh).top_radius, hazard.radius),
		"Barrel warning does not match damage radius"
	)
	_check(
		behavior._barrel_wave_queue == [1, 2, 3] and behavior._barrel_used_spots.size() == 1,
		"Escalating barrage did not start wave 1 with 1 barrel queued"
	)
	_check(
		(
			(
				Vector2(
					hazard.global_position.x - player.global_position.x,
					hazard.global_position.z - player.global_position.z
				)
				. length()
			)
			< 0.05
		),
		"First wave throw did not aim straight at player"
	)
	_check(
		(
			visual.texture == visual.ATTACKS_SHEET
			and visual.clip == BlubberbeardVisual.Clip.BARREL_THROW
		),
		"Barrel windup did not switch to attacks sheet"
	)
	_check(
		visual.frame == 0 or visual.frame == 1, "Barrel windup must start on barrel-in-hand frame"
	)
	_check(
		hazard != null and hazard.get("_held_for_throw") and not hazard.barrel_visual.visible,
		"Separate barrel sprite appeared prematurely before throw release frame"
	)

	# Advance into throw release moment (windup_progress >= THROW_RELEASE_PROGRESS).
	var step_to_release := behavior._barrel_step_duration * 0.40
	behavior.fight_tick(step_to_release)
	_check(behavior._barrel_released, "Barrel was not released at throw frame threshold")
	_check(
		visual.frame == 2 or visual.frame == 3,
		"Boss sprite did not switch to empty-handed throw release frame"
	)
	_check(
		hazard != null and hazard.barrel_visual.visible,
		"Separate barrel sprite did not appear at throw release"
	)
	var hand_pos := visual.get_barrel_release_world_position()
	var barrel_start_world := hazard.to_global(hazard.get("_flight_start"))
	_check(
		hand_pos.distance_to(barrel_start_world) < 0.05,
		"Released barrel did not detach from boss raised throwing hand position"
	)
	_check(
		hazard.barrel_visual.texture.resource_path.ends_with("powder_barrel_sheet.png"),
		"Hazard barrel did not use matching powder_barrel_sheet texture"
	)
	_check(
		hazard.barrel_visual.frame >= 0 and hazard.barrel_visual.frame <= 3,
		"Airborne barrel did not start in Row 0 flight frames"
	)

	# Step into grounded priming ("about to explode") state, then detonate for ash scorch.
	var flight_dur: float = hazard.get("_flight_duration")
	hazard._physics_process(flight_dur + 0.05)
	hazard._physics_process(hazard.remaining * 0.7)
	_check(
		hazard.barrel_visual.frame >= 4 and hazard.barrel_visual.frame <= 7,
		"Grounded priming barrel did not switch to Row 1 about-to-explode frames"
	)
	hazard._physics_process(hazard.remaining + 0.05)
	_check(not hazard.warning.visible, "Barrel warning remained after detonation")
	var ash := arena.get_node_or_null("BarrelAshScorch") as Sprite3D
	_check(
		ash != null and ash.texture.resource_path.ends_with("barrel_ash_scorch.png"),
		"Barrel explosion did not leave ground ash scorch sprite"
	)
	_check(
		ash != null and absf(ash.rotation.x + PI * 0.5) < 0.05,
		"Ground ash scorch sprite was not laid flat on the ground"
	)
	if is_instance_valid(hazard):
		hazard.queue_free()

	# Continue stepping barrage through wave 2 (2 barrels tracking moved player) & wave 3.
	player.position = Vector3(9, 0, -2)
	for _tick in 40:
		if behavior.state == BlubberbeardBoss.State.RECOVERY:
			break
		behavior.fight_tick(0.1)
	_check(
		(
			behavior.state == BlubberbeardBoss.State.RECOVERY
			and behavior._barrel_used_spots.size() == 6
		),
		"Escalating 1->2->3 barrel barrage did not place 6 total spots into recovery"
	)
	if behavior._barrel_used_spots.size() >= 2:
		var wave2_lead := behavior._barrel_used_spots[1]
		_check(
			(
				Vector2(wave2_lead.x - player.position.x, wave2_lead.z - player.position.z).length()
				< 0.05
			),
			"Wave 2 barrel did not follow moved player position"
		)
	for child in arena.get_children():
		if child.get_script() == HAZARD_SCRIPT:
			child.queue_free()
	barrel_skill.barrel_escalating_burst = prev_escalating
	barrel_skill.barrel_final_burst_min = prev_fmin
	barrel_skill.barrel_final_burst_max = prev_fmax
	barrel_skill.barrel_throw_duration = prev_dur
	barrel_skill.barrel_throw_gap_min = prev_gmin
	barrel_skill.barrel_throw_gap_max = prev_gmax

	# 3. Parabolic Sky Dive, Anchor Whirlwind, 4-dir Venom Spit & Longer Spiky Inflation hold.
	behavior.forced_skill_index = 1
	behavior._choose_skill()
	_check(
		(
			visual.clip == BlubberbeardVisual.Clip.SKYDIVE_LAUNCH
			and visual.texture == visual.SKYDIVE_SHEET
		),
		"Parabolic leap did not select skydive launch sheet"
	)
	behavior._execute_skill()
	behavior.fight_tick(behavior.skill.skydive_leap_duration * 0.42)
	_check(
		visual.clip == BlubberbeardVisual.Clip.SKYDIVE_GLIDE,
		"Parabolic leap apex did not enter glide frame"
	)
	behavior.fight_tick(behavior.skill.skydive_leap_duration * 0.25)
	_check(
		visual.clip == BlubberbeardVisual.Clip.SKYDIVE_LOCK and visual.frame == 4,
		"Parabolic leap crest did not show anchor lock frame 4"
	)
	behavior.fight_tick(behavior.skill.skydive_leap_duration * 0.20)
	_check(
		visual.clip == BlubberbeardVisual.Clip.SKYDIVE_DIVE and visual.frame == 5,
		"Parabolic leap plunge did not select frame 5"
	)
	for _i in 20:
		if behavior.state == BlubberbeardBoss.State.RECOVERY:
			break
		behavior.fight_tick(0.05)
	_check(
		visual.clip == BlubberbeardVisual.Clip.SKYDIVE_IMPACT and visual.frame == 6,
		"Parabolic leap impact did not show crater frame 6"
	)

	var phase2 := boss.boss_data.phases[1]
	boss.take_damage(boss.boss_data.max_hp * 0.5)
	behavior.forced_skill_index = 3
	behavior._choose_skill()
	_check(
		(
			visual.clip == BlubberbeardVisual.Clip.WHIRLWIND_WINDUP
			and visual.texture == visual.WHIRLWIND_SHEET
			and visual.frame == 0
		),
		"Anchor Whirlwind windup did not select frame 0"
	)
	behavior._execute_skill()
	_check(
		(
			visual.clip == BlubberbeardVisual.Clip.WHIRLWIND_SPIN
			and visual.texture == visual.WHIRLWIND_SHEET
		),
		"Anchor Whirlwind spin did not select whirlwind sheet"
	)
	behavior._whirlwind_rig.hide_all()

	behavior.forced_skill_index = 4
	behavior._choose_skill()
	visual.face_direction(Vector3.FORWARD)
	_check(
		(
			visual.clip == BlubberbeardVisual.Clip.VENOM_SPIT
			and visual.texture == visual.VENOM_SPIT_4DIR_SHEET
			and visual.frame == 8
		),
		"Venom Spit Up windup frame mismatch"
	)
	visual.face_direction(Vector3.RIGHT)
	_check(visual.frame == 4, "Venom Spit Side row mismatch")

	behavior.skill = phase2.skills[2] as BlubberbeardSkillData
	behavior.state = BlubberbeardBoss.State.WINDUP
	behavior.timer = behavior.skill.windup
	visual.begin_windup(BlubberbeardSkillData.Kind.SPIKY_INFLATION)
	visual.face_direction(Vector3.FORWARD)
	_check(
		(
			visual.clip == BlubberbeardVisual.Clip.INFLATE_WINDUP
			and visual.texture == visual.INFLATE_4DIR_SHEET
			and visual.frame == 8
		),
		"Spiky Inflation Up windup frame mismatch"
	)
	behavior._execute_skill()
	_check(
		visual.clip == BlubberbeardVisual.Clip.INFLATE_BURST and visual.frame == 10,
		"Spiky Inflation Up burst frame mismatch"
	)

	# 4. Hit & Death animations.
	visual.pose = BlubberbeardVisual.Pose.IDLE
	visual.flash_hit()
	visual._process(0.05)
	_check(
		visual.texture == visual.HIT_DEATH_SHEET and visual.frame <= 3,
		"Hit recoil did not use hit_death sheet Row 0"
	)
	boss.take_damage(boss.boss_data.max_hp + 50.0)
	_check(visual._dying, "Death did not trigger BlubberbeardVisual death animation")
	visual._process(0.8)
	_check(
		visual.texture == visual.HIT_DEATH_SHEET and visual.frame >= 4 and visual.frame <= 7,
		"Death animation did not advance through hit_death sheet Row 1"
	)

	behavior.sound.stop()
	root.get_node("AudioManager").stop_all_sfx()
	arena.queue_free()
	await process_frame
	if failures.is_empty():
		print("Blubberbeard animation and throw-sync tests passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
