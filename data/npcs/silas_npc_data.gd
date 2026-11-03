class_name SilasNpcData
extends NpcData

## Merchant-specific dialogue configuration. Silas stays at the scene's spawn position.

@export_group("Silas Dialogue")
@export_file("*.dtl") var greeting_timeline: String
@export_file("*.dtl") var farewell_timeline: String
