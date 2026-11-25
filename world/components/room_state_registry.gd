class_name RoomStateRegistry
extends RefCounted
## What has changed in the rooms the player visited, owned by GameManager so it survives
## scene changes. Objects are keyed by room scene path plus the NodePath from the room root.
##
## A world cycle lasts from one rest (campfire rest, death or New Game) to the next:
## - Cleared objects (killed enemies, broken props) stay gone only for the cycle.
## - Permanent objects (opened chests) stay changed for the whole run and are saved.
## - The cycle seed drives every room's random layout, so a room looks the same whenever
##   it is entered again within a cycle and is reshuffled by the next rest.

## Seeds stay below 2^31 so they survive a JSON round trip exactly.
const MAX_SEED := 2147483647

## Increases on every new cycle; a room built in an older cycle must not record into it.
var cycle: int = 0
var cycle_seed: int = 0
## Campfire of the latest rest ({"scene", "rest_point"}); empty until the first rest.
var rest_location: Dictionary = {}
var _cleared: Dictionary[String, Dictionary] = {}
var _permanent: Dictionary[String, Dictionary] = {}


func _init() -> void:
	cycle_seed = _roll_seed()


## Starts a fresh cycle: cleared objects return and every room is reshuffled.
## Permanent changes are kept.
func begin_new_cycle(location: Dictionary) -> void:
	cycle += 1
	cycle_seed = _roll_seed()
	_cleared.clear()
	rest_location = location.duplicate()


func is_cleared(scene_path: String, key: String) -> bool:
	return _cleared.has(scene_path) and _cleared[scene_path].has(key)


func mark_cleared(scene_path: String, key: String, built_cycle: int) -> void:
	if built_cycle != cycle or scene_path.is_empty() or key.is_empty():
		return
	if not _cleared.has(scene_path):
		_cleared[scene_path] = {}
	_cleared[scene_path][key] = true


func is_permanent(scene_path: String, key: String) -> bool:
	return _permanent.has(scene_path) and _permanent[scene_path].has(key)


func mark_permanent(scene_path: String, key: String) -> void:
	if scene_path.is_empty() or key.is_empty():
		return
	if not _permanent.has(scene_path):
		_permanent[scene_path] = {}
	_permanent[scene_path][key] = true


## Deterministic seed for one random source in one room during this cycle.
func seed_for(scene_path: String, source_key: String) -> int:
	return hash([cycle_seed, scene_path, source_key])


## Cleared objects are not saved: a save is always written right after a rest, which has
## already started a new cycle.
func get_save_data() -> Dictionary:
	var permanent := {}
	for scene_path: String in _permanent:
		var keys: Array[String] = []
		keys.assign(_permanent[scene_path].keys())
		keys.sort()
		permanent[scene_path] = keys
	return {"seed": cycle_seed, "permanent": permanent}


## Expects data already checked by GameSaveSnapshot.
func restore_save_data(saved: Dictionary, location: Dictionary) -> void:
	cycle += 1
	cycle_seed = int(saved.seed)
	_cleared.clear()
	_permanent.clear()
	for scene_path: String in saved.permanent:
		for key: Variant in saved.permanent[scene_path]:
			mark_permanent(scene_path, String(key))
	rest_location = location.duplicate()


static func _roll_seed() -> int:
	return randi() % MAX_SEED
