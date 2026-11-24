class_name PropPool
extends Resource
## Interchangeable props a PropSlot may place. Keep entries of one size class and one
## collision kind (all walk-through decor, or all small breakables), and of one room
## pattern, so any pick keeps the room's paths, clusters and prop budget intact.

## Repeat a scene to make it more likely.
@export var scenes: Array[PackedScene] = []
## Chance that the slot stays empty this cycle, so areas vary between sparse and dense.
@export_range(0.0, 1.0, 0.01) var empty_chance: float = 0.0


## Null means the slot stays empty.
func pick(random: RandomNumberGenerator) -> PackedScene:
	var candidates := scenes.filter(func(scene: PackedScene) -> bool: return scene != null)
	if candidates.is_empty() or random.randf() < empty_chance:
		return null
	return candidates[random.randi_range(0, candidates.size() - 1)]
