class_name ChaosComponent
extends Node

signal chaos_changed(current: float, maximum: float)

var current: float = 0.0
var maximum: float = 100.0


func init(capacity: float) -> void:
	maximum = maxf(0.0, capacity)
	current = 0.0
	chaos_changed.emit(current, maximum)


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
