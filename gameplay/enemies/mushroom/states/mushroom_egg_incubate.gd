class_name MushroomEggIncubate
extends EnemyState
## Trạng thái ủ mầm của Trứng Nấm: đứng yên tại chỗ rung nhẹ và phát sáng mạnh dần,
## nếu Player không tiêu diệt kịp thì nở ra Mushroom bình thường.


func _enter() -> void:
	var egg := enemy as MushroomEgg
	if egg == null:
		return
	egg.stop_movement()
	egg.play_directional_animation(&"idle", true)


func _exit() -> void:
	var egg := enemy as MushroomEgg
	if egg != null:
		egg.reset_incubation_visual()


func _update(delta: float) -> void:
	var egg := enemy as MushroomEgg
	if egg == null or egg.dead:
		return
	var step := maxf(0.0, delta)
	egg.stop_movement(step)
	egg.advance_incubation(step)
	if egg.is_about_to_hatch():
		egg.play_directional_animation(&"hatch_soon")
	else:
		egg.play_directional_animation(&"idle")
	if egg.is_ready_to_hatch():
		egg.hatch_into_mushroom()
