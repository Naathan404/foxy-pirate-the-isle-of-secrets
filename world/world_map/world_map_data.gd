@tool
class_name WorldMapData
extends Resource
## Every biome shown on the world map. Rooms and exits come from the room scenes;
## press "Sync rooms from scenes" on the WorldMapCanvas node to refresh them.

@export_dir var biomes_root: String = "res://world/biomes"
@export var biomes: Array[BiomeMapData] = []


func find_biome(biome_id: StringName) -> BiomeMapData:
	for biome: BiomeMapData in biomes:
		if biome.biome_id == biome_id:
			return biome
	return null


func find_room(scene_path: String) -> RoomMapData:
	var biome := find_biome_of_room(scene_path)
	return null if biome == null else biome.find_room(scene_path)


func find_biome_of_room(scene_path: String) -> BiomeMapData:
	for biome: BiomeMapData in biomes:
		if biome.find_room(scene_path) != null:
			return biome
	return null


## Pairs of biomes joined by at least one room exit, each pair listed once.
func get_biome_links() -> Array[Vector2i]:
	var links: Array[Vector2i] = []
	for from_index in biomes.size():
		for room: RoomMapData in biomes[from_index].rooms:
			for destination: String in room.exits.values():
				var to_index := biomes.find(find_biome_of_room(destination))
				if to_index <= from_index:
					continue
				var link := Vector2i(from_index, to_index)
				if not links.has(link):
					links.append(link)
	return links


## Rooms the player has not entered but knows about: a door of an entered room leads there
## (or one of their own doors leads to an entered room). Hidden rooms never qualify, and
## rooms further away are unknown, so the explored area is wrapped in a single ring.
func get_frontier_rooms(progress: MapProgress) -> Dictionary[String, bool]:
	var frontier: Dictionary[String, bool] = {}
	for biome: BiomeMapData in biomes:
		for room: RoomMapData in biome.rooms:
			for destination: String in room.exits.values():
				var other := find_room(destination)
				if other == null:
					continue
				_mark_if_frontier(room, other, progress, frontier)
				_mark_if_frontier(other, room, progress, frontier)
	return frontier


func _mark_if_frontier(
	visited: RoomMapData,
	candidate: RoomMapData,
	progress: MapProgress,
	frontier: Dictionary[String, bool]
) -> void:
	if (
		progress.has_visited(visited.scene_path)
		and not progress.has_visited(candidate.scene_path)
		and not candidate.hidden
	):
		frontier[candidate.scene_path] = true
