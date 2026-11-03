class_name SilasHidden
extends NpcState

## Owns the off-screen wait after Silas burrows to another hideout.


func _enter() -> void:
	var silas := npc as SilasNpc
	if silas == null:
		push_error("SilasHidden must be used by SilasNpc")
		return
	silas.enter_hidden_state()


func _update(_delta: float) -> void:
	var silas := npc as SilasNpc
	if silas != null:
		silas.update_hidden_state()
