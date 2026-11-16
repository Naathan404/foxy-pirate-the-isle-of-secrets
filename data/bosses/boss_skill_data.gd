class_name BossSkillData
extends Resource

## Common tuning only. Extend this resource for a boss's own skill parameters.
@export var display_name: String = ""
@export_range(0.0, 1000.0, 0.5) var damage: float = 10.0
@export_range(0.05, 10.0, 0.05) var windup: float = 1.0
@export_range(0.0, 10.0, 0.1) var recovery: float = 1.0
