class_name ChestNoteDrop
extends Resource
## Select the actual bestiary entry; no handwritten ID is needed.
@export var note: MonsterNote
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0
