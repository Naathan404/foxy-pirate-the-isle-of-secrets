class_name NpcTalk
extends NpcState


func _enter() -> void:
	npc.stop_movement()
	npc.play_directional_animation(&"idle")


func _update(delta: float) -> void:
	npc.stop_movement(delta)
	npc.play_directional_animation(&"idle")
