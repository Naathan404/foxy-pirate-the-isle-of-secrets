extends Node3D
## Presentation only: combat damage and its radius stay in boss_hazard.gd.

@onready var sprite: AnimatedSprite3D = $Explosion
@onready var light: OmniLight3D = $Flash


func _ready() -> void:
	sprite.animation_finished.connect(queue_free)
	sprite.play(&"explode")
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.4).set_ease(Tween.EASE_OUT)
