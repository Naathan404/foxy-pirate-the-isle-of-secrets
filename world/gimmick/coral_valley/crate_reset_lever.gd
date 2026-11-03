class_name CrateResetLever
extends Node3D
## Resets only the assigned puzzle crates, with a dry landing point for displaced riders.

signal crates_reset
signal reset_rejected

@export var crates: Array[PushableCrate] = []
@export var safe_point: Marker3D
@export var input_action: StringName = &"interact"
@export_range(0.2, 3.0, 0.1) var cooldown_seconds: float = 0.8
@export var reset_sound: AudioStream

var _pending_player: WeakRef
var _cooldown: float = 0.0
var _returning: bool = true
var _blocked_remaining: float = 0.0

@onready var _area: Area3D = $InteractionArea
@onready var _prompt: Label3D = $Prompt
@onready var _base_body: StaticBody3D = $BaseBody
@onready var _animator: AnimationPlayer = (
	$Visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_pending_player = null


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_echo() and event.is_action_pressed(input_action):
		var player := _get_interactor()
		if player != null and request_reset(player):
			get_viewport().set_input_as_handled()


func request_reset(player: Player) -> bool:
	if _pending_player != null or _cooldown > 0.0 or player != _get_interactor():
		return false
	if player == null or crates.is_empty():
		return false
	_pending_player = weakref(player)
	return true


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_blocked_remaining = maxf(0.0, _blocked_remaining - delta)
	if not _returning and _cooldown <= cooldown_seconds * 0.5:
		_play_animation(&"toggle-off")
		_returning = true
	if _pending_player != null:
		var player := _pending_player.get_ref() as Player
		_pending_player = null
		if is_instance_valid(player) and player == _get_interactor():
			if not _perform_reset(player):
				_blocked_remaining = 0.8
				reset_rejected.emit()
	_update_prompt()


func _get_interactor() -> Player:
	if get_tree().paused:
		return null
	for body in _area.get_overlapping_bodies():
		var player := body as Player
		if player == null or player.dead or player.is_gameplay_input_blocked():
			continue
		var offset := player.global_position - global_position
		if not player.is_on_floor() or Vector2(offset.x, offset.z).length() > 3.0:
			continue
		if absf(offset.y) > 3.0:
			continue
		var allowed := true
		for state: FsmState in [player.fsm.current_state, player.fsm.next_state]:
			if state != null and state.name.to_lower() not in ["idle", "run"]:
				allowed = false
		if allowed:
			return player
	return null


func _perform_reset(player: Player) -> bool:
	var targets: Array[PushableCrate] = []
	var excluded: Array[RID] = [player.get_rid()]
	for crate in crates:
		if is_instance_valid(crate) and crate.is_inside_tree() and not targets.has(crate):
			targets.append(crate)
			excluded.append(crate.get_rid())
	if targets.is_empty():
		return false
	var relocate := _is_riding_crate(player, targets)
	var space := get_world_3d().direct_space_state
	# Check every destination before moving any body. Current puzzle boxes move as one batch.
	for crate in targets:
		var collider := crate.get_node("CollisionShape3D") as CollisionShape3D
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = collider.shape
		query.transform = crate.get_reset_transform() * collider.transform
		query.transform.origin.y += 0.02
		query.exclude = excluded
		query.collision_mask = CombatLayers.WORLD | CombatLayers.ENEMY_BODY
		if not space.intersect_shape(query, 1).is_empty():
			return false
		query.collision_mask = CombatLayers.PLAYER_BODY
		query.exclude = []
		for hit in space.intersect_shape(query, 8):
			if hit.collider != player:
				return false
			relocate = true
	if relocate:
		var destination: Variant = _get_safe_destination(player, targets, excluded)
		if not destination is Vector3:
			return false
		_relocate_player(player, destination)
	for crate in targets:
		crate.reset_to_start()
	_cooldown = cooldown_seconds
	_returning = false
	_blocked_remaining = 0.0
	_play_animation(&"toggle-on")
	get_node("/root/AudioManager").play_sfx_3d(reset_sound, global_position, -9.0)
	crates_reset.emit()
	return true


func _is_riding_crate(player: Player, targets: Array[PushableCrate]) -> bool:
	for index in player.get_slide_collision_count():
		var collision := player.get_slide_collision(index)
		var crate := collision.get_collider() as PushableCrate
		if crate != null and collision.get_normal().y > 0.5 and targets.has(crate):
			return true
	return false


func _get_safe_destination(
	player: Player, targets: Array[PushableCrate], excluded: Array[RID]
) -> Variant:
	if not is_instance_valid(safe_point):
		return null
	var marker := safe_point.global_position
	var ray := PhysicsRayQueryParameters3D.create(
		marker + Vector3.UP * 2.0, marker + Vector3.DOWN * 4.0, CombatLayers.WORLD
	)
	ray.exclude = excluded + [_base_body.get_rid()]
	var space := get_world_3d().direct_space_state
	var floor_hit := space.intersect_ray(ray)
	if floor_hit.is_empty() or floor_hit.collider is PushableCrate:
		return null
	var floor_position: Vector3 = floor_hit.position
	if absf(floor_position.y - marker.y) > 0.5:
		return null
	for crate in targets:
		var tide := crate.tide_controller
		if is_instance_valid(tide) and is_instance_valid(tide.water):
			var water := tide.water as MeshInstance3D
			if water != null and water.mesh != null:
				var point := water.to_local(floor_position)
				var bounds := water.get_aabb()
				if point.x < bounds.position.x or point.x > bounds.end.x:
					continue
				if point.z < bounds.position.z or point.z > bounds.end.z:
					continue
			if floor_position.y <= maxf(tide.high_height, tide.get_water_height()) + 0.05:
				return null
	var collider := player.get_node("CollisionShape3D") as CollisionShape3D
	var bounds: AABB = (
		Transform3D(player.global_basis, Vector3.ZERO)
		* collider.transform
		* collider.shape.get_debug_mesh().get_aabb()
	)
	var destination := Vector3(marker.x, floor_position.y - bounds.position.y + 0.02, marker.z)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = Transform3D(player.global_basis, destination) * collider.transform
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	if not space.intersect_shape(query, 1).is_empty():
		return null
	return destination


func _relocate_player(player: Player, destination: Vector3) -> void:
	player.clear_gameplay_input()
	player.velocity = Vector3.ZERO
	player.global_position = destination
	# Refresh the old platform contact so a reset box cannot fling its former rider.
	var platform_layers := player.platform_floor_layers
	player.platform_floor_layers = 0
	player.move_and_slide()
	player.platform_floor_layers = platform_layers
	player.reset_physics_interpolation()


func _play_animation(animation: StringName) -> void:
	if is_instance_valid(_animator) and _animator.has_animation(animation):
		var length := _animator.get_animation(animation).length
		_animator.speed_scale = length / maxf(0.05, cooldown_seconds * 0.5)
		_animator.play(animation)


func _update_prompt() -> void:
	_prompt.visible = _get_interactor() != null and not crates.is_empty()
	if _blocked_remaining > 0.0:
		_prompt.text = "Reset blocked"
	elif _cooldown > 0.0:
		_prompt.text = "Resetting..."
	else:
		var key := "G"
		for event in InputMap.action_get_events(input_action):
			if event is InputEventKey:
				var code: int = event.physical_keycode if event.physical_keycode else event.keycode
				key = OS.get_keycode_string(code)
				break
		_prompt.text = "[%s] Reset crates" % key
