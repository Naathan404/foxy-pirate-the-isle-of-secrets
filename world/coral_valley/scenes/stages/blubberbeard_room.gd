@tool
class_name BlubberbeardRoom
extends "res://world/biomes/base/base_room.gd"
## Manages Captain Blubberbeard's boss arena, collapsing the exit bridge on entry.

signal exit_locked
signal exit_unlocked
signal exit_blocked_attempted

const BRIDGE_TEXTURE := preload("res://assets/textures/bridge/bridge.png")
const COLLAPSE_SOUND := preload("res://gameplay/bosses/blubberbeard/boss_explosion.wav")
const RESTORE_SOUND := preload("res://assets/audio/world/crate_lever.wav")

const SHORE_REGION_RECT := Rect2(820.0, 0.0, 582.0, 1122.0)
const SHORE_SPRITE_OFFSET := Vector2(410.0, 0.0)
const BRIDGE_RIGHT_PIVOT_X := -28.0
const BRIDGE_LEFT_PIVOT_X := -38.8
const BRIDGE_SPAN_LENGTH := 5.4
const BRIDGE_DECK_WIDTH := 4.6
const BRIDGE_DECK_HEIGHT := 0.36
const BRIDGE_REST_Y := 0.05
const COLLAPSED_DEPTH_Y := -3.5
const COLLAPSE_BARRIER_X := -27.95
const COLLAPSE_DELAY_SECONDS := 0.15
const COLLAPSE_DURATION_SECONDS := 0.55
const RESTORE_DURATION_SECONDS := 0.55
const PROMPT_COOLDOWN_SECONDS := 3.0

var _boss: BossBase
var _encounter: Node
var _left_trigger: SceneChangeTrigger
var _left_trigger_shape: CollisionShape3D
var _collapse_barrier_shape: CollisionShape3D
var _bridge_right_span: Node3D
var _bridge_left_span: Node3D
var _collapsed_rubble: Node3D
var _collapse_particles: CPUParticles3D
var _bridge_tween: Tween
var _exit_is_locked: bool = false
var _prompt_cooldown: float = 0.0


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	_cache_room_nodes()
	_crop_left_shore_sprite()
	_build_exit_bridge()
	if _should_lock_exit():
		_exit_is_locked = true
		_set_exit_locked(true)
		_boss.fight_finished.connect(_on_boss_fight_finished)
		_trigger_bridge_collapse()
	else:
		_exit_is_locked = false
		_set_exit_locked(false)


func _physics_process(delta: float) -> void:
	super(delta)
	if Engine.is_editor_hint():
		return
	if _prompt_cooldown > 0.0:
		_prompt_cooldown = maxf(0.0, _prompt_cooldown - delta)


func is_exit_locked() -> bool:
	return _exit_is_locked


func _cache_room_nodes() -> void:
	_boss = get_node_or_null("CaptainBlubberbeard") as BossBase
	_encounter = get_node_or_null("BossEncounter")
	_left_trigger = get_node_or_null("Exits/LeftPath/SceneChangeTrigger") as SceneChangeTrigger
	if is_instance_valid(_left_trigger):
		_left_trigger_shape = _left_trigger.get_node_or_null("CollisionShape3D") as CollisionShape3D


func _should_lock_exit() -> bool:
	if not is_instance_valid(_boss) or _boss.is_queued_for_deletion() or _boss.dead:
		return false
	if _encounter != null:
		var encounter_id: Variant = _encounter.get("encounter_id")
		var manager := get_node_or_null("/root/GameManager")
		if manager != null and encounter_id is StringName and not encounter_id.is_empty():
			var state: Dictionary = manager.boss_encounters.get(encounter_id, {})
			if bool(state.get("defeated", false)):
				return false
	return true


func _crop_left_shore_sprite() -> void:
	var sprite := get_node_or_null("Exits/LeftPath/Sprite3D") as Sprite3D
	if not is_instance_valid(sprite):
		return
	sprite.region_enabled = true
	sprite.region_rect = SHORE_REGION_RECT
	sprite.offset = SHORE_SPRITE_OFFSET


func _build_exit_bridge() -> void:
	var bridge_root := Node3D.new()
	bridge_root.name = "ExitBridge"
	add_child(bridge_root)

	var deck_material := _create_bridge_material()
	var timber_material := _create_timber_material()

	_bridge_right_span = _create_bridge_span(
		"RightSpan",
		Vector3(BRIDGE_RIGHT_PIVOT_X, BRIDGE_REST_Y, 0.0),
		-BRIDGE_SPAN_LENGTH * 0.5,
		deck_material,
		timber_material
	)
	bridge_root.add_child(_bridge_right_span)

	_bridge_left_span = _create_bridge_span(
		"LeftSpan",
		Vector3(BRIDGE_LEFT_PIVOT_X, BRIDGE_REST_Y, 0.0),
		BRIDGE_SPAN_LENGTH * 0.5,
		deck_material,
		timber_material
	)
	bridge_root.add_child(_bridge_left_span)

	_collapsed_rubble = _create_collapsed_rubble(timber_material)
	_collapsed_rubble.visible = false
	bridge_root.add_child(_collapsed_rubble)

	_create_collapse_barrier(bridge_root)
	_create_collapse_particles(bridge_root)
	_create_barrier_prompt_sensor(bridge_root)


func _create_bridge_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = BRIDGE_TEXTURE
	mat.uv1_scale = Vector3(0.35, 1.0, 0.45)
	mat.uv1_offset = Vector3(0.5, 0.0, 0.0)
	mat.uv1_triplanar = true
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat


func _create_timber_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.19, 0.11)
	mat.roughness = 0.9
	return mat


func _create_bridge_span(
	span_name: String,
	pivot_pos: Vector3,
	center_offset_x: float,
	deck_mat: StandardMaterial3D,
	timber_mat: StandardMaterial3D
) -> Node3D:
	var span := Node3D.new()
	span.name = span_name
	span.position = pivot_pos

	var deck := MeshInstance3D.new()
	var deck_mesh := BoxMesh.new()
	deck_mesh.size = Vector3(BRIDGE_SPAN_LENGTH, BRIDGE_DECK_HEIGHT, BRIDGE_DECK_WIDTH)
	deck.mesh = deck_mesh
	deck.material_override = deck_mat
	deck.position = Vector3(center_offset_x, -BRIDGE_DECK_HEIGHT * 0.5, 0.0)
	span.add_child(deck)

	for side_sign in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(BRIDGE_SPAN_LENGTH, 0.28, 0.28)
		rail.mesh = rail_mesh
		rail.material_override = timber_mat
		rail.position = Vector3(center_offset_x, 0.12, side_sign * (BRIDGE_DECK_WIDTH * 0.5 - 0.14))
		span.add_child(rail)
	return span


func _create_collapsed_rubble(timber_mat: StandardMaterial3D) -> Node3D:
	var rubble := Node3D.new()
	rubble.name = "CollapsedRubble"
	rubble.position = Vector3(BRIDGE_RIGHT_PIVOT_X + 0.15, 0.0, 0.0)

	for side_sign in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.45, 1.4, 0.45)
		post.mesh = post_mesh
		post.material_override = timber_mat
		post.position = Vector3(0.0, 0.55, side_sign * (BRIDGE_DECK_WIDTH * 0.5 - 0.2))
		post.rotation = Vector3(side_sign * 0.12, 0.0, 0.18)
		rubble.add_child(post)

	var broken_plank := MeshInstance3D.new()
	var plank_mesh := BoxMesh.new()
	plank_mesh.size = Vector3(0.32, 0.24, BRIDGE_DECK_WIDTH * 0.85)
	broken_plank.mesh = plank_mesh
	broken_plank.material_override = timber_mat
	broken_plank.position = Vector3(-0.25, 0.18, 0.0)
	broken_plank.rotation = Vector3(0.0, 0.14, 0.32)
	rubble.add_child(broken_plank)
	return rubble


func _create_collapse_barrier(parent: Node3D) -> void:
	var barrier := StaticBody3D.new()
	barrier.name = "ExitCollapseBarrier"
	barrier.collision_layer = CombatLayers.WORLD | CombatLayers.PLAYER_BOUNDARY
	barrier.collision_mask = 0
	barrier.position = Vector3(COLLAPSE_BARRIER_X, 1.5, 0.0)

	_collapse_barrier_shape = CollisionShape3D.new()
	_collapse_barrier_shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 3.5, 11.0)
	_collapse_barrier_shape.shape = box
	_collapse_barrier_shape.disabled = true
	barrier.add_child(_collapse_barrier_shape)
	parent.add_child(barrier)


func _create_collapse_particles(parent: Node3D) -> void:
	_collapse_particles = CPUParticles3D.new()
	_collapse_particles.name = "BridgeCollapseSplash"
	_collapse_particles.emitting = false
	_collapse_particles.one_shot = true
	_collapse_particles.explosiveness = 0.9
	_collapse_particles.amount = 36
	_collapse_particles.lifetime = 0.85
	_collapse_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_collapse_particles.emission_box_extents = Vector3(2.8, 0.2, 2.0)
	_collapse_particles.direction = Vector3.UP
	_collapse_particles.spread = 65.0
	_collapse_particles.initial_velocity_min = 3.0
	_collapse_particles.initial_velocity_max = 7.5
	_collapse_particles.gravity = Vector3(0.0, -12.0, 0.0)
	_collapse_particles.scale_amount_min = 0.35
	_collapse_particles.scale_amount_max = 0.9

	var colors := Gradient.new()
	colors.set_color(0, Color(0.85, 0.96, 1.0, 0.95))
	colors.set_color(1, Color(0.62, 0.44, 0.28, 0.0))
	_collapse_particles.color_ramp = colors

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.28, 0.22, 0.28)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	_collapse_particles.mesh = mesh
	_collapse_particles.position = Vector3(-31.2, 0.3, 0.0)
	parent.add_child(_collapse_particles)


func _create_barrier_prompt_sensor(parent: Node3D) -> void:
	var sensor := Area3D.new()
	sensor.name = "CollapsedExitSensor"
	sensor.collision_layer = 0
	sensor.collision_mask = CombatLayers.PLAYER_BODY
	sensor.monitorable = false
	sensor.position = Vector3(COLLAPSE_BARRIER_X + 1.35, 1.0, 0.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 2.5, 6.0)
	shape.shape = box
	sensor.add_child(shape)
	sensor.body_entered.connect(_on_barrier_sensor_entered)
	parent.add_child(sensor)


func _on_barrier_sensor_entered(body: Node3D) -> void:
	if not _exit_is_locked or _prompt_cooldown > 0.0:
		return
	if body is Player and not (body as Player).dead:
		_prompt_cooldown = PROMPT_COOLDOWN_SECONDS
		exit_blocked_attempted.emit()


func _set_exit_locked(locked: bool) -> void:
	if is_instance_valid(_left_trigger):
		_left_trigger.enabled = not locked
		_left_trigger.monitoring = not locked
	if is_instance_valid(_left_trigger_shape):
		_left_trigger_shape.disabled = locked
	if is_instance_valid(_collapse_barrier_shape):
		_collapse_barrier_shape.disabled = not locked


func _trigger_bridge_collapse() -> void:
	_play_bridge_collapse_sequence.call_deferred()


func _play_bridge_collapse_sequence() -> void:
	var manager := get_node_or_null("/root/GameManager")
	if manager != null and bool(manager.get("_transition_pending")):
		await manager.scene_transition_finished
	elif is_inside_tree():
		await get_tree().create_timer(COLLAPSE_DELAY_SECONDS).timeout
	if not is_inside_tree() or not _exit_is_locked:
		return
	if is_instance_valid(_collapsed_rubble):
		_collapsed_rubble.visible = true
	if is_instance_valid(_collapse_particles):
		_collapse_particles.restart()
		_collapse_particles.emitting = true
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_sfx_3d(COLLAPSE_SOUND, Vector3(-29.0, 0.5, 0.0), -6.0, 0.72)
	var shake := get_node_or_null("/root/ScreenShakeController")
	if shake != null:
		shake.request(8.5, 0.3)
	_animate_bridge_spans(COLLAPSED_DEPTH_Y, 0.58, -0.52, COLLAPSE_DURATION_SECONDS, true)
	exit_locked.emit()


func _on_boss_fight_finished() -> void:
	_exit_is_locked = false
	_set_exit_locked(false)
	if is_instance_valid(_collapsed_rubble):
		_collapsed_rubble.visible = false
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_sfx_3d(RESTORE_SOUND, Vector3(-29.0, 0.5, 0.0), -6.0, 0.9)
	_animate_bridge_spans(BRIDGE_REST_Y, 0.0, 0.0, RESTORE_DURATION_SECONDS, false)
	exit_unlocked.emit()


func _animate_bridge_spans(
	target_y: float, right_rot_z: float, left_rot_z: float, duration: float, falling: bool
) -> void:
	if _bridge_tween != null and _bridge_tween.is_valid():
		_bridge_tween.kill()
	if not is_instance_valid(_bridge_right_span) or not is_instance_valid(_bridge_left_span):
		return
	_bridge_tween = create_tween().set_parallel(true)
	var ease_mode := Tween.EASE_IN if falling else Tween.EASE_OUT
	var trans_mode := Tween.TRANS_QUAD if falling else Tween.TRANS_BACK
	(
		_bridge_tween
		. tween_property(_bridge_right_span, "position:y", target_y, duration)
		. set_trans(trans_mode)
		. set_ease(ease_mode)
	)
	(
		_bridge_tween
		. tween_property(_bridge_right_span, "rotation:z", right_rot_z, duration)
		. set_trans(trans_mode)
		. set_ease(ease_mode)
	)
	(
		_bridge_tween
		. tween_property(_bridge_left_span, "position:y", target_y, duration)
		. set_trans(trans_mode)
		. set_ease(ease_mode)
	)
	(
		_bridge_tween
		. tween_property(_bridge_left_span, "rotation:z", left_rot_z, duration)
		. set_trans(trans_mode)
		. set_ease(ease_mode)
	)
