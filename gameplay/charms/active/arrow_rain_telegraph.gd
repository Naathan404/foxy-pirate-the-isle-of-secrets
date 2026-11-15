class_name ArrowRainTelegraph
extends Node3D
## Vòng báo trước phạm vi rơi của Arrow Rain.

@export var radius: float = 2.0
@export var lifetime: float = 1.7
@export var ring_color: Color = Color(1.0, 0.65, 0.2, 0.7)


func _ready() -> void:
	CharmVfx.spawn(self, global_position, ring_color, radius, lifetime, CharmVfx.Style.TARGET)
	get_tree().create_timer(lifetime).timeout.connect(queue_free, CONNECT_ONE_SHOT)
