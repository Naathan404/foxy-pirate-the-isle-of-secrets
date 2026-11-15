class_name ChestItemDrop
extends Resource
## Each entry rolls independently when the chest opens.
@export var item: BaseItem
@export_range(1, 999, 1) var quantity: int = 1
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0
