extends Node

@export var hitbox: HitBox
@export_range(0.0, 1.0, 0.01) var hitstop_duration: float = 0.05

@export_group("Screen Shake")
## Độ rung tính theo pixel tại mặt phẳng nhân vật, đặt 0 để tắt.
@export_range(0.0, 30.0, 0.5) var shake_pixels: float = 3.0
@export_range(0.0, 1.0, 0.01) var shake_duration: float = 0.14


func _ready() -> void:
	if not is_instance_valid(hitbox):
		push_warning("CombatFeedback: chưa gán HitBox")
		return

	hitbox.hit_confirmed.connect(_on_hit_confirmed)


func _on_hit_confirmed(damage: DamageContext, _target: Node, applied_hp: float) -> void:
	if applied_hp <= 0.0:
		return
	var impact_scale := damage.get_impact_scale()
	# Resolve at runtime so preloading weapon resources before autoload setup remains valid.
	var hitstop := get_node("/root/HitstopController")
	var shake := get_node("/root/ScreenShakeController")
	# Normalize authored values to effective caps before scaling, so weaker forges remain
	# perceptibly weaker even when a scene's baseline already exceeds the controller limit.
	var base_hitstop := minf(hitstop_duration, float(hitstop.maximum_duration))
	var base_shake := minf(shake_pixels, float(shake.maximum_pixels))
	hitstop.request(base_hitstop * impact_scale)
	shake.request(base_shake * impact_scale, shake_duration)
