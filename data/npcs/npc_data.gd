class_name NpcData
extends Resource

## Shared configuration for friendly NPC types. Keep scene-only concerns
## (sprite, collider, spawn position and available FSM states) in the scene.

@export_group("Identity")
@export var display_name: String = "NPC"
@export_multiline var description: String

@export_group("Movement")
@export_range(0.0, 100.0, 0.1) var move_speed: float = 1.5
@export_range(0.0, 100.0, 0.1) var acceleration: float = 12.0
@export_range(0.0, 100.0, 0.1) var deceleration: float = 18.0

@export_group("Dialogue")
## The default conversation for this NPC. Quest-specific scripts can start a
## different timeline when their progression conditions require it.
@export_file("*.dtl") var dialogue_timeline: String
