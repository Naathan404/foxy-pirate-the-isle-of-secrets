# gdlint: disable=max-public-methods
# Player remains the gameplay API for locomotion, combat, inventory and dialogue callers.
class_name Player
extends CharacterBody3D

@warning_ignore("unused_signal")  # Emitted by player states.
signal action_rejected(action: StringName)
@warning_ignore("unused_signal")  # Emitted by player states.
signal dash_finished(interrupted: bool)
@warning_ignore("unused_signal")  # Emitted by player states.
signal dash_started
## Emitted for confirmed outgoing or incoming damage, including Charm hits.
signal combat_activity
signal poison_ticked(applied_hp: float)
signal dizzy_started(duration_seconds: float)

const DIALOGUE_STATE_PRIORITY: int = 20
const DIZZY_OVERLAY_SCRIPT: Script = preload("res://gameplay/player/effects/dizzy_swirl_overlay.gd")
const VENOM_INK_OVERLAY_NAME := &"BlubberbeardVenomOverlay"
const POISON_STATUS_HOLD_SECONDS: float = 1.6
const MIN_SNARE_MOVE_SPEED_MULTIPLIER: float = 0.2
const WHIRLWIND_HIT_STUN_SECONDS: float = 0.52
const WHIRLWIND_DIZZY_SECONDS: float = 2.2
const WHIRLWIND_SPIRAL_STRENGTH: float = 1.0

@export var data: PlayerData

@export var stamina: StaminaComponent
@export var hp: HealthComponent
@export var hurtbox: HurtBox
@export_enum("None:0", "Player:1", "Enemy:2") var team: int = CombatTeams.PLAYER
@export var weapon_controller: WeaponController
@export var ammo: AmmoComponent
@export var charm_socket_manager: CharmSocketManager
@export var chaos: ChaosComponent
@export var potion: PotionComponent
@export var potion_selector: PotionQuickSelect
@export var inventory_ui: InventoryUI
@export var attack_animation_prefix: String = "attack_dagger"
@export var camera: Camera3D
@export var dash_action: StringName = &"dash"
@export var attack_action: StringName = &"normal_attack"
@export var secondary_attack_action: StringName = &"secondary_attack"
@export_group("Damage")
@export_range(0.0, 3.0, 0.05, "suffix:s") var post_hit_invulnerability_duration: float = 0.8
@export_group("Poison & Venom")
@export var venom_ink_color: Color = Color(0.24, 0.72, 0.22, 0.92)
@export_range(0.0, 1.0, 0.01) var venom_ink_opacity: float = 0.78
@export_range(0.01, 2.0, 0.01, "suffix:s") var venom_ink_spread_seconds: float = 0.14
@export_range(0.0, 3.0, 0.05, "suffix:s") var venom_ink_hold_seconds: float = 0.55
@export_range(0.05, 4.0, 0.05, "suffix:s") var venom_ink_fade_seconds: float = 1.15
@export_range(0.15, 1.0, 0.05) var poison_move_speed_multiplier: float = 0.45
@export_range(0.15, 1.0, 0.05) var dizzy_move_speed_multiplier: float = 0.45

var move_direction: Vector3 = Vector3.ZERO
# Đứng yên vẫn nhớ hướng để đánh và dash
var last_facing_direction: Vector3 = Vector3.BACK
# nuffer nút dash
var dash_buffer_remaining: float = 0.0
var attack_requested: bool = false
var attack_held: bool = false
var secondary_attack_held: bool = false
var attack_buffer_remaining: float = 0.0
var pending_attack_action: StringName = &"normal"
var dead: bool = false
var pending_hit_duration: float = 0.0
var pending_hit_direction: Vector3 = Vector3.ZERO
var pending_hit_knockback_multiplier: float = 1.0
var pending_hit_tangent_direction: Vector3 = Vector3.ZERO
var pending_hit_spiral_strength: float = 0.0
var poison_remaining: float = 0.0
var dizzy_remaining: float = 0.0
var snare_remaining: float = 0.0
var pending_free_dash: bool = false
var pending_free_dash_direction: Vector3 = Vector3.ZERO
var blocked: bool = false
## Applied by environmental surfaces to ordinary ground movement only.
var environment_move_speed_multiplier: float = 1.0
## Hệ số quãng đường dash do địa hình cung cấp; được lấy khi bắt đầu dash.
var environment_dash_distance_multiplier: float = 1.0
var environment_is_water: bool = false
var potion_selection_active: bool = false
var _snare_move_speed_multiplier: float = 1.0
var _environment_push_direction := Vector3.ZERO
var _environment_push_speed := 0.0
var _environment_push_remaining := 0.0
var _environment_push_duration := 0.0
var _charm_grapple_tween: Tween
var _post_hit_invulnerability_remaining: float = 0.0
var _suppress_next_hit_reaction: bool = false

@onready var visual: PlayerVisual = $Visual
@onready var fsm: Fsm = $FSM
@onready var charm_registry: CharmRegistry = get_node_or_null("CharmSocketManager/CharmRegistry")

@onready var stamina_label: Label = get_node_or_null("TestHUD/SP")
@onready var hp_label: Label = get_node_or_null("TestHUD/HP")
@onready var debug_grant_charms_button: Button = get_node_or_null("TestHUD/DebugGrantAllCharms")


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
	if is_instance_valid(potion_selector):
		potion_selector.configure(self, potion)
	get_node("/root/GameManager").register_player(self)
	# GameManager applies the debug grant before the button reads its state. This
	# keeps the label correct after entering a new map.
	_setup_debug_charm_button()


func _setup_debug_charm_button() -> void:
	if not is_instance_valid(debug_grant_charms_button):
		return
	debug_grant_charms_button.visible = OS.is_debug_build()
	debug_grant_charms_button.text = (
		"Clear All Charms"
		if is_instance_valid(charm_socket_manager) and charm_socket_manager.debug_all_charms_owned()
		else "Grant All Charms"
	)
	if (
		OS.is_debug_build()
		and not debug_grant_charms_button.pressed.is_connected(_on_debug_grant_all_charms_pressed)
	):
		debug_grant_charms_button.pressed.connect(_on_debug_grant_all_charms_pressed)


func _on_debug_grant_all_charms_pressed() -> void:
	if not is_instance_valid(charm_socket_manager):
		return
	var granted := charm_socket_manager.debug_toggle_all_charms()
	var game_manager := get_node_or_null("/root/GameManager")
	if game_manager != null and game_manager.has_method("set_debug_all_charms_granted"):
		game_manager.set_debug_all_charms_granted(granted)
	if is_instance_valid(debug_grant_charms_button):
		debug_grant_charms_button.text = "Clear All Charms" if granted else "Grant All Charms"


func _exit_tree() -> void:
	get_node("/root/GameManager").unregister_player(self)


# Khởi tạo HP, SP và nối signal để cập nhật HUD
func _setup_stats() -> void:
	if is_instance_valid(chaos):
		chaos.init(data.max_chaos)
		combat_activity.connect(chaos.notify_combat_activity)
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
	if not is_instance_valid(weapon_controller):
		push_error("Player: chưa gán WeaponController")
		return
	weapon_controller.team = team
	weapon_controller.chaos = chaos
	weapon_controller.damage_dealt.connect(_on_weapon_damage_dealt)
	if not weapon_controller.setup(self, stamina, ammo):
		push_error("Player: set up vũ khí bị fail")


func _setup_charm_system() -> void:
	if not is_instance_valid(charm_socket_manager):
		return
	if not is_instance_valid(charm_registry):
		push_error("Player: CharmRegistry chưa được gắn dưới CharmSocketManager")
		return
	charm_socket_manager.actor = self
	charm_registry.charm_unequipped.connect(_on_charm_unequipped)


func play_charm_cast(
	charm_id: StringName,
	phase: StringName,
	direction: Vector3,
	duration_seconds: float = 0.0,
	continue_only: bool = false
) -> void:
	if not dead and is_instance_valid(visual):
		visual.play_charm_cast(
			charm_id,
			phase,
			direction if not direction.is_zero_approx() else last_facing_direction,
			duration_seconds,
			continue_only
		)


func cancel_charm_cast(charm_id: StringName) -> void:
	if is_instance_valid(visual):
		visual.stop_charm_cast(charm_id)


func _on_charm_unequipped(charm_id: StringName, _socket_id: int) -> void:
	cancel_charm_cast(charm_id)


func _on_weapon_damage_dealt(damage: DamageContext, target: Node, applied_hp: float) -> void:
	if dead or not is_instance_valid(chaos) or applied_hp <= 0:
		return
	if damage == null or damage.source != self or not is_instance_valid(target):
		return
	if target is EnemyBase or target is BossBase or target.is_in_group("training_dummy"):
		chaos.gain(damage.chaos_gain)


func _on_stamina_changed(amount: float, maximum: float) -> void:
	if is_instance_valid(stamina_label):
		stamina_label.text = "SP: " + str(int(amount)) + "/" + str(int(maximum))


func _on_hp_changed(amount: float, maximum: float) -> void:
	if is_instance_valid(hp_label):
		hp_label.text = "HP: %s / %s" % [String.num(amount, 2), String.num(maximum, 2)]


func _on_damaged(_applied_hp: float) -> void:
	combat_activity.emit()
	if _suppress_next_hit_reaction:
		return
	# Đòn chí mạng để state Death xử lý, không vào Hit nữa
	if hp.is_alive():
		var hit_duration := (
			WHIRLWIND_HIT_STUN_SECONDS if pending_hit_spiral_strength > 0.0 else -1.0
		)
		notify_hit(hit_duration)


func is_poisoned() -> bool:
	return not dead and poison_remaining > 0.0


func is_dizzy() -> bool:
	return not dead and dizzy_remaining > 0.0


func apply_dizzy(duration_seconds: float) -> void:
	if dead or duration_seconds <= 0.0:
		return
	dizzy_remaining = maxf(dizzy_remaining, duration_seconds)
	dizzy_started.emit(dizzy_remaining)


func is_snared() -> bool:
	return not dead and snare_remaining > 0.0


func apply_snare(duration_seconds: float, speed_multiplier: float = 0.75) -> void:
	if dead or duration_seconds <= 0.0:
		return
	var clamped_multiplier := clampf(speed_multiplier, MIN_SNARE_MOVE_SPEED_MULTIPLIER, 1.0)
	if snare_remaining <= 0.0:
		_snare_move_speed_multiplier = clamped_multiplier
	else:
		_snare_move_speed_multiplier = minf(_snare_move_speed_multiplier, clamped_multiplier)
	snare_remaining = maxf(snare_remaining, duration_seconds)


func is_suppressing_hit_reaction() -> bool:
	return _suppress_next_hit_reaction


# Dùng cho damage trực tiếp, ví dụ bẫy hoặc nút test
func take_damage(amount: float) -> float:
	var damage := DamageContext.new()
	damage.amount_hp = amount
	return receive_damage(damage)


# Đòn từ HurtBox đi qua phòng thủ trước rồi mới trừ HP
func receive_damage(damage: DamageContext) -> float:
	if dead or not is_instance_valid(hp) or damage == null or damage.amount_hp <= 0:
		return 0
	if damage.source == self:
		return 0
	if is_instance_valid(damage.source) and damage.source_team == team:
		return 0
	var is_poison_tick := damage.tag == &"poison"
	if not is_poison_tick:
		if _post_hit_invulnerability_remaining > 0.0:
			return 0
		if is_instance_valid(weapon_controller) and weapon_controller.is_attack_invulnerable():
			return 0
	var amount := damage.amount_hp
	if is_instance_valid(weapon_controller):
		if weapon_controller.has_method("modify_incoming_damage"):
			amount = float(weapon_controller.call("modify_incoming_damage", amount, damage))
	if is_instance_valid(charm_socket_manager):
		amount = charm_socket_manager.modify_incoming_damage(amount, damage)
	if not is_finite(amount) or amount <= 0.0 or not hp.is_alive():
		return 0
	if is_poison_tick:
		return _apply_poison_damage_tick(damage, amount)
	_prepare_incoming_hit_motion(damage)
	# Set this before take_damage emits signals, which may trigger another hit.
	_post_hit_invulnerability_remaining = post_hit_invulnerability_duration
	var applied_hp := hp.take_damage(amount)
	if applied_hp <= 0.0:
		_post_hit_invulnerability_remaining = 0.0
	if applied_hp > 0:
		if damage.tag == &"boss_venom_hit":
			_apply_poison_status(true)
		if is_instance_valid(charm_socket_manager):
			charm_socket_manager.dispatch_event(&"damage_received", [damage, applied_hp])
	return applied_hp


func _apply_poison_damage_tick(damage: DamageContext, amount: float) -> float:
	# Sát thương độc theo chu kỳ không kích hoạt PlayerHit stun hay i-frame miễn nhiễm.
	var was_poisoned := is_poisoned()
	_suppress_next_hit_reaction = true
	var applied_hp := hp.take_damage(amount)
	_suppress_next_hit_reaction = false
	if applied_hp > 0.0:
		var overlay := get_node_or_null(NodePath(VENOM_INK_OVERLAY_NAME))
		var overlay_active: bool = (
			overlay != null and overlay.has_method("is_active") and bool(overlay.call("is_active"))
		)
		_apply_poison_status(not was_poisoned or not overlay_active)
		poison_ticked.emit(applied_hp)
		if is_instance_valid(charm_socket_manager):
			charm_socket_manager.dispatch_event(&"damage_received", [damage, applied_hp])
	return applied_hp


func _apply_poison_status(show_ink_splash: bool) -> void:
	poison_remaining = maxf(poison_remaining, POISON_STATUS_HOLD_SECONDS)
	apply_dizzy(POISON_STATUS_HOLD_SECONDS)
	if show_ink_splash:
		_trigger_venom_ink_splash()


func _prepare_incoming_hit_motion(damage: DamageContext) -> void:
	pending_hit_direction = _get_hit_direction(damage.source, damage.origin)
	pending_hit_knockback_multiplier = maxf(0.0, damage.knockback_multiplier)
	if damage.tag == &"boss_whirlwind":
		pending_hit_spiral_strength = WHIRLWIND_SPIRAL_STRENGTH
		var flat_tan := Vector3(damage.direction.x, 0.0, damage.direction.z)
		if flat_tan.is_zero_approx():
			flat_tan = Vector3.UP.cross(pending_hit_direction)
		pending_hit_tangent_direction = flat_tan.normalized()
	else:
		pending_hit_spiral_strength = 0.0
		pending_hit_tangent_direction = Vector3.ZERO


func _trigger_venom_ink_splash() -> void:
	var overlay := get_node_or_null(NodePath(VENOM_INK_OVERLAY_NAME))
	if overlay == null:
		overlay = DIZZY_OVERLAY_SCRIPT.new()
		overlay.name = VENOM_INK_OVERLAY_NAME
		add_child(overlay)
	overlay.splash(
		false,
		venom_ink_color,
		venom_ink_spread_seconds,
		venom_ink_hold_seconds,
		venom_ink_fade_seconds,
		venom_ink_opacity
	)


func _physics_process(delta: float) -> void:
	_post_hit_invulnerability_remaining = maxf(0.0, _post_hit_invulnerability_remaining - delta)
	poison_remaining = maxf(0.0, poison_remaining - delta)
	dizzy_remaining = maxf(0.0, dizzy_remaining - delta)
	snare_remaining = maxf(0.0, snare_remaining - delta)
	if snare_remaining <= 0.0:
		_snare_move_speed_multiplier = 1.0
	dash_buffer_remaining = maxf(0.0, dash_buffer_remaining - delta)
	attack_buffer_remaining = maxf(0.0, attack_buffer_remaining - delta)
	if attack_buffer_remaining <= 0.0:
		attack_requested = false
	_read_input()
	if get_node("/root/HitstopController").is_frozen(self):
		return

	if blocked:
		return

	fsm._update(delta)
	var game_manager = get_node("/root/GameManager")
	if (
		not dead
		and is_instance_valid(chaos)
		and not is_gameplay_input_blocked()
		and game_manager.state == game_manager.State.PLAYING
		and (not is_instance_valid(weapon_controller) or not weapon_controller.holds_chaos())
	):
		chaos.advance(delta)

	if OS.is_debug_build() and Input.is_action_just_pressed("test_hit"):
		take_damage(1)

	# State chọn vận tốc, Player chỉ di chuyển vật lý 1 lần mỗi frame
	if dead:
		set_horizontal_velocity(Vector3.ZERO)
	# Dash keeps its launch height even after crossing a ledge. Resume gravity
	# on the next state, including when the dash was interrupted.
	var dash_state := fsm.states.get("dash") as FsmState
	var dash_holds_height := (
		fsm.current_state == dash_state
		and dash_state != null
		and (bool(dash_state.get("active")) or bool(dash_state.get("completed")))
	)
	if dash_holds_height:
		velocity.y = 0.0
	elif not is_on_floor():
		velocity += get_gravity() * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	_apply_environment_push(delta)
	move_and_slide()


func _read_input() -> void:
	move_direction = Vector3.ZERO
	attack_held = false
	secondary_attack_held = false
	if is_gameplay_input_blocked():
		if not potion_selection_active:
			clear_gameplay_input()
		return
	if dead:
		return
	attack_held = Input.is_action_pressed(attack_action)
	var secondary_blocked: bool = (
		is_instance_valid(potion_selector) and potion_selector.blocks_secondary_attack()
	)
	secondary_attack_held = (
		not secondary_blocked and Input.is_action_pressed(secondary_attack_action)
	)
	if (
		not is_instance_valid(potion_selector)
		and Input.is_action_just_pressed("swap_potion")
		and is_instance_valid(potion)
	):
		potion.swap_potions()
	if Input.is_action_just_pressed("potion") and is_instance_valid(potion):
		potion.use_equipped_potion()
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
		not secondary_blocked
		and InputMap.has_action(secondary_attack_action)
		and Input.is_action_just_pressed(secondary_attack_action)
	):
		request_attack(&"secondary")


func clear_gameplay_input() -> void:
	if is_instance_valid(potion_selector):
		potion_selector.cancel_selection()
	move_direction = Vector3.ZERO
	attack_held = false
	secondary_attack_held = false
	attack_requested = false
	attack_buffer_remaining = 0.0
	if is_instance_valid(weapon_controller):
		weapon_controller.clear_attack_buffer()
		if weapon_controller.is_aiming():
			weapon_controller.cancel()
	dash_buffer_remaining = 0.0


func hold_for_dialogue() -> void:
	if dead:
		return
	clear_gameplay_input()
	set_horizontal_velocity(Vector3.ZERO)
	var idle_state := fsm.states.get("idle") as FsmState
	if is_instance_valid(idle_state) and fsm.change_state(idle_state, DIALOGUE_STATE_PRIORITY):
		fsm._update(0.0)
	else:
		play_directional_animation("idle")


func is_gameplay_input_blocked() -> bool:
	return (
		blocked
		or potion_selection_active
		or (is_instance_valid(inventory_ui) and inventory_ui.is_open())
	)


func _get_active_camera() -> Camera3D:
	if is_instance_valid(camera):
		return camera
	return get_viewport().get_camera_3d()


func request_dash() -> void:
	if not dead and not is_gameplay_input_blocked():
		dash_buffer_remaining = data.dash_buffer_duration


func request_attack(action: StringName = &"normal") -> void:
	if not dead and not is_gameplay_input_blocked():
		pending_attack_action = action
		attack_requested = true
		attack_buffer_remaining = 0.18
		if is_instance_valid(weapon_controller) and weapon_controller.equipped != null:
			var attack := weapon_controller.equipped.get_attack(action)
			if attack != null:
				attack_buffer_remaining = attack.input_buffer_seconds


func _consume_attack_input() -> void:
	attack_requested = false
	attack_buffer_remaining = 0.0


# Chốt hướng đánh theo chuột; thiếu mục tiêu hợp lệ thì giữ hướng nhìn.
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
		var aim_direction: Vector3 = mouse_target - context.origin
		aim_direction.y = 0.0
		if not aim_direction.is_zero_approx():
			context.direction = aim_direction.normalized()
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


func _get_hit_direction(source: Node, hit_origin: Vector3 = Vector3.ZERO) -> Vector3:
	if not hit_origin.is_zero_approx():
		var origin_dir := global_position - hit_origin
		origin_dir.y = 0.0
		if not origin_dir.is_zero_approx():
			return origin_dir.normalized()
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
## Reuse hit recovery without applying damage when an environmental wave hits.
func apply_environment_knockback(direction: Vector3, speed: float, duration: float) -> void:
	if not apply_environment_push(direction, speed, duration):
		return
	pending_hit_direction = _environment_push_direction
	pending_hit_knockback_multiplier = speed / 8.0
	notify_hit(duration)


## Carries the player along `direction` without a hit reaction (e.g. riding a tide surge).
## Returns false when the push is rejected (dead, zero speed/duration or vertical direction).
func apply_environment_push(direction: Vector3, speed: float, duration: float) -> bool:
	var horizontal := Vector3(direction.x, 0.0, direction.z)
	if dead or speed <= 0.0 or duration <= 0.0 or horizontal.length_squared() < 0.0001:
		return false
	_environment_push_direction = horizontal.normalized()
	_environment_push_speed = speed
	_environment_push_duration = duration
	_environment_push_remaining = duration
	return true


func _apply_environment_push(delta: float) -> void:
	if dead:
		_environment_push_remaining = 0.0
		return
	if _environment_push_remaining <= 0.0:
		return
	# Locomotion, attacks and dash may set velocity, but cannot cancel the wave's
	# minimum forward component. Wall collisions still constrain actual movement.
	var strength := _environment_push_remaining / _environment_push_duration
	var minimum_speed := _environment_push_speed * lerpf(0.35, 1.0, strength)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var forward_speed := horizontal.dot(_environment_push_direction)
	if forward_speed < minimum_speed:
		horizontal += _environment_push_direction * (minimum_speed - forward_speed)
		set_horizontal_velocity(horizontal)
	_environment_push_remaining = maxf(0.0, _environment_push_remaining - maxf(delta, 0.0))


func notify_hit(duration: float = -1.0) -> void:
	if dead:
		return
	if is_instance_valid(weapon_controller) and weapon_controller.is_attack_invulnerable():
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
	poison_remaining = 0.0
	dizzy_remaining = 0.0
	snare_remaining = 0.0
	_snare_move_speed_multiplier = 1.0
	if is_instance_valid(potion_selector):
		potion_selector.cancel_selection()
	if is_instance_valid(inventory_ui):
		inventory_ui.close_inventory(true)
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
	_consume_attack_input()
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
	var status_speed_mult := _get_status_move_speed_multiplier()
	# Thứ tự stat: base -> tổng flat -> tích multiplier -> clamp.
	return maxf(
		0.0,
		(
			(data.move_speed + stats[&"move_speed_flat"])
			* stats[&"move_speed_multiplier"]
			* environment_move_speed_multiplier
			* status_speed_mult
		)
	)


func _get_status_move_speed_multiplier() -> float:
	var mult := 1.0
	if is_poisoned():
		mult = minf(mult, poison_move_speed_multiplier)
	if is_dizzy():
		mult = minf(mult, dizzy_move_speed_multiplier)
	if is_snared():
		mult = minf(mult, _snare_move_speed_multiplier)
	return mult
