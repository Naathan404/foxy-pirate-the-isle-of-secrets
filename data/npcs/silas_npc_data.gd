class_name SilasNpcData
extends NpcData

## Merchant-specific dialogue and roaming configuration. Hideout positions belong
## to the Hub scene because they are world coordinates, not reusable NPC data.

@export_group("Silas Dialogue")
@export_file("*.dtl") var greeting_timeline: String
@export_file("*.dtl") var farewell_timeline: String

@export_group("Silas Wander")
@export_range(0.0, 20.0, 0.1, "suffix:m") var wander_radius := 4.0
@export_range(0.1, 60.0, 0.1, "suffix:s") var wander_move_duration_min := 1.0
@export_range(0.1, 60.0, 0.1, "suffix:s") var wander_move_duration_max := 3.0
@export_range(0.1, 60.0, 0.1, "suffix:s") var wander_rest_duration_min := 1.0
@export_range(0.1, 60.0, 0.1, "suffix:s") var wander_rest_duration_max := 3.0
