class_name HealthComponent
extends Node

signal hp_changed(current_hp: int, max_hp: int)
signal damaged(applied_hp: int)
signal healed(applied_hp: int)
signal died

var current_hp: int:
	get:
		return _current_hp

var _current_hp: int = 0
var _max_hp: int = 0
var _configured: bool = false


# khởi tạo
func init(max_hp: int) -> bool:
	if _configured:
		push_error("HealthComponent: init() chỉ được gọi 1 lần")
		return false
	if max_hp <= 0:
		push_error("HealthComponent: max_hp phải lớn hơn 0")
		return false
	_max_hp = max_hp
	_current_hp = _max_hp
	_configured = true
	hp_changed.emit(_current_hp, _max_hp)
	return true

# gọi khi hồi máu -> trả về lượng hp thực sự hồi
func heal(amount: int) -> int:
	if not is_alive() or amount <= 0:
		return 0
	var applied = mini(amount, _max_hp - _current_hp)
	if applied > 0:
		_current_hp += applied
		hp_changed.emit(_current_hp, _max_hp)
		healed.emit(applied)
	return applied

# gọi khi trừ máu -> trả về lượng hp bị mất
func take_damage(amount: int) -> int:
	if not is_alive() or amount <= 0:
		return 0
	var applied = mini(amount, _current_hp)
	_current_hp -= applied
	# Chot viec chet truoc khi phat signal, tranh bao chet hai lan neu signal gay them damage.
	var killed = _current_hp == 0
	hp_changed.emit(_current_hp, _max_hp)
	damaged.emit(applied)
	if killed:
		died.emit()
	return applied


# helpers
func get_current_hp() -> int:
	return _current_hp
func get_max_hp() -> int:
	return _max_hp
func is_alive() -> bool:
	return _configured and _current_hp > 0
