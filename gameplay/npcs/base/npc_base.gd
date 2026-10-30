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

@export var data: NpcData
@export var initial_facing: InitialFacing = InitialFacing.DOWN
@export var initial_state_name: StringName = &"Idle"

@export_group("Wander Bounds")
@export_range(0.0, 100.0, 0.1, "suffix:m") var wander_radius: float = 3.0

var last_facing_direction: Vector3 = Vector3.BACK
var is_talking := false
var _conversation_player: Player
var _conversation_player_was_blocked := false
var _wander_origin := Vector3.ZERO

@onready var visual: NpcVisual = $Visual
@onready var direction_pivot: Node3D = $Direction
@onready var front_ray: RayCast3D = $Direction/FrontRayCast3D
@onready var ground_ray: RayCast3D = $Direction/GroundRayCast3D
@onready var fsm: Fsm = $FSM
@onready var interaction_area: NpcInteractionArea = $InteractionArea
@onready var initial_state: FsmState = get_node_or_null(
	NodePath("States/" + String(initial_state_name))
) as FsmState


func _ready() -> void:
	if data == null or not is_instance_valid(initial_state) or not is_instance_valid(fsm):
		push_error("BaseNpc: missing data, FSM or initial state on %s" % name)
		set_physics_process(false)
		return
	_wander_origin = global_position
	interaction_area.interaction_requested.connect(_on_interaction_requested)
	face_direction(_get_initial_facing_direction())
	if not fsm.setup(self, initial_state.get_parent(), initial_state):
		set_physics_process(false)


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
	var horizontal := Vector3(direction.x, 0.0, direction.z)
	if not horizontal.is_zero_approx():
		horizontal = horizontal.normalized()
		face_direction(horizontal)
	var target_velocity: Vector3 = horizontal * data.move_speed * maxf(0.0, speed_scale)
	var rate: float = data.acceleration if not horizontal.is_zero_approx() else data.deceleration
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
	return data


func has_wander_bounds() -> bool:
	return wander_radius > 0.0


func get_wander_origin() -> Vector3:
	return _wander_origin


func get_wander_radius() -> float:
	return wander_radius


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
	if is_talking or data.dialogue_timeline.is_empty() or Dialogic.current_timeline != null:
		return
	if not ResourceLoader.exists(data.dialogue_timeline):
		push_warning("BaseNpc: dialogue timeline not found: %s" % data.dialogue_timeline)
		return

	is_talking = true
	_conversation_player = interactor
	_conversation_player_was_blocked = interactor.blocked
	interactor.blocked = true
	interactor.clear_gameplay_input()
	interaction_area.set_interaction_enabled(false)
	face_target(interactor)
	var talk_state := fsm.states.get("talk") as FsmState
	if is_instance_valid(talk_state):
		fsm.change_state(talk_state)
	Dialogic.timeline_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)
	Dialogic.start(data.dialogue_timeline)
	dialogue_started.emit(interactor)


func _on_dialogue_ended() -> void:
	is_talking = false
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
