class_name MonsterNote
extends Resource
## One bestiary entry. Unlock defaults are authored here; runtime overrides live in the tab.

enum Layout { MONSTER, BOSS }

@export var note_id: StringName
@export var display_name: String = "New entry"
@export var unlocked: bool = false
@export var layout: Layout = Layout.MONSTER
@export var portrait: Texture2D
@export var enemy_data: EnemyData
@export_multiline var description: String = ""
@export_multiline var behavior: String = ""
@export_multiline var strategy: String = ""
