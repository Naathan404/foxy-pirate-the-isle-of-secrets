class_name GlacialSpike
extends Node3D
## Grow the crystals from the ground while the ice chips follow their own trajectories.

signal raised

const RISE_SECONDS := 0.09
const HOLD_SECONDS := 0.34
const MELT_SECONDS := 0.2

@onready var _crystals: Node3D = $Crystals


func _ready() -> void:
	_crystals.scale.y = 0.03
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(_crystals, "scale:y", 1.0, RISE_SECONDS).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(raised.emit)
	tween.tween_interval(HOLD_SECONDS)
	tween.tween_property(_crystals, "scale", Vector3.ZERO, MELT_SECONDS).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(queue_free)
