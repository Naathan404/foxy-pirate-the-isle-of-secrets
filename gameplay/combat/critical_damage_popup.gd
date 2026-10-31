extends Label3D
## Owned by the world so killing/freeing the enemy does not remove its damage number.

@export var rise_units: float = 0.85
@export var lifetime: float = 0.7


func show_damage(amount_hp: float) -> void:
	text = ("%.2f" % amount_hp).trim_suffix("0").trim_suffix("0").trim_suffix(".")
	var start := position
	var sideways := Vector3(randf_range(-0.25, 0.25), 0.0, randf_range(-0.12, 0.12))
	var motion := create_tween()
	(
		motion
		. tween_property(
			self, "position", start + sideways + Vector3.UP * rise_units, lifetime * 0.35
		)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		motion
		. tween_property(
			self,
			"position",
			start + sideways * 1.5 + Vector3.UP * rise_units * 0.55,
			lifetime * 0.65
		)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	var fade := create_tween()
	fade.tween_interval(lifetime * 0.55)
	fade.tween_property(self, "modulate:a", 0.0, lifetime * 0.45)
	fade.tween_callback(queue_free)
	scale = Vector3.ONE * 0.65
	var pop := create_tween()
	pop.tween_property(self, "scale", Vector3.ONE * 1.2, 0.1).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	pop.tween_property(self, "scale", Vector3.ONE, 0.12)
