class_name WeaponController
extends Node

# Báo đánh xong hoặc bị ngắt để Player thoát state Attack
signal attack_finished
signal attack_started(context: AttackContext)
signal weapon_changed(weapon: WeaponInstance)
signal damage_dealt(damage: DamageContext, target: Node, applied_hp: int)

# Các giai đoạn của 1 đòn đánh
enum Phase { WINDUP, ACTIVE, RECOVERY }

const Teams := preload("res://gameplay/combat/combat_teams.gd")

@export var default_weapon: WeaponData
@export_enum("None:0", "Player:1", "Enemy:2") var team: int = Teams.PLAYER

var equipped: WeaponInstance
# Đang đánh thì không nhận đòn mới hoặc đổi vũ khí
var busy: bool = false
var actor: Node3D
var stamina: StaminaComponent
var ammo: AmmoComponent
var chaos: ChaosComponent
# Giảm cooldown cả những vũ khí không được trang bị
var _owned: Array[WeaponInstance] = []
# Hiệu ứng vũ khí đang trang bị
var _effect: WeaponEffect
# Scene đòn đánh hiện tại
var _execution: WeaponAttack
# Chỉ số đã chốt cho đòn đánh, đổi vũ khí không sửa lại context này
var _context: AttackContext
var _phase: Phase = Phase.WINDUP
# Thời gian còn lại của giai đoạn hiện tại
var _remaining: float = 0.0
# Thời gian sau khi tính thuộc tính rèn
var _windup: float = 0.0
var _active: float = 0.0
var _recovery: float = 0.0
var _animation_prefix: String = ""
var _next_attack_id: int = 0
var _combo_index: int = 0
var _combo_remaining: float = 0.0
var _queued_attack: AttackContext
var _buffer_remaining: float = 0.0


# Setup nhân vật, SP, đạn và vũ khí khởi đầu
func setup(
	owner_actor: Node3D,
	stamina_component: StaminaComponent = null,
	ammo_component: AmmoComponent = null
) -> bool:
	if is_instance_valid(actor) or not is_instance_valid(owner_actor):
		return false
	actor = owner_actor
	stamina = stamina_component
	ammo = ammo_component
	if actor.has_signal("dash_started"):
		actor.connect("dash_started", _on_dash_started)
	if actor.has_signal("dash_finished"):
		actor.connect("dash_finished", _on_dash_finished)
	if default_weapon != null:
		var starter := WeaponInstance.new()
		starter.definition = default_weapon
		return equip(starter)
	return true


# Kiểm tra vũ khí mới trước, lỗi thì giữ vũ khí cũ
func equip(weapon: WeaponInstance) -> bool:
	if busy or not is_instance_valid(actor) or weapon == null or weapon.definition == null:
		return false
	if actor.has_method("can_equip_weapon") and not bool(actor.call("can_equip_weapon")):
		return false
	var definition := weapon.definition
	if definition.normal_attack == null or not definition.normal_attack.is_valid():
		return false
	if not _has_animation(definition.normal_attack.animation_prefix):
		return false
	if definition.secondary_attack != null:
		if (
			not definition.secondary_attack.is_valid()
			or not _has_animation(definition.secondary_attack.animation_prefix)
		):
			return false
	var next_effect: WeaponEffect
	if definition.equipped_effect_scene != null:
		var effect_node := definition.equipped_effect_scene.instantiate()
		next_effect = effect_node as WeaponEffect
		if next_effect == null:
			effect_node.free()
			return false
	if is_instance_valid(_effect):
		_effect.on_unequip()
		_effect.queue_free()
	_effect = next_effect
	equipped = weapon
	reset_combo()
	if not _owned.has(weapon):
		_owned.append(weapon)
	if is_instance_valid(_effect):
		_effect.actor = actor
		_effect.weapon = weapon
		add_child(_effect)
		_effect.on_equip()
	weapon_changed.emit(weapon)
	return true


func _has_animation(prefix: String) -> bool:
	return (
		not actor.has_method("has_attack_animation")
		or bool(actor.call("has_attack_animation", prefix))
	)


func get_aim_mode(action: StringName = &"normal") -> AttackData.AimMode:
	var attack := equipped.get_attack(action) if equipped != null else null
	return attack.aim_mode if attack != null else AttackData.AimMode.FACING


func get_attack_animation_prefix() -> String:
	return _animation_prefix


# Tổng thời gian để Player chỉnh tốc độ animation
func get_attack_duration() -> float:
	return _windup + _active + _recovery


func queue_attack(request: AttackContext) -> bool:
	if request == null:
		return false
	if not busy or _context == null or _context.combo_step == null or request.action != &"normal":
		return false
	# A single slot: repeated presses never extend its lifetime or queue an entire chain.
	if _queued_attack != null:
		return true
	_queued_attack = request
	_buffer_remaining = equipped.definition.normal_attack.input_buffer_seconds
	return true


func clear_attack_buffer() -> void:
	_queued_attack = null
	_buffer_remaining = 0.0


func reset_combo() -> void:
	_combo_index = 0
	_combo_remaining = 0.0
	clear_attack_buffer()


func can_dash_cancel() -> bool:
	if not busy or _context == null or _context.combo_step == null:
		return false
	return (
		_phase == Phase.RECOVERY
		and (_recovery - _remaining >= _recovery * _context.combo_step.dash_cancel_fraction)
	)


# Nhận đòn thì trả true, chỉ trừ SP hoặc đạn 1 lần
func try_attack(request: AttackContext) -> bool:
	if busy or request == null or not is_instance_valid(actor) or equipped == null:
		return false
	if not actor.is_inside_tree() or actor.get_parent() == null:
		return false
	if (
		actor.has_method("can_start_weapon_attack")
		and not bool(actor.call("can_start_weapon_attack"))
	):
		return false
	var attack := equipped.get_attack(request.action)
	if attack == null or not attack.is_valid() or not _has_animation(attack.animation_prefix):
		return false
	if request.action == &"secondary" and (not is_instance_valid(chaos) or not chaos.is_full()):
		return false
	if equipped.unavailable_seconds > 0.0 or equipped.cooldowns.get(request.action, 0.0) > 0.0:
		return false
	if request.action != &"normal" or _combo_remaining <= 0.0:
		_combo_index = 0
	var snapshot := _make_context(request, attack)
	if snapshot == null:
		return false
	var cost := attack.stamina_cost
	var speed := 1.0
	var cooldown := attack.cooldown_seconds
	if equipped.forge != null:
		cost *= maxf(0.0, equipped.forge.stamina_cost_multiplier)
		speed = maxf(0.01, equipped.forge.attack_speed_multiplier)
	if not _can_pay_attack_cost(attack, cost):
		return false
	# Validate scene trước khi trừ SP hoặc đạn
	var execution_node := attack.attack_scene.instantiate()
	var execution := execution_node as WeaponAttack
	if execution == null or not execution.validate():
		execution_node.free()
		return false
	_windup = attack.windup_seconds / speed
	_active = attack.active_seconds / speed
	_recovery = attack.recovery_seconds / speed
	_animation_prefix = attack.animation_prefix
	if snapshot.combo_step != null:
		var step := snapshot.combo_step
		_windup = step.windup_seconds / speed
		_active = step.active_seconds / speed
		_recovery = step.recovery_seconds / speed
		if not step.animation_prefix.is_empty():
			_animation_prefix = step.animation_prefix
	snapshot.active_seconds = _active
	_next_attack_id += 1
	snapshot.attack_id = _next_attack_id
	# Chỉ bind vũ khí, bind context sẽ tạo vòng tham chiếu
	snapshot.damage_prepared.connect(_on_damage_prepared)
	snapshot.damage_applied.connect(_on_damage_applied.bind(snapshot.weapon))
	_context = snapshot
	_execution = execution
	execution.context = snapshot
	_phase = Phase.WINDUP
	_remaining = _windup
	# Khóa nhận đòn trước khi signal SP hoặc đạn được phát
	busy = true
	# Gắn đòn vào thế giới để đạn, phép không chạy theo nhân vật
	actor.get_parent().add_child(execution)
	execution.global_position = snapshot.origin
	var paid := true
	if cost > 0.0:
		paid = stamina.try_consume(cost)
	elif attack.ammo_cost > 0:
		paid = ammo.try_consume(attack.ammo_id, attack.ammo_cost)
	if not paid:
		cancel()
		return false
	if snapshot.action == &"secondary" and not chaos.try_consume_full():
		cancel()
		return false
	snapshot.weapon.cooldowns[snapshot.action] = cooldown / speed
	clear_attack_buffer()
	if busy and _context == snapshot:
		attack_started.emit(snapshot)
	# Signal trừ tài nguyên có thể hủy đòn, kiểm tra lại trước khi chạy tiếp
	if busy and _context == snapshot and _remaining <= 0.0:
		_advance_phase()
	return true


# Kiểm tra chi phí đã tính sau forge trước khi tạo scene và trừ tài nguyên.
func _can_pay_attack_cost(attack: AttackData, stamina_cost: float) -> bool:
	if (
		stamina_cost > 0.0
		and (not is_instance_valid(stamina) or not stamina.can_consume(stamina_cost))
	):
		return false
	if (
		attack.ammo_cost > 0
		and (not is_instance_valid(ammo) or not ammo.can_consume(attack.ammo_id, attack.ammo_cost))
	):
		return false
	return true


# Chốt hướng, mục tiêu và chỉ số sau khi rèn, không sửa data gốc
func _make_context(request: AttackContext, attack: AttackData) -> AttackContext:
	var result := AttackContext.new()
	result.actor = actor
	result.team = team
	result.action = request.action
	result.weapon = equipped
	result.weapon_category = equipped.definition.category
	result.origin = actor.global_position
	result.direction = Vector3(request.direction.x, 0, request.direction.z)
	result.target_position = request.target_position
	result.has_target = request.has_target
	result.damage_hp = attack.damage_hp
	if request.action == &"normal" and not attack.combo_steps.is_empty():
		result.combo_index = _combo_index % attack.combo_steps.size()
		result.combo_step = attack.combo_steps[result.combo_index]
		if not result.combo_step.animation_prefix.is_empty():
			if not _has_animation(result.combo_step.animation_prefix):
				return null
		result.damage_hp = maxi(1, roundi(attack.damage_hp * result.combo_step.damage_multiplier))
	result.range_units = attack.range_units
	if equipped.forge != null:
		result.damage_hp = maxi(1, roundi(result.damage_hp * equipped.forge.damage_multiplier))
		result.range_units *= maxf(0.01, equipped.forge.range_multiplier)
		result.hitbox_multiplier = maxf(0.01, equipped.forge.hitbox_multiplier)
	var charm_manager := actor.get("charm_socket_manager") as CharmSocketManager
	if is_instance_valid(charm_manager):
		result.damage_hp = charm_manager.modify_attack_damage(result.damage_hp, result)
	if attack.aim_mode != AttackData.AimMode.FACING:
		if not request.has_target:
			return null
		var offset := request.target_position - result.origin
		offset.y = 0.0
		result.direction = offset
		result.target_position = result.origin + offset.limit_length(result.range_units)
	if result.direction.is_zero_approx():
		return null
	result.direction = result.direction.normalized()
	# Trả hướng đánh về Player để animation nhìn đúng hướng
	request.direction = result.direction
	return result


func _physics_process(delta: float) -> void:
	if get_node("/root/HitstopController").is_frozen(actor):
		return
	for weapon: WeaponInstance in _owned:
		weapon.advance(delta)
	if not busy:
		_combo_remaining = maxf(0.0, _combo_remaining - delta)
		return
	if (
		not is_instance_valid(actor)
		or not is_instance_valid(_execution)
		or _execution.is_queued_for_deletion()
	):
		cancel()
		return
	var budget := delta
	# Chia delta cho từng giai đoạn để frame chậm không làm mất nhịp đánh
	while busy and budget > 0.0:
		var step := minf(budget, _remaining)
		_buffer_remaining = maxf(0.0, _buffer_remaining - step)
		if _buffer_remaining <= 0.0:
			clear_attack_buffer()
		var current := _context
		if _phase == Phase.ACTIVE:
			_execution.tick_active(step)
		# Gây damage có thể hủy đòn, không update tiếp context cũ
		if not busy or _context != current:
			return
		_remaining -= step
		budget -= step
		if _remaining <= 0.000001:
			_advance_phase()
		if not is_physics_processing() or get_node("/root/HitstopController").is_frozen(actor):
			return


# Chuyển giai đoạn, bật và tắt đòn đánh
func _advance_phase() -> void:
	if not busy:
		return
	match _phase:
		Phase.WINDUP:
			_phase = Phase.ACTIVE
			_remaining = _active
			_execution.activate()
		Phase.ACTIVE:
			_phase = Phase.RECOVERY
			_remaining = _recovery
			_execution.deactivate()
			if busy and _remaining <= 0.0:
				_finish(false)
		Phase.RECOVERY:
			_finish(false)


# Hủy đòn hiện tại, đạn hoặc phép đã phóng có vòng đời riêng
func cancel() -> void:
	reset_combo()
	_finish(true)


# Xóa trạng thái trước khi báo xong để signal có thể yêu cầu đòn mới
func _finish(interrupted: bool) -> void:
	if not busy:
		return
	var execution := _execution
	var completed_context := _context
	var queued := _queued_attack if not interrupted else null
	if not interrupted and completed_context.combo_step != null:
		var attack := completed_context.weapon.definition.normal_attack
		_combo_index = (completed_context.combo_index + 1) % attack.combo_steps.size()
		_combo_remaining = attack.combo_reset_seconds
	clear_attack_buffer()
	busy = false
	_execution = null
	_context = null
	if is_instance_valid(execution):
		if interrupted:
			execution.cancel()
		else:
			execution.release()
	if queued != null and try_attack(queued):
		return
	attack_finished.emit()


# Xử lý phòng thủ trước khi trừ máu
func modify_incoming_damage(amount_hp: int, damage: DamageContext) -> int:
	if is_instance_valid(_effect):
		return maxi(0, _effect.modify_incoming_damage(amount_hp, damage))
	return amount_hp


func _on_damage_prepared(damage: DamageContext, target: Node) -> void:
	if damage == null or damage.source != actor or not is_instance_valid(target):
		return
	damage.target = target
	var charm_manager := actor.get("charm_socket_manager") as CharmSocketManager
	if is_instance_valid(charm_manager):
		damage.amount_hp = charm_manager.modify_outgoing_damage(damage.amount_hp, damage)


func _on_damage_applied(
	damage: DamageContext, target: Node, applied_hp: int, source_weapon: WeaponInstance
) -> void:
	if damage == null or applied_hp <= 0:
		return
	damage.target = target
	damage.target_defeated = _is_target_defeated(target)
	# Chỉ kích hoạt hiệu ứng nếu vũ khí gây damage vẫn đang được trang bị
	if source_weapon == equipped and is_instance_valid(_effect):
		_effect.on_damage_dealt(damage, target, applied_hp)
	damage_dealt.emit(damage, target, applied_hp)
	var charm_manager := actor.get("charm_socket_manager") as CharmSocketManager
	if is_instance_valid(charm_manager):
		charm_manager.dispatch_event(&"damage_dealt", [damage, target, applied_hp])
		if damage.target_defeated:
			charm_manager.dispatch_event(&"target_defeated", [target, damage])


func _is_target_defeated(target: Node) -> bool:
	if not is_instance_valid(target):
		return false
	if target is EnemyBase:
		return (target as EnemyBase).dead
	if target.has_method("is_defeated"):
		return bool(target.call("is_defeated"))
	return false


func _on_dash_started() -> void:
	reset_combo()
	if is_instance_valid(_effect):
		_effect.on_dash_started()


func _on_dash_finished(interrupted: bool) -> void:
	if is_instance_valid(_effect):
		_effect.on_dash_finished(interrupted)


# Nhân vật bị xóa thì hủy đòn và gỡ hiệu ứng trang bị
func _exit_tree() -> void:
	cancel()
	if is_instance_valid(_effect):
		_effect.on_unequip()
