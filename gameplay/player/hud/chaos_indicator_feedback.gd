class_name ChaosIndicatorFeedback
extends TextureRect
## Feedback for the small Chaos light; its resting position and scale stay Inspector-owned.

@export_group("Chaos Feedback")
@export var empty_tint: Color = Color(0.45, 0.40, 0.55, 0.75)
@export var gain_tint: Color = Color(0.85, 1.20, 1.35)
@export var ready_tint: Color = Color(1.25, 0.90, 0.35)
@export var spent_tint: Color = Color(1.40, 1.25, 0.80)
@export var decay_tint: Color = Color(0.80, 0.65, 1.25)
@export var rejected_tint: Color = Color(1.25, 0.30, 0.25)
@export_range(0.4, 3.0, 0.1, "suffix:s") var ready_pulse_seconds: float = 1.2

var _chaos: ChaosComponent
var _weapons: WeaponController
var _player: Player
var _current: float = 0.0
var _maximum: float = 0.0
var _initialized: bool = false
var _base_position: Vector2
var _base_scale: Vector2
var _base_tint: Color
var _feedback_active: bool = false
var _feedback_tween: Tween
var _pulse_tween: Tween
var _size_factor: float = 1.0:
	set(value):
		_size_factor = value
		if is_node_ready():
			scale = _base_scale * value
			# Compensate around the artwork's center without changing its authored pivot.
			position = (
				_base_position
				+ ((_base_scale - scale) * (size * 0.5 - pivot_offset)).rotated(rotation)
			)


func _ready() -> void:
	_base_position = position
	_base_scale = scale
	_base_tint = modulate
	visibility_changed.connect(_on_visibility_changed)


## The owning HUD binds once after all its children have entered the tree.
func bind_components(chaos: ChaosComponent, weapons: WeaponController, player: Player) -> void:
	_chaos = chaos
	_weapons = weapons
	_player = player
	if is_instance_valid(_chaos):
		_chaos.chaos_changed.connect(set_stat)
		_chaos.decay_started.connect(_on_decay_started)
		set_stat(_chaos.current, _chaos.maximum)
	if is_instance_valid(_weapons):
		_weapons.attack_started.connect(_on_attack_started)
		_weapons.charge_released.connect(_on_charge_released)
	if is_instance_valid(_player):
		_player.action_rejected.connect(_on_action_rejected)


func set_stat(current: float, maximum: float) -> void:
	var was_full := _is_full()
	var gained := _initialized and current > _current
	_current = current
	_maximum = maximum
	if not _initialized:
		_initialized = true
		_settle()
	elif _is_full() and not was_full:
		_flash(ready_tint, 1.18, 0.35)
	elif gained:
		_flash(gain_tint, 1.10, 0.25)
	elif not _is_full():
		if _pulse_tween != null and _pulse_tween.is_valid():
			_pulse_tween.kill()
		if not _feedback_active:
			_size_factor = 1.0
			modulate = _rest_color()


func _on_decay_started() -> void:
	_flash(decay_tint, 1.04, 0.35)


func _on_attack_started(context: AttackContext) -> void:
	if context.action == &"secondary" and not _weapons.is_aiming():
		_flash(spent_tint, 0.88, 0.30)


func _on_charge_released(context: AttackContext) -> void:
	if context.action == &"secondary":
		_flash(spent_tint, 0.88, 0.30)


func _on_action_rejected(action: StringName) -> void:
	if (
		action != &"normal_attack"
		or not is_instance_valid(_player)
		or _player.pending_attack_action != &"secondary"
		or not is_instance_valid(_chaos)
		or _chaos.is_full()
		or not is_instance_valid(_weapons)
		or _weapons.busy
		or _weapons.equipped == null
		or _weapons.equipped.get_attack(&"secondary") == null
	):
		return
	_flash(rejected_tint, 1.08, 0.25)


func _flash(tint: Color, size_factor: float, seconds: float) -> void:
	if not is_visible_in_tree():
		return
	_stop_animations()
	_feedback_active = true
	modulate = _base_tint * tint
	_size_factor = size_factor
	_feedback_tween = create_tween().set_parallel(true)
	_feedback_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_method(_fade_flash.bind(tint), 1.0, 0.0, seconds)
	_feedback_tween.tween_property(self, "_size_factor", 1.0, seconds)
	_feedback_tween.chain().tween_callback(_settle)


func _fade_flash(strength: float, tint: Color) -> void:
	# CP can keep changing during a flash, particularly while charging a skill.
	modulate = _rest_color().lerp(_base_tint * tint, strength)


func _settle() -> void:
	_stop_animations()
	_feedback_active = false
	_size_factor = 1.0
	modulate = _rest_color()
	if not _is_full() or not is_visible_in_tree():
		return
	var half_cycle := maxf(0.2, ready_pulse_seconds * 0.5)
	_pulse_tween = create_tween().set_loops().set_parallel(true)
	_pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(
		self, "modulate", _base_tint * ready_tint.lightened(0.25), half_cycle
	)
	_pulse_tween.tween_property(self, "_size_factor", 1.05, half_cycle)
	_pulse_tween.chain().tween_property(self, "modulate", _rest_color(), half_cycle)
	_pulse_tween.parallel().tween_property(self, "_size_factor", 1.0, half_cycle)


func _rest_color() -> Color:
	if _is_full():
		return _base_tint * ready_tint
	var ratio := clampf(_current / _maximum, 0.0, 1.0) if _maximum > 0.0 else 0.0
	return _base_tint * empty_tint.lerp(Color(0.90, 0.85, 1.0), ratio)


func _is_full() -> bool:
	return _maximum > 0.0 and _current >= _maximum


func _stop_animations() -> void:
	for animation: Tween in [_feedback_tween, _pulse_tween]:
		if animation != null and animation.is_valid():
			animation.kill()


func _on_visibility_changed() -> void:
	_settle()
