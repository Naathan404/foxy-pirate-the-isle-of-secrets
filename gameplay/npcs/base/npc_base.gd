class_name BaseNpc
extends CharacterBody3D

## Shared foundation for friendly, non-combat characters. Child scenes supply
## their sprite, animation library and any optional FSM states such as Wander.

signal interaction_requested(interactor: Player)
signal dialogue_started(interactor: Player)
signal dialogue_finished(interactor: Player)

enum InitialFacing {
	DOWN,
	UP,
	LEFT,
	RIGHT,
}

@export_group("Initial State")
@export var initial_facing: InitialFacing = InitialFacing.DOWN
@export var initial_state_name: StringName = &"Idle"

@export_group("Dialogue Presentation")
@export var dialogue_camera_enabled := true
@export_range(0.0, 1.0, 0.01) var dialogue_camera_focus_ratio := 0.82
@export_range(0.5, 1.0, 0.01) var dialogue_camera_fov_scale := 0.84
@export_range(0.05, 2.0, 0.01, "suffix:s") var dialogue_camera_transition_duration := 0.5

var last_facing_direction: Vector3 = Vector3.BACK
var is_talking := false
var _conversation_player: Player
var _conversation_player_was_blocked := false
var _initial_world_position := Vector3.ZERO
var _dialogue_camera: Camera3D
var _dialogue_camera_initial_position := Vector3.ZERO
var _dialogue_camera_initial_fov := 0.0
var _dialogue_camera_tween: Tween

@onready var visual: NpcVisual = $Visual
@onready var direction_pivot: Node3D = $Direction
@onready var front_ray: RayCast3D = $Direction/FrontRayCast3D
@onready var ground_ray: RayCast3D = $Direction/GroundRayCast3D
@onready var fsm: Fsm = $FSM
@onready var interaction_area: NpcInteractionArea = $InteractionArea
@onready var initial_state: FsmState = (
	get_node_or_null(NodePath("States/" + String(initial_state_name))) as FsmState
)


func _ready() -> void:
	if get_npc_data() == null or not is_instance_valid(initial_state) or not is_instance_valid(fsm):
		push_error("BaseNpc: missing data, FSM or initial state on %s" % name)
		set_physics_process(false)
		return
	_initial_world_position = global_position
	interaction_area.interaction_requested.connect(_on_interaction_requested)
	face_direction(_get_initial_facing_direction())
	if not fsm.setup(self, initial_state.get_parent(), initial_state):
		set_physics_process(false)


func _exit_tree() -> void:
	_restore_dialogue_camera(true)


func _physics_process(delta: float) -> void:
	if get_node("/root/HitstopController").is_frozen(self):
		return
	fsm._update(delta)
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()


func move_in_direction(direction: Vector3, delta: float, speed_scale: float = 1.0) -> void:
	var npc_data := get_npc_data()
	if npc_data == null:
		return
	var horizontal := Vector3(direction.x, 0.0, direction.z)
	if not horizontal.is_zero_approx():
		horizontal = horizontal.normalized()
		face_direction(horizontal)
	var target_velocity: Vector3 = horizontal * npc_data.move_speed * maxf(0.0, speed_scale)
	var rate: float = (
		npc_data.acceleration if not horizontal.is_zero_approx() else npc_data.deceleration
	)
	var current_velocity := Vector3(velocity.x, 0.0, velocity.z)
	current_velocity = current_velocity.move_toward(target_velocity, rate * maxf(0.0, delta))
	_set_horizontal_velocity(current_velocity)


func move_forward(delta: float, speed_scale: float = 1.0) -> void:
	move_in_direction(last_facing_direction, delta, speed_scale)


func stop_movement(delta: float = 0.0) -> void:
	move_in_direction(Vector3.ZERO, delta)


func face_direction(direction: Vector3) -> void:
	var horizontal := Vector3(direction.x, 0.0, direction.z)
	if horizontal.is_zero_approx():
		return
	last_facing_direction = horizontal.normalized()
	visual.set_facing(last_facing_direction)
	direction_pivot.look_at(
		direction_pivot.global_position + last_facing_direction, Vector3.UP, true
	)


func face_target(target: Node3D) -> void:
	if is_instance_valid(target):
		face_direction(target.global_position - global_position)


func turn_around() -> void:
	face_direction(-last_facing_direction)


func play_directional_animation(action: StringName, restart: bool = false) -> bool:
	return visual.play_directional(action, last_facing_direction, restart)


func is_front_blocked() -> bool:
	return front_ray.enabled and front_ray.is_colliding()


func is_ground_ahead() -> bool:
	return not ground_ray.enabled or ground_ray.is_colliding()


func can_be_picked_up() -> bool:
	# Pickup/carry is intentionally opt-in in a future specialized NPC. The
	# current Player has no carry controller, so a base NPC must not pretend it
	# can be picked up.
	return false


func get_npc_data() -> NpcData:
	return null


func get_initial_world_position() -> Vector3:
	return _initial_world_position


func _focus_dialogue_camera(interactor: Player) -> void:
	if not dialogue_camera_enabled:
		return
	var active_camera := interactor.camera
	if not is_instance_valid(active_camera):
		active_camera = get_viewport().get_camera_3d()
	if not is_instance_valid(active_camera):
		return

	_stop_dialogue_camera_tween()
	_dialogue_camera = active_camera
	_dialogue_camera_initial_position = active_camera.global_position
	_dialogue_camera_initial_fov = active_camera.fov

	var player_to_npc := global_position - interactor.global_position
	player_to_npc.y = 0.0
	var target_position := (
		_dialogue_camera_initial_position + player_to_npc * dialogue_camera_focus_ratio
	)
	var target_fov := _dialogue_camera_initial_fov * dialogue_camera_fov_scale
	_dialogue_camera_tween = create_tween().set_parallel()
	_dialogue_camera_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dialogue_camera_tween.tween_property(
		_dialogue_camera, "global_position", target_position, dialogue_camera_transition_duration
	)
	_dialogue_camera_tween.tween_property(
		_dialogue_camera, "fov", target_fov, dialogue_camera_transition_duration
	)


func _restore_dialogue_camera(immediate := false) -> void:
	if not is_instance_valid(_dialogue_camera):
		_clear_dialogue_camera_state()
		return

	_stop_dialogue_camera_tween()
	if immediate:
		_dialogue_camera.global_position = _dialogue_camera_initial_position
		_dialogue_camera.fov = _dialogue_camera_initial_fov
		_clear_dialogue_camera_state()
		return

	_dialogue_camera_tween = create_tween().set_parallel()
	_dialogue_camera_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_dialogue_camera_tween.tween_property(
		_dialogue_camera,
		"global_position",
		_dialogue_camera_initial_position,
		dialogue_camera_transition_duration
	)
	_dialogue_camera_tween.tween_property(
		_dialogue_camera, "fov", _dialogue_camera_initial_fov, dialogue_camera_transition_duration
	)
	_dialogue_camera_tween.set_parallel(false)
	_dialogue_camera_tween.tween_callback(_clear_dialogue_camera_state)


func _stop_dialogue_camera_tween() -> void:
	if _dialogue_camera_tween != null and _dialogue_camera_tween.is_valid():
		_dialogue_camera_tween.kill()
	_dialogue_camera_tween = null


func _clear_dialogue_camera_state() -> void:
	_dialogue_camera = null
	_dialogue_camera_initial_position = Vector3.ZERO
	_dialogue_camera_initial_fov = 0.0
	_dialogue_camera_tween = null


func _set_horizontal_velocity(value: Vector3) -> void:
	velocity.x = value.x
	velocity.z = value.z


func _get_initial_facing_direction() -> Vector3:
	match initial_facing:
		InitialFacing.UP:
			return Vector3.FORWARD
		InitialFacing.LEFT:
			return Vector3.LEFT
		InitialFacing.RIGHT:
			return Vector3.RIGHT
		_:
			return Vector3.BACK


func _on_interaction_requested(interactor: Player) -> void:
	interaction_requested.emit(interactor)
	_start_dialogue(interactor)


func _start_dialogue(interactor: Player) -> void:
	var npc_data := get_npc_data()
	if (
		is_talking
		or npc_data == null
		or npc_data.dialogue_timeline.is_empty()
		or Dialogic.current_timeline != null
	):
		return
	if not ResourceLoader.exists(npc_data.dialogue_timeline):
		push_warning("BaseNpc: dialogue timeline not found: %s" % npc_data.dialogue_timeline)
		return

	is_talking = true
	_conversation_player = interactor
	_conversation_player_was_blocked = interactor.blocked
	interactor.blocked = true
	interactor.clear_gameplay_input()
	interaction_area.set_interaction_enabled(false)
	face_target(interactor)
	_focus_dialogue_camera(interactor)
	var talk_state := fsm.states.get("talk") as FsmState
	if is_instance_valid(talk_state):
		fsm.change_state(talk_state)
	Dialogic.timeline_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)
	Dialogic.start(npc_data.dialogue_timeline)
	dialogue_started.emit(interactor)


func _on_dialogue_ended() -> void:
	is_talking = false
	_restore_dialogue_camera()
	if is_instance_valid(_conversation_player):
		_conversation_player.blocked = _conversation_player_was_blocked
		dialogue_finished.emit(_conversation_player)
	_conversation_player = null
	interaction_area.set_interaction_enabled(true)
	var resume_state := fsm.states.get("wander") as FsmState
	if not is_instance_valid(resume_state):
		resume_state = fsm.states.get("idle") as FsmState
	if is_instance_valid(resume_state):
		fsm.change_state(resume_state)
