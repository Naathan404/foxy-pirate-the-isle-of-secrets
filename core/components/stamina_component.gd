class_name StaminaComponent
extends Node

signal stamina_changed(current_sp: float, max_sp: float)

var current_sp: float:
	get:
		return _current_sp

var _current_sp: float = 0.0
var _max_sp: float = 0.0
# Max gốc ban đầu, chưa có thêm tăng/giảm bonus
var _base_max_sp: float = 0.0
# Mỗi nguồn có 1 bonus riêng, không ảnh hưởng đến cái khác
var _max_modifiers: Dictionary[StringName, float] = {}
### hồi phục sp
var _regen_rate: float = 0.0
var _regen_delay: float = 0.0
var _regeneration_enabled: bool = true
# thời gian chờ thêm trước khi bắt đầu hồi thể lực
var _delay_remaining: float = 0.0

var _configured: bool = false


func init(max_sp: float, regen_sp_per_sec: float, regen_delay_sec: float) -> void:
	if _configured:
		push_error("StaminaComponent: init() chỉ được gọi 1 lần")
		return

	_base_max_sp = maxf(0.0, max_sp)
	_max_sp = _base_max_sp
	_current_sp = _max_sp
	_regen_rate = maxf(0.0, regen_sp_per_sec)
	_regen_delay = maxf(0.0, regen_delay_sec)

	_configured = true

	stamina_changed.emit(_current_sp, _max_sp)


# Tăng thể lực tối đa, không tự hồi thể lực, không cộng dồn cùng 1 nguồn bonus
func set_max_sp_modifier(source: StringName, bonus: float) -> void:
	if _configured and not source.is_empty():
		_max_modifiers[source] = bonus
		_refresh_max_sp()


# loại bỏ bonus
func remove_max_sp_modifier(source: StringName) -> void:
	if _max_modifiers.erase(source):
		_refresh_max_sp()


# refresh sp tối đa
func _refresh_max_sp() -> void:
	_max_sp = _base_max_sp
	for bonus: float in _max_modifiers.values():
		_max_sp += bonus
	_max_sp = maxf(0.0, _max_sp)
	_current_sp = minf(_current_sp, _max_sp)
	stamina_changed.emit(_current_sp, _max_sp)


# check có thể tiêu thụ sp không
func can_consume(cost_sp: float) -> bool:
	return _configured and cost_sp >= 0.0 and _current_sp >= cost_sp


# tiêu thụ sp
func try_consume(cost_sp: float) -> bool:
	if not can_consume(cost_sp):
		return false
	if cost_sp > 0.0:
		_current_sp -= cost_sp
		_delay_remaining = _regen_delay
		stamina_changed.emit(_current_sp, _max_sp)
	return true


# bật công tắc hồi sp =)))
func set_regeneration_enabled(enabled: bool) -> void:
	_regeneration_enabled = enabled


# Update để hồi stamina
func _physics_process(delta: float) -> void:
	if not _configured or not _regeneration_enabled or delta <= 0.0:
		return
	# Neu het thoi gian cho giua frame, chi hoi trong phan thoi gian con lai cua frame do.
	var regen_delta := maxf(0.0, delta - _delay_remaining)
	_delay_remaining = maxf(0.0, _delay_remaining - delta)
	if regen_delta > 0.0 and _current_sp < _max_sp:
		var previous_sp := _current_sp
		_current_sp = minf(_max_sp, _current_sp + _regen_rate * regen_delta)
		if _current_sp != previous_sp:
			stamina_changed.emit(_current_sp, _max_sp)


# helpers
func get_current_sp() -> float:
	return _current_sp


func get_max_sp() -> float:
	return _max_sp
