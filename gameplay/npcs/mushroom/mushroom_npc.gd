class_name MushroomNpc
extends BaseNpc

## Concrete NPC behavior for the Mushroom. Its tunable values live in
## MushroomNpcData, while BaseNpc owns the shared movement and dialogue flow.

@export_group("Mushroom NPC")
@export var data: MushroomNpcData


func _ready() -> void:
	if data == null:
		push_error("MushroomNpc: MushroomNpcData must be assigned")
		set_physics_process(false)
		return
	super()


func get_npc_data() -> NpcData:
	return data


func get_mushroom_data() -> MushroomNpcData:
	return data
