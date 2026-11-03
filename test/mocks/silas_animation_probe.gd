class_name SilasAnimationProbe
extends SilasNpc

var started_timelines: Array[String] = []
var shop_opened := false


func _start_dialogue(_interactor: Player, timeline_path: String = "") -> bool:
	started_timelines.append(timeline_path)
	is_talking = true
	return true


func _open_shop(_interactor: Player) -> void:
	shop_opened = true
