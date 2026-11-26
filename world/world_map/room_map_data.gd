@tool
class_name RoomMapData
extends Resource
## One room on the world map. `exits` and `safe_room` are copied from the room scene by
## WorldMapSync; `cell`, `hidden` and `marker` are authored and survive every sync.

enum Direction { UP, RIGHT, DOWN, LEFT }
enum Marker { NONE, CHECKPOINT, NPC }

const DIRECTION_OFFSETS: Dictionary[Direction, Vector2i] = {
	Direction.UP: Vector2i.UP,
	Direction.RIGHT: Vector2i.RIGHT,
	Direction.DOWN: Vector2i.DOWN,
	Direction.LEFT: Vector2i.LEFT,
}

@export_file("*.tscn") var scene_path: String = ""
## Grid position inside the biome; x grows right, y grows down.
@export var cell: Vector2i = Vector2i.ZERO
## Hidden rooms are not drawn at all until the player has entered them.
@export var hidden: bool = false
@export var marker: Marker = Marker.NONE
## Mirrors the scene's `BaseRoom.safe_room`: a place to rest, shown with a campfire badge.
@export var safe_room: bool = false
## Open exits of the scene: direction -> destination scene path.
@export var exits: Dictionary[Direction, String] = {}


static func offset_of(direction: Direction) -> Vector2i:
	return DIRECTION_OFFSETS[direction]
