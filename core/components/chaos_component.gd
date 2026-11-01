class_name ChaosComponent
extends Node

signal chaos_changed(current: float, maximum: float)
signal decay_started

@export_group("Out-of-Combat Decay")
@export_range(0.0, 60.0, 0.5, "suffix:s") var idle_decay_delay: float = 6.0
@export_range(0.0, 100.0, 0.5, "suffix:%/s") var idle_decay_percent_per_second: float = 3.0

var current: float = 0.0
var maximum: float = 100.0
var _idle_remaining: float = 0.0
var _decay_active: bool = false


func init(capacity: float) -> void:
	maximum = maxf(0.0, capacity)
	current = 0.0
	notify_combat_activity()
	chaos_changed.emit(current, maximum)


## Confirmed damage, including hits at full CP, restarts the grace period.
func notify_combat_activity() -> void:
	_idle_remaining = maxf(0.0, idle_decay_delay)
	_decay_active = false


## The owning Player advances this only while gameplay and passive decay are allowed.
func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var decay_seconds := maxf(0.0, delta - _idle_remaining)
	_idle_remaining = maxf(0.0, _idle_remaining - delta)
	var decay_amount := maximum * maxf(0.0, idle_decay_percent_per_second) * 0.01 * decay_seconds
	if decay_amount > 0.0 and current > 0.0:
		if not _decay_active:
			_decay_active = true
			decay_started.emit()
		consume(decay_amount)


func gain(amount: float) -> void:
	var next = clampf(current + maxf(0.0, amount), 0.0, maximum)
	if next == current:
		return
	current = next
	chaos_changed.emit(current, maximum)


func is_full() -> bool:
	return maximum > 0.0 and current >= maximum


## Partial expenditure for sustained skills; returns the actual CP spent.
func consume(amount: float) -> float:
	if not is_finite(amount) or amount <= 0.0:
		return 0.0
	var spent := minf(current, amount)
	if spent > 0.0:
		current = maxf(0.0, current - spent)
		chaos_changed.emit(current, maximum)
	return spent


func try_consume_full() -> bool:
	if not is_full():
		return false
	current = 0.0
	chaos_changed.emit(current, maximum)
	return true
