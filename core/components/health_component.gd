class_name HealthComponent
extends Node

signal hp_changed(current_hp: float, max_hp: float)
signal damaged(applied_hp: float)
signal healed(applied_hp: float)
signal died

## Only absorb arithmetic residue; Godot's general comparison tolerance is too wide for HP.
const LETHAL_RELATIVE_TOLERANCE: float = 1e-12

var current_hp: float:
	get:
		return _current_hp

var _current_hp: float = 0
var _max_hp: float = 0
var _base_max_hp: float = 0
var _max_modifiers: Dictionary[StringName, float] = {}
var _configured: bool = false


# khởi tạo
func init(max_hp: float) -> bool:
	if _configured:
		push_error("HealthComponent: init() chỉ được gọi 1 lần")
		return false
	if not is_finite(max_hp) or max_hp <= 0.0:
		push_error("HealthComponent: max_hp phải lớn hơn 0")
		return false
	_max_hp = max_hp
	_base_max_hp = max_hp
	_current_hp = _max_hp
	_configured = true
	hp_changed.emit(_current_hp, _max_hp)
	return true


# gọi khi hồi máu -> trả về lượng hp thực sự hồi
func heal(amount: float) -> float:
	if not is_alive() or not is_finite(amount) or amount <= 0.0:
		return 0
	var applied := minf(amount, _max_hp - _current_hp)
	if applied > 0:
		_current_hp += applied
		hp_changed.emit(_current_hp, _max_hp)
		healed.emit(applied)
	return applied


# gọi khi trừ máu -> trả về lượng hp bị mất
func take_damage(amount: float) -> float:
	if not is_alive() or not is_finite(amount) or amount <= 0.0:
		return 0
	var applied := minf(amount, _current_hp)
	# Decimal damage must not leave an enemy alive with rounding residue near zero.
	var residue := _current_hp - applied
	if residue <= _current_hp * LETHAL_RELATIVE_TOLERANCE:
		applied = _current_hp
	_current_hp = maxf(0.0, _current_hp - applied)
	# Chot viec chet truoc khi phat signal, tranh bao chet hai lan neu signal gay them damage.
	var killed = _current_hp == 0
	hp_changed.emit(_current_hp, _max_hp)
	damaged.emit(applied)
	if killed:
		died.emit()
	return applied


func set_max_hp_modifier(source: StringName, bonus: float) -> void:
	if _configured and not source.is_empty() and is_finite(bonus):
		_max_modifiers[source] = bonus
		_refresh_max_hp()


func remove_max_hp_modifier(source: StringName) -> void:
	if _max_modifiers.erase(source):
		_refresh_max_hp()


func _refresh_max_hp() -> void:
	_max_hp = _base_max_hp
	for bonus: float in _max_modifiers.values():
		_max_hp += bonus
	_max_hp = maxf(0.01, _max_hp)
	_current_hp = minf(_current_hp, _max_hp)
	hp_changed.emit(_current_hp, _max_hp)


# helpers
func get_current_hp() -> float:
	return _current_hp


func get_max_hp() -> float:
	return _max_hp


func is_alive() -> bool:
	return _configured and _current_hp > 0
