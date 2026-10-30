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

@export_group("Wander")
@export var wander_turn_on_wall: bool = true
@export var wander_turn_at_ledge: bool = true
@export_range(0.0, 10.0, 0.1) var wander_speed_scale: float = 1.0
@export_range(0.1, 60.0, 0.1, "suffix:s") var wander_move_duration_min: float = 1.0
@export_range(0.1, 60.0, 0.1, "suffix:s") var wander_move_duration_max: float = 3.0
@export_range(0.1, 60.0, 0.1, "suffix:s") var wander_rest_duration_min: float = 1.0
@export_range(0.1, 60.0, 0.1, "suffix:s") var wander_rest_duration_max: float = 3.0
