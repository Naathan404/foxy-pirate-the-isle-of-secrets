class_name EnemyBase
extends CharacterBody3D

## Enemy-only character foundation. Player and bosses intentionally use their own roots.
##
## Required: Direction, HealthComponent, HurtBox, FSM, and an initial state.
##
## Direction owns all facing-sensitive nodes: HurtBox, optional HitBox, TargetDetector,
## ray casts, spawn markers, and attack effects. Visual stays outside Direction because
## AnimationPlayer expresses its facing through directional animation clips.
##
## Optional: HitBox, TargetDetector, RayCast3D nodes, throwable components, and skills.
##
## Layer/mask convention: EnemyBody only collides with World and PlayerBody;
## EnemyHurtBox only receives PlayerAttack; a contact HitBox only queries
## PlayerHurtBox; TargetDetector only queries PlayerBody; patrol rays query World.
## Concrete enemy scenes own their AI states and choose which optional capabilities to attach.

signal target_changed(target: Node3D)
signal damaged(applied_hp: int)
signal died

@export var data: EnemyData
@export var hp: HealthComponent
@export var hurtbox: HurtBox
@export var hitbox: HitBox
@export var target_detector: Area3D
@export var visual: EnemyVisual
@export var direction_pivot: Node3D
@export var front_ray: RayCast3D
@export var ground_ray: RayCast3D
@export var fsm: Fsm
@export var initial_state: FsmState
@export var team: int = 2
@export var target_group: StringName = &"player"
## When enabled, a dead enemy remains visible until its non-looping death animation finishes.
@export var destroy_on_death: bool = false

var target: Node3D
var move_direction: Vector3 = Vector3.ZERO
var last_facing_direction: Vector3 = Vector3.BACK
var dead: bool = false
var pending_hit_duration: float = 0.0
var pending_hit_direction: Vector3 = Vector3.ZERO


func _ready() -> void:
	if not _validate_components():
		set_physics_process(false)
		return
	_setup_stats()
	_setup_combat()
	_setup_direction_checks()
	_setup_target_detector()
	var state_parent := initial_state.get_parent()
	if not fsm.setup(self, state_parent, initial_state):
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	fsm._update(delta)
	if dead:
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()


## Shared locomotion API for patrol, chase, charge, and custom enemy states.
func move_in_direction(direction: Vector3, delta: float, speed_scale: float = 1.0) -> void:
	if dead or data == null:
		return
	move_direction = Vector3(direction.x, 0.0, direction.z)
	if not move_direction.is_zero_approx():
		move_direction = move_direction.normalized()
		face_direction(move_direction)

	var target_velocity := move_direction * data.move_speed * maxf(0.0, speed_scale)
	var change_speed := data.deceleration
	if not move_direction.is_zero_approx():
		change_speed = data.acceleration
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	horizontal_velocity = horizontal_velocity.move_toward(
		target_velocity, change_speed * maxf(delta, 0.0)
	)
	_set_horizontal_velocity(horizontal_velocity)


func move_forward(delta: float, speed_scale: float = 1.0) -> void:
	move_in_direction(last_facing_direction, delta, speed_scale)


func move_toward_target(delta: float, stop_distance: float = 0.0) -> bool:
	if not has_target():
		stop_movement(delta)
		return false
	var direction := target.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() <= stop_distance * stop_distance:
		stop_movement(delta)
		return false
	move_in_direction(direction, delta)
	return true


func stop_movement(delta: float = 0.0) -> void:
	move_in_direction(Vector3.ZERO, delta)


func _set_horizontal_velocity(value: Vector3) -> void:
	velocity.x = value.x
	velocity.z = value.z


func _damp_horizontal_velocity(delta: float, deceleration: float) -> void:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	horizontal_velocity = horizontal_velocity.move_toward(
		Vector3.ZERO, maxf(0.0, deceleration) * maxf(0.0, delta)
	)
	_set_horizontal_velocity(horizontal_velocity)


func face_direction(direction: Vector3) -> void:
	var horizontal := Vector3(direction.x, 0.0, direction.z)
	if horizontal.is_zero_approx():
		return
	last_facing_direction = horizontal.normalized()
	if is_instance_valid(visual):
		visual.set_facing(last_facing_direction)
	if is_instance_valid(direction_pivot):
		direction_pivot.look_at(
			direction_pivot.global_position + last_facing_direction, Vector3.UP, true
		)


func face_target() -> bool:
	if not has_target():
		return false
	face_direction(target.global_position - global_position)
	return true


func turn_around() -> void:
	face_direction(-last_facing_direction)


func play_directional_animation(action: StringName, restart: bool = false) -> bool:
	if not is_instance_valid(visual):
		return false
	return visual.play_directional(action, last_facing_direction, restart)


func play_animation(animation_name: StringName, restart: bool = false) -> bool:
	if not is_instance_valid(visual):
		return false
	return visual.play_animation(animation_name, restart)


## Death state calls this after it has stopped all gameplay behavior.
## A death animation must not loop, otherwise AnimationPlayer never emits animation_finished.
func _play_death_animation() -> void:
	var started := play_directional_animation(&"death", true)
	if not destroy_on_death:
		return
	if not started or not is_instance_valid(visual):
		queue_free()
		return
	visual.animation_finished.connect(_on_death_animation_finished, CONNECT_ONE_SHOT)


func has_target() -> bool:
	return is_instance_valid(target) and not dead


func _distance_to_target() -> float:
	if not has_target():
		return INF
	var direction := target.global_position - global_position
	direction.y = 0.0
	return direction.length()


func is_front_blocked() -> bool:
	return is_instance_valid(front_ray) and front_ray.enabled and front_ray.is_colliding()


func is_ground_ahead() -> bool:
	return not is_instance_valid(ground_ray) or not ground_ray.enabled or ground_ray.is_colliding()


## Optional contact attack helper. Custom states control exactly when it starts and ends.
func begin_attack(attack_id: int = 0, tag: StringName = &"contact") -> bool:
	if data == null:
		return false
	return begin_attack_with_damage(data.attack_damage, attack_id, tag)


func begin_attack_with_damage(
	amount_hp: int, attack_id: int = 0, tag: StringName = &"contact"
) -> bool:
	if dead or amount_hp <= 0 or not is_instance_valid(hitbox):
		return false
	return hitbox.begin_attack(amount_hp, attack_id, tag)


func end_attack() -> void:
	if is_instance_valid(hitbox):
		hitbox.end_attack()


func take_damage(amount: int) -> int:
	var damage := DamageContext.new()
	damage.amount_hp = amount
	return receive_damage(damage)


func receive_damage(damage: DamageContext) -> int:
	if dead or not is_instance_valid(hp):
		return 0
	if damage == null or damage.amount_hp <= 0:
		return 0
	if damage.source == self or damage.source_team == team:
		return 0
	pending_hit_direction = _get_hit_direction(damage.source)
	return hp.take_damage(damage.amount_hp)


func _notify_hit() -> void:
	if dead or data == null:
		return
	pending_hit_duration = data.hit_duration
	end_attack()
	request_state(&"hit", 50)


func die() -> void:
	if dead:
		return
	dead = true
	_set_horizontal_velocity(Vector3.ZERO)
	end_attack()
	collision_layer = 0
	collision_mask = 0
	if is_instance_valid(hurtbox):
		hurtbox.enabled = false
		hurtbox.collision_layer = 0
		hurtbox.collision_mask = 0
	if is_instance_valid(target_detector):
		target_detector.monitoring = false
	set_target(null)
	var entered_death_state := request_state(&"death", 100)
	died.emit()
	if destroy_on_death and not entered_death_state:
		queue_free()


func request_state(state_name: StringName, priority: int = 0) -> bool:
	if not is_instance_valid(fsm):
		return false
	return fsm.change_state(fsm.states.get(String(state_name).to_lower()) as FsmState, priority)


func set_target(next_target: Node3D) -> void:
	if target == next_target:
		return
	target = next_target
	target_changed.emit(target)


func _validate_components() -> bool:
	if data == null:
		push_error("EnemyBase: EnemyData must be assigned")
		return false
	if not is_instance_valid(direction_pivot):
		push_error("EnemyBase: Direction is required")
		return false
	if not is_instance_valid(hp) or not is_instance_valid(hurtbox):
		push_error("EnemyBase: HealthComponent and HurtBox are required")
		return false
	if not is_instance_valid(fsm) or not is_instance_valid(initial_state):
		push_error("EnemyBase: FSM and an initial state are required")
		return false
	if not _validate_directional_node(hurtbox, &"HurtBox"):
		return false
	if not _validate_directional_node(hitbox, &"HitBox"):
		return false
	if not _validate_directional_node(target_detector, &"TargetDetector"):
		return false
	if not _validate_directional_node(front_ray, &"FrontRayCast3D"):
		return false
	if not _validate_directional_node(ground_ray, &"GroundRayCast3D"):
		return false
	return true


func _validate_directional_node(node: Node, component_name: StringName) -> bool:
	if node == null:
		return true
	if direction_pivot.is_ancestor_of(node):
		return true
	push_error("EnemyBase: %s must be a child of Direction so it rotates with facing" % component_name)
	return false


func _setup_stats() -> void:
	hp.damaged.connect(_on_damaged)
	hp.died.connect(die)
	hp.init(data.max_hp)


func _setup_combat() -> void:
	hurtbox.actor = self
	hurtbox.team = team
	hurtbox.collision_layer = CombatLayers.ENEMY_HURTBOX
	hurtbox.collision_mask = CombatLayers.PLAYER_ATTACK
	if is_instance_valid(hitbox):
		hitbox.actor = self
		hitbox.team = team
		hitbox.collision_layer = CombatLayers.ENEMY_ATTACK
		hitbox.collision_mask = CombatLayers.PLAYER_HURTBOX


func _setup_target_detector() -> void:
	if not is_instance_valid(target_detector):
		return
	target_detector.collision_layer = CombatLayers.TARGET_DETECTOR
	target_detector.collision_mask = CombatLayers.PLAYER_BODY
	target_detector.body_entered.connect(_on_target_body_entered)
	target_detector.body_exited.connect(_on_target_body_exited)
	_refresh_target()


func _setup_direction_checks() -> void:
	for ray: RayCast3D in [front_ray, ground_ray]:
		if is_instance_valid(ray):
			ray.collision_mask = CombatLayers.WORLD


func _refresh_target() -> void:
	if not is_instance_valid(target_detector):
		return
	var nearest_target: Node3D = null
	var nearest_distance := INF
	for body: Node3D in target_detector.get_overlapping_bodies():
		if not _is_target_candidate(body):
			continue
		var distance := global_position.distance_squared_to(body.global_position)
		if distance < nearest_distance:
			nearest_target = body
			nearest_distance = distance
	set_target(nearest_target)


func _is_target_candidate(candidate: Node3D) -> bool:
	return candidate != self and candidate.is_in_group(target_group)


func _on_target_body_entered(body: Node3D) -> void:
	if _is_target_candidate(body):
		_refresh_target()


func _on_target_body_exited(body: Node3D) -> void:
	if body == target:
		_refresh_target()


func _on_damaged(applied_hp: int) -> void:
	damaged.emit(applied_hp)
	if hp.is_alive():
		_notify_hit()


func _on_death_animation_finished(_animation_name: StringName) -> void:
	if dead and destroy_on_death:
		queue_free()


func _get_hit_direction(source: Node) -> Vector3:
	if not source is Node3D:
		return Vector3.ZERO
	var direction := global_position - (source as Node3D).global_position
	direction.y = 0.0
	if direction.is_zero_approx():
		return -last_facing_direction
	return direction.normalized()
