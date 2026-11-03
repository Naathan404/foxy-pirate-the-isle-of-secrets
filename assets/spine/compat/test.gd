extends Node3D

func _ready() -> void:
	if not $Foxy.set_animation("animation", true, 0):
		push_error("Foxy: could not start animation")
