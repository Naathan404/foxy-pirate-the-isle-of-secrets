class_name Player
extends CharacterBody3D

signal action_rejected(action: StringName)
signal dash_finished(interrupted: bool)
signal dash_started

@export var data: PlayerData

@export var stamina: StaminaComponent
@export var hp: HealthComponent
@export var hitbox: HitBox
@export var hurtbox: HurtBox
@export var team: int = 1
@export var attack_controller: Node
@export var ammo: Node
@export var attack_animation_prefix: String = "attack_dagger"
@export var camera: Camera3D
@export var dash_action: StringName = &"dash"
@export var attack_action: StringName = &"normal_attack"
@export var secondary_attack_action: StringName = &"secondary_attack"

var move_direction: Vector3 = Vector3.ZERO
var last_facing_direction: Vector3 = Vector3.BACK
var dash_buffer_remaining: float = 0.0
var attack_requested: bool = false
var pending_attack_action: StringName = &"normal"
var dead: bool = false
var pending_hit_duration: float = 0.0
var pending_free_dash: bool = false
var pending_free_dash_direction: Vector3 = Vector3.ZERO

@onready var visual: Node3D = $Visual
@onready var fsm: Fsm = $FSM

@onready var stamina_label: Label = get_node_or_null("TestHUD/Stamina")
@onready var hp_label: Label = get_node_or_null("TestHUD/HP")


func _ready() -> void:
	if data == null:
		push_error("Player: assign a PlayerData resource in the Inspector.")
		set_physics_process(false)
		return
	pending_hit_duration = data.hit_duration
	if is_instance_valid(stamina):
		stamina.init(data.max_sp, data.stamina_regen_rate, data.stamina_regen_delay)
	if not fsm.setup(self, $PlayerStates, $PlayerStates/Idle):
		set_physics_process(false)
		return
	if is_instance_valid(hp):
		hp.hp_changed.connect(_on_hp_changed)
		hp.damaged.connect(_on_damaged)
		hp.died.connect(die)
		hp.init(data.max_hp)
	if is_instance_valid(hurtbox):
		hurtbox.actor = self
		hurtbox.team = team
	if is_instance_valid(hitbox):
		hitbox.actor = self
		hitbox.team = team
		hitbox.end_attack()
	if is_instance_valid(attack_controller) and attack_controller.has_method("setup"):
		if not attack_controller.call("setup", self, stamina, ammo):
			push_error("Player: weapon setup failed; verify data, attack scene and animations.")
	if is_instance_valid(stamina) and stamina.has_signal("stamina_changed"):
		stamina.connect("stamina_changed", _on_stamina_changed)
		_on_stamina_changed(stamina.current_sp, stamina.get_max_sp())


func _on_stamina_changed(amount: float, maximum: float) -> void:
	if is_instance_valid(stamina_label):
		stamina_label.text = "SP: " + str(int(amount)) + "/" + str(int(maximum))


func _on_hp_changed(amount: int, maximum: int) -> void:
	if is_instance_valid(hp_label):
		hp_label.text = "HP: " + str(amount) + "/" + str(maximum)


func _on_damaged(_applied_hp: int) -> void:
	if hp.is_alive():
		notify_hit()


func take_damage(amount: int) -> int:
	var damage := DamageContext.new()
	damage.amount_hp = amount
	return receive_damage(damage)


func receive_damage(damage: DamageContext) -> int:
	if dead or not is_instance_valid(hp):
		return 0
	if damage == null or damage.amount_hp <= 0:
		return 0
	if damage.source == self:
		return 0
	if is_instance_valid(damage.source) and damage.source_team == team:
		return 0
	var amount := damage.amount_hp
	if (
		is_instance_valid(attack_controller)
		and attack_controller.has_method("modify_incoming_damage")
	):
		amount = int(attack_controller.call("modify_incoming_damage", amount, damage))
	return hp.take_damage(amount)


func _physics_process(delta: float) -> void:
	dash_buffer_remaining = maxf(0.0, dash_buffer_remaining - delta)
	read_input()
	fsm._update(delta)
	if dead:
		set_horizontal_velocity(Vector3.ZERO)
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()
	attack_requested = false


func read_input() -> void:
	move_direction = Vector3.ZERO
	if dead:
		return
	var input_vector := Input.get_vector("left", "right", "up", "down")
	var right := Vector3.RIGHT
	var back := Vector3.BACK
	var active_camera := get_active_camera()
	if is_instance_valid(active_camera):
		right = active_camera.global_basis.x
		back = active_camera.global_basis.z
		right.y = 0.0
		back.y = 0.0
		right = right.normalized()
		back = back.normalized()
	move_direction = right * input_vector.x + back * input_vector.y
	if not move_direction.is_zero_approx():
		move_direction = move_direction.normalized()
	if InputMap.has_action(dash_action) and Input.is_action_just_pressed(dash_action):
		request_dash()
	if InputMap.has_action(attack_action) and Input.is_action_just_pressed(attack_action):
		request_attack()
	elif (
		InputMap.has_action(secondary_attack_action)
		and Input.is_action_just_pressed(secondary_attack_action)
	):
		request_attack(&"secondary")


func get_active_camera() -> Camera3D:
	if is_instance_valid(camera):
		return camera
	return get_viewport().get_camera_3d()


func request_dash() -> void:
	if not dead:
		dash_buffer_remaining = data.dash_buffer_duration


func request_attack(action: StringName = &"normal") -> void:
	if not dead:
		pending_attack_action = action
		attack_requested = true


func has_attack_animation(prefix: String) -> bool:
	if not visual.has_method("has_directional_animation"):
		return false
	if not visual.call("has_directional_animation", prefix):
		return false
	var animated_sprite := visual.get("anim") as AnimatedSprite3D
	if not is_instance_valid(animated_sprite) or animated_sprite.sprite_frames == null:
		return false
	var frames := animated_sprite.sprite_frames
	for suffix: String in ["down", "up", "side"]:
		var animation_name := prefix + "_" + suffix
		if (
			frames.get_animation_loop(animation_name)
			or frames.get_frame_count(animation_name) == 0
			or frames.get_animation_speed(animation_name) <= 0.0
		):
			return false
	return true


func request_free_dash(direction: Vector3) -> bool:
	if dead or not is_on_floor():
		return false
	var horizontal := Vector3(direction.x, 0, direction.z)
	if horizontal.is_zero_approx():
		return false
	if not fsm.change_state(fsm.states.get("dash") as FsmState, 10):
		return false
	pending_free_dash = true
	pending_free_dash_direction = horizontal.normalized()
	return true


func equip_attack(controller: Node, animation_prefix: String) -> bool:
	if dead or not is_instance_valid(controller):
		return false
	if is_instance_valid(fsm):
		var attack_state := fsm.states.get("attack") as FsmState
		if (
			attack_state != null
			and (fsm.current_state == attack_state or fsm.next_state == attack_state)
		):
			return false
	if (
		not controller.has_method("try_attack")
		or not controller.has_method("cancel")
		or not controller.has_signal("attack_finished")
	):
		return false
	if not has_attack_animation(animation_prefix):
		return false
	attack_controller = controller
	attack_animation_prefix = animation_prefix
	return true


func update_facing() -> void:
	if not move_direction.is_zero_approx():
		last_facing_direction = move_direction


func set_horizontal_velocity(value: Vector3) -> void:
	velocity.x = value.x
	velocity.z = value.z


func update_movement(delta: float, moving: bool) -> void:
	var target := move_direction * data.move_speed if moving else Vector3.ZERO
	var rate := data.acceleration if moving else data.deceleration
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	set_horizontal_velocity(horizontal.move_toward(target, rate * delta))


func play_animation(anim_name: String) -> void:
	if visual.has_method("play_animation"):
		visual.call("play_animation", anim_name)


func play_directional_animation(action: String, restart: bool = false) -> void:
	var facing := last_facing_direction
	var active_camera := get_active_camera()
	if is_instance_valid(active_camera):
		var right := active_camera.global_basis.x
		var back := active_camera.global_basis.z
		right.y = 0.0
		back.y = 0.0
		facing = Vector3(
			last_facing_direction.dot(right.normalized()),
			0.0,
			last_facing_direction.dot(back.normalized())
		)
	if visual.has_method("play_directional"):
		visual.call("play_directional", action, facing, restart)


func notify_hit(duration: float = -1.0) -> void:
	if dead:
		return
	pending_free_dash = false
	pending_hit_duration = data.hit_duration if duration < 0.0 else maxf(0.01, duration)
	cancel_attack()
	var hit_state := fsm.states.get("hit") as FsmState
	if fsm.current_state == hit_state:
		hit_state.timer = pending_hit_duration
	else:
		fsm.change_state(hit_state, 50)


func die() -> void:
	if dead:
		return
	dead = true
	if is_instance_valid(hurtbox):
		hurtbox.enabled = false
	pending_free_dash = false
	if is_instance_valid(stamina) and stamina.has_method("set_regeneration_enabled"):
		stamina.call("set_regeneration_enabled", false)
	dash_buffer_remaining = 0.0
	attack_requested = false
	cancel_attack()
	set_horizontal_velocity(Vector3.ZERO)
	fsm.change_state(fsm.states.get("death") as FsmState)


func cancel_attack() -> void:
	end_hitbox_attack()
	if is_instance_valid(attack_controller) and attack_controller.has_method("cancel"):
		attack_controller.call("cancel")


func begin_hitbox_attack(amount_hp: int, attack_id: int = 0, tag: StringName = &"normal") -> bool:
	if dead or not is_instance_valid(hitbox):
		return false
	return hitbox.begin_attack(amount_hp, attack_id, tag)


func end_hitbox_attack() -> void:
	if is_instance_valid(hitbox):
		hitbox.end_attack()
