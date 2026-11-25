class_name RaidWave
extends Resource
## A scripted raid wave: a short ground rumble, then each `RaidSpawnSpec` rises in turn.

## Designer note on what the wave is meant to do; not shown in game.
@export_multiline var intent: String = ""
## Rumble before the first crack, so Foxy knows a wave is coming.
@export_range(0.0, 3.0, 0.05, "suffix:s") var lead_in_seconds: float = 0.6
@export var spawns: Array[RaidSpawnSpec] = []
