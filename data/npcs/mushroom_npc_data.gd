class_name MushroomNpcData
extends NpcData

## Configuration owned only by Mushroom NPC instances. Base NpcData keeps the
## attributes every friendly NPC shares.

@export_group("Mushroom Wander Bounds")
## A radius of 0 keeps the Mushroom on an unbounded straight-line patrol.
@export_range(0.0, 100.0, 0.1, "suffix:m") var wander_radius := 3.0

@export_group("Mushroom Wander Movement")
@export var wander_turn_on_wall := true
@export var wander_turn_at_ledge := true
@export_range(0.0, 10.0, 0.1) var wander_speed_scale := 1.0

@export_group("Mushroom Wander Timing")
@export_range(0.1, 60.0, 0.1, "suffix:s") var wander_move_duration_min := 1.0
@export_range(0.1, 60.0, 0.1, "suffix:s") var wander_move_duration_max := 3.0
@export_range(0.1, 60.0, 0.1, "suffix:s") var wander_rest_duration_min := 1.0
@export_range(0.1, 60.0, 0.1, "suffix:s") var wander_rest_duration_max := 3.0
