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


func try_consume_full() -> bool:
	if not is_full():
		return false
	current = 0.0
	chaos_changed.emit(current, maximum)
	return true
