class_name RaidSpawnSpec
extends Resource
## One enemy of a raid wave: what rises, where, and when. Positions are planned rather than
## random so each wave reads as a deliberate move (an ambush, a pincer, a firing line).

enum Anchor {
	## Around Foxy at the moment the spawn is scheduled.
	PLAYER,
	## Around the centre of the island (the spawner's position).
	ISLAND_CENTER,
}

@export var scene: PackedScene
## Elites get a longer, stronger telegraph and a heavier landing shake.
@export var is_elite: bool = false
@export var anchor: Anchor = Anchor.PLAYER
## Horizontal offset from the anchor: x points east (screen right), y points south
## (towards the camera). Unreachable points are pulled back towards the island centre.
@export var offset_meters: Vector2 = Vector2.ZERO
## Time after the wave's lead-in before this spawn point starts to crack.
@export_range(0.0, 10.0, 0.05, "suffix:s") var delay_seconds: float = 0.0
