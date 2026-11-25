extends Node3D

const PROP_SCENES: Array[PackedScene] = [
	preload("res://world/biomes/coral_valley/objects/shell.tscn"),
	preload("res://world/biomes/coral_valley/objects/stone.tscn"),
	preload("res://world/biomes/coral_valley/objects/octopus.tscn"),
]

const CORAL_SCENES: Array[PackedScene] = [
	preload("res://world/biomes/coral_valley/objects/beach_coral_orange.tscn"),
	preload("res://world/biomes/coral_valley/objects/beach_coral_pink.tscn"),
	preload("res://world/biomes/coral_valley/objects/beach_coral_turquoise.tscn"),
]

@export var spawn_positions: PackedVector3Array
@export var fixed_spawn_count := 0
@export var prop_scenes: Array[PackedScene] = PROP_SCENES.duplicate()
@export var include_coral: bool = false
# //NLVP sửa: Cho phép cấu hình nhóm chỉ sinh 1–3 vật thể.
@export_range(1, 64, 1) var min_spawn_count := 3
@export_range(1, 64, 1) var max_spawn_count := 6
## Spawned destructible props also take damage from enemy and boss attacks.
@export var props_receive_enemy_attacks := false


## Spawns use the room's cycle seed: the same props and enemies appear whenever the room is
## re-entered, and a new mix appears after the next campfire rest or death. Spawned children
## get stable names, so the room can remember which of them were killed or broken.
func _ready() -> void:
	var scenes := prop_scenes.filter(func(scene: PackedScene) -> bool: return scene != null)
	if include_coral:
		scenes.append_array(CORAL_SCENES)
	if scenes.is_empty():
		return
	var random := BaseRoom.create_random(self)
	var positions := Array(spawn_positions)
	_shuffle(positions, random)
	var count := (
		fixed_spawn_count
		if fixed_spawn_count > 0
		else random.randi_range(min_spawn_count, maxi(min_spawn_count, max_spawn_count))
	)
	for index in mini(count, positions.size()):
		var scene: PackedScene = scenes[random.randi_range(0, scenes.size() - 1)]
		var prop := scene.instantiate() as Node3D
		prop.position = positions[index]
		if props_receive_enemy_attacks and "receives_enemy_attacks" in prop:
			prop.set("receives_enemy_attacks", true)
		add_child(prop, true)


## Fisher-Yates with the seeded source; Array.shuffle() would use the global generator.
func _shuffle(values: Array, random: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var other := random.randi_range(0, index)
		var held: Variant = values[index]
		values[index] = values[other]
		values[other] = held
