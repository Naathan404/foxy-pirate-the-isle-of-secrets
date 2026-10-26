class_name BaseItem
extends Resource

@export var item_id: String = "item_id"
@export var display_name: String = "Base Item"
@export var icon: Texture2D = null
@export_multiline var description: String = &""
@export_range(1, 99, 1) var max_stack: int = 1
