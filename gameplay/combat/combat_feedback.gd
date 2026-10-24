extends Node

@export var hitbox: HitBox
@export_range(0.0, 0.3, 0.01) var hitstop_duration: float = 0.05

@export_group("Screen Shake")
## Độ rung tính theo pixel tại mặt phẳng nhân vật, đặt 0 để tắt.
@export_range(0.0, 12.0, 0.5) var shake_pixels: float = 3.0
@export_range(0.0, 0.5, 0.01) var shake_duration: float = 0.14


func _ready() -> void:
	if not is_instance_valid(hitbox):
		push_warning("CombatFeedback: chưa gán HitBox")
		return

	hitbox.hit_confirmed.connect(_on_hit_confirmed)


func _on_hit_confirmed(_damage: DamageContext, _target: Node, _applied_hp: int) -> void:
	HitstopController.request(hitstop_duration)
	ScreenShakeController.request(shake_pixels, shake_duration)
