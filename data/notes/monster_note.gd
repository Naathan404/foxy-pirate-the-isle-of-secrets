class_name MonsterNote
extends Resource
## One bestiary entry. Unlock defaults are authored here; runtime overrides live in the tab.

enum Layout { MONSTER, BOSS }

@export var note_id: StringName
@export var display_name: String = "New entry"
@export var unlocked: bool = false
@export var layout: Layout = Layout.MONSTER
## Optional item presentation for this note; defaults to the standard note or boss diary.
@export var pickup_item: BaseItem
@export var portrait: Texture2D
@export var enemy_data: EnemyData
@export_multiline var description: String = ""
## Optional lore shown in the boss layout.
@export_multiline var story: String = ""
@export_multiline var behavior: String = ""
@export_multiline var strategy: String = ""
