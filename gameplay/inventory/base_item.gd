class_name BaseItem
extends Resource

@export var item_id: String = "item_id"
@export var display_name: String = "Base Item"
@export var icon: Texture2D = null
@export_multiline var description: String = &""
@export_range(1, 99, 1) var max_stack: int = 1
@export var type: GlobalConstants.ItemType = GlobalConstants.ItemType.MATERIAL
## Notes and diaries must be collected through a pickup linked to a bestiary entry.
@export var opens_note: bool = false
## If set, collecting this item grants the registered playable Charm instead of inventory.
@export var charm: CharmData
## Blueprint pickups unlock crafting permission without occupying inventory.
@export var weapon_blueprint: WeaponData
