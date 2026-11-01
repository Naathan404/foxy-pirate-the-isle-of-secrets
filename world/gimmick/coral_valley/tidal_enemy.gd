class_name TidalEnemy
extends Node
## Add as a direct child of an EnemyBase and assign the level's TideController.
## The enemy root is its feet position. High ground remains active at every tide.
const Placement = preload("res://world/gimmick/coral_valley/tidal_placement.gd")

@export var tide_controller: TideController
## Water must reach this far above the feet before the enemy hides.
@export_range(0.0, 5.0, 0.01, "suffix:m") var submerge_depth: float = 0.15
## Prevent flickering when feet and water are almost at the same height.
@export_range(0.0, 0.5, 0.01, "suffix:m") var hysteresis: float = 0.05

@export_group("Appearance")
@export_range(0.0, 3.0, 0.05, "suffix:s") var emerge_duration: float = 0.7
@export_range(0.0, 3.0, 0.05, "suffix:m") var emerge_depth: float = 0.8
## Spawners enable this; enemies already on dry land can start normally.
@export var animate_initial_spawn: bool = false
@export_range(0.0, 3.0, 0.05, "suffix:s") var sink_duration: float = 0.45

@export_group("Safe Return")
@export_flags_3d_physics var ground_collision_mask: int = CombatLayers.WORLD
@export_range(0.0, 0.2, 0.01, "suffix:m") var ground_clearance: float = 0.03
@export_range(0.0, 10.0, 0.1, "suffix:m") var recovery_radius: float = 4.0
@export_range(0.1, 2.0, 0.05, "suffix:s") var recovery_interval: float = 0.35
@export_range(0.0, 10.0, 0.1, "suffix:m") var reveal_player_distance: float = 1.5
## Optional fallback anchors, configured automatically by TidalSpawner.
@export var recovery_points: Array[Marker3D] = []
@export_range(0.2, 5.0, 0.1, "suffix:s") var stuck_turn_delay: float = 0.8

var _enemy: EnemyBase
var _initialized: bool = false
var _emerging: bool = false
var _sinking: bool = false
var _forced_sink: bool = false
var _sink_elapsed: float = 0.0
var _emerge_elapsed: float = 0.0
var _home_position: Vector3
var _position_valid: bool = false
var _recovery_remaining: float = 0.0
var _last_active_position: Vector3
var _resting_position: Vector3
var _stuck_elapsed: float = 0.0
var _visual_position: Vector3
var _sprite_color: Color
var _sprite_alpha_cut: int = 0
var _effect: Node3D
var _rings: Array[MeshInstance3D] = []
var _droplets: Array[MeshInstance3D] = []
var _effect_material: StandardMaterial3D


func _ready() -> void:
	# Explicit PAUSABLE overrides the disabled enemy parent, but respects game pause.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = -100
	set_physics_process(false)
	# Child _ready runs before EnemyBase has initialized its combat and FSM.
	_initialize.call_deferred()


func _initialize() -> void:
	if _initialized:
		return
	_enemy = get_parent() as EnemyBase
	if not is_instance_valid(_enemy):
		push_warning("TidalEnemy: add this component directly under an EnemyBase.")
		return
	if not is_instance_valid(tide_controller) or not is_instance_valid(tide_controller.water):
		push_warning("TidalEnemy: assign a TideController with a Water node.")
		return
	if _enemy.fsm == null or _enemy.initial_state == null or _enemy.hurtbox == null:
		push_warning("TidalEnemy: enemy components must be initialized first.")
		return
	_initialized = true
	_home_position = _enemy.global_position
	_last_active_position = _home_position
	_enemy.add_to_group(&"tidal_enemies")
	if animate_initial_spawn:
		_enemy.set_submerged(true)
	_update_submersion()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_enemy) or _enemy.dead:
		_cancel_emergence()
		set_physics_process(false)
		return
	if not is_instance_valid(tide_controller) or not is_instance_valid(tide_controller.water):
		# A removed water controller must not leave a living enemy suspended forever.
		_cancel_emergence()
		_enemy.set_submerged(false)
		set_physics_process(false)
		return
	_recovery_remaining = maxf(0.0, _recovery_remaining - delta)
	_update_submersion()
	if _emerging:
		_update_emergence(delta)
	elif _sinking:
		_update_sinking(delta)
	elif not _enemy.submerged:
		_update_stuck_turn(delta)


func _update_submersion() -> void:
	if _enemy.dead:
		return
	var depth := tide_controller.get_depth_at(_enemy.global_position)
	if _emerging:
		if depth > submerge_depth:
			_sinking = true
			_forced_sink = false
			_emerging = false
			_sink_elapsed = (1.0 - clampf(_emerge_elapsed / maxf(0.001, emerge_duration), 0.0, 1.0)) * sink_duration
		return
	if _sinking:
		if not _forced_sink and depth <= submerge_depth - hysteresis:
			_emerging = true
			_sinking = false
			_emerge_elapsed = (1.0 - clampf(_sink_elapsed / maxf(0.001, sink_duration), 0.0, 1.0)) * emerge_duration
		return
	if _enemy.submerged:
		if _enemy.global_position != _resting_position:
			_recovery_remaining = 0.0
		if _recovery_remaining <= 0.0:
			_position_valid = _recover_hidden_position()
			_resting_position = _enemy.global_position
			_recovery_remaining = recovery_interval
		depth = tide_controller.get_depth_at(_enemy.global_position)
		if _position_valid and depth <= submerge_depth - hysteresis:
			_begin_emergence()
	elif depth > submerge_depth:
		_begin_sinking()


func _recover_hidden_position() -> bool:
	# Try the same seabed first; only relocate if it is genuinely unsafe.
	var origins: Array[Vector3] = [_enemy.global_position]
	for ring in range(1, 4):
		for index in range(8):
			var angle := TAU * float(index) / 8.0
			origins.append(_enemy.global_position + Vector3(cos(angle), 0, sin(angle)) * recovery_radius * float(ring) / 3.0)
	origins.append(_home_position)
	for point: Marker3D in recovery_points:
		if is_instance_valid(point):
			origins.append(point.global_position)
	for origin: Vector3 in origins:
		var ground = Placement.find_floor(_enemy, origin, ground_collision_mask, 2.0, 128.0, ground_clearance)
		if not ground is Vector3:
			continue
		# Do not turn a newly placed obstacle into a stair up onto its roof.
		if ground.y > origin.y + 0.4:
			continue
		if not Placement.can_stand(_enemy, _enemy, ground, ground_collision_mask,
				ground_clearance, reveal_player_distance):
			continue
		_enemy.global_position = ground
		_resting_position = ground
		_enemy.velocity = Vector3.ZERO
		_enemy.reset_physics_interpolation()
		return true
	return false


func _choose_exit_direction() -> bool:
	var forward := _enemy.last_facing_direction
	var distance := maxf(0.8, Placement.body_radius(_enemy))
	for angle: float in [0.0, PI / 4.0, -PI / 4.0, PI / 2.0, -PI / 2.0, 3.0 * PI / 4.0, -3.0 * PI / 4.0, PI]:
		var direction := forward.rotated(Vector3.UP, angle)
		if Placement.can_step(_enemy, _enemy, _enemy.global_position + direction * distance,
				ground_collision_mask, ground_clearance):
			_enemy.face_direction(direction)
			return true
	return false


func _update_stuck_turn(delta: float) -> void:
	var moved := Placement.horizontal_distance(_enemy.global_position, _last_active_position)
	_last_active_position = _enemy.global_position
	var state := _enemy.fsm.current_state
	if not _enemy.is_on_floor() or _enemy.move_direction.is_zero_approx() or moved > maxf(0.0005, delta * 0.05) or (is_instance_valid(state) and state.name in [&"Hit", &"Death"]):
		_stuck_elapsed = 0.0
		return
	_stuck_elapsed += delta
	if _stuck_elapsed >= stuck_turn_delay:
		_stuck_elapsed = 0.0
		if _choose_exit_direction():
			_enemy.velocity = Vector3.ZERO
			_enemy.request_state(_enemy.initial_state.name, 40)


func _begin_emergence() -> void:
	if emerge_duration <= 0.0 or not is_instance_valid(_enemy.visual):
		_choose_exit_direction()
		_enemy.set_submerged(false)
		return
	_emerging = true
	_emerge_elapsed = 0.0
	_capture_visual()
	_enemy.play_directional_animation(&"idle", true)
	# Only the visual rises. The body stays at the seabed with combat/AI disabled.
	_enemy.show()
	_create_emergence_effect()
	_update_emergence(0.0)


func _capture_visual() -> void:
	_visual_position = _enemy.visual.position
	if is_instance_valid(_enemy.visual.sprite):
		_sprite_color = _enemy.visual.sprite.modulate
		_sprite_alpha_cut = _enemy.visual.sprite.alpha_cut
		_enemy.visual.sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED


func _update_emergence(delta: float) -> void:
	_emerge_elapsed += maxf(0.0, delta)
	var progress := clampf(_emerge_elapsed / maxf(0.001, emerge_duration), 0.0, 1.0)
	_apply_transition(progress)
	if progress >= 1.0:
		# A crate/player may have moved into this spot during the visual effect.
		if not Placement.can_stand(_enemy, _enemy, _enemy.global_position,
				ground_collision_mask, ground_clearance, reveal_player_distance):
			_emerging = false
			_sinking = true
			_forced_sink = true
			_sink_elapsed = 0.0
			_position_valid = false
			_recovery_remaining = recovery_interval
			return
		_restore_emergence_visual()
		_choose_exit_direction()
		_last_active_position = _enemy.global_position
		_stuck_elapsed = 0.0
		_enemy.set_submerged(false)


func _begin_sinking() -> void:
	_enemy.set_submerged(true)
	_position_valid = false
	_recovery_remaining = 0.0
	if sink_duration <= 0.0 or not is_instance_valid(_enemy.visual):
		return
	_sinking = true
	_forced_sink = false
	_sink_elapsed = 0.0
	_capture_visual()
	_enemy.show()
	_create_emergence_effect()
	_apply_transition(1.0)


func _update_sinking(delta: float) -> void:
	_sink_elapsed += maxf(0.0, delta)
	var progress := clampf(_sink_elapsed / maxf(0.001, sink_duration), 0.0, 1.0)
	_apply_transition(1.0 - progress)
	if progress >= 1.0:
		_restore_emergence_visual()
		_enemy.hide()
		_recovery_remaining = 0.0


func _apply_transition(progress: float) -> void:
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	_enemy.visual.position = _visual_position + Vector3.DOWN * emerge_depth * (1.0 - eased)
	if is_instance_valid(_enemy.visual.sprite):
		var color := _sprite_color
		color.a *= smoothstep(0.0, 0.65, progress)
		_enemy.visual.sprite.modulate = color
	for index in range(_rings.size()):
		var radius := 0.15 + progress * (1.1 + index * 0.45)
		_rings[index].scale = Vector3(radius, 0.06, radius)
	for index in range(_droplets.size()):
		var angle := TAU * float(index) / float(_droplets.size())
		var distance := 0.2 + progress * 0.9
		_droplets[index].position = Vector3(cos(angle) * distance,
			0.05 + sin(progress * PI) * (0.35 + (index % 3) * 0.12), sin(angle) * distance)
	_effect_material.albedo_color.a = sin(progress * PI) * 0.7


func _cancel_emergence() -> void:
	if not _emerging and not _sinking:
		return
	_restore_emergence_visual()
	if is_instance_valid(_enemy) and _enemy.submerged:
		_enemy.hide()


func _restore_emergence_visual() -> void:
	_emerging = false
	_sinking = false
	_forced_sink = false
	if is_instance_valid(_enemy) and is_instance_valid(_enemy.visual):
		_enemy.visual.position = _visual_position
		if is_instance_valid(_enemy.visual.sprite):
			_enemy.visual.sprite.modulate = _sprite_color
			_enemy.visual.sprite.alpha_cut = _sprite_alpha_cut
	if is_instance_valid(_effect):
		_effect.queue_free()
	_effect = null
	_rings.clear()
	_droplets.clear()


func _create_emergence_effect() -> void:
	_effect = Node3D.new()
	_effect.name = &"TidalEmergenceEffect"
	_enemy.add_child(_effect)
	_effect.position.y = 0.04
	_effect_material = StandardMaterial3D.new()
	_effect_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_effect_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_effect_material.albedo_color = Color(0.65, 0.9, 0.95, 0.7)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.75
	ring_mesh.outer_radius = 1.0
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 8
	for index in range(2):
		var ring := MeshInstance3D.new()
		ring.mesh = ring_mesh
		ring.material_override = _effect_material
		_effect.add_child(ring)
		_rings.append(ring)
	var droplet_mesh := SphereMesh.new()
	droplet_mesh.radius = 0.045
	droplet_mesh.height = 0.09
	droplet_mesh.radial_segments = 8
	droplet_mesh.rings = 4
	for index in range(8):
		var droplet := MeshInstance3D.new()
		droplet.mesh = droplet_mesh
		droplet.material_override = _effect_material
		_effect.add_child(droplet)
		_droplets.append(droplet)
