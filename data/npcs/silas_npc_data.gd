class_name SilasNpcData
extends NpcData

## Merchant-specific dialogue configuration. Hideout positions belong
## to the Hub scene because they are world coordinates, not reusable NPC data.

@export_group("Silas Dialogue")
@export_file("*.dtl") var greeting_timeline: String
@export_file("*.dtl") var farewell_timeline: String
