class_name RaidBoulderGate
extends Node3D
## Boulders that rise out of the ground to shut an entrance, and sink again when it reopens.
## The solid blocker follows the boulders: it is only active while they are up.

signal raised
signal lowered

@export_range(0.5, 6.0, 0.1, "suffix:m") var buried_depth_meters: float = 3.0
@export_range(0.1, 3.0, 0.05, "suffix:s") var travel_seconds: float = 0.6
## Delay between neighbouring boulders, so the gate closes as a ripple, not one block.
@export_range(0.0, 0.5, 0.01, "suffix:s") var stagger_seconds: float = 0.12

var _tween: Tween
var _boulders: Array[Node3D] = []

@onready var _blocker: StaticBody3D = $Blocker


func _ready() -> void:
	for child in get_children():
		if child is Node3D and child != _blocker:
			_boulders.append(child as Node3D)
	_set_blocking(false)
	_set_boulder_heights(-buried_depth_meters)
	visible = false


## Closes the gate. The blocker turns solid right away, so nothing walks through while
## the boulders are still rising.
func raise() -> void:
	_set_blocking(true)
	visible = true
	_travel(0.0, Tween.EASE_OUT, raised)


func lower() -> void:
	_travel(-buried_depth_meters, Tween.EASE_IN, lowered)
	_set_blocking(false)


## Jumps straight to the closed state, for a gate that already stood when the room was entered.
func set_closed_immediately() -> void:
	_kill_tween()
	_set_blocking(true)
	_set_boulder_heights(0.0)
	visible = true


## Jumps straight to the open state, for rooms entered after the raid was cleared.
func set_open_immediately() -> void:
	_kill_tween()
	_set_blocking(false)
	_set_boulder_heights(-buried_depth_meters)
	visible = false


func _travel(target_y: float, easing: Tween.EaseType, finished: Signal) -> void:
	_kill_tween()
	_tween = create_tween().set_parallel()
	for index in _boulders.size():
		var step := _tween.tween_property(_boulders[index], "position:y", target_y, travel_seconds)
		step.set_trans(Tween.TRANS_BACK).set_ease(easing).set_delay(stagger_seconds * index)
	_tween.chain().tween_callback(_on_travel_finished.bind(finished))


func _on_travel_finished(finished: Signal) -> void:
	if finished == lowered:
		visible = false
	finished.emit()


func _set_blocking(blocking: bool) -> void:
	for shape in _blocker.find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).set_deferred("disabled", not blocking)


func _set_boulder_heights(height: float) -> void:
	for boulder in _boulders:
		boulder.position.y = height


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
