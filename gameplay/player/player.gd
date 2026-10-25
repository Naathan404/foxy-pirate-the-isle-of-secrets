class_name Player
extends CharacterBody3D

signal action_rejected(action: StringName)
signal dash_finished(interrupted: bool)
signal dash_started

const Teams := preload("res://gameplay/combat/combat_teams.gd")

@export var data: PlayerData

@export var stamina: StaminaComponent
@export var hp: HealthComponent
@export var hurtbox: HurtBox
@export_enum("None:0", "Player:1", "Enemy:2") var team: int = Teams.PLAYER
@export var weapon_controller: WeaponController
@export var ammo: AmmoComponent
@export var charm_socket_manager: CharmSocketManager
@export var attack_animation_prefix: String = "attack_dagger"
@export var camera: Camera3D
@export var dash_action: StringName = &"dash"
@export var attack_action: StringName = &"normal_attack"
@export var secondary_attack_action: StringName = &"secondary_attack"

var move_direction: Vector3 = Vector3.ZERO
# Đứng yên vẫn nhớ hướng để đánh và dash
var last_facing_direction: Vector3 = Vector3.BACK
# nuffer nút dash
var dash_buffer_remaining: float = 0.0
var attack_requested: bool = false
var pending_attack_action: StringName = &"normal"
var dead: bool = false
var pending_hit_duration: float = 0.0
var pending_hit_direction: Vector3 = Vector3.ZERO
var pending_free_dash: bool = false
var pending_free_dash_direction: Vector3 = Vector3.ZERO
var _charm_grapple_tween: Tween

@onready var visual: PlayerVisual = $Visual
@onready var fsm: Fsm = $FSM
@onready var charm_registry: CharmRegistry = get_node_or_null("CharmSocketManager/CharmRegistry")

@onready var stamina_label: Label = get_node_or_null("TestHUD/SP")
@onready var hp_label: Label = get_node_or_null("TestHUD/HP")


func _ready() -> void:
	if data == null:
		push_error("Player: playerdata chưa được gán")
		set_physics_process(false)
		return
	if not fsm.setup(self, $States, $States/Idle):
		set_physics_process(false)
		return

	pending_hit_duration = data.hit_duration
	_setup_stats()
	_setup_combat()
	_setup_charm_system()


# Khởi tạo HP, SP và nối signal để cập nhật HUD
func _setup_stats() -> void:
	if is_instance_valid(hp):
		hp.hp_changed.connect(_on_hp_changed)
		hp.damaged.connect(_on_damaged)
		hp.died.connect(die)
		hp.init(data.max_hp)

	if is_instance_valid(stamina):
		stamina.stamina_changed.connect(_on_stamina_changed)
		stamina.init(data.max_sp, data.stamina_regen_rate, data.stamina_regen_delay)


# HitBox gây damage, HurtBox nhận damage
func _setup_combat() -> void:
	if is_instance_valid(hurtbox):
		hurtbox.actor = self
		hurtbox.team = team
		hurtbox.collision_layer = CombatLayers.PLAYER_HURTBOX
		hurtbox.collision_mask = CombatLayers.ENEMY_ATTACK
	if is_instance_valid(weapon_controller) and weapon_controller.has_method("setup"):
		weapon_controller.team = team
	if not weapon_controller.call("setup", self, stamina, ammo):
		push_error("Player: set up vũ khí bị fail")


func _setup_charm_system() -> void:
	if not is_instance_valid(charm_socket_manager):
		return
	if not is_instance_valid(charm_registry):
		push_error("Player: CharmRegistry chưa được gắn dưới CharmSocketManager")
		return
	charm_socket_manager.actor = self


func _on_stamina_changed(amount: float, maximum: float) -> void:
	if is_instance_valid(stamina_label):
		stamina_label.text = "SP: " + str(int(amount)) + "/" + str(int(maximum))


func _on_hp_changed(amount: int, maximum: int) -> void:
	if is_instance_valid(hp_label):
		hp_label.text = "HP: " + str(amount) + "/" + str(maximum)


func _on_damaged(_applied_hp: int) -> void:
	# Đòn chí mạng để state Death xử lý, không vào Hit nữa
	if hp.is_alive():
		notify_hit()


# Dùng cho damage trực tiếp, ví dụ bẫy hoặc nút test
func take_damage(amount: int) -> int:
	var damage := DamageContext.new()
	damage.amount_hp = amount
	return receive_damage(damage)


# Đòn từ HurtBox đi qua phòng thủ trước rồi mới trừ HP
func receive_damage(damage: DamageContext) -> int:
	if dead or not is_instance_valid(hp):
		return 0
	if damage == null or damage.amount_hp <= 0:
		return 0
	if damage.source == self:
		return 0
	if is_instance_valid(damage.source) and damage.source_team == team:
		return 0
	pending_hit_direction = _get_hit_direction(damage.source)
	var amount := damage.amount_hp
	if is_instance_valid(weapon_controller):
		if weapon_controller.has_method("modify_incoming_damage"):
			amount = int(weapon_controller.call("modify_incoming_damage", amount, damage))
	if is_instance_valid(charm_socket_manager):
		amount = charm_socket_manager.modify_incoming_damage(amount, damage)
	var applied_hp := hp.take_damage(amount)
	if applied_hp > 0 and is_instance_valid(charm_socket_manager):
		charm_socket_manager.dispatch_event(&"damage_received", [damage, applied_hp])
	return applied_hp


func _physics_process(delta: float) -> void:
	dash_buffer_remaining = maxf(0.0, dash_buffer_remaining - delta)
	_read_input()
	fsm._update(delta)

	### test
	if Input.is_action_just_pressed("test_hit"):
		take_damage(1)

	# State chọn vận tốc, Player chỉ di chuyển vật lý 1 lần mỗi frame
	if dead:
		set_horizontal_velocity(Vector3.ZERO)
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()
	# Yêu cầu đánh chỉ dùng trong frame này
	attack_requested = false


func _read_input() -> void:
	move_direction = Vector3.ZERO
	if dead:
		return
	var input_vector := Input.get_vector("left", "right", "up", "down")
	# Đổi WASD sang hướng trong thế giới theo góc camera
	var right := Vector3.RIGHT
	var back := Vector3.BACK
	var active_camera := _get_active_camera()
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


func _get_active_camera() -> Camera3D:
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


# Tạo context cho đòn đánh, hướng ngắm do controller quyết định
func build_attack_context() -> AttackContext:
	var context := AttackContext.new()
	context.actor = self
	context.team = team
	context.action = pending_attack_action
	context.origin = global_position
	context.direction = Vector3(last_facing_direction.x, 0.0, last_facing_direction.z)
	if context.direction.is_zero_approx():
		context.direction = Vector3.BACK
	context.direction = context.direction.normalized()

	var mouse_target: Variant = _get_mouse_target()
	if mouse_target is Vector3:
		context.target_position = mouse_target
		context.has_target = true
	return context


# Chiếu chuột xuống mặt phẳng XZ ngang nhân vật
func _get_mouse_target() -> Variant:
	var active_camera := _get_active_camera()
	if not is_instance_valid(active_camera):
		return null

	var mouse_position := get_viewport().get_mouse_position()
	var ray_start := active_camera.project_ray_origin(mouse_position)
	var ray_direction := active_camera.project_ray_normal(mouse_position)
	var ground_plane := Plane(Vector3.UP, global_position.y)
	return ground_plane.intersects_ray(ray_start, ray_direction)


# Không đổi vũ khí khi đang đánh, dash, bị hit hoặc chết
func can_equip_weapon() -> bool:
	if dead or not is_instance_valid(fsm):
		return false
	# Kiểm tra cả state hiện tại và state đang chờ, ví dụ vừa bị hit
	var allowed_states := ["idle", "run", "fall"]
	for state: FsmState in [fsm.current_state, fsm.next_state]:
		if state == null:
			continue
		if state.name.to_lower() not in allowed_states:
			return false
	return true


# Cho phép state Attack gọi controller, nhưng không đánh khi rơi hoặc bị ngắt
func can_start_weapon_attack() -> bool:
	if dead or not is_on_floor() or not is_instance_valid(fsm):
		return false
	var allowed_states := ["idle", "run", "attack"]
	for state: FsmState in [fsm.current_state, fsm.next_state]:
		if state == null:
			continue
		if state.name.to_lower() not in allowed_states:
			return false
	return true


func has_attack_animation(prefix: String) -> bool:
	if not is_instance_valid(visual):
		return false
	return visual.has_attack_animation(prefix)


# Dash do vũ khí yêu cầu, state Dash sẽ bỏ qua chi phí SP
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


func apply_charm_grapple_pull(
	target_position: Vector3, stop_distance: float, pull_speed_units_per_second: float
) -> bool:
	if dead:
		return false
	var direction := target_position - global_position
	direction.y = 0.0
	if direction.is_zero_approx():
		return false
	var destination := target_position - direction.normalized() * maxf(0.0, stop_distance)
	var travel_distance := global_position.distance_to(destination)
	if _charm_grapple_tween != null and _charm_grapple_tween.is_valid():
		_charm_grapple_tween.kill()
	if travel_distance <= 0.001:
		global_position = destination
		return true
	var duration := travel_distance / maxf(0.01, pull_speed_units_per_second)
	_charm_grapple_tween = create_tween()
	_charm_grapple_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_charm_grapple_tween.tween_property(self, "global_position", destination, duration)
	_charm_grapple_tween.tween_callback(_on_charm_grapple_finished)
	return true


# Đổi bộ xử lý đòn đánh cùng animation tương ứng
func equip_attack(controller: Node, animation_prefix: String) -> bool:
	if not can_equip_weapon() or not is_instance_valid(controller):
		return false
	if (
		not controller.has_method("try_attack")
		or not controller.has_method("cancel")
		or not controller.has_signal("attack_finished")
	):
		return false
	if not has_attack_animation(animation_prefix):
		return false
	weapon_controller = controller
	attack_animation_prefix = animation_prefix
	return true


func update_facing() -> void:
	if not move_direction.is_zero_approx():
		last_facing_direction = move_direction


# Chỉ sửa vận tốc ngang, giữ nguyên vận tốc rơi theo Y
func set_horizontal_velocity(value: Vector3) -> void:
	velocity.x = value.x
	velocity.z = value.z


func _get_hit_direction(source: Node) -> Vector3:
	if source is Node3D:
		var direction := global_position - (source as Node3D).global_position
		direction.y = 0.0
		if not direction.is_zero_approx():
			return direction.normalized()
	return -last_facing_direction


func update_movement(delta: float, moving: bool) -> void:
	var target_velocity := Vector3.ZERO
	var change_speed := data.deceleration
	if moving:
		target_velocity = move_direction * _get_move_speed()
		change_speed = data.acceleration

	# Tăng hoặc giảm vận tốc từ từ để di chuyển có quán tính
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, change_speed * delta)
	set_horizontal_velocity(horizontal_velocity)


func play_directional_animation(action: String, restart: bool = false) -> void:
	if is_instance_valid(visual):
		visual.play_directional(action, last_facing_direction, _get_active_camera(), restart)


# Ngắt đòn đang đánh và yêu cầu chuyển sang state Hit
func notify_hit(duration: float = -1.0) -> void:
	if dead:
		return
	pending_free_dash = false
	if duration < 0.0:
		pending_hit_duration = data.hit_duration
	else:
		pending_hit_duration = maxf(0.01, duration)
	cancel_attack()
	var hit_state := fsm.states.get("hit") as FsmState
	if fsm.current_state == hit_state:
		hit_state.timer = pending_hit_duration
	else:
		fsm.change_state(hit_state, 50)


# Khóa điều khiển, ngừng hồi SP và hủy đòn trước khi vào Death
func die() -> void:
	if dead:
		return
	dead = true
	if is_instance_valid(hurtbox):
		hurtbox.enabled = false
	pending_free_dash = false
	if _charm_grapple_tween != null and _charm_grapple_tween.is_valid():
		_charm_grapple_tween.kill()
	_charm_grapple_tween = null
	if is_instance_valid(stamina):
		stamina.set_regeneration_enabled(false)
	dash_buffer_remaining = 0.0
	attack_requested = false
	cancel_attack()
	set_horizontal_velocity(Vector3.ZERO)
	fsm.change_state(fsm.states.get("death") as FsmState)


func cancel_attack() -> void:
	#end_hitbox_attack()
	if is_instance_valid(weapon_controller) and weapon_controller.has_method("cancel"):
		weapon_controller.call("cancel")


func _on_charm_grapple_finished() -> void:
	_charm_grapple_tween = null


func _get_move_speed() -> float:
	if data == null:
		return 0.0
	var stats: Dictionary[StringName, float] = {
		&"move_speed_flat": 0.0,
		&"move_speed_multiplier": 1.0,
	}
	if is_instance_valid(charm_socket_manager):
		charm_socket_manager.modify_stats(stats)
	# Thứ tự stat: base -> tổng flat -> tích multiplier -> clamp.
	return maxf(
		0.0, (data.move_speed + stats[&"move_speed_flat"]) * stats[&"move_speed_multiplier"]
	)

#func begin_hitbox_attack(amount_hp: int, attack_id: int = 0, tag: StringName = &"normal") -> bool:
#if dead or not is_instance_valid(hitbox):
#return false
#return hitbox.begin_attack(amount_hp, attack_id, tag)
#
#
#func end_hitbox_attack() -> void:
#if is_instance_valid(hitbox):
#hitbox.end_attack()
